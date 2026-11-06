//  GameAI.swift
//  For use with the Astroship product line of Sol-X LLC
//
//  Created by Blaze Sanders on 2026-10-31
//  For support email dev@astroship.store

// Standard libraries
import SwiftData                // Instead of "import Foundation", "SQLite" or "GRDB" (feature-rich SQLite toolkit in Swift)
import Foundation
import DeveloperToolsSupport    // Used to define images in "GridAsset" struct
import SwiftUI                  // Used to define SF Symbols in "GridAsset" struct

// External libraries

// Max skill level 10 with miminmium of 0 for debugging. Min level shown to player is 1.
// Phase 0 fix: the old line `AI_SKILL_LEVEL = 5` assigned to a
// name that was never declared, and `import Random` is not a
// module — randomness in Swift comes from Foundation
// (`Int.random(in:)`, `Bool.random()`, ...). Declared here.
let AI_SKILL_LEVEL = 5

// Phase 1 stubs. Bodies land with the GameState / GameAI
// protocol in the architecture doc — CrissCross is the
// default, DumbScan is the simplest, the rest are later.
func AiCrissCross(){}

func AiDumbScan(){}

func AiLocalFoundationModel(){}

func AiServerFoundationModel(){}

func AiCarey(){}

func AiBlaze(){}

// Phase 0 fix: the second `struct ShipAsset` that used to
// live here is deleted. It was a different, broken copy
// (undefined SHIP_PHYSICAL_SHAPE / SHIP_SKIN / xAxislength /
// myGridState, invalid `[0][10]`) that clashed with the
// ShipAsset in Ship.swift. Ship.swift's ShipAsset is the
// single definition now.
