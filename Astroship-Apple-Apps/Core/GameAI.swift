//  GameAI.swift
//  The computer opponents for solo play.
//
//  ------------------------------------------------
//  WHAT THIS FILE DOES
//  ------------------------------------------------
//  Two computer opponents:
//    - DumbScanAI    fires at random   (SOFT-008)
//    - CrissCrossAI  the smart one      (SOFT-007)
//
//  Requirements doc:
//  https://github.com/Sol-X-LLC/Astroship-Product-Requirements-Document
//
//  ------------------------------------------------
//  IT IS "PURE" SWIFT
//  ------------------------------------------------
//  It imports only Foundation.
//  No screen. No network. No database.
//
//  Why: keeping the game logic on its own
//  makes it easy to test and easy to reuse.
//
//  ------------------------------------------------
//  THE BOARD   (one cell = three numbers)
//  ------------------------------------------------
//    x = column    left to right     (0 up to WIDTH)
//    y = row       top to bottom      (0 up to HEIGHT)
//    z = layer     into the screen    (0 up to DEPTH)
//
//  - Origin (0, 0, 0) is the top-left of the front layer.
//  - +z points away from you, into the screen.
//  - x right, y down, z in  =  the right-hand rule.
//    https://en.wikipedia.org/wiki/Right-hand_rule
//
//  (The board lives in Core/GridPoint, CellState, GameState.)
//
//  ------------------------------------------------
//  FAIR PLAY   (SOFT-012, the important rule)
//  ------------------------------------------------
//  The AI is handed the WHOLE game.
//  That includes where the human's ships are hidden.
//
//  The rule: it must NEVER look at a ship
//  it has not already hit.
//
//  How we keep it honest:
//  the AI only reads cells that are revealed
//  (a hit or a miss). A hidden ship looks exactly
//  like empty water to it, so it cannot cheat.

import Foundation

// =====================================================================
// Reproducible random numbers
// =====================================================================
//
// What this piece is for:
//   - Swift's built-in random cannot be given a "seed".
//   - Without a seed, a test could never replay the same
//     game twice.
//   - SeededGenerator fixes that: the same seed always
//     gives the same sequence of numbers (SOFT-010).
//
// About the strange numbers below:
//   - They come from a well-known recipe (SplitMix64).
//   - You do not need to understand them to use this.

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// =====================================================================
// The computer-opponent interface
// =====================================================================
//
// Every AI has ONE job:
//   look at the board, then hand back the next cell to fire at.
//
// We write that job as a "protocol" (an interface).
// Think of it as a job description, not the worker itself.
//
// Why bother?
//   - We can have several opponents:
//       a simple one, a smart one, maybe an
//       Apple-Intelligence one later.
//   - The rest of the game uses whichever is plugged in,
//     without caring which one it is.
//   - Adding a new AI never means editing the old ones.
//
// This is the "program to an interface" rule of good design.

protocol GameAI {
    /// A short label, like "DumbScan" or "CrissCross".
    var name: String { get }

    /// The next cell this AI fires at.
    ///   game   = the current match
    ///   side   = whose grid the AI is shooting at
    ///   random = the seeded dice, so a game can replay
    func nextShot(on game: GameState,
                  firingAt side: Side,
                  using random: inout SeededGenerator) -> GridPoint
}

// =====================================================================
// Helpers shared by every AI
// =====================================================================
// Small tools, used by both opponents below.

/// Which grid is the AI shooting at?
///   firing at .opponent  -> the opponent's grid
///   firing at .me        -> my grid
private func grid(of game: GameState, _ side: Side) -> [[[CellState]]] {
    side == .me ? game.myGrid : game.opponentGrid
}

/// The ships sitting on that grid.
/// Used ONLY to see which ships are already sunk,
/// never to find ships that are still hidden.
private func ships(of game: GameState, _ side: Side) -> [PlacedShip] {
    side == .me ? game.myShips : game.opponentShips
}

