//  GameCenterSDK.swift
//
//  Created by Blaze Sanders on 2026-11-01
//  For support email dev@astroship.store at Sol-X LLC

// Game Center sign-in starter for iOS/iPadOS 15+.
//
// Setup:
// 1. Add this file to your app target, replacing the existing empty placeholder.
// 2. In Xcode > Signing & Capabilities, add Game Center. Configure the matching
//    bundle ID and enable Game Center for your app in App Store Connect.
// 3. In MyApp.swift, change ContentView() to:
//        ContentView().gameCenterConnection()
//
// Optional status UI inside any SwiftUI view:
//    @ObservedObject private var gameCenter = GameCenterSDK.shared
//    Text(gameCenter.playerName ?? gameCenter.statusMessage)
//
// Authentication only: matchmaking and Astroship move synchronization are not implemented. 
// Never use playerName as a unique player identifier.

import Combine
import GameKit
import SwiftUI
import UIKit

@MainActor
final class GameCenterSDK: ObservableObject {
    static let shared = GameCenterSDK()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var playerName: String?
    @Published private(set) var playerID: String?
    @Published private(set) var statusMessage = "Game Center has not started."
    @Published private(set) var errorMessage: String?
    @Published fileprivate var signInPresentation: SignInPresentation?

    private var hasStarted = false

    private init() {}

    /// Install once. GameKit may call the handler repeatedly as sign-in changes.
    /// Call after attaching gameCenterConnection() to the visible root view.
    func authenticate() {
        guard !hasStarted else { return }
        hasStarted = true
        statusMessage = "Connecting to Game Center…"

        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            // GameKit owns the callback queue; publish SwiftUI state on main.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.errorMessage = error?.localizedDescription
                self.refreshPlayer()

                if let controller {
                    self.statusMessage = "Sign in to Game Center to connect."
                    self.signInPresentation = SignInPresentation(controller: controller)
                    return
                }

                self.signInPresentation = nil
                if self.isAuthenticated {
                    self.statusMessage = "Connected to Game Center."
                } else {
                    self.statusMessage = error?.localizedDescription
                        ?? "Game Center is unavailable or you are signed out. You can still play locally."
                }
            }
        }
    }

    private func refreshPlayer() {
        let player = GKLocalPlayer.local
        isAuthenticated = player.isAuthenticated
        playerName = player.isAuthenticated ? player.displayName : nil
        playerID = player.isAuthenticated ? player.gamePlayerID : nil
    }

    fileprivate func signInDismissed() {
        refreshPlayer()
        statusMessage = isAuthenticated
            ? "Connected to Game Center."
            : errorMessage ?? "Not connected. Sign in through Settings > Game Center, then reopen the game."
    }
}

fileprivate struct SignInPresentation: Identifiable {
    let id = UUID()
    let controller: UIViewController
}

/// Presents the exact authentication controller supplied by GameKit.
@MainActor
fileprivate struct GameCenterSignInView: UIViewControllerRepresentable {
    let controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

@MainActor
fileprivate struct GameCenterConnectionModifier: ViewModifier {
    @ObservedObject private var gameCenter = GameCenterSDK.shared

    func body(content: Content) -> some View {
        content
            .sheet(
                item: $gameCenter.signInPresentation,
                onDismiss: { gameCenter.signInDismissed() }
            ) { presentation in
                GameCenterSignInView(controller: presentation.controller)
                    .interactiveDismissDisabled()
            }
            .task { gameCenter.authenticate() }
    }
}

extension View {
    /// Apply once to the root view of your game's primary window.
    @MainActor
    func gameCenterConnection() -> some View {
        modifier(GameCenterConnectionModifier())
    }
}
