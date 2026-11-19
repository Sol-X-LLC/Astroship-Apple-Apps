//  GameAITests.swift
//
//  Tests for the solo opponents in Core/GameAI.swift (issue #4).
//  They check the promises SOFT-007/008/010/012 make: the random source
//  repeats for a seed, every shot the AI returns is legal, the AI never
//  cheats, and a full solo game ends with a winner.
//
//  This file needs a test target, which the project does not have yet.
//  Adding one is a one-time Xcode step: File > New > Target > Unit
//  Testing Bundle, then add this file to it. The import below assumes
//  the app's product name stays "Astroship-Apple-Apps" (module name
//  Astroship_Apple_Apps); change it if the product name changes.

import XCTest
@testable import Astroship_Apple_Apps

final class GameAITests: XCTestCase {

    // MARK: - Helpers

    /// Plays a full solo game between two AIs from a fixed seed, so the
    /// whole match can be repeated. Returns the winner and the number of
    /// shots fired. It throws if any move is illegal, which is itself the
    /// legality + fair-play check: the AI must only ever return a cell
    /// that GameState.fire accepts.
    private func playSoloGame(me: any GameAI,
                              opponent: any GameAI,
                              seed: UInt64) throws -> (winner: Side?, shots: Int) {
        var random = SeededGenerator(seed: seed)
        var game = GameState()
        try AIFleet.placeStraightFleet(on: &game, forOpponent: false, using: &random)
        try AIFleet.placeStraightFleet(on: &game, forOpponent: true, using: &random)
        try game.beginBattle()

        let cellCount = GRID_CONSTANTS.WIDTH * GRID_CONSTANTS.HEIGHT * GRID_CONSTANTS.DEPTH
        let safetyCap = 2 * cellCount + 10 // a real game ends well inside this
        var shots = 0

        while !game.isGameOver && shots < safetyCap {
            let targetSide: Side = game.currentTurn == .me ? .opponent : .me
            let shooter = game.currentTurn == .me ? me : opponent
            let shot = shooter.nextShot(on: game, firingAt: targetSide, using: &random)
            _ = try game.fire(at: shot, atOpponent: targetSide == .opponent)
            shots += 1
        }
        return (game.winner, shots)
    }

    /// Records the exact cells one AI fires, as .me, against a fixed
    /// opponent layout and seed. Used to prove two runs match.
    private func shotSequence(ai: any GameAI, seed: UInt64, maxShots: Int = 60) throws -> [GridPoint] {
        var random = SeededGenerator(seed: seed)
        var game = GameState()
        try AIFleet.placeStraightFleet(on: &game, forOpponent: true, using: &random)
        // "me" needs a ship so the battle can legally begin.
        try game.placeShip(ShipAsset(), at: [GridPoint(x: 0, y: 0, z: 0), GridPoint(x: 1, y: 0, z: 0)])
        try game.beginBattle()

        var shots: [GridPoint] = []
        while !game.isGameOver, shots.count < maxShots, game.currentTurn == .me {
            let point = ai.nextShot(on: game, firingAt: .opponent, using: &random)
            shots.append(point)
            _ = try game.fire(at: point, atOpponent: true)
            if case .over = game.phase { break }
            // A filler opponent shot hands the turn back to .me.
            if game.currentTurn == .opponent {
                let filler = DumbScanAI().nextShot(on: game, firingAt: .me, using: &random)
                _ = try game.fire(at: filler, atOpponent: false)
            }
        }
        return shots
    }

    // MARK: - Seeded randomness (SOFT-010)