/// Every cell the AI is still allowed to fire at.
///
/// "Unknown" means a cell it has not resolved yet.
/// Fog (blank water) and an un-hit ship both look the
/// same to the AI, so a hidden ship gives it no secret.
private func unknownCells(on grid: [[[CellState]]]) -> [GridPoint] {
    var result: [GridPoint] = []
    for z in 0 ..< GRID_CONSTANTS.DEPTH {
        for y in 0 ..< GRID_CONSTANTS.HEIGHT {
            for x in 0 ..< GRID_CONSTANTS.WIDTH {
                let cell = grid[z][y][x]
                if cell == .fog || cell == .ship {
                    result.append(GridPoint(x: x, y: y, z: z))
                }
            }
        }
    }
    return result
}

/// Is this one point on the board AND still unknown?
/// (Safe to fire at.)
private func isUnknown(_ point: GridPoint, on grid: [[[CellState]]]) -> Bool {
    guard point.isInBounds else { return false }
    let cell = grid[point.z][point.y][point.x]
    return cell == .fog || cell == .ship
}

/// The six cells touching this one:
///   left, right, up, down, and the layers in front and behind.
/// Some may be off the board; callers filter those out.
private func neighbours(of point: GridPoint) -> [GridPoint] {
    [
        GridPoint(x: point.x - 1, y: point.y,     z: point.z),
        GridPoint(x: point.x + 1, y: point.y,     z: point.z),
        GridPoint(x: point.x,     y: point.y - 1, z: point.z),
        GridPoint(x: point.x,     y: point.y + 1, z: point.z),
        GridPoint(x: point.x,     y: point.y,     z: point.z - 1),
        GridPoint(x: point.x,     y: point.y,     z: point.z + 1),
    ]
}

// =====================================================================
// DumbScanAI  (SOFT-008): the simplest opponent
// =====================================================================
//
// Fires at a random square it has not tried yet.
// No memory. No strategy.
//
// It is the "easy" opponent, and the baseline the
// tests measure the smart one against.

struct DumbScanAI: GameAI {
    let name = "DumbScan"

    func nextShot(on game: GameState,
                  firingAt side: Side,
                  using random: inout SeededGenerator) -> GridPoint {

        // 1. Get every square we are still allowed to fire at.
        let choices = unknownCells(on: grid(of: game, side))

        // 2. Pick one at random, and fire there.
        //    (There is always at least one square left until the
        //     game ends, so this is safe.)
        return choices.randomElement(using: &random)!
    }
}

// =====================================================================
// CrissCrossAI  (SOFT-007): the default, smart opponent
// =====================================================================
//
// It has two moods, checked in this order:
//
//   1. TARGET
//      If a ship has been hit but not sunk yet,
//      fire right next to that hit to finish it off.
//
//   2. HUNT
//      Otherwise, search smartly.
//      Every ship is at least two squares long, so it
//      must sit on at least one "checkerboard" square
//      (one where x + y + z is an even number).
//      Firing only on those still finds every ship,
//      using about half the shots.

struct CrissCrossAI: GameAI {
    let name = "CrissCross"

    func nextShot(on game: GameState,
                  firingAt side: Side,
                  using random: inout SeededGenerator) -> GridPoint {
        let board = grid(of: game, side)

        // Mood 1: finish a wounded ship, if there is one.
        if let shot = targetNearAHit(on: board,
                                     ships: ships(of: game, side),
                                     using: &random) {
            return shot
        }

        // Mood 2: otherwise, hunt on the checkerboard.
        return hunt(on: board, using: &random)
    }

    /// Looks for a hit on a ship that is NOT sunk yet,
    /// then returns an unknown square next to it.
    /// Returns nil when there is no wounded ship to chase.
    private func targetNearAHit(on board: [[[CellState]]],
                                ships: [PlacedShip],
                                using random: inout SeededGenerator) -> GridPoint? {

        // Squares belonging to ships that are already sunk.
        // We stop chasing those, so the AI goes back to
        // hunting after it finishes a ship.
        //   .filter  = keep only the ships that are sunk
        //   .flatMap = join all their squares into one list
        let sunkCells = Set(ships.filter { $0.isSunk }.flatMap { $0.cells })

        // Walk the board. For every hit that is NOT part of a
        // sunk ship, collect its still-unknown neighbours.
        var candidates: [GridPoint] = []
        for z in 0 ..< GRID_CONSTANTS.DEPTH {
            for y in 0 ..< GRID_CONSTANTS.HEIGHT {
                for x in 0 ..< GRID_CONSTANTS.WIDTH {
                    let point = GridPoint(x: x, y: y, z: z)
                    let isActiveHit = board[z][y][x] == .hit
                                      && !sunkCells.contains(point)
                    if isActiveHit {
                        for next in neighbours(of: point) where isUnknown(next, on: board) {
                            candidates.append(next)
                        }
                    }
                }
            }
        }

        // No candidates = no wounded ship. randomElement
        // returns nil for an empty list, which is our signal.
        return candidates.randomElement(using: &random)
    }

