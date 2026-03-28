import SwiftUI
import AVKit
import UIKit

// MARK: - Video-kort för kasinots entré

struct CasinoVideoCard: View {
    @State private var player: AVPlayer? = nil

    var body: some View {
        ZStack {
            Group {
                if let p = player {
                    LoopingVideoPlayer(player: p)
                } else {
                    Color.black
                }
            }
            .frame(height: 180)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)

            VStack {
                Spacer()
                Text("CASINO")
                    .font(.system(size: 36, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.8), radius: 12)
                    .padding(.bottom, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            guard let url = Bundle.main.url(forResource: "Casino", withExtension: "mp4") else { return }
            let p = AVPlayer(url: url)
            p.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: p.currentItem,
                queue: .main
            ) { _ in
                p.seek(to: .zero)
                p.play()
            }
            p.play()
            player = p
        }
        .onDisappear { player?.pause() }
    }
}

// MARK: - Casino Hub — Fullständigt omdesignad

struct CasinoHubView: View {
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var server = ServerSync.shared
    @ObservedObject private var reputation = ZoneReputationManager.shared
    @ObservedObject private var governance = GovernanceManager.shared
    @ObservedObject private var nightMarket = NightMarketManager.shared
    @AppStorage("selectedTab") private var selectedTab: Int = 0

    @State private var selectedGame: CasinoGame? = nil
    @State private var lockedMessageIndex: Int = Int.random(in: 0..<6)
    @State private var bribeAccepted: Bool = false
    @State private var bribePhase: BribePhase = .idle
    @State private var bribeStatusText: String = ""
    @State private var bribeMessage: String = ""
    @State private var pulseGlow: Bool = false

    enum BribePhase { case idle, deducting, accepted, denied }

    enum CasinoGame: String, Identifiable {
        case poker      = "poker"
        case roulette   = "roulette"
        case blackjack  = "blackjack"
        case yatzy      = "yatzy"
        case crash      = "crash"
        var id: String { rawValue }
    }

    // Varierade avvisningsmeddelanden vid mutor som inte accepteras
    private let bribeRejections = [
        "Vakten sneglar på dina token... men skakar på huvudet.",
        "Han tar emot, tittar ner, och säger 'inte tillräckligt.'",
        "Vakten visslar lågt. Inte imponerad.",
        "Du räcker fram handen. Han ignorerar den.",
        "Vakten ler kallt. Du blir inte insläppt."
    ]

    private let doormanQuotes = [
        "Titta på sig själv — tror du verkligen att du hör hemma här?",
        "Jag har sett fattigare... men inte mycket fattigare.",
        "Listan är stängd. Kom tillbaka när du har råd att förlora.",
        "Den där klockan du bär... räcker inte ens till dricksen.",
        "Eliten kliver inte i kö. Du gör det. Säger allt.",
        "Kasinot är för dom som har råd att förlora. Är du den sortens person?"
    ]

    private var needsDoorman: Bool {
        gameState.currentZone.index <= 3 && !bribeAccepted
    }

    private var suggestedGame: CasinoGame {
        if engine.balance < 1800 { return .blackjack }
        if engine.balance > 86400 * 3 { return .poker }
        return .roulette
    }

    private var zoneReputation: Int {
        reputation.reputation(for: gameState.currentZone.name)
    }

    private var zoneTone: String {
        reputation.npcTone(for: gameState.currentZone.name)
    }

    var body: some View {
        ZStack {
            // Djup kasinobakgrund
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.01, blue: 0.04), Color(red: 0.04, green: 0.02, blue: 0.06), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            // Atmosfärisk glöd
            RadialGradient(
                colors: [Color(red: 0.4, green: 0.1, blue: 0.6).opacity(pulseGlow ? 0.12 : 0.07), .clear],
                center: .top, startRadius: 0, endRadius: 500
            ).ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulseGlow)

