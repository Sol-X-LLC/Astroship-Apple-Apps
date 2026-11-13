//  GameAITests.swift
//
//  Tests for the solo opponents in Models/GameAI.swift (issue #4).
//  Covers the guarantees SOFT-007/008/010/011/012 and SYSA-001 ask
//  for: determinism, legality, fair play, and a full solo game that
//  ends with a winner.
//
//  This file needs a test target. There is none in the project yet,
//  so adding it is a one-time Xcode step (see the pull request):
//  File > New > Target > Unit Testing Bundle, then add this file to
//  it. The module name below assumes the app product name stays
//  "Astroship-Apple-Apps" (module Astroship_Apple_Apps); change the
//  import if the product name changes.

import XCTest
@testable import Astroship_Apple_Apps

final class GameAITests: XCTestCase {

    // MARK: - Helpers

    /// Plays a full solo game between two AIs from a fixed seed, so
    /// the whole match is reproducible. Returns the winner and how
    /// many shots were fired. Throws if any move is illegal — which
    /// is itself the legality + fair-play assertion, because the AI
    /// must only ever return cells GameState.fire accepts.
    private func playSoloGame<A: GameAI, B: GameAI>(
        me: A,
        opponent: B,
        seed: UInt64
    ) throws -> (winner: Side?, shots: Int) {
        var rng = SeededGenerator(seed: seed)
        var state = GameState()
        try AIFleet.placeStraightFleet(on: &state, forOpponent: false, using: &rng)
        try AIFleet.placeStraightFleet(on: &state, forOpponent: true, using: &rng)
        try state.beginBattle()

        let cellCount = GRID_CONSTANTS.WIDTH * GRID_CONSTANTS.HEIGHT * GRID_CONSTANTS.DEPTH
        let cap = 2 * cellCount + 10 // generous: a game must end well within this
        var shots = 0

        while !state.isGameOver && shots < cap {
            let targetSide: Side = state.currentTurn == .me ? .opponent : .me
            let shot: GridPoint = state.currentTurn == .me
                ? me.nextShot(on: state, firingAt: targetSide, using: &rng)
                : opponent.nextShot(on: state, firingAt: targetSide, using: &rng)
            _ = try state.fire(at: shot, atOpponent: targetSide == .opponent)
            shots += 1
        }
        return (state.winner, shots)
    }

    /// Records the exact sequence of cells an AI fires, for one side,
    /// against a fixed opponent layout and seed. Used to prove two
    /// runs match (determinism).
    private func shotSequence(
        ai: some GameAI,
        seed: UInt64,
        maxShots: Int = 60
    ) throws -> [GridPoint] {
        var rng = SeededGenerator(seed: seed)
        var state = GameState()
        try AIFleet.placeStraightFleet(on: &state, forOpponent: true, using: &rng)
        // Give "me" a single ship so the battle can legally begin.
        try state.placeShip(ShipAsset(), at: [GridPoint(x: 0, y: 0, z: 0), GridPoint(x: 1, y: 0, z: 0)])
        try state.beginBattle()

        var shots: [GridPoint] = []
        while !state.isGameOver, shots.count < maxShots, state.currentTurn == .me {
            let point = ai.nextShot(on: state, firingAt: .opponent, using: &rng)
            shots.append(point)
            _ = try state.fire(at: point, atOpponent: true)
            if case .over = state.phase { break }
            // Fire a harmless, legal shot for the opponent so it
            // becomes .me's turn again.
            if state.currentTurn == .opponent {
                let filler = DumbScanAI().nextShot(on: state, firingAt: .me, using: &rng)
                _ = try state.fire(at: filler, atOpponent: false)
            }
        }
        return shots
    }

    // MARK: - SeededGenerator (SOFT-010)

