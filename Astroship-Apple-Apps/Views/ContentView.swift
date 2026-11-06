import SwiftUI

/// Lobby. This is the first screen the app shows.
///
/// It is deliberately small: it proves the Game Center wiring
/// works end to end before any real game UI exists.
/// - Game Center status comes from GameCenterSDK.
/// - Finding an opponent and the match itself come from MatchMaking.
/// - Sending and receiving test moves goes through GameSession,
///   which is created here (as a shared singleton) so its
///   onDataReceived handler is installed exactly once.
///
/// The full BattleView (twin 14x10 grids, placement, turn
/// ownership) is Phase 1 / Phase 2 work and will replace the
/// test-shot section below — not this lobby.
struct ContentView: View {
    @ObservedObject private var gameCenter = GameCenterSDK.shared
    @ObservedObject private var matchmaking = MatchMaking.shared
    @ObservedObject private var session = GameSession.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Astroship")
                    .font(.largeTitle.bold())

                Text(gameCenter.playerName.map { "Signed in as \($0)" }
                    ?? gameCenter.statusMessage)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)

                MatchMakingView()

                if matchmaking.isReady {
                    Divider()

                    Text("Match ready — test the link")
                        .font(.headline)

                    Text("Sends one encoded shot over Game Center. "
                        + "Your opponent should see it appear below.")
                        .font(.caption)
                        .multilineTextAlignment(.center)

                    HStack {
                        Button("Send test shot (7, 5)") {
                            session.sendShot(x: 7, y: 5)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Ping") {
                            session.sendPing()
                        }
                        .buttonStyle(.bordered)
                    }

                    if let lastSent = session.lastSent {
                        Text("Sent: \(lastSent.label)")
                            .font(.caption)
                    }

                    if let error = session.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    List(session.receivedMessages) { received in
                        Text("\(received.playerName): \(received.message.label)")
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Astroship")
        }
    }
}

#Preview {
    ContentView()
}