            if needsDoorman {
                doormanView
            } else {
                casinoFloor
            }
        }
        .fullScreenCover(item: $selectedGame) { game in
            switch game {
            case .poker:     PokerView()
            case .roulette:  RouletteGameView()
            case .blackjack: BlackjackView()
            case .yatzy:     MultiplayerYatzyView()
            case .crash:     CrashView()
            }
        }
        .onAppear { pulseGlow = true }
    }

    // MARK: - Dörrvakt

    private var doormanView: some View {
        ZStack {
            // Mörk rökig entré
            RadialGradient(
                colors: [Color(red: 0.1, green: 0.04, blue: 0.02).opacity(0.9), Color.black],
                center: .center, startRadius: 10, endRadius: 420
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                CasinoVideoCard()
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                Text("DÖRRVAKT")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.5))
                    .tracking(8)
                    .padding(.bottom, 20)

                Text("\"\(doormanQuotes[lockedMessageIndex % doormanQuotes.count])\"")
                    .font(.system(size: 14, design: .monospaced))
                    .italic()
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 32)

                LTInfoCallout(
                    title: "Entréregel",
                    message: "I lägre zoner krävs muta för tillgång till kasinot. När du växer i zoner får du direktaccess.",
                    icon: "person.crop.rectangle.badge.exclamationmark",
                    tint: .yellow
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                // Mutningssektion
                let bribeAmt = engine.balance * 0.05

                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("FÖRSÖK MUTA VAKTEN")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow.opacity(0.5))
                            .tracking(4)
                        Text(TimeEngine.shortFormatted(bribeAmt))
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                            .shadow(color: .yellow.opacity(0.3), radius: 8)
                        Text("5% av din balans — engångsavgift för detta besök")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(20)
                    .background(Color.yellow.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.15), lineWidth: 1))

                    // Statustext visas efter mutningsförsök
                    if bribePhase != .idle {
                        Text(bribeStatusText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(bribePhase == .accepted ? .green : .red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred()
                        attemptBribe()
                    } label: {
                        HStack(spacing: LTSpacing.sm) {
                            Image(systemName: "banknote")
                            Text("FÖRSÖK MUTA VAKTEN")
                                .font(LTFont.heading(14))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [LTPalette.gold, Color(red: 0.9, green: 0.7, blue: 0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                        .shadow(color: LTPalette.gold.opacity(0.35), radius: 12, y: 4)
                        .opacity(bribePhase == .deducting ? 0.5 : 1.0)
                    }
                    .buttonStyle(LTPressEffect())
                    .disabled(bribePhase == .deducting || engine.balance < bribeAmt + 60)
                    .accessibilityLabel("Försök muta vakten för \(TimeEngine.shortFormatted(bribeAmt))")
                    .padding(.horizontal, 32)

                    Button("Lämna platsen") { selectedTab = 0 }
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }

                Spacer()
                Spacer()
            }
        }
    }

    private func attemptBribe() {
        let bribe = engine.balance * 0.05
        bribePhase = .deducting
        if TimeEngine.shared.deductTime(bribe) {
            withAnimation(.spring()) {
                bribeStatusText = "Vakten granskar dig... nickar långsamt.\n\"Gå in då. Men rör ingenting.\""
                bribePhase = .accepted
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { bribeAccepted = true }
            }
        } else {
            // Välj ett slumpmässigt avvisningsmeddelande
            let rejection = bribeRejections.randomElement() ?? bribeRejections[0]
            withAnimation(.spring()) {
                bribeStatusText = rejection
                bribePhase = .denied
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { bribePhase = .idle }
            }
        }
    }

    // MARK: - Kasinogolvet

    private var casinoFloor: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                casinoHeader

                casinoIntelPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                featuredTableCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                // Spelkort-rutnät
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    gameCard(
                        .poker,
                        icon: "suit.spade.fill",
                        title: "TEXAS HOLD'EM",
                        subtitle: "5% husfördel",
                        tag: "Hus 5%",
                        gradient: [Color(red: 0.05, green: 0.25, blue: 0.10), Color(red: 0.02, green: 0.12, blue: 0.05)],
                        accent: Color(red: 0.2, green: 0.9, blue: 0.4)
                    )
                    gameCard(
                        .roulette,
                        icon: "circle.grid.cross.fill",
                        title: "EUROPEISK ROULETT",
                        subtitle: "Europeisk variant",
                        tag: "Hus 2.7%",
                        gradient: [Color(red: 0.28, green: 0.04, blue: 0.04), Color(red: 0.14, green: 0.02, blue: 0.02)],
                        accent: Color.red
                    )
                    gameCard(
                        .blackjack,
                        icon: "rectangle.on.rectangle",
                        title: "BLACKJACK 21",
                        subtitle: "Klassiskt 21",
                        tag: "Hus 0.5%",
                        gradient: [Color(red: 0.02, green: 0.18, blue: 0.28), Color(red: 0.01, green: 0.10, blue: 0.16)],
                        accent: Color.cyan
                    )
                    gameCard(
                        .yatzy,
                        icon: "dice.fill",
                        title: "YATZY",
                        subtitle: "Mot spel/AI",
                        tag: "Vinnaren tar allt",
                        gradient: [Color(red: 0.20, green: 0.13, blue: 0.02), Color(red: 0.10, green: 0.07, blue: 0.01)],
                        accent: Color.orange
                    )
                    gameCard(
                        .crash,
                        icon: "chart.line.uptrend.xyaxis",
                        title: "ROCKET CRASH",
                        subtitle: "Cash out i tid",
                        tag: "Hus ~5%",
                        gradient: [Color(red: 0.26, green: 0.04, blue: 0.04), Color(red: 0.13, green: 0.02, blue: 0.02)],
                        accent: Color(red: 1, green: 0.35, blue: 0.1)
                    )
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 100)
            }
        }
    }

    private var casinoIntelPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KASINO-INTEL")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .tracking(3)

            HStack(spacing: 8) {
                infoPill(
                    icon: "person.wave.2.fill",
                    text: "Rykte \(zoneReputation)/50",
                    color: .mint
                )
                infoPill(
                    icon: nightMarket.isOpen ? "moon.stars.fill" : "moon.zzz.fill",
                    text: nightMarket.isOpen ? "Nattmarknad öppen" : "Nattmarknad stängd",
                    color: nightMarket.isOpen ? .purple : .gray
                )
            }

            HStack(spacing: 8) {
                infoPill(
                    icon: "bubble.left.and.bubble.right.fill",
                    text: zoneTone,
                    color: zoneReputation >= 40 ? .green : (zoneReputation >= 20 ? .yellow : .red)
                )
                if let activeRule = governance.activeRule {
                    infoPill(
                        icon: "building.columns.fill",
                        text: activeRule.type.title,
                        color: .orange
                    )
                } else {
                    infoPill(
                        icon: "building.columns",
                        text: "Inga globala regler",
                        color: .gray
                    )
                }
            }

            LTInfoCallout(
                title: "Kasinointel",
                message: "Högre rykte ger bättre bemötande och kan indirekt förbättra dina val i zonens ekonomisystem.",
                icon: "brain.head.profile",
                tint: .mint
            )
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var featuredTableCard: some View {
        Button {
            selectedGame = suggestedGame
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("REKOMMENDERAT BORD")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(2)
                    Text(featuredTitle(for: suggestedGame))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Baserat på saldo och zonstatus")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.orange.opacity(0.9))
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(LTPressEffect(scale: 0.98))
    }

    private func featuredTitle(for game: CasinoGame) -> String {
        switch game {
        case .poker: return "TEXAS HOLD'EM"
        case .roulette: return "EUROPEISK ROULETT"
        case .blackjack: return "BLACKJACK 21"
        case .yatzy: return "YATZY"
        case .crash: return "ROCKET CRASH"
        }
    }

    private func infoPill(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(color.opacity(0.95))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.32), lineWidth: 1))
    }

    private var casinoHeader: some View {
        VStack(spacing: 10) {
            // Onlinestatus
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(server.isOnline ? Color.green : Color.red)
                        .frame(width: 5, height: 5)
                    Text("\(max(1, server.onlineCount)) online")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)

            // Videokort med kasinonamn
            CasinoVideoCard()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Text(TimeEngine.formatted(engine.balance))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.3))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.08))
                .clipShape(Capsule())

            Text("ODDSEN GYNNAR ALLTID HUSET")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.red.opacity(0.5))
                .tracking(3)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func gameCard(
        _ game: CasinoGame,
        icon: String,
        title: String,
        subtitle: String,
        tag: String,
        gradient: [Color],
        accent: Color
    ) -> some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            selectedGame = game
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.18))
                            .frame(width: 40, height: 40)
                            .shadow(color: accent.opacity(0.3), radius: 6)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundColor(accent)
                    }
                    Spacer()
                    Text(tag)
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(accent.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.12))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                    Text(subtitle)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                }

                // Glödande botten-bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent.opacity(0.5))
                    .frame(height: 2)
                    .shadow(color: accent.opacity(0.6), radius: 4)
            }
            .padding(14)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(accent.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.12), radius: 10, y: 5)
        }
        .buttonStyle(LTPressEffect(scale: 0.95))
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

#Preview {
    CasinoHubView()
        .preferredColorScheme(.dark)
}