    func testSeededGeneratorIsDeterministic() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        for _ in 0..<1000 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testSeededGeneratorDiffersBySeed() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        var sawDifference = false
        for _ in 0..<10 where a.next() != b.next() { sawDifference = true }
        XCTAssertTrue(sawDifference)
    }

    // MARK: - Placement

    func testFleetPlacesSevenStraightShips() throws {
        var rng = SeededGenerator(seed: 7)
        var state = GameState()
        try AIFleet.placeStraightFleet(on: &state, forOpponent: false, using: &rng)

        XCTAssertEqual(state.myShips.count, GRID_CONSTANTS.MAX_NUMBER_OF_SHIPS)
        XCTAssertEqual(state.myShips.map(\.asset.length).sorted(), AIFleet.straightLengths.sorted())
        for ship in state.myShips {
            XCTAssertEqual(ship.cells.count, ship.asset.length)
            for cell in ship.cells {
                XCTAssertTrue(cell.isInBounds, "\(cell) is off the board")
            }
        }
    }

    // MARK: - Legality (SOFT-011) via DumbScan

    func testDumbScanShotsAreLegalAndNeverRepeat() throws {
        var rng = SeededGenerator(seed: 3)
        var state = GameState()
        try state.placeShip(ShipAsset(), at: [GridPoint(x: 0, y: 0, z: 0), GridPoint(x: 1, y: 0, z: 0)])
        try AIFleet.placeStraightFleet(on: &state, forOpponent: true, using: &rng)
        try state.beginBattle()

        let ai = DumbScanAI()
        var fired: Set<GridPoint> = []
        for _ in 0..<100 where state.currentTurn == .me && !state.isGameOver {
            let shot = ai.nextShot(on: state, firingAt: .opponent, using: &rng)
            XCTAssertTrue(shot.isInBounds)
            XCTAssertFalse(fired.contains(shot), "DumbScan repeated a shot at \(shot)")
            fired.insert(shot)
            _ = try state.fire(at: shot, atOpponent: true)
            // Let a filler opponent move pass the turn back to .me.
            if state.currentTurn == .opponent, !state.isGameOver {
                let filler = DumbScanAI().nextShot(on: state, firingAt: .me, using: &rng)
                _ = try state.fire(at: filler, atOpponent: false)
            }
        }
    }

    // MARK: - Determinism (SOFT-010)

    func testCrissCrossIsDeterministicForASeed() throws {
        let first = try shotSequence(ai: CrissCrossAI(skillLevel: 7), seed: 99)
        let second = try shotSequence(ai: CrissCrossAI(skillLevel: 7), seed: 99)
        XCTAssertEqual(first, second)
        XCTAssertFalse(first.isEmpty)
    }

    // MARK: - Checkerboard hunting (SOFT-007)

    func testFirstShotIsOnTheCheckerboard() throws {
        // With no hits yet, a full-skill CrissCross is hunting, so its
        // shot must be an even-parity (checkerboard) cell. This holds
        // for any seed, so it is a stable guarantee, not a lucky run.
        var rng = SeededGenerator(seed: 11)
        var state = GameState()
        try state.placeShip(ShipAsset(), at: [GridPoint(x: 0, y: 0, z: 0), GridPoint(x: 1, y: 0, z: 0)])
        try AIFleet.placeStraightFleet(on: &state, forOpponent: true, using: &rng)
        try state.beginBattle()

        let shot = CrissCrossAI(skillLevel: 10).nextShot(on: state, firingAt: .opponent, using: &rng)
        XCTAssertEqual((shot.x + shot.y + shot.z) % 2, 0, "hunting shot \(shot) was off the checkerboard")
    }

    func testTargetsANeighbourAfterAHit() throws {
        // After one hit on a not-yet-sunk ship, CrissCross must fire at
        // one of that cell's six neighbours, not wander off hunting.
        var rng = SeededGenerator(seed: 5)
        var state = GameState()
        try state.placeShip(ShipAsset(), at: [GridPoint(x: 0, y: 9, z: 3), GridPoint(x: 1, y: 9, z: 3)])

        var opponentShip = ShipAsset()
        opponentShip.length = 2
        let hitCell = GridPoint(x: 3, y: 3, z: 0)
        try state.placeShip(opponentShip, at: [hitCell, GridPoint(x: 4, y: 3, z: 0)], forOpponent: true)
        try state.beginBattle()

        _ = try state.fire(at: hitCell, atOpponent: true) // a hit; ship not yet sunk
        // Pass the turn back to .me with a legal filler shot.
        let filler = DumbScanAI().nextShot(on: state, firingAt: .me, using: &rng)
        _ = try state.fire(at: filler, atOpponent: false)

        let shot = CrissCrossAI(skillLevel: 10).nextShot(on: state, firingAt: .opponent, using: &rng)
        let neighbours: Set<GridPoint> = [
            GridPoint(x: 4, y: 3, z: 0),
            GridPoint(x: 2, y: 3, z: 0),
            GridPoint(x: 3, y: 4, z: 0),
            GridPoint(x: 3, y: 2, z: 0),
            GridPoint(x: 3, y: 3, z: 1),
        ]
        XCTAssertTrue(neighbours.contains(shot), "\(shot) is not a neighbour of the hit")
    }

    // MARK: - Full game ends with a winner (SYSA-001)

    func testFullSoloGameEndsWithAWinner() throws {
        for seed in UInt64(1)...UInt64(5) {
            let (winner, shots) = try playSoloGame(
                me: CrissCrossAI(skillLevel: 8),
                opponent: DumbScanAI(),
                seed: seed
            )
            XCTAssertNotNil(winner, "game \(seed) ended with no winner")
            XCTAssertGreaterThan(shots, 0)
        }
    }

    // MARK: - Fair play, on average (SOFT-012)

    /// Over several full games, the smart CrissCross AI should beat
    /// the random DumbScan AI most of the time. It cannot if it is
    /// cheating-blind random, and it must not win by peeking: this is
    /// a sanity check that the strategy both works and stays fair.
    func testCrissCrossBeatsDumbScanMostly() throws {
        var crissCrossWins = 0
        let games = 20
        for seed in UInt64(1)...UInt64(games) {
            let (winner, _) = try playSoloGame(
                me: CrissCrossAI(skillLevel: 9),
                opponent: DumbScanAI(),
                seed: seed
            )
            if winner == .me { crissCrossWins += 1 }
        }
        XCTAssertGreaterThan(crissCrossWins, games / 2,
            "CrissCross won only \(crissCrossWins)/\(games); expected a clear majority")
    }
}
