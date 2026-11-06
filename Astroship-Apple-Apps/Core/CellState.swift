//  CellState.swift
//
//  Created by Blaze Sanders on 2026-11-06
//  For support email dev@astroship.store at Sol-X LLC
//
//  Phase 1, first piece. The state of one cell of the battle grid.
//
//  This is the type the architecture doc's Phase 0 called for:
//  GridAsset's grid states were `[[[String]]]` ("F", "X", "O", ...),
//  and are now `[[[CellState]]]` — one value per cell, with the
//  symbol, the shape, and the accessibility label carried together.
//
//  Accessibility (INTE-001, v2026.1 gate): a cell is distinguished
//  by shape + text label, never by colour alone. The symbols below
//  are the same codes Grid.swift already used, so nothing the
//  player has seen changes: hit = X, miss = O, ship = S,
//  radar = R, fog = F. VoiceOver reads the label, e.g.
//  "Row 3, Column 4, Layer 2, hit" — rows, columns and layers
//  are 1-based for humans, 0-based in the model.

import Foundation

enum CellState: String, Codable, Equatable, CaseIterable, CustomStringConvertible {
    /// Unshot, unknown. The default for every cell of a fresh grid.
    case fog = "F"
    /// Known empty: no ship here, revealed without a shot
    /// (for example by radar). Not the same as `.miss`.
    case empty = "·"
    /// A ship cell that has not been hit yet.
    case ship = "S"
    /// A shot that hit a ship.
    case hit = "X"
    /// A shot that found no ship.
    case miss = "O"
    /// Revealed by a radar ping.
    case radar = "R"

    /// The one-character symbol for the cell, as used in
    /// GridAsset's debug description and in tests.
    var symbol: String { rawValue }

    var description: String { rawValue }

    /// The word VoiceOver and the UI use for this cell,
    /// never a colour name.
    var accessibilityLabel: String {
        switch self {
        case .fog: "fog"
        case .empty: "empty"
        case .ship: "ship"
        case .hit: "hit"
        case .miss: "miss"
        case .radar: "radar"
        }
    }

    /// The full VoiceOver label for this cell at a point,
    /// e.g. "Row 3, Column 4, Layer 2, hit".
    func label(at point: GridPoint) -> String {
        "Row \(point.y + 1), Column \(point.x + 1), Layer \(point.z + 1), \(accessibilityLabel)"
    }

    /// A fresh grid: every cell `.fog`.
    /// Indexed grid[z][y][x] — z layer outermost, then row y,
    /// then column x — so a shot (x, y, z) reads grid[z][y][x].
    static func freshGrid() -> [[[CellState]]] {
        [[[CellState]]](
            repeating: [[CellState]](
                repeating: [CellState](repeating: .fog, count: GRID_CONSTANTS.WIDTH),
                count: GRID_CONSTANTS.HEIGHT
            ),
            count: GRID_CONSTANTS.DEPTH
        )
    }
}
