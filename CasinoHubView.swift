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
                // Locked state — filminspirad design
                VStack(spacing: 28) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 100, height: 100)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.25))
                    }

                    VStack(spacing: 10) {
                        Text("KASINO LÅST")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        Text("Kasinot tillhör de som har råd att förlora.")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                            .multilineTextAlignment(.center)
                            .italic()
                            .padding(.horizontal)

                        Text("Tillgängligt från Aetherpoint och uppåt")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    VStack(spacing: 12) {
                        Text("Kräver zonen Aetherpoint")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.8))

                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.yellow)
                            Text("Inträdesavgift: \(TimeEngine.shortFormatted(ZoneProfile.aetherpoint.entryCostSeconds))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.yellow)
                        }

                        Text("Nuvarande zon: \(gameState.currentZone.name)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(gameState.currentZone.color)
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 6) {
                            Text("KASINO")
                                .font(.system(size: 26, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.top, 60)
                            HStack(spacing: 8) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                Text(TimeEngine.shortFormatted(engine.balance))
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            Text("Huset vinner alltid — på lång sikt.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.red.opacity(0.6))
                                .italic()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)

                        // Spel-grid
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 14
                        ) {
                            CasinoGameCard(
                                icon: "suit.spade.fill",
                                title: "ARM POKER",
                                subtitle: "Texas Hold'em",
                                detail: "Rake: 5%",
                                color: .green,
                                locked: false
                            ) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                selectedGame = .poker
                            }

                            CasinoGameCard(
                                icon: "circle.grid.cross.fill",
                                title: "ROULETTE",
                                subtitle: "Europeisk",
                                detail: "House edge: 2.7%",
                                color: .red,
                                locked: false
                            ) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                selectedGame = .roulette
                            }

                            CasinoGameCard(
                                icon: "slider.horizontal.3",
                                title: "SLOTS",
                                subtitle: "Countdown",
                                detail: "RTP: 94%",
                                color: .yellow,
                                locked: false
                            ) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                selectedGame = .slots
                            }

                            CasinoGameCard(
                                icon: "rectangle.on.rectangle",
                                title: "BLACKJACK",
                                subtitle: "Classic 21",
                                detail: "House edge: 0.5%",
                                color: .cyan,
                                locked: false
                            ) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                selectedGame = .blackjack
                            }

                            CasinoGameCard(
                                icon: "ticket.fill",
                                title: "LOTTERI",
                                subtitle: "Veckojackpott",
                                detail: "Odds: 1:500 000",
                                color: .purple,
                                locked: false
                            ) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                selectedGame = .lottery
                            }
                        }
                        .padding(.horizontal)

                        // Ansvarsfullt spelande-banner
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange.opacity(0.6))
                                .font(.system(size: 12))
                            Text("Spela ansvarsfullt. Tid förlorad i kasino återfås inte.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        Spacer(minLength: 100)
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

    @State private var pressed = false

    var body: some View {
        Button(action: { if !locked { action() } }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(color)
                    }
                    Spacer()
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                    Text(detail)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(color.opacity(0.7))
                }
            }
            .padding(14)
            .background(locked ? Color.white.opacity(0.03) : Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(locked ? 0.08 : 0.25), lineWidth: 1)
            )
            .scaleEffect(pressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
        }
        .disabled(locked)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }
        )
    }
}