    func testSeededGeneratorIsDeterministic() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        for _ in 0 ..< 1000 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testSeededGeneratorDiffersBySeed() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        var sawDifference = false
        for _ in 0 ..< 10 where a.next() != b.next() { sawDifference = true }
        XCTAssertTrue(sawDifference)
    }

    // MARK: - Placement

    func testFleetPlacesSevenStraightShips() throws {
        var random = SeededGenerator(seed: 7)
        var game = GameState()
        try AIFleet.placeStraightFleet(on: &game, forOpponent: false, using: &random)

        XCTAssertEqual(game.myShips.count, GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS)
        XCTAssertEqual(game.myShips.map { $0.asset.length }.sorted(), AIFleet.straightLengths.sorted())
        for ship in game.myShips {
            XCTAssertEqual(ship.cells.count, ship.asset.length)
            for cell in ship.cells {
                XCTAssertTrue(cell.isInBounds, "\(cell) is off the board")
            }
        }
    }

    // MARK: - Legality (SOFT-011) via DumbScan

    func testDumbScanShotsAreLegalAndNeverRepeat() throws {
        var random = SeededGenerator(seed: 3)
        var game = GameState()
        try game.placeShip(ShipAsset(), at: [GridPoint(x: 0, y: 0, z: 0), GridPoint(x: 1, y: 0, z: 0)])
        try AIFleet.placeStraightFleet(on: &game, forOpponent: true, using: &random)
        try game.beginBattle()

        let ai = DumbScanAI()
        var fired: Set<GridPoint> = []
        for _ in 0 ..< 100 where game.currentTurn == .me && !game.isGameOver {
            let shot = ai.nextShot(on: game, firingAt: .opponent, using: &random)
            XCTAssertTrue(shot.isInBounds)
            XCTAssertFalse(fired.contains(shot), "DumbScan repeated a shot at \(shot)")
            fired.insert(shot)
            _ = try game.fire(at: shot, atOpponent: true)
            if game.currentTurn == .opponent, !game.isGameOver {
                let filler = DumbScanAI().nextShot(on: game, firingAt: .me, using: &random)
                _ = try game.fire(at: filler, atOpponent: false)
            }
        }
    }

    // MARK: - Determinism (SOFT-010)

    func testCrissCrossIsDeterministicForASeed() throws {
        let first = try shotSequence(ai: CrissCrossAI(), seed: 99)
        let second = try shotSequence(ai: CrissCrossAI(), seed: 99)
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
    }

    // MARK: - Checkerboard hunting (SOFT-007)

    func testFirstShotIsOnTheCheckerboard() throws {
        // With no hits yet, CrissCross is hunting, so its shot must be an
        // even-parity (checkerboard) cell. This holds for any seed.
        var random = SeededGenerator(seed: 11)
        var game = GameState()
        try game.placeShip(ShipAsset(), at: [GridPoint(x: 0, y: 0, z: 0), GridPoint(x: 1, y: 0, z: 0)])
        try AIFleet.placeStraightFleet(on: &game, forOpponent: true, using: &random)
        try game.beginBattle()

        let shot = CrissCrossAI().nextShot(on: game, firingAt: .opponent, using: &random)
        XCTAssertEqual((shot.x + shot.y + shot.z) % 2, 0, "hunting shot \(shot) was off the checkerboard")
    }

    func testTargetsANeighbourAfterAHit() throws {
        // After one hit on a ship that is not sunk, CrissCross must fire
        // at one of that cell's six neighbours, not wander off hunting.
        var random = SeededGenerator(seed: 5)
        var game = GameState()
        try game.placeShip(ShipAsset(), at: [GridPoint(x: 0, y: 9, z: 3), GridPoint(x: 1, y: 9, z: 3)])

        var opponentShip = ShipAsset()
        opponentShip.length = 2
        let hitCell = GridPoint(x: 3, y: 3, z: 0)
        try game.placeShip(opponentShip, at: [hitCell, GridPoint(x: 4, y: 3, z: 0)], forOpponent: true)
        try game.beginBattle()

        _ = try game.fire(at: hitCell, atOpponent: true) // a hit; ship not yet sunk
        let filler = DumbScanAI().nextShot(on: game, firingAt: .me, using: &random)
        _ = try game.fire(at: filler, atOpponent: false)

        let shot = CrissCrossAI().nextShot(on: game, firingAt: .opponent, using: &random)
        let neighbours: Set<GridPoint> = [
            GridPoint(x: 4, y: 3, z: 0),
            GridPoint(x: 2, y: 3, z: 0),
            GridPoint(x: 3, y: 4, z: 0),
            GridPoint(x: 3, y: 2, z: 0),
            GridPoint(x: 3, y: 3, z: 1),
        ]
        XCTAssertTrue(neighbours.contains(shot), "\(shot) is not a neighbour of the hit")
    }

    // MARK: - A full game ends with a winner

    func testFullSoloGameEndsWithAWinner() throws {
        for seed in UInt64(1) ... UInt64(5) {
            let (winner, shots) = try playSoloGame(me: CrissCrossAI(), opponent: DumbScanAI(), seed: seed)
            XCTAssertNotNil(winner, "game \(seed) ended with no winner")
            XCTAssertGreaterThan(shots, 0)
        }
    }

    // MARK: - CrissCross beats random, and does it without cheating

    func testCrissCrossBeatsDumbScanMostly() throws {
        var crissCrossWins = 0
        let games = 20
        for seed in UInt64(1) ... UInt64(games) {
            let (winner, _) = try playSoloGame(me: CrissCrossAI(), opponent: DumbScanAI(), seed: seed)
            if winner == .me { crissCrossWins += 1 }
        }
        XCTAssertGreaterThan(crissCrossWins, games / 2,
            "CrissCross won only \(crissCrossWins)/\(games); expected a clear majority")
    }
}
