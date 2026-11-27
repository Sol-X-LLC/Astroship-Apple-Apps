//  Grid.swift
//  For use with the Astroship product line of Sol-X LLC
//
//  Created by Blaze Sanders on 2026-10-31
//  For support email dev@astroship.store

// Standard libraries
import SwiftData                // TODO or "GRDB" (feature-rich SQLite toolkit in Swift)
import Foundation
import DeveloperToolsSupport    // Used to define images in "GridAsset" struct
import SwiftUI                  // Used to define SF Symbols in "GridAsset" struct

/** The Grid (one 3D cell is an array of three numbers)
    - Origin (0, 0, 0) is the top-left as the player holds the iPhone.
    - x = column,   left to right           (0 up to Grid.WIDTH)
    - y = row,          top to bottom      (0 up to Grid.HEIGHT)
    - z = layer,        into the screen    (0 up toGrid. DEPTH), defaults to 0 for 2D play on standard iPhones
 */
struct GridPoint: Hashable, Codable, Equatable, CustomStringConvertible {
    var x: Int
    var y: Int
    var z: Int

    init(x: Int, y: Int, z: Int = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    /// True when the point is on the board in all three axes.
    var isInBounds: Bool {
        (0..<GRID_CONSTANTS.WIDTH).contains(x)
            && (0..<GRID_CONSTANTS.HEIGHT).contains(y)
            && (0..<GRID_CONSTANTS.DEPTH).contains(z)
    }

    var description: String { "(\(x), \(y), \(z))" }
}

/// Enum namespace for every grid, MoveCodec bound check, and UI layout
enum GRID_CONSTANTS{
    static let WIDTH = 14               // The Duo screen is 1.4 to 1 when folded and unfoled
    static let HEIGHT = 10
    static let DEPTH = 4                // Four fold postions of the Duo worked best in play testing
    static let MAX_NUMBER_OF_SHIPS = 7  // Five ships in 3D was not enough in play testing
    static let NOT_A_NUMBER = -1        // TODO - Do we need this?
    static let MIN_VALUE = 0            // The board is zero-indexed in back-end and front-end
    static let ONLY_2D = 0              // TODO - Do we want to allow 2D only game modes for standard iPhones
}


/**
 Represent battle grid data structure

 - Parameters:
   - xAxisLength: Battle grid length left side to right side as viewed from player holding iPhone
   - yAxisLength: Battle grid length up and down as viewed from player holding iPhone
   - zAxisLength: Battle grid length away and towards player as  iPhone Duo is folded
   - myGridState: Live game play state of your own battle grid
   - opponentGridState: Live game play state of the opponents battle grid
*/
struct GridAsset: Codable, Equatable {
    var xAxisLength = GRID_CONSTANTS.WIDTH
    var yAxisLength = GRID_CONSTANTS.HEIGHT
    var zAxisLength = GRID_CONSTANTS.DEPTH

    /** Each grid state is a 3D array of CellState (Core/CellState.swift):
        - fog, ship, hit, miss, radar, empty — distinguished by shape + label, never by colour alone (INTE-001).
        - gridState[z][y][x] — z layer outermost, then row y, then column x
        - A shot (x, y, z) reads gridState[z][y][x].
        - GameState (Core/GameState.swift) owns the rules that change these cells.
    */
    var myGridState = CellState.freshGrid()
    
    // See Ship.swift for custom data type
    var myShipLayout = [ShipAsset](
        repeating: ShipAsset(),
        count: GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS
    )
    var opponentGridState = CellState.freshGrid()
    var opponentShipLayout = [ShipAsset](
        repeating: ShipAsset(),
        count: GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS
    )
    
    
    var description: String {
        """
        ⊞ Grid Info:
          • X-Axis Length:  \(xAxisLength)
          • Y-Axis Length:  \(yAxisLength)
          • Z-Axis Length:  \(zAxisLength)
          • My Grid:        \(myGridState)
          • My Ships:       \(myShipLayout)
          • Opponent Grid:  \(opponentGridState)
          • Opponent Ships: \(opponentShipLayout)
        
        """
    }

}
