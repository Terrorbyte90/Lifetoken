import SwiftUI

struct CasinoHubView: View {
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var server = ServerSync.shared

    @State private var selectedGame: CasinoGame? = nil
    @State private var lockedMessageIndex: Int = Int.random(in: 0..<5)

    enum CasinoGame: String, Identifiable {
        case poker      = "Arm Poker"
        case roulette   = "Time Roulette"
        case slots      = "Countdown Slots"
        case blackjack  = "Blackjack"
        case lottery    = "Time Lottery"
        case yatzy      = "Yatzy"
        case crash      = "Crash"
        var id: String { rawValue }
    }

    let lockedMessages = [
        "Kasino? I din tidszon? Glöm det, grabben.",
        "Du är inte välkommen här. Ännu.",
        "Kasino existerar bara i rykten härifrån.",
        "Pengarna du inte har kan inte spelas bort.",
        "Gå och jobba istället."
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            if !gameState.currentZone.casinoAccess {
                lockedView
            } else {
                unlockedView
            }
        }
        .fullScreenCover(item: $selectedGame) { game in
            switch game {
            case .poker:     PokerView()
            case .roulette:  RouletteGameView()
            case .slots:     SlotMachineView()
            case .blackjack: BlackjackView()
            case .lottery:   LotteryView()
            case .yatzy:     MultiplayerYatzyView()
            case .crash:     CrashView()
            }
        }
    }

    // MARK: - Locked View
    private var lockedView: some View {
        ZStack {
            // Blurred silhouette of cards in background
            VStack {
                HStack(spacing: 8) {
                    ForEach(0..<4) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.03))
                            .frame(width: 50, height: 70)
                    }
                }
                .blur(radius: 4)
                .padding(.top, 80)
                Spacer()
            }

            // Red glow border
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                .blur(radius: 3)
                .padding(24)

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red.opacity(0.7))
                    .shadow(color: .red.opacity(0.4), radius: 12)

                Text("KASINO")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(lockedMessages[lockedMessageIndex])
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text("Klättra uppåt i zonerna för att låsa upp kasinot.\nStarka spelare spelar sina sekunder på hög risk.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    // MARK: - Unlocked View
    private var unlockedView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("⚡ KASINO")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.top, 60)
                    Text("Saldo: \(TimeEngine.formatted(engine.balance))")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(.yellow)
                    HStack(spacing: 16) {
                        Text("Oddsen gynnar alltid huset")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.red.opacity(0.7))
                        HStack(spacing: 4) {
                            Circle()
                                .fill(server.isOnline ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            Text("\(max(1, server.onlineCount)) online")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)

                // Game cards grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    CasinoGameCard(
                        icon: "suit.spade.fill",
                        title: "ARM POKER",
                        subtitle: "Texas Hold'em",
                        detail: "House rake: 5%",
                        gradient: [Color(red: 0.05, green: 0.25, blue: 0.12), Color(red: 0.02, green: 0.15, blue: 0.06)],
                        accentColor: .green,
                        locked: false
                    ) { selectedGame = .poker }

                    CasinoGameCard(
                        icon: "circle.grid.cross.fill",
                        title: "TIME ROULETTE",
                        subtitle: "Europeisk",
                        detail: "House edge: 2.7%",
                        gradient: [Color(red: 0.25, green: 0.04, blue: 0.04), Color(red: 0.15, green: 0.02, blue: 0.02)],
                        accentColor: .red,
                        locked: false
                    ) { selectedGame = .roulette }

                    CasinoGameCard(
                        icon: "slider.horizontal.3",
                        title: "COUNTDOWN SLOTS",
                        subtitle: "3-reel spinner",
                        detail: "RTP: 94%",
                        gradient: [Color(red: 0.25, green: 0.2, blue: 0.02), Color(red: 0.15, green: 0.12, blue: 0.02)],
                        accentColor: .yellow,
                        locked: false
                    ) { selectedGame = .slots }

                    CasinoGameCard(
                        icon: "rectangle.on.rectangle",
                        title: "BLACKJACK",
                        subtitle: "Classic 21",
                        detail: "House edge: 0.5%",
                        gradient: [Color(red: 0.02, green: 0.18, blue: 0.25), Color(red: 0.02, green: 0.10, blue: 0.15)],
                        accentColor: .cyan,
                        locked: false
                    ) { selectedGame = .blackjack }

                    CasinoGameCard(
                        icon: "ticket.fill",
                        title: "TIME LOTTERY",
                        subtitle: "Veckojackpott",
                        detail: "Odds: 1:500 000",
                        gradient: [Color(red: 0.2, green: 0.04, blue: 0.22), Color(red: 0.12, green: 0.02, blue: 0.14)],
                        accentColor: .purple,
                        locked: false
                    ) { selectedGame = .lottery }

                    CasinoGameCard(
                        icon: "dice.fill",
                        title: "YATZY DUELL",
                        subtitle: "Mot spelare eller AI",
                        detail: "Vinnaren tar allt",
                        gradient: [Color(red: 0.18, green: 0.12, blue: 0.02), Color(red: 0.10, green: 0.07, blue: 0.02)],
                        accentColor: .orange,
                        locked: false
                    ) { selectedGame = .yatzy }

                    CasinoGameCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "CRASH",
                        subtitle: "Cash out i tid",
                        detail: "House edge: ~5%",
                        gradient: [Color(red: 0.22, green: 0.04, blue: 0.04), Color(red: 0.12, green: 0.02, blue: 0.02)],
                        accentColor: Color(red: 1, green: 0.3, blue: 0.1),
                        locked: false
                    ) { selectedGame = .crash }
                }
                .padding(.horizontal)

                Spacer(minLength: 100)
            }
        }
    }
}

// MARK: - Premium Game Card

struct CasinoGameCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
    let gradient: [Color]
    let accentColor: Color
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if !locked { action() } }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundColor(accentColor)
                    }
                    Spacer()
                    if locked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.3))
                    }
                }

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                Text(detail)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(accentColor.opacity(0.8))
            }
            .padding(14)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accentColor.opacity(locked ? 0.1 : 0.35), lineWidth: 1)
            )
            .shadow(color: accentColor.opacity(0.1), radius: 8, x: 0, y: 4)
            .opacity(locked ? 0.5 : 1.0)
        }
        .disabled(locked)
    }
}

#Preview {
    CasinoHubView()
        .preferredColorScheme(.dark)
}
