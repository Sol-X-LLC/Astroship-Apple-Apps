//  GameState.swift
//
//  Created by Blaze Sanders on 2026-11-06
//  For support email dev@astroship.store at Sol-X LLC
//
//  Phase 1, first piece. The pure rules of an Astroship match.
//
//  Pure Swift — no SwiftUI, no GameKit, no SwiftData — so it
//  can be unit-tested without a device (SYSA-001) and reused
//  by solo play, Game Center multiplayer, and a future tvOS
//  target without touching the rules.
//
//  What it owns: placement, firing, sinking, turn order, and
//  win detection, on two 14x10x4 grids (mine + opponent's).
//  What it does NOT own: the UI, the AI that picks shots
//  (GameAI protocol, next piece), or the transport that
//  carries moves (GameKit / MoveCodec, Phase 2).
//
//  Two rules the architecture doc sets, enforced here:
//  1. Never trust a peer. Every shot is validated against
//     this state — in bounds, unshot, and on your turn —
//     before anything is applied. Invalid moves throw
//     and change nothing.
//  2. GameState does not invent ship shapes. A ship is
//     placed by giving its exact cells; GameState checks
//     the count matches the ship's length, every cell is
//     in bounds, and no cell overlaps another ship. The
//     T / X / Y footprints themselves are still an open
//     design question (architecture doc §7) — the caller
//     (PlacementView / AI) supplies the cells for a shape.

import Foundation

/// Which side of the match a grid, a ship, or a turn belongs to.
enum Side: String, Codable, Equatable {
    case me
    case opponent
}

/// Where a match is in its lifecycle.
enum GamePhase: Codable, Equatable {
    /// Ships are being placed. No shots yet.
    case placement
    /// Ships are placed, shots are being fired.
    case battle
    /// All of one side's ships are sunk.
    case over(winner: Side)
}

/// One ship on the board: its asset plus the exact cells
/// it occupies and which of those have been hit.
struct PlacedShip: Codable, Equatable {
    var asset: ShipAsset
    var cells: [GridPoint]
    var hits: Set<GridPoint>

    init(asset: ShipAsset, cells: [GridPoint]) {
        self.asset = asset
        self.cells = cells
        self.hits = []
    }

    /// True when every cell of the ship has been hit.
    var isSunk: Bool {
        !cells.isEmpty && Set(cells).isSubset(of: hits)
    }
}

/// What a fired shot did.
enum ShotResult: Equatable {
    /// The shot found no ship.
    case miss
    /// The shot hit a ship, which is still afloat.
    case hit
    /// The shot hit a ship, and that was its last cell.
    case sunk(PlacedShip)
}

enum GameStateError: Error, LocalizedError, Equatable {
    case outOfBounds(GridPoint)
    case overlappingShip(GridPoint)
    case wrongLength(expected: Int, actual: Int)
    case tooManyShips
    case alreadyFired(GridPoint)
    case notInPlacement
    case notInBattle
    case noShipsPlaced
    case notYourTurn

    var errorDescription: String? {
        switch self {
        case let .outOfBounds(point):
            "\(point) is outside the \(GRID_CONSTANTS.WIDTH)x\(GRID_CONSTANTS.HEIGHT)x\(GRID_CONSTANTS.DEPTH) board."
        case let .overlappingShip(point):
            "\(point) is already occupied by a ship."
        case let .wrongLength(expected, actual):
            "Ship needs \(expected) cells, got \(actual)."
        case .tooManyShips:
            "All \(GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS) ships are already placed."
        case let .alreadyFired(point):
            "\(point) has already been fired at."
        case .notInPlacement:
            "Ships can only be placed before the battle starts."
        case .notInBattle:
            "Shots can only be fired once the battle has started."
        case .noShipsPlaced:
            "Both sides need at least one ship placed before the battle starts."
        case .notYourTurn:
            "It is not your turn to fire."
        }
    }
}

struct GameState: Codable, Equatable {
    /// My grid, indexed [z][y][x]. Starts all `.fog`.
    var myGrid: [[[CellState]]]
    /// The opponent's grid, indexed [z][y][x]. Starts all `.fog`.
    var opponentGrid: [[[CellState]]]
    var myShips: [PlacedShip]
    var opponentShips: [PlacedShip]
    var phase: GamePhase
    /// Whose shot it is. `.me` starts the battle.
    var currentTurn: Side

    init() {
        myGrid = CellState.freshGrid()
        opponentGrid = CellState.freshGrid()
        myShips = []
        opponentShips = []
        phase = .placement
        currentTurn = .me
    }

    var isGameOver: Bool {
        if case .over = phase { return true }
        return false
    }

    var winner: Side? {
        if case let .over(winner) = phase { return winner }
        return nil
    }

    // MARK: - Placement

