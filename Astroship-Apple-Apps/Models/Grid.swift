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

// External libraries

// enum namespace
enum GRID_CONSTANTS{
    // Every grid, AI bound, MoveCodec bound check, and UI layout must read WIDTH / HEIGHT / DEPTH here
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
struct GridAsset {
    var xAxisLength = GRID_CONSTANTS.WIDTH
    var yAxisLength = GRID_CONSTANTS.HEIGHT
    var zAxisLength = GRID_CONSTANTS.DEPTH
    
    // Each grid state is a 3D array of cell strings:
    // "F" = Fog of War, "X" = Hit, "O" = Miss, "S" = Ship not Hit, "R" = RADAR
    // gridState[z][y][x] — z layer outermost, then row y, then column x — so a shot (x, y, z) reads gridState[z][y][x].
    // Each layout is one ShipAsset per ship (7).
    
    // TODO Replace the String cells with CellState, per the architecture doc.
    var myGridState = [[[String]]](
        repeating: [[String]](
            repeating: [String](repeating: "F", count: GRID_CONSTANTS.WIDTH),
            count: GRID_CONSTANTS.HEIGHT
        ),
        count: GRID_CONSTANTS.DEPTH
    )
    
    // See Ship.swift for custom data type
    var myShipLayout = [ShipAsset](
        repeating: ShipAsset(),
        count: GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS
    )
    var opponentGridState = [[[String]]](
        repeating: [[String]](
            repeating: [String](repeating: "F", count: GRID_CONSTANTS.WIDTH),
            count: GRID_CONSTANTS.HEIGHT
        ),
        count: GRID_CONSTANTS.DEPTH
    )
    var opponentShipLayout = [ShipAsset](
        repeating: ShipAsset(),
        count: GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS
    )
    
    
    var description: String {
        """
        ⊞ Grid Info:
          • X-Axis Length:  \(xAxisLength)
          • Y-Axis Length:  \(yAxisLength)
          • Z-Axis Length:  \(xAxisLength)
          • My Grid:        \(myGridState)
          • My Ships:       \(myShipLayout)
          • Opponent Grid:  \(opponentGridState)
          • Opponent Ships: \(opponentShipLayout)
        
        """
    }

}
