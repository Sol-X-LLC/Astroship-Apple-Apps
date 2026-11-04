// MatchMaking.swift — iOS/iPadOS 15+
// Add alongside GameCenterSDK.swift in your app target.
// Keep ContentView().gameCenterConnection() in MyApp.swift.
// Place MatchMakingView() in your lobby after Game Center sign-in.
//
// This uses a live two-player GKMatch, not asynchronous turn-based matches.
// Both devices must run compatible game versions with the same Game Center app.
// Wire onDataReceived to your game model; validate every incoming move there.
// Ship placement, turn ownership, move encoding, and game rules remain app logic.

/**
Includes two-player matchmaking, a SwiftUI lobby, reliable data sending, and disconnect handling using Apple’s GameKit matchmaking.

Add it alongside GameCenterSDK.swift, then place MatchMakingView() in your lobby. Astroship move validation and turn logic still need wiring.
*/

import Combine
import GameKit
import SwiftUI
import UIKit

@MainActor
final class MatchMaking: NSObject, ObservableObject {
    static let shared = MatchMaking()

    @Published private(set) var match: GKMatch?
    @Published private(set) var isReady = false
    @Published private(set) var statusMessage = "Find an opponent to start a battle."
    @Published private(set) var errorMessage: String?
    @Published fileprivate var presentation: MatchMakingPresentation?

    /// Called on the main thread. Set before opening matchmaking so early
    /// messages are handled. Do not replace match.delegate; this object owns it.
    var onDataReceived: ((Data, GKPlayer) -> Void)?

    var opponentName: String? { match?.players.first?.displayName }

    private override init() { super.init() }

    func findOpponent() {
        guard GKLocalPlayer.local.isAuthenticated else {
            report("Sign in to Game Center before finding an opponent.")
            return
        }
        guard presentation == nil, match == nil else { return }

        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.defaultNumberOfPlayers = 2
        guard let controller = GKMatchmakerViewController(matchRequest: request) else {
            report("Game Center could not open matchmaking. Please try again.")
            return
        }
        errorMessage = nil
        statusMessage = "Finding an opponent…"
        controller.matchmakerDelegate = self
        presentation = MatchMakingPresentation(controller: controller)
    }

    /// Send your own encoded Battleship messages using reliable delivery.
    /// Reliability does not validate moves or decide whose turn it is.
    func send(_ data: Data) throws {
        guard let match, isReady, GKLocalPlayer.local.isAuthenticated else {
            throw ConnectionError.notConnected
        }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            report(error.localizedDescription)
            throw error
        }
    }

    func leaveMatch() {
        let previousMatch = match
        match = nil
        isReady = false
        previousMatch?.delegate = nil
        previousMatch?.disconnect()
        statusMessage = "You left the battle."
    }

    fileprivate func matchmakingDismissed() {
        if match == nil, errorMessage == nil {
            statusMessage = "Matchmaking canceled."
        }
    }

    private func refreshReadiness() {
        isReady = GKLocalPlayer.local.isAuthenticated
            && match?.expectedPlayerCount == 0
            && match?.players.count == 1
        statusMessage = isReady ? "Opponent connected. Ready to play!" : "Waiting for opponent…"
    }

    private func report(_ message: String) {
        errorMessage = message
        statusMessage = message
    }

    enum ConnectionError: LocalizedError {
        case notConnected
        var errorDescription: String? { "A connected opponent is required to send a move." }
    }
}

extension MatchMaking: GKMatchmakerViewControllerDelegate {
    nonisolated func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        DispatchQueue.main.async { [weak self] in
            self?.presentation = nil
            self?.statusMessage = "Matchmaking canceled."
        }
    }

    nonisolated func matchmakerViewController(
        _ viewController: GKMatchmakerViewController, didFailWithError error: Error
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.presentation = nil
            self?.report(error.localizedDescription)
        }
    }

    nonisolated func matchmakerViewController(
        _ viewController: GKMatchmakerViewController, didFind match: GKMatch
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { match.disconnect(); return }
            self.match = match
            match.delegate = self
            self.errorMessage = nil
            self.refreshReadiness()
            self.presentation = nil
        }
    }
}

extension MatchMaking: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.match === match else { return }
            self.onDataReceived?(data, player)
        }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.match === match else { return }
            if state == .disconnected {
                self.leaveMatch()
                self.report("Your opponent disconnected. Find a new opponent to play again.")
            } else {
                self.refreshReadiness()
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.match === match else { return }
            self.leaveMatch()
            self.report(error?.localizedDescription ?? "The match connection failed.")
        }
    }
}

fileprivate struct MatchMakingPresentation: Identifiable {
    let id = UUID()
    let controller: GKMatchmakerViewController
}

@MainActor
fileprivate struct MatchMakingControllerView: UIViewControllerRepresentable {
    let controller: GKMatchmakerViewController
    func makeUIViewController(context: Context) -> GKMatchmakerViewController { controller }
    func updateUIViewController(_ uiViewController: GKMatchmakerViewController, context: Context) {}
}

/// A ready-to-use lobby. Keep mounted during the match, or build your own UI
/// observing MatchMaking.shared and present its matchmaker from your lobby.
@MainActor
struct MatchMakingView: View {
    @ObservedObject private var gameCenter = GameCenterSDK.shared
    @ObservedObject private var matchmaking = MatchMaking.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Online Battleship").font(.headline)
            Text(matchmaking.statusMessage)
            if let opponent = matchmaking.opponentName {
                Text("Opponent: \(opponent)")
            }
            if matchmaking.match != nil {
                Button("Leave Match", role: .destructive) { matchmaking.leaveMatch() }
            } else {
                Button("Find Opponent") { matchmaking.findOpponent() }
                    .disabled(!gameCenter.isAuthenticated || matchmaking.presentation != nil)
            }
            if !gameCenter.isAuthenticated {
                Text(gameCenter.statusMessage).font(.caption)
            }
        }
        .padding()
        .sheet(item: $matchmaking.presentation, onDismiss: {
            matchmaking.matchmakingDismissed()
        }) { presentation in
            MatchMakingControllerView(controller: presentation.controller)
                .interactiveDismissDisabled()
        }
        .onChange(of: gameCenter.isAuthenticated) { authenticated in
            if !authenticated {
                matchmaking.presentation = nil
                matchmaking.leaveMatch()
            }
        }
    }
}
