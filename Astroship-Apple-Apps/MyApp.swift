import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            // Starts Game Center auth (GameCenterSDK) and presents
            // the sign-in sheet when GameKit asks for it. Without
            // this modifier, MatchMaking can never find an opponent,
            // because GKLocalPlayer is never authenticated.
            ContentView()
                .gameCenterConnection()
        }
    }
}