    /// Fires on a checkerboard square (x + y + z is even).
    /// If somehow none is left, falls back to any open square.
    private func hunt(on board: [[[CellState]]],
                      using random: inout SeededGenerator) -> GridPoint {
        let unknown = unknownCells(on: board)
        let checkerboard = unknown.filter { ($0.x + $0.y + $0.z) % 2 == 0 }
        let pool = checkerboard.isEmpty ? unknown : checkerboard
        return pool.randomElement(using: &random)!
    }
}

// =====================================================================
// Placing the computer's fleet
// =====================================================================
//
// Before the battle, the AI puts its ships down.
//
// For now every ship is a straight line. The bent
// shapes (I / X / T / Y) are not defined in code yet,
// so this is a clearly-marked placeholder.
//
// Seven ships, lengths 2 to 5.

enum AIFleet {

    /// Seven straight ships. These lengths are a placeholder
    /// until the real fleet is decided.
    static let straightLengths = [2, 2, 3, 3, 4, 4, 5]

    /// Thrown if a ship somehow cannot be placed.
    enum PlacementError: Error {
        case couldNotPlace(length: Int)
    }

    /// Places the whole fleet on one side of the board.
    static func placeStraightFleet(on game: inout GameState,
                                   forOpponent: Bool,
                                   using random: inout SeededGenerator) throws {
        for length in straightLengths {
            try placeOneShip(length: length,
                             on: &game,
                             forOpponent: forOpponent,
                             using: &random)
        }
    }

    /// Tries random spots until the ship fits with no overlap.
    private static func placeOneShip(length: Int,
                                     on game: inout GameState,
                                     forOpponent: Bool,
                                     using random: inout SeededGenerator) throws {

        // axis 0 = lie along x,  1 = along y,  2 = along z.
        for _ in 0 ..< 1000 {
            let axis = Int.random(in: 0 ... 2, using: &random)

            // The last start position where the ship still fits
            // on the board along its chosen direction.
            let maxX = axis == 0 ? GRID_CONSTANTS.WIDTH  - length : GRID_CONSTANTS.WIDTH  - 1
            let maxY = axis == 1 ? GRID_CONSTANTS.HEIGHT - length : GRID_CONSTANTS.HEIGHT - 1
            let maxZ = axis == 2 ? GRID_CONSTANTS.DEPTH  - length : GRID_CONSTANTS.DEPTH  - 1

            // Too long for this direction? Try another.
            if maxX < 0 || maxY < 0 || maxZ < 0 { continue }

            // Pick a random starting square.
            let startX = Int.random(in: 0 ... maxX, using: &random)
            let startY = Int.random(in: 0 ... maxY, using: &random)
            let startZ = Int.random(in: 0 ... maxZ, using: &random)

            // Lay the ship out, one square per step, along the axis.
            var cells: [GridPoint] = []
            for step in 0 ..< length {
                cells.append(GridPoint(x: startX + (axis == 0 ? step : 0),
                                       y: startY + (axis == 1 ? step : 0),
                                       z: startZ + (axis == 2 ? step : 0)))
            }

            var ship = ShipAsset()
            ship.length = length
            ship.shape = "I"   // a straight line

            // GameState rejects an overlap by throwing.
            // If it does, just try another random spot.
            do {
                try game.placeShip(ship, at: cells, forOpponent: forOpponent)
                return
            } catch {
                continue
            }
        }

        // 1000 tries all failed. On a near-empty board this
        // never happens, so reaching here means something is wrong.
        throw PlacementError.couldNotPlace(length: length)
    }
}
