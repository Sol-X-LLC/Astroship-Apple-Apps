//  GameAI.swift
//  For use with the Astroship product line of Sol-X LLC
//
//  Created by Blaze Sanders on 2026-10-31
//  AI opponents filled in for issue #4 (SOFT-007).
//  For support email dev@astroship.store
//
//  Two solo opponents, both behind one protocol so a view model
//  can swap them and a future Foundation Model AI (SOFT-004) drops
//  in without touching the rest of the app:
//
//  - DumbScanAI, fires at random. The simplest opponent, for
//                   SOFT-002 / SOFT-008 and for debugging.
//  - CrissCrossAI, the default v2026.0 opponent (SOFT-007).
//                   Hunts on a 3D checkerboard, and on a hit works
//                   outward until the ship sinks, then hunts again.
//
//  Rules kept, from the PRD and the architecture doc:
//  * Fair play (SOFT-012). The AI is handed the whole GameState,
//    including the cells of ships it has not found. It must never
//    read them. Here it only ever looks at cells the game has
//    already revealed: hits, misses, and the cells of ships the
//    game itself has reported sunk (which are all hits already, so
//    reading them reveals nothing new). A `.ship` cell that has not
//    been hit is treated exactly like fog: unknown.
//  * Same rules as a human (SOFT-011). Every cell this returns is a
//    legal target for GameState.fire(at:), in bounds and not yet
//    fired at, so an AI shot goes through the same validation a
//    human tap does.
//  * Deterministic (SOFT-010). nextShot takes the random generator
//    by reference. Given the same GameState and the same seed it
//    always returns the same cell, so solo matches replay exactly
//    in tests. SeededGenerator below is that reproducible source.
//  * Radar-safe (SOFT-024). `.radar` and `.empty` cells are already
//    resolved, so they are never chosen.
//
//  Ships: the AI places straight-line ships only for now. The
//  X / T / Y footprints are still undefined in code (see the open
//  note in GameState.swift and Ship.swift), so AIFleet uses a
//  documented placeholder fleet of straight ships, lengths 2...5.
//  Swap in the real shapes once they are defined.

import Foundation

/// The skill level a solo opponent uses when none is chosen.
/// 0 is debug (never shown to the player); 1 is the minimum the
/// player sees; 10 plays its best (SOFT-009).
let DEFAULT_AI_SKILL_LEVEL = 5

// MARK: - Deterministic randomness (SOFT-010)

/// A small seeded random generator (SplitMix64). Swift's default
/// generator cannot be seeded, so tests could not replay a match.
/// This can: the same seed always yields the same sequence.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - The AI interface

/// A solo opponent. Given the board and which side it is firing at,
/// it returns the one cell to fire at next. Pure: it changes nothing
/// and reads only revealed information.
protocol GameAI {
    /// 0...10. Higher plays better. See SOFT-009.
    var skillLevel: Int { get }

    /// The next cell to fire at.
    /// - Parameters:
    ///   - state: the current match. Only revealed cells are read.
    ///   - side: the side being fired at (`.me` or `.opponent`),
    ///     i.e. whose grid to shoot.
    ///   - rng: the random source, by reference, for determinism.
    /// - Returns: a legal, not-yet-fired-at cell on that grid.
    func nextShot<R: RandomNumberGenerator>(
        on state: GameState,
        firingAt side: Side,
        using rng: inout R
    ) -> GridPoint
}

// MARK: - DumbScanAI (SOFT-008)

/// Fires at a random cell the game has not resolved. No memory, no
/// targeting. The easiest opponent and a baseline for tests.
struct DumbScanAI: GameAI {
    var skillLevel: Int = 0

    func nextShot<R: RandomNumberGenerator>(
        on state: GameState,
        firingAt side: Side,
        using rng: inout R
    ) -> GridPoint {
        let grid = side.grid(in: state)
        let openCells = unresolvedCells(in: grid)
        precondition(!openCells.isEmpty, "No cell left to fire at; the game should already be over.")
        return openCells[Int.random(in: 0..<openCells.count, using: &rng)]
    }
}

// MARK: - CrissCrossAI (SOFT-007), the default opponent

/// Hunts on a 3D checkerboard; on a hit, works outward from it until
/// the ship sinks, then resumes hunting. `skillLevel` blends in some
/// random shots at low levels and adds open-water aiming at high ones.
struct CrissCrossAI: GameAI {
    var skillLevel: Int

    init(skillLevel: Int = DEFAULT_AI_SKILL_LEVEL) {
        self.skillLevel = skillLevel
    }

