//  Grid.swift
//
//  Created by Blaze Sanders on 2026-10-31
//  For support email dev@astroship.store at Sol-X LLC

// Standard libraries
import SwiftData                // TODO or "GRDB" (feature-rich SQLite toolkit in Swift)
import Foundation
import DeveloperToolsSupport    // Used to define images in "GridAsset" struct
import SwiftUI                  // Used to define SF Symbols in "GridAsset" struct

// External libraries

// enum namespace
enum GRID_CONSTANTS{
    // Board size decided 2026-11-05: 14x10 everywhere.
    // Depth added 2026-11-06: 14 columns (x) by 10 rows (y)
    // by 4 layers (z), 560 cells per grid.
    // Every grid, AI bound, MoveCodec bound check, and UI layout
    // must read WIDTH / HEIGHT / DEPTH here — never hardcode 14x10.
    static let WIDTH = 14
    static let HEIGHT = 10
    static let DEPTH = 4
    static let MAX_NUMBER_OF_SHIPS = 7
    static let NOT_A_NUMBER = -1
    // Minimum grid coordinate. The board is zero-indexed,
    // so the smallest valid x / y / z is 0.
    static let MIN_VALUE = 0
    static let ONLY_2D = 0
}


/**
 Represent battle grid data structure

 - Parameters:
   - xAxislength: The unique identifier for the user profile instance (Satisfies Identifiable protocol)
   - yAxislength: The user's given name.
   - myGridState: 
   - opponentGridState:
*/ 
struct GridAsset {
    var xAxislength = GRID_CONSTANTS.WIDTH
    var yAxislength = GRID_CONSTANTS.HEIGHT
    var zAxislength = GRID_CONSTANTS.DEPTH
    
    // See Ship.swift for custom data type
    // "X" = Hit
    // "O" = Miss
    // "S" = Ship not Hit
    // "R" = RADAR
    // "F" = Fog of War

    // Phase 0 fix: `[String][String]` and `[GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS]`
    // are not valid Swift. Each grid state is a 3D array of cell
    // strings ("F" = Fog of War, "X" = Hit, "O" = Miss,
    // "S" = Ship not Hit, "R" = RADAR), 14 wide x 10 tall x 4 deep,
    // indexed gridState[z][y][x] — z layer outermost, then row y,
    // then column x — so a shot (x, y, z) reads gridState[z][y][x].
    // Each layout is one ShipAsset per ship (7). Phase 1 replaces
    // the String cells with CellState, per the architecture doc.
    var myGridState = [[[String]]](
        repeating: [[String]](
            repeating: [String](repeating: "F", count: GRID_CONSTANTS.WIDTH),
            count: GRID_CONSTANTS.HEIGHT
        ),
        count: GRID_CONSTANTS.DEPTH
    )
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
          • X-Axis Length:  \(xAxislength)
          • Y-Axis Length:  \(yAxislength)
          • Z-Axis Length:  \(zAxislength)
          • My Grid:        \(myGridState)
          • My Ships:       \(myShipLayout)
          • Opponent Grid:  \(opponentGridState)
          • Opponent Ships: \(opponentShipLayout)
        
        """
    }

}
