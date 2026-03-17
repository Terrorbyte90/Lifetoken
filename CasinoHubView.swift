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

    @State private var bribeAccepted: Bool = false
    @State private var bribeMessage: String = ""
    @State private var showBribeResult: Bool = false

    private var needsDoorman: Bool {
        gameState.currentZone.index <= 3 && !bribeAccepted
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            if needsDoorman {
                doormanView
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
        .alert("Vakten låter dig in", isPresented: $showBribeResult) {
            Button("Gå in") { bribeAccepted = true }
        } message: { Text(bribeMessage) }
    }

    // MARK: - Doorman View (bottom 4 zones)
    private var doormanView: some View {
        ZStack {
            // Smoky atmosphere
            RadialGradient(
                colors: [Color(red: 0.12, green: 0.06, blue: 0.02).opacity(0.8), .black],
                center: .center, startRadius: 20, endRadius: 400
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Bouncer icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.08, blue: 0.04))
                        .frame(width: 90, height: 90)
                        .overlay(Circle().stroke(Color.red.opacity(0.4), lineWidth: 2))
                        .shadow(color: .red.opacity(0.3), radius: 12)
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 38))
                        .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.1))
                }
                .padding(.bottom, 20)

                Text("DÖRRVAKT")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.red.opacity(0.6))
                    .tracking(6)
                    .padding(.bottom, 12)

                // Doorman quote
                let quote = doormanQuotes[lockedMessageIndex % doormanQuotes.count]
                Text("\"\(quote)\"")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .italic()
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)

                // Bribe info
                let bribeAmount = engine.balance * 0.05
                VStack(spacing: 6) {
                    Text("MUT VAKTEN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow.opacity(0.5))
                        .tracking(3)
                    Text(TimeEngine.shortFormatted(bribeAmount))
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text("5% av din tid — varje besök")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(20)
                .background(Color.yellow.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                // Buttons
                VStack(spacing: 10) {
                    Button {
                        let bribe = engine.balance * 0.05
                        if TimeEngine.shared.deductTime(bribe) {
                            let formatted = TimeEngine.shortFormatted(bribe)
                            bribeMessage = "Du stack fram din klocka och förde över \(formatted) till vakten i smyg.\n\nVakten granskade dig från topp till tå, snöste och muttrade:\n\n\"Gå in då... ditt patrask.\""
                            showBribeResult = true
                        }
                    } label: {
                        Text("MUT VAKTEN")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(engine.balance < engine.balance * 0.05 + 60)
                    .padding(.horizontal, 32)

                    Button {
                        // Just dismiss / do nothing
                    } label: {
                        Text("Lämna platsen")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()
                Spacer()
            }
        }
    }

    private let doormanQuotes = [
        "Titta på sig själv — tror du verkligen att du hör hemma här?",
        "Jag har sett fattigare... men inte mycket fattigare.",
        "Listan är stängd. Kom tillbaka när du har råd att förlora.",
        "Den där klockan du bär... den räcker inte ens till dricksen.",
        "Eliten kliver inte i kö. Du gör det. Säger allt.",
        "Kasino är för dom som har råd att förlora. Är du den sortens person?"
    ]

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
