//  Ship.swift
//
//  Created by Blaze Sanders on 2026-10-31
//  For support email dev@astroship.store at Sol-X LLC

// Standard libraries
import SwiftData                // TODO or "GRDB" (feature-rich SQLite toolkit in Swift)
import DeveloperToolsSupport    // Used to define images in "ShipAsset" struct
import SwiftUI                  // Used to define SF Symbols in "ShipAsset" struct

/** TODO
 private let fileOnlySpeed = 5.0       // only Ship.swift
 public let publicSpeed = 10.0         // also visible to other modules/frameworks
*/
// enum namespace
enum SHIP_CONSTANTS{
    static let MIN_SHIP_LENGTH = 2
    static let MAX_SHIP_LENGTH = 5
    
    static let PHYSICAL_SHAPE = ["I", "X", "T", "Y"]
    // Length 2 shapse --  Length 3 shapes --   Length 4 shapes -- Length 5 shapes
    // X                   X   X X  XXX  X X    X  XXXXX           X   X   X
    // X                   X    X    X   XXX    X    X             X   X   X
    //                     X   X X   X    X     X    X             X   XXXXX
    //                                          X    X             X     X
    //                                                             X     X
    
    static let SKIN = ["Yellow", "SunWars", "CombustionFly", "SunTrek", "Red"]
    //TODO static let shipCenterOfGravityForEachShapeWithInBoundingBox = [][]

}


/**
 Represents a ship data structure
 
 - Parameters:
   - shape: Ship layout once placed on grid
   - length: Length of ship in grid units
   - skin: Custom colored outline of a ship
   - gridLocation: Zero indexed location
   
*/ 
struct ShipAsset {
    var shape = SHIP_CONSTANTS.PHYSICAL_SHAPE[0]
    var length = SHIP_CONSTANTS.MIN_SHIP_LENGTH
    var skin = SHIP_CONSTANTS.SKIN[0]
    
    // Future Work: 3D Grid
    var gridLocation = [Grid.GRID_CONSTANTS.NOT_A_NUMBER][Grid.GRID_CONSTANTS.MIN_VALUE][Grid.GRID_CONSTANTS.ONLY_2D]
    
    var description: String {
        """
        🚀 Grid Info:
          • Ship Shape:     \(shape)
          • Ship Length:    \(length)
          • Ship Skin:      \(skin)
          • Ship Location:  \(gridLocation)
        """
    }
}
