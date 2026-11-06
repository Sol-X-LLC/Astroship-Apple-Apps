//  MoveCodec.swift
//
//  Created by Blaze Sanders on 2026-11-06
//  For support email dev@astroship.store at Sol-X LLC
//
//  Minimal versioned wire format for Game Center multiplayer (v2026.1).
//  Pure Swift — no SwiftUI, no GameKit, no SwiftData — so it can be
//  unit-tested without a device and reused by a future transport
//  (SYSA-005 FastAPI, v2028.0) without touching the game rules.
//
//  How it fits together:
//  - GameSession encodes a message with MoveCodec.encode(_:)
//    and hands the Data to MatchMaking.shared.send(_:).
//  - MatchMaking delivers the peer's Data to
//    GameSession via MatchMaking.shared.onDataReceived.
//  - GameSession decodes with MoveCodec.decode(_:), which
//    REJECTS anything it cannot validate. Never trust a peer:
//    a remote player must not be able to win by sending a
//    forged move, an out-of-bounds shot, or a future version.

import Foundation

/// One Astroship move, as sent over the wire.
/// v1 kinds only. Add new cases in a new protocol version,
/// never by changing what an existing case means.
enum AstroshipMessage: Codable, Equatable {
    /// Connectivity check. No game effect.
    case ping
    /// A shot at a grid cell. `x` is the column, `y` is the row,
    /// both zero-based. Validated against GRID_CONSTANTS on decode.
    case shot(x: Int, y: Int)
    /// The sender concedes the match.
    case surrender

    /// Human-readable label for the lobby debug log.
    var label: String {
        switch self {
        case .ping:
            "ping"
        case let .shot(x, y):
            "shot (\(x), \(y))"
        case .surrender:
            "surrender"
        }
    }
}

/// Versioned envelope. The version is checked before the
/// message is trusted, so a future client cannot silently
/// change what an old client understands.
struct AstroshipEnvelope: Codable {
    let version: Int
    let message: AstroshipMessage
}

enum MoveCodec {
    /// Current wire protocol version. Bump only when the
    /// meaning of a message changes or a kind is added.
    static let protocolVersion = 1

    static func encode(_ message: AstroshipMessage) throws -> Data {
        let envelope = AstroshipEnvelope(version: protocolVersion, message: message)
        return try JSONEncoder().encode(envelope)
    }

    /// Decodes and validates. Throws instead of returning a
    /// partially trusted message — callers must not apply
    /// a move that fails here.
    static func decode(_ data: Data) throws -> AstroshipMessage {
        let envelope = try JSONDecoder().decode(AstroshipEnvelope.self, from: data)

        guard envelope.version == protocolVersion else {
            throw MoveCodecError.unsupportedVersion(envelope.version)
        }

        if case let .shot(x, y) = envelope.message {
            guard (0..<GRID_CONSTANTS.WIDTH).contains(x),
                  (0..<GRID_CONSTANTS.HEIGHT).contains(y) else {
                throw MoveCodecError.outOfBounds(x: x, y: y)
            }
        }

        return envelope.message
    }

    enum MoveCodecError: Error, LocalizedError {
        case unsupportedVersion(Int)
        case outOfBounds(x: Int, y: Int)

        var errorDescription: String? {
            switch self {
            case let .unsupportedVersion(version):
                "Unsupported move version \(version) (expected \(MoveCodec.protocolVersion))."
            case let .outOfBounds(x, y):
                "Shot (\(x), \(y)) is outside the \(GRID_CONSTANTS.WIDTH)x\(GRID_CONSTANTS.HEIGHT) board."
            }
        }
    }
}