    func nextShot<R: RandomNumberGenerator>(
        on state: GameState,
        firingAt side: Side,
        using rng: inout R
    ) -> GridPoint {
        let grid = side.grid(in: state)

        // Fair knowledge only. Cells of ships the game has reported
        // sunk are all hits already, so reading them reveals nothing.
        // Ships that are NOT sunk are never read, that would be the
        // cheat SOFT-012 forbids.
        let ships = side.ships(in: state)
        let sunkCells = Set(ships.filter(\.isSunk).flatMap(\.cells))

        var openCells: [GridPoint] = []
        var activeHits: [GridPoint] = []
        for z in 0..<GRID_CONSTANTS.DEPTH {
            for y in 0..<GRID_CONSTANTS.HEIGHT {
                for x in 0..<GRID_CONSTANTS.WIDTH {
                    let point = GridPoint(x: x, y: y, z: z)
                    switch grid[z][y][x] {
                    case .fog, .ship:
                        // Unknown to a fair AI: a hidden ship looks
                        // just like open water.
                        openCells.append(point)
                    case .hit:
                        if !sunkCells.contains(point) { activeHits.append(point) }
                    case .miss, .radar, .empty:
                        break // already resolved
                    }
                }
            }
        }
        precondition(!openCells.isEmpty, "No cell left to fire at; the game should already be over.")

        if shouldPlaySmart(using: &rng) {
            // Target a wounded ship first, otherwise hunt.
            if let shot = targetShot(near: activeHits, in: grid, using: &rng) {
                return shot
            }
            return huntShot(among: openCells, in: grid, using: &rng)
        }

        // A deliberately careless shot, for lower skill levels.
        return openCells[Int.random(in: 0..<openCells.count, using: &rng)]
    }

    /// Whether to play the strategy this turn, or throw a careless
    /// shot. Always smart at 10, never at 0, a `skill/10` chance between.
    private func shouldPlaySmart<R: RandomNumberGenerator>(using rng: inout R) -> Bool {
        if skillLevel >= 10 { return true }
        if skillLevel <= 0 { return false }
        return Double.random(in: 0..<1, using: &rng) < Double(skillLevel) / 10.0
    }

    /// Work outward from existing hits. Prefers extending a line of
    /// two or more hits (how a straight ship lies), then any unshot
    /// neighbour of a hit. Nil when there are no wounded ships.
    private func targetShot<R: RandomNumberGenerator>(
        near activeHits: [GridPoint],
        in grid: [[[CellState]]],
        using rng: inout R
    ) -> GridPoint? {
        guard !activeHits.isEmpty else { return nil }
        let hitSet = Set(activeHits)

        // Extend a run of hits along an axis.
        var lineCandidates: [GridPoint] = []
        for point in activeHits {
            for axis in Axis.allCases {
                let forward = point.step(axis, by: 1)
                let backward = point.step(axis, by: -1)
                if hitSet.contains(backward), isUnresolved(forward, in: grid) {
                    lineCandidates.append(forward)
                }
                if hitSet.contains(forward), isUnresolved(backward, in: grid) {
                    lineCandidates.append(backward)
                }
            }
        }
        if let pick = pickRandom(lineCandidates, using: &rng) { return pick }

        // No line yet: any unshot neighbour of a hit.
        var neighbourCandidates: [GridPoint] = []
        for point in activeHits {
            for neighbour in point.neighbours6 where isUnresolved(neighbour, in: grid) {
                neighbourCandidates.append(neighbour)
            }
        }
        return pickRandom(neighbourCandidates, using: &rng)
    }

    /// Pick a checkerboard cell to hunt. Every ship is at least two
    /// cells long, so it must touch a cell where x+y+z is even;
    /// hunting those halves the search. At skill 8+ it also aims at
    /// the most open cell (the biggest patch of unknown water).
    private func huntShot<R: RandomNumberGenerator>(
        among openCells: [GridPoint],
        in grid: [[[CellState]]],
        using rng: inout R
    ) -> GridPoint {
        let checker = openCells.filter { ($0.x + $0.y + $0.z) % 2 == 0 }
        let pool = checker.isEmpty ? openCells : checker

        if skillLevel >= 8 {
            let scored = pool.map { (cell: $0, openness: openness(of: $0, in: grid)) }
            let best = scored.map { $0.openness }.max() ?? 0
            let openest = scored.filter { $0.openness == best }.map { $0.cell }
            return openest[Int.random(in: 0..<openest.count, using: &rng)]
        }
        return pool[Int.random(in: 0..<pool.count, using: &rng)]
    }

    /// How many of a cell's neighbours are still unknown. A proxy for
    /// "open water", never reads ship positions, only resolved state.
    private func openness(of point: GridPoint, in grid: [[[CellState]]]) -> Int {
        point.neighbours6.filter { isUnresolved($0, in: grid) }.count
    }
}

// MARK: - AI ship placement (straight ships only, for now)

/// Places an AI fleet. Straight-line ships only until the X / T / Y
/// footprints are defined in code. The fleet below is a placeholder:
/// seven ships with lengths inside SHIP_CONSTANTS (2...5). The exact
/// per-length counts are not set in the PRD yet.
enum AIFleet {
    /// Seven straight ships (GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS),
    /// lengths within SHIP_CONSTANTS.MIN/MAX_SHIP_LENGTH. Placeholder.
    static let straightLengths = [2, 2, 3, 3, 4, 4, 5]

