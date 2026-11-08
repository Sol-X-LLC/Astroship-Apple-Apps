import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            // TEMP (StarryTestView smoke test): launch straight into the
            // starfields + 14x10 grid instead of the Game Center lobby,
            // so the app opens without the auth flow. To revert, delete
            // Views/StarryTestView.swift and uncomment the line below.
            //
            // Starts Game Center auth (GameCenterSDK) and presents
            // the sign-in sheet when GameKit asks for it. Without
            // this modifier, MatchMaking can never find an opponent,
            // because GKLocalPlayer is never authenticated.
            // ContentView()
            //     .gameCenterConnection()
            StarryTestView()
        }
    }
}
