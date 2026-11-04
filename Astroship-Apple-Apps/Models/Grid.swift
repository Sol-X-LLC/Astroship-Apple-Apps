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
    static let MAX_NUMBER_OF_SHIPS = 7
    static let NOT_A_NUMBER = -1
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
    var xAxislength = 14
    var yAxislength = 10
    
    // See Ship.swift for custom data type
    // "X" = Hit
    // "O" = Miss
    // "S" = Ship not Hit
    // "R" = RADAR
    // "F" = Fog of War

    var myGridState = [String][String]
    var myShipLayout = [GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS]
    var opponentGridState = [String][String]
    var opponentShipLayout = [GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS]
    
    
    var description: String {
        """
        ⊞ Grid Info:
          • X-Axis Length:  \(xAxislength)
          • Y-Axis Length:  \(yAxislength)
          • My Grid:        \(myGridState)
          • My Ships:       \(myShipLayout)
          • Opponent Grid:  \(opponentGridState)
          • Opponent Ships: \(opponentShipLayout)
        
        """
    }

}