    enum PlacementError: Error {
        case couldNotPlace(length: Int)
    }

    /// Places the whole fleet on one side's grid, retrying random
    /// positions until each ship fits without overlap.
    static func placeStraightFleet<R: RandomNumberGenerator>(
        on state: inout GameState,
        forOpponent: Bool,
        using rng: inout R
    ) throws {
        for length in straightLengths {
            try placeOne(length: length, on: &state, forOpponent: forOpponent, using: &rng)
        }
    }

    private static func placeOne<R: RandomNumberGenerator>(
        length: Int,
        on state: inout GameState,
        forOpponent: Bool,
        using rng: inout R,
        maxAttempts: Int = 2000
    ) throws {
        for _ in 0..<maxAttempts {
            let axis = Axis.allCases[Int.random(in: 0..<Axis.allCases.count, using: &rng)]
            let span = axis.size
            if length > span { continue } // a length-5 ship cannot lie along the 4-deep axis

            var x = Int.random(in: 0..<GRID_CONSTANTS.WIDTH, using: &rng)
            var y = Int.random(in: 0..<GRID_CONSTANTS.HEIGHT, using: &rng)
            var z = Int.random(in: 0..<GRID_CONSTANTS.DEPTH, using: &rng)
            switch axis {
            case .x: x = Int.random(in: 0...(GRID_CONSTANTS.WIDTH - length), using: &rng)
            case .y: y = Int.random(in: 0...(GRID_CONSTANTS.HEIGHT - length), using: &rng)
            case .z: z = Int.random(in: 0...(GRID_CONSTANTS.DEPTH - length), using: &rng)
            }

            let origin = GridPoint(x: x, y: y, z: z)
            let cells = (0..<length).map { origin.step(axis, by: $0) }

            var ship = ShipAsset()
            ship.length = length
            ship.shape = "I" // straight

            do {
                try state.placeShip(ship, at: cells, forOpponent: forOpponent)
                return
            } catch {
                continue // overlap or out of bounds: try another spot
            }
        }
        throw PlacementError.couldNotPlace(length: length)
    }
}

// MARK: - Small shared helpers

/// The three board axes, for stepping and neighbours.
private enum Axis: CaseIterable {
    case x, y, z

    /// The board's size along this axis.
    var size: Int {
        switch self {
        case .x: GRID_CONSTANTS.WIDTH
        case .y: GRID_CONSTANTS.HEIGHT
        case .z: GRID_CONSTANTS.DEPTH
        }
    }
}

private extension GridPoint {
    /// This point moved `distance` cells along `axis`.
    func step(_ axis: Axis, by distance: Int) -> GridPoint {
        switch axis {
        case .x: GridPoint(x: x + distance, y: y, z: z)
        case .y: GridPoint(x: x, y: y + distance, z: z)
        case .z: GridPoint(x: x, y: y, z: z + distance)
        }
    }

    /// The six face-adjacent cells (left/right, up/down, near/far).
    /// Some may be off the board; callers filter with isUnresolved.
    var neighbours6: [GridPoint] {
        Axis.allCases.flatMap { [step($0, by: 1), step($0, by: -1)] }
    }
}

/// Every cell a fair AI may still fire at on this grid: fog or an
/// unhit ship, which look identical to it. Hit, miss, radar, and
/// empty are already resolved.
private func unresolvedCells(in grid: [[[CellState]]]) -> [GridPoint] {
    var cells: [GridPoint] = []
    for z in 0..<GRID_CONSTANTS.DEPTH {
        for y in 0..<GRID_CONSTANTS.HEIGHT {
            for x in 0..<GRID_CONSTANTS.WIDTH {
                switch grid[z][y][x] {
                case .fog, .ship: cells.append(GridPoint(x: x, y: y, z: z))
                default: break
                }
            }
        }
    }
    return cells
}

/// Whether `point` is on the board and not yet resolved.
private func isUnresolved(_ point: GridPoint, in grid: [[[CellState]]]) -> Bool {
    guard point.isInBounds else { return false }
    switch grid[point.z][point.y][point.x] {
    case .fog, .ship: return true
    default: return false
    }
}

private func pickRandom<R: RandomNumberGenerator>(
    _ candidates: [GridPoint],
    using rng: inout R
) -> GridPoint? {
    guard !candidates.isEmpty else { return nil }
    return candidates[Int.random(in: 0..<candidates.count, using: &rng)]
}

// MARK: - Side helpers

private extension Side {
    /// The grid belonging to this side: the one you fire at when
    /// firingAt this side.
    func grid(in state: GameState) -> [[[CellState]]] {
        self == .me ? state.myGrid : state.opponentGrid
    }

    /// The ships belonging to this side.
    func ships(in state: GameState) -> [PlacedShip] {
        self == .me ? state.myShips : state.opponentShips
    }
}
