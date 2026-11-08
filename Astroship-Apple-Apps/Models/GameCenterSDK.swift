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
    /// Set once GameKit's authenticate handler has fired with a result.
    /// The lobby shows "Try again" only after an attempt has resolved,
    /// never while the first connection is still in flight.
    @Published private(set) var authenticationAttempted = false
    @Published private(set) var playerName: String?
    @Published private(set) var playerID: String?
    @Published private(set) var statusMessage = "Game Center has not started."
    @Published private(set) var errorMessage: String?
    @Published fileprivate var signInPresentation: SignInPresentation?

    private var hasStarted = false
    /// The error from the most recent auth attempt, if any. Kept so
    /// signInDismissed() can show the same friendly message the handler
    /// showed, instead of falling back to the raw error text.
    private var lastAuthError: Error?

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
                self.authenticationAttempted = true
                self.errorMessage = error?.localizedDescription
                self.lastAuthError = error
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
                    self.statusMessage = self.friendlyAuthMessage(for: error)
                }
            }
        }
    }

    /// Retry authentication after a failure. authenticate() runs once by
    /// design (hasStarted guard); this resets the guard so the lobby's
    /// "Try again" button can re-run it without relaunching the app.
    /// Re-setting GKLocalPlayer's authenticateHandler is the supported
    /// way to re-trigger it; GameKit calls the handler again with the
    /// current sign-in state.
    func retryAuthentication() {
        hasStarted = false
        authenticationAttempted = false
        authenticate()
    }

    /// Turns a GameKit auth error into something the player can act on.
    /// The raw NSError text ("local player has not been authenticated")
    /// says what happened but not what to do about it.
    /// - Code 2, cancelled: the sign-in prompt was dismissed, or Game
    ///   Center is turned off on the device.
    /// - Code 3, communications failure: Game Center could not be reached.
    /// - Code 6, not authenticated: no Apple ID is signed in to Game Center.
    /// Anything else falls through to the raw message.
    private func friendlyAuthMessage(for error: Error?) -> String {
        guard let error else {
            return "Game Center is unavailable or you are signed out. Sign in under Settings > Game Center, then tap Try again."
        }
        if let gkError = error as? GKError {
            switch gkError.code {
            case .cancelled:
                return "Game Center sign-in was canceled or is turned off. Turn on Game Center in Settings, then tap Try again."
            case .communicationsFailure:
                return "Couldn't reach Game Center. Check your connection, then tap Try again."
            case .notAuthenticated:
                return "You're not signed in to Game Center. Sign in under Settings > Game Center, then tap Try again."
            default:
                break
            }
        }
        return error.localizedDescription
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
            : friendlyAuthMessage(for: lastAuthError)
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
