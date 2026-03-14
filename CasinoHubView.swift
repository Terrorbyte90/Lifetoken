import SwiftUI

struct CasinoHubView: View {
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    @State private var selectedGame: CasinoGame? = nil

    enum CasinoGame: String, Identifiable {
        case poker      = "Arm Poker"
        case roulette   = "Time Roulette"
        case slots      = "Countdown Slots"
        case blackjack  = "Blackjack"
        case lottery    = "Time Lottery"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !gameState.currentZone.casinoAccess {
                // No access view
                VStack(spacing: 24) {
                    Text("🎰")
                        .font(.system(size: 60))
                    Text("KASINO LÅST")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Kasino är tillgängligt från\nAetherpoint och uppåt.")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                    Text("Din zon: \(gameState.currentZone.name)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding()
            } else {
                ScrollView {
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
                            Text("Odds gynnar alltid huset")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)

                        // Game cards grid
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 16
                        ) {
                            CasinoGameCard(
                                icon: "suit.spade.fill",
                                title: "ARM POKER",
                                subtitle: "Texas Hold'em",
                                detail: "House rake: 5%",
                                color: .green,
                                locked: false
                            ) { selectedGame = .poker }

                            CasinoGameCard(
                                icon: "circle.grid.cross.fill",
                                title: "ROULETTE",
                                subtitle: "Europeisk",
                                detail: "House edge: 2.7%",
                                color: .red,
                                locked: false
                            ) { selectedGame = .roulette }

                            CasinoGameCard(
                                icon: "slider.horizontal.3",
                                title: "SLOTS",
                                subtitle: "Countdown",
                                detail: "RTP: 94%",
                                color: .yellow,
                                locked: false
                            ) { selectedGame = .slots }

                            CasinoGameCard(
                                icon: "rectangle.on.rectangle",
                                title: "BLACKJACK",
                                subtitle: "Classic 21",
                                detail: "House edge: 0.5%",
                                color: .cyan,
                                locked: false
                            ) { selectedGame = .blackjack }

                            CasinoGameCard(
                                icon: "ticket.fill",
                                title: "LOTTERI",
                                subtitle: "Veckojackpott",
                                detail: "Odds: 1:500 000",
                                color: .purple,
                                locked: false
                            ) { selectedGame = .lottery }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 80)
                    }
                }
            }
        }
        .sheet(item: $selectedGame) { game in
            switch game {
            case .poker:     PokerView()
            case .roulette:  RouletteGameView()
            case .slots:     SlotMachineView()
            case .blackjack: BlackjackView()
            case .lottery:   LotteryView()
            }
        }
    }
}

// MARK: - Game Card

struct CasinoGameCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let detail: String
    let color: Color
    let locked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if !locked { action() } }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(color)
                    Spacer()
                    if locked {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))
            }
            .padding(14)
            .background(locked ? Color.white.opacity(0.03) : Color.white.opacity(0.07))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(locked ? 0.1 : 0.3), lineWidth: 1)
            )
        }
        .disabled(locked)
    }
}
