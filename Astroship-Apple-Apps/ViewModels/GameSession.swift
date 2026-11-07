//  GameSession.swift
//
//  Created by Blaze Sanders on 2026-11-06
//  For support email dev@astroship.store at Sol-X LLC
//
//  The one owner of the Game Center -> game wiring.
//
//  Before this file, GameCenterSDK and MatchMaking worked
//  on their own but nothing connected them:
//  - GameCenterSDK authenticated the local player, and
//  - MatchMaking could find an opponent and deliver Data,
//  but MatchMaking.shared.onDataReceived was never set,
//  so incoming moves were dropped, and MyApp never called
//  .gameCenterConnection(), so auth never started.
//
//  GameSession is the single place that:
//  1. sets onDataReceived exactly once (in init),
//  2. decodes + validates every incoming move with MoveCodec,
//  3. exposes sendShot/sendPing for the UI, and
//  4. keeps a small log so two devices can prove the link
//     works before any real game rules exist.
//
//  It is deliberately NOT the game itself: there is no
//  turn ownership, placement, or win detection here yet.
//  Those belong in GameState (Phase 1), which will consume
//  the validated AstroshipMessage values this file produces.

import Combine
import Foundation
import GameKit
import SwiftUI

/// One received move, for the lobby debug log.
struct ReceivedMessage: Identifiable {
    let id = UUID()
    let playerName: String
    let message: AstroshipMessage
}

@MainActor
final class GameSession: ObservableObject {
    static let shared = GameSession()

    /// Valid moves received from the opponent, newest last.
    @Published private(set) var receivedMessages: [ReceivedMessage] = []
    /// The last move this device sent, if any.
    @Published private(set) var lastSent: AstroshipMessage?
    /// The last send/decode failure, if any. Shown in the lobby.
    @Published private(set) var lastError: String?

    private init() {
        // MatchMaking calls this on the main thread, but the
        // explicit @MainActor hop keeps this correct even if
        // that ever changes, and in Swift 6 mode.
        MatchMaking.shared.onDataReceived = { [weak self] data, player in
            Task { @MainActor in
                self?.handleIncoming(data, from: player)
            }
        }
    }

    /// Send a shot at a cell. Validates the cell locally
    /// before anything goes on the wire.
    func sendShot(x: Int, y: Int, z: Int) {
        send(.shot(x: x, y: y, z: z))
    }

    /// Send a connectivity check. No game effect.
    func sendPing() {
        send(.ping)
    }

    func sendSurrender() {
        send(.surrender)
    }

    private func send(_ message: AstroshipMessage) {
        lastError = nil
        do {
            let data = try MoveCodec.encode(message)
            try MatchMaking.shared.send(data)
            lastSent = message
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func handleIncoming(_ data: Data, from player: GKPlayer) {
        do {
            // Throws on a bad version or an out-of-bounds shot.
            // Invalid moves are logged as errors and never applied.
            let message = try MoveCodec.decode(data)
            receivedMessages.append(
                ReceivedMessage(playerName: player.displayName, message: message)
            )
        } catch {
            lastError = error.localizedDescription
        }
    }
}