    /// Places a ship on the given side's grid.
    /// - Parameters:
    ///   - asset: the ship to place. Its `gridLocation` is set
    ///     to the first cell as the ship's origin.
    ///   - cells: the exact cells the ship occupies. The count
    ///     must equal `asset.length`; the shape they form is
    ///     the caller's choice (I / X / T / Y).
    ///   - forOpponent: false places on my grid, true on the
    ///     opponent's grid.
    mutating func placeShip(_ asset: ShipAsset, at cells: [GridPoint], forOpponent: Bool = false) throws {
        guard phase == .placement else {
            throw GameStateError.notInPlacement
        }
        if forOpponent {
            try Self.placeShipOnGrid(asset, at: cells, grid: &opponentGrid, ships: &opponentShips)
        } else {
            try Self.placeShipOnGrid(asset, at: cells, grid: &myGrid, ships: &myShips)
        }
    }

    // Static on purpose: a mutating method may not pass its own
    // stored properties as inout to another method on self
    // (Swift's exclusivity rule). A static helper that only
    // touches the grid and ships handed to it has no such overlap.
    private static func placeShipOnGrid(
        _ asset: ShipAsset,
        at cells: [GridPoint],
        grid: inout [[[CellState]]],
        ships: inout [PlacedShip]
    ) throws {
        guard cells.count == asset.length else {
            throw GameStateError.wrongLength(expected: asset.length, actual: cells.count)
        }
        guard ships.count < GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS else {
            throw GameStateError.tooManyShips
        }
        for point in cells {
            guard point.isInBounds else {
                throw GameStateError.outOfBounds(point)
            }
        }
        // A repeated cell inside one ship is an overlap with itself.
        var seen: Set<GridPoint> = []
        for point in cells {
            guard seen.insert(point).inserted else {
                throw GameStateError.overlappingShip(point)
            }
            guard grid[point.z][point.y][point.x] != .ship else {
                throw GameStateError.overlappingShip(point)
            }
        }
        var placedAsset = asset
        if let origin = cells.first {
            placedAsset.gridLocation = [origin.x, origin.y, origin.z]
        }
        for point in cells {
            grid[point.z][point.y][point.x] = .ship
        }
        ships.append(PlacedShip(asset: placedAsset, cells: cells))
    }

    /// Ends placement and starts the battle. Both sides need
    /// at least one ship placed. The PlacementView enforces
    /// all seven ships; GameState only requires a playable game.
    mutating func beginBattle() throws {
        guard phase == .placement else {
            throw GameStateError.notInPlacement
        }
        guard !myShips.isEmpty, !opponentShips.isEmpty else {
            throw GameStateError.noShipsPlaced
        }
        phase = .battle
        currentTurn = .me
    }

    // MARK: - Firing

    /// Fires a shot.
    /// - Parameters:
    ///   - point: the cell to shoot at.
    ///   - atOpponent: true fires at the opponent's grid
    ///     (my shot), false fires at my grid (their shot).
    /// - Returns: whether the shot missed, hit, or sank a ship.
    /// Throws without changing anything when the shot is
    /// invalid: wrong phase, out of bounds, already fired,
    /// or not the firer's turn.
    mutating func fire(at point: GridPoint, atOpponent: Bool = true) throws -> ShotResult {
        guard phase == .battle else {
            throw GameStateError.notInBattle
        }
        let firer: Side = atOpponent ? .me : .opponent
        guard firer == currentTurn else {
            throw GameStateError.notYourTurn
        }
        let result: ShotResult
        if atOpponent {
            result = try Self.fireOnGrid(at: point, grid: &opponentGrid, ships: &opponentShips)
            if opponentShips.allSatisfy(\.isSunk) {
                phase = .over(winner: .me)
            }
        } else {
            result = try Self.fireOnGrid(at: point, grid: &myGrid, ships: &myShips)
            if myShips.allSatisfy(\.isSunk) {
                phase = .over(winner: .opponent)
            }
        }
        if !isGameOver {
            currentTurn = firer == .me ? .opponent : .me
        }
        return result
    }

    // Static for the same exclusivity reason as placeShipOnGrid.
    private static func fireOnGrid(
        at point: GridPoint,
        grid: inout [[[CellState]]],
        ships: inout [PlacedShip]
    ) throws -> ShotResult {
        guard point.isInBounds else {
            throw GameStateError.outOfBounds(point)
        }
        switch grid[point.z][point.y][point.x] {
        // `.hit` / `.miss` were already shot. `.radar` / `.empty`
        // are already-resolved knowledge (revealed, no shot needed),
        // so firing there is also rejected — the radar move itself,
        // and what it reveals, is a Phase 2 decision.
        case .hit, .miss, .radar, .empty:
            throw GameStateError.alreadyFired(point)
        case .fog:
            grid[point.z][point.y][point.x] = .miss
            return .miss
        case .ship:
            grid[point.z][point.y][point.x] = .hit
            for index in ships.indices where ships[index].cells.contains(point) {
                ships[index].hits.insert(point)
                if ships[index].isSunk {
                    return .sunk(ships[index])
                }
                return .hit
            }
            // A `.ship` cell with no ship claiming it is a
            // corrupted state, not a playable one. Treat it
            // as a hit rather than crashing.
            return .hit
        }
    }
}
