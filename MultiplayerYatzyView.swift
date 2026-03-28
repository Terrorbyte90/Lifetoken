import SwiftUI

// MARK: - MultiplayerYatzyView (Coordinator)

struct MultiplayerYatzyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var timeEngine = TimeEngine.shared
    @ObservedObject private var server     = ServerSync.shared

    @StateObject private var engine = YatzyGameEngine()

    // MARK: Lobby state
    @State private var player1Name: String      = GameState.shared.username.isEmpty ? "Spelare 1" : GameState.shared.username
    @State private var betAmount: TimeInterval  = 600
    @State private var gameMode: MultiYatzyMode = .vsAI
    @State private var showInsufficientFundsAlert = false
    @State private var selectedOnlineOpponent: ServerUser? = nil
    @State private var useRandomOpponent: Bool  = false

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.08), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch engine.phase {
            case .lobby:
                YatzyLobbyView(
                    player1Name: $player1Name,
                    betAmount: $betAmount,
                    gameMode: $gameMode,
                    selectedOnlineOpponent: $selectedOnlineOpponent,
                    useRandomOpponent: $useRandomOpponent,
                    balance: timeEngine.balance,
                    zoneMembers: server.zoneMembers,
                    onDismiss: { dismiss() },
                    onStart: startGame
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))

            case .handoff(let idx):
                handoffView(toPlayerIndex: idx)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal:   .opacity.combined(with: .move(edge: .leading))
                    ))

            case .playing:
                YatzyGameplayView(
                    engine: engine,
                    gameMode: gameMode,
                    betAmount: betAmount,
                    balance: timeEngine.balance,
                    onDismiss: { dismiss() }
                )
                .transition(.opacity)

            case .gameOver:
                YatzyGameOverView(
                    players: engine.players,
                    winnerIndex: engine.winnerIndex,
                    isTie: engine.isTie,
                    gameMode: gameMode,
                    betAmount: betAmount,
                    resultAnimating: $engine.resultAnimating,
                    onPlayAgain: {
                        engine.resultAnimating = false
                        engine.resetToLobby()
                    },
                    onDismiss: { dismiss() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: engine.phase)
        .alert("Otillräckligt saldo", isPresented: $showInsufficientFundsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Du har inte nog med tid för denna insats.\nDitt saldo: \(TimeEngine.shortFormatted(timeEngine.balance))")
        }
    }

    // MARK: - Handoff View

    private func handoffView(toPlayerIndex idx: Int) -> some View {
        let playerName   = engine.players.indices.contains(idx) ? engine.players[idx].name : "Spelare \(idx+1)"
        let isAI         = gameMode == .vsAI && idx == 1
        let color: Color = idx == 0 ? .accentGreen : .orange

        return VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 100, height: 100)
                    if isAI {
                        Text("🤖").font(.system(size: 52))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(color.opacity(0.8))
                    }
                }
                .scaleEffect(engine.handoffReady ? 1 : 0.6)
                .opacity(engine.handoffReady ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: engine.handoffReady)

                VStack(spacing: 6) {
                    Text("LÄMNA ÖVER TILL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(3)
                    Text(playerName)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(color)
                    Text("Det är din tur!")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .offset(y: engine.handoffReady ? 0 : 20)
                .opacity(engine.handoffReady ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: engine.handoffReady)

                LTInfoCallout(
                    title: isAI ? "AI tur" : "Spelarbyte",
                    message: isAI
                        ? "AI spelar automatiskt med högsta svårighetsnivå."
                        : "Lämna över enheten till nästa spelare innan rundan fortsätter.",
                    icon: isAI ? "cpu.fill" : "person.2.fill",
                    tint: color
                )
                .padding(.horizontal, 28)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.3)) { engine.phase = .playing }
            } label: {
                Text("JAG ÄR REDO")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 40)
            }
            .opacity(engine.handoffReady ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.3), value: engine.handoffReady)
            .padding(.bottom, 60)
        }
        .onAppear {
            engine.handoffReady = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { engine.handoffReady = true }
        }
    }

    // MARK: - Start Game Logic

    private func startGame() {
        engine.setGameContext(mode: gameMode, bet: betAmount)
        let zoneOpponents = server.zoneMembers
            .filter { $0.username != player1Name }
            .map { $0.username }
        let ok = engine.startGame(
            player1Name: player1Name,
            gameMode: gameMode,
            betAmount: betAmount,
            zoneOpponents: zoneOpponents,
            useRandomOpponent: useRandomOpponent,
            selectedOpponentName: selectedOnlineOpponent?.username
        )
        if !ok {
            showInsufficientFundsAlert = true
        } else if gameMode == .onlineOneVsOne || gameMode == .onlineThreePlayer {
            let opponentName = selectedOnlineOpponent?.username ?? (useRandomOpponent ? "slumpmässig spelare" : "motståndare")
            NotificationManager.shared.sendYatzyChallenge(
                from: player1Name,
                stake: TimeEngine.shortFormatted(betAmount)
            )
            _ = opponentName  // used above for future server-push
        }
    }
}

// MARK: - Preview

#Preview {
    MultiplayerYatzyView()
        .preferredColorScheme(.dark)
}
