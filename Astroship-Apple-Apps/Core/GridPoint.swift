//  GridPoint.swift
//
//  Created by Blaze Sanders on 2026-11-06
//  For support email dev@astroship.store at Sol-X LLC
//
//  Phase 1, first piece. One cell address on the 3D board.
//
//  `x` is the column (0..<WIDTH, left to right as the player
//  holds the iPhone), `y` is the row (0..<HEIGHT, up and down),
//  `z` is the depth layer (0..<DEPTH, away from the player as
//  the Duo folds). All zero-based, matching GRID_CONSTANTS —
//  the board is zero-indexed in back-end and front-end.
//
//  `z` defaults to 0, so 2D-only play (the user's open question
//  in Grid.swift about a 2D mode for standard iPhones) is just
//  points with z = 0; nothing about the type has to change.
//
//  Note: GRID_CONSTANTS still lives in Models/Grid.swift, so
//  this Core file reads it from there. The architecture doc's
//  file layout moves Grid itself into Core later in Phase 1;
//  until then this cross-folder reference is inside the same
//  module and target, so it compiles as-is.

import Foundation

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
