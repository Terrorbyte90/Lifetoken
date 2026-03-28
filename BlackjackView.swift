import SwiftUI

// MARK: - PlayingCardView

struct PlayingCardView: View {
    let rank: String   // "A", "K", "Q", "J", "10", "2"-"9"
    let suit: String   // "♠", "♥", "♦", "♣"
    var faceDown: Bool = false
    var large: Bool = false

    // Kortets flip-state — triggas av parent
    var flipped: Bool = false

    var isRed: Bool { suit == "♥" || suit == "♦" }

    var body: some View {
        Group {
            if faceDown {
                faceDownCard
            } else {
                faceUpCard
            }
        }
        // Flip-animation på X-axeln vid avslöjning
        .scaleEffect(x: flipped ? 1 : 0, y: 1)
        .animation(.easeInOut(duration: 0.3), value: flipped)
    }

    private var faceDownCard: some View {
        RoundedRectangle(cornerRadius: large ? 10 : 7)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.25, blue: 0.1), Color(red: 0.02, green: 0.15, blue: 0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: large ? 64 : 40, height: large ? 90 : 56)
            .overlay(RoundedRectangle(cornerRadius: large ? 10 : 7).stroke(Color.green.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 4)
    }

    private var faceUpCard: some View {
        let w: CGFloat = large ? 64 : 40
        let h: CGFloat = large ? 90 : 56
        let r: CGFloat = large ? 10 : 7
        let p: CGFloat = large ? 4 : 3
        let rankFont = Font.system(size: large ? 14 : 9, weight: .bold)
        let suitSmall = Font.system(size: large ? 11 : 7)
        let suitCenter = Font.system(size: large ? 24 : 15)
        let cardColor = isRed ? Color.red : Color(white: 0.08)

        return RoundedRectangle(cornerRadius: r)
            .fill(Color.white)
            .frame(width: w, height: h)
            .shadow(color: .black.opacity(0.7), radius: 5, y: 3)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(rank).font(rankFont).foregroundColor(cardColor).lineLimit(1)
                    Text(suit).font(suitSmall).foregroundColor(cardColor).lineLimit(1)
                }
                .padding(p)
            }
            .overlay {
                Text(suit).font(suitCenter).foregroundColor(cardColor)
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(suit).font(suitSmall).foregroundColor(cardColor).lineLimit(1)
                    Text(rank).font(rankFont).foregroundColor(cardColor).lineLimit(1)
                }
                .rotationEffect(.degrees(180))
                .padding(p)
            }
            .clipShape(RoundedRectangle(cornerRadius: r))
    }
}

// MARK: - ChipView

struct ChipView: View {
    let amount: TimeInterval
    let label: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 52, height: 52)
                .shadow(color: color.opacity(0.5), radius: 6, y: 3)
            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 52, height: 52)
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 4)
                .frame(width: 44, height: 44)
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Hjälpfunktioner för att konvertera Card till PlayingCardView-parametrar

private extension Card {
    var pvRank: String { rank.display }
    var pvSuit: String { suit.rawValue }
}

// MARK: - Blackjack speltillstånd

enum BJGameState {
    case betting
    case playing
    case dealerTurn
    case done
}

// MARK: - Spelresultat-enum för visuell feedback

private enum BJOutcome {
    case win, loss, push, none
}

// MARK: - BlackjackView

struct BlackjackView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    @State private var deck          = Deck()
    @State private var playerCards:  [Card] = []
    @State private var splitCards:   [Card] = []
    @State private var dealerCards:  [Card] = []
    @State private var betAmount:    TimeInterval = 600
    @State private var bjState:      BJGameState = .betting
    @State private var resultMessage: String = ""
    @State private var showResult:   Bool = false
    @State private var showConfetti: Bool = false
    @State private var dealerHidden: Bool = true
    @State private var playerTotal:  Int = 0
    @State private var dealerTotal:  Int = 0
    @State private var splitActive:  Bool = false
    @State private var playingSplit: Bool = false
    @State private var outcome:      BJOutcome = .none
    @State private var cardFlipStates: [Int: Bool] = [:]

    // Chip-definitioner: (belopp, etikett, färg)
    private let chips: [(TimeInterval, String, Color)] = [
        (300,   "5m",  Color(red: 0.7, green: 0.45, blue: 0.2)),
        (1800,  "30m", Color(red: 0.7, green: 0.7, blue: 0.7)),
        (3600,  "1h",  Color(red: 0.8, green: 0.7, blue: 0.1)),
        (21600, "6h",  Color(red: 0.1, green: 0.4, blue: 0.9)),
        (86400, "1d",  Color(red: 0.6, green: 0.1, blue: 0.8))
    ]

    // Resultat-glödfärg
    private var outcomeGlowColor: Color {
        switch outcome {
        case .win:  return .green
        case .loss: return .red
        case .push: return .yellow
        case .none: return .clear
        }
    }

    var body: some View {
        ZStack {
            // Mörkgrön filtbakgrund
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.18, blue: 0.08), Color(red: 0.02, green: 0.10, blue: 0.04)],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            // Dekorativ oval bordsform
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.6, green: 0.5, blue: 0.1).opacity(0.6), Color(red: 0.3, green: 0.25, blue: 0.05).opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: 340, height: 500)
                .opacity(0.4)

            // Glöd-overlay vid vinst/förlust/lika
            if outcome != .none {
                RoundedRectangle(cornerRadius: 0)
                    .fill(outcomeGlowColor.opacity(0.06))
                    .ignoresSafeArea()
                    .animation(.easeIn(duration: 0.3), value: outcome)
            }

            VStack(spacing: 0) {
                headerBar
                LTInfoCallout(
                    title: "Blackjacktips",
                    message: "Målet är att slå dealern utan att gå över 21. Split och double används bäst när handen är stark.",
                    icon: "suit.spade.fill",
                    tint: .yellow
                )
                .padding(.horizontal)
                .padding(.top, 10)
                Spacer()
                dealerSection.padding(.top, 8)
                Spacer()
                playerSection
                betAndControls.padding(.bottom, 20)
            }
        }
        .alert("Resultat", isPresented: $showResult) {
            Button("OK") { resetGame() }
        } message: {
            Text(resultMessage)
        }
        .overlay {
            if showConfetti {
                CasinoParticleView()
                    .environmentObject(ThemeEngine.shared)
            }
        }
    }

    // MARK: - Delvyer

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(10)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("BLACKJACK 21")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("Hus 0.5%")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.6))
            }
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.yellow.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
        }
        .padding()
        .padding(.top, 20)
        .background(Color.black.opacity(0.25))
    }

    private var dealerSection: some View {
        VStack(spacing: 12) {
            // DEALER-badge i guld
            HStack(spacing: 6) {
                Text(dealerHidden ? "DEALER" : "DEALER: \(dealerTotal)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.85, green: 0.7, blue: 0.1), Color(red: 0.6, green: 0.48, blue: 0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .yellow.opacity(0.4), radius: 6)
            }

            HStack(spacing: 10) {
                ForEach(dealerCards.indices, id: \.self) { idx in
                    let card = dealerCards[idx]
                    if idx == 1 && dealerHidden {
                        PlayingCardView(rank: "?", suit: "?", faceDown: true, large: true, flipped: true)
                    } else {
                        PlayingCardView(
                            rank: card.pvRank,
                            suit: card.pvSuit,
                            large: true,
                            flipped: cardFlipStates[idx + 100] ?? true
                        )
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: dealerCards.count)
        }
    }

    private var playerSection: some View {
        VStack(spacing: 12) {
            if splitActive {
                HStack(spacing: 24) {
                    splitHandDisplay(cards: playerCards, total: handValue(playerCards), label: "HAND 1", active: !playingSplit)
                    splitHandDisplay(cards: splitCards, total: handValue(splitCards), label: "HAND 2", active: playingSplit)
                }
            } else {
                // Spelarens totalsumma med färgindikering
                HStack(spacing: 6) {
                    Text("DU:")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(playerTotal)")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(playerTotal > 21 ? .red : (playerTotal == 21 ? .yellow : .white))
                        .shadow(
                            color: playerTotal > 21 ? .red.opacity(0.6) : (playerTotal == 21 ? .yellow.opacity(0.6) : .clear),
                            radius: 8
                        )
                }

                HStack(spacing: 10) {
                    ForEach(Array(playerCards.enumerated()), id: \.offset) { idx, card in
                        PlayingCardView(
                            rank: card.pvRank,
                            suit: card.pvSuit,
                            large: true,
                            flipped: cardFlipStates[idx] ?? true
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: playerCards.count)
            }
        }
    }

    private func splitHandDisplay(cards: [Card], total: Int, label: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Text("\(label): \(total)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(active ? .yellow : .white.opacity(0.4))
            HStack(spacing: 6) {
                ForEach(cards) { card in
                    PlayingCardView(rank: card.pvRank, suit: card.pvSuit, large: false, flipped: true)
                }
            }
        }
        .padding(10)
        .background(active ? Color.green.opacity(0.12) : Color.black.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(active ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1), lineWidth: active ? 1.5 : 0.5)
        )
        .shadow(color: active ? .yellow.opacity(0.15) : .clear, radius: 8)
    }

    private var betAndControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Text("INSATS:")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Text(TimeEngine.shortFormatted(betAmount))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.4), radius: 6)
            }

            switch bjState {
            case .betting:    bettingControls
            case .playing:    playingControls
            case .dealerTurn:
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.yellow)
                    Text("Dealer drar...")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 16)
            case .done:
                Button { resetGame() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .bold))
                        Text("NY HAND")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.7, green: 0.6, blue: 0.1), Color(red: 0.5, green: 0.4, blue: 0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .yellow.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    private var bettingControls: some View {
        VStack(spacing: 14) {
            // Chip-rad
            HStack(spacing: 10) {
                ForEach(chips, id: \.0) { chip in
                    Button {
                        betAmount = min(chip.0, engine.balance)
                    } label: {
                        ChipView(amount: chip.0, label: chip.1, color: chip.2)
                    }
                    .buttonStyle(LTPressEffect(scale: 0.92))
                }
            }
            .padding(.horizontal)

            Slider(
                value: $betAmount,
                in: 60...max(120, min(engine.balance, 86400 * 10)),
                step: 60
            )
            .tint(Color(red: 0.7, green: 0.6, blue: 0.1))
            .padding(.horizontal)

            LTInfoCallout(
                title: "Insatsnivå",
                message: "Anpassa insatsen efter din buffert. En längre session kräver utrymme för varians.",
                icon: "banknote.fill",
                tint: .green
            )
            .padding(.horizontal)

            Button { startGame() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "suit.spade.fill")
                        .font(.system(size: 16))
                    Text("SPELA  (\(TimeEngine.shortFormatted(betAmount)))")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                }
                .foregroundColor(betAmount > engine.balance ? .white.opacity(0.4) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background {
                    if betAmount > engine.balance {
                        Color(white: 0.2)
                    } else {
                        LinearGradient(
                            colors: [Color(red: 0.7, green: 0.6, blue: 0.1), Color(red: 0.5, green: 0.4, blue: 0.05)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: betAmount > engine.balance ? .clear : .yellow.opacity(0.4), radius: 8, y: 4)
            }
            .disabled(betAmount > engine.balance)
            .padding(.horizontal)
        }
    }

    private var playingControls: some View {
        VStack(spacing: 12) {
            // Primära knappar — Hit och Stand som stora capsule-knappar
            HStack(spacing: 12) {
                premiumActionButton(label: "HIT", icon: "plus.circle.fill", color: .green) { playerHit() }
                premiumActionButton(label: "STAND", icon: "hand.raised.fill", color: Color(red: 0.5, green: 0.5, blue: 0.6)) { playerStand() }
            }
            .padding(.horizontal)

            // Sekundära knappar — Double och Split
            HStack(spacing: 12) {
                if activeHandCardCount() == 2 && engine.balance >= betAmount {
                    premiumActionButton(label: "DOUBLE", icon: "arrow.up.circle.fill", color: Color(red: 0.85, green: 0.7, blue: 0.1)) { playerDouble() }
                }
                if canSplit() {
                    premiumActionButton(label: "SPLIT", icon: "arrow.left.and.right.circle.fill", color: Color(red: 0.55, green: 0.1, blue: 0.75)) { playerSplit() }
                }
            }
            .padding(.horizontal)
        }
    }

    // Premium casino-stilknapp som Capsule
    private func premiumActionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                Text(label)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.5), radius: 8, y: 4)
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(LTPressEffect(scale: 0.94))
    }

    // MARK: - Spellogik

    func startGame() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        deck.reset()
        playerCards  = []
        splitCards   = []
        dealerCards  = []
        splitActive  = false
        playingSplit = false
        dealerHidden = true
        outcome      = .none
        cardFlipStates = [:]

        guard let pc1 = deck.deal(), let dc1 = deck.deal(),
              let pc2 = deck.deal(), let dc2 = deck.deal() else { return }

        // Dela ut kort med fördröjd flip-animation
        playerCards.append(pc1)
        dealerCards.append(dc1)
        playerCards.append(pc2)
        dealerCards.append(dc2)

        // Trigga flip-animationer med liten fördröjning per kort
        for i in 0..<2 {
            let delay = Double(i) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation { cardFlipStates[i] = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { cardFlipStates[100] = true }
        }

        playerTotal  = handValue(playerCards)
        dealerTotal  = handValue(dealerCards)
        bjState      = .playing

        if playerTotal == 21 { runDealerTurn() }
    }

    func handValue(_ cards: [Card]) -> Int {
        var value = 0
        var aces  = 0
        for card in cards {
            switch card.rank {
            case .ace:                       value += 11; aces += 1
            case .jack, .queen, .king:       value += 10
            default:                         value += card.rank.rawValue
            }
        }
        while value > 21 && aces > 0 { value -= 10; aces -= 1 }
        return value
    }

    func isSoft(_ cards: [Card]) -> Bool {
        var value = 0; var aces = 0
        for card in cards {
            switch card.rank {
            case .ace:                       value += 11; aces += 1
            case .jack, .queen, .king:       value += 10
            default:                         value += card.rank.rawValue
            }
        }
        return aces > 0 && value <= 21
    }

    func playerHit() {
        guard let card = deck.deal() else { return }
        if playingSplit {
            splitCards.append(card)
            let total = handValue(splitCards)
            if total > 21 { runDealerTurn() }
        } else {
            let idx = playerCards.count
            playerCards.append(card)
            playerTotal = handValue(playerCards)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation { cardFlipStates[idx] = true }
            }
            if playerTotal > 21 { bustPlayer() }
        }
    }

    func playerStand() {
        if splitActive && !playingSplit {
            playingSplit = true
        } else {
            runDealerTurn()
        }
    }

    func playerDouble() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        betAmount *= 2
        playerHit()
        if (playingSplit ? handValue(splitCards) : playerTotal) <= 21 {
            playerStand()
        }
    }

    func playerSplit() {
        guard !splitActive, playerCards.count == 2 else { return }
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        splitCards  = [playerCards.removeLast()]
        splitActive = true
        playingSplit = false
        if let c1 = deck.deal() { playerCards.append(c1) }
        if let c2 = deck.deal() { splitCards.append(c2) }
        playerTotal = handValue(playerCards)
    }

    func bustPlayer() {
        dealerHidden = false
        outcome = .loss
        resultMessage = "Bust! \(playerTotal) — Du förlorade \(TimeEngine.shortFormatted(betAmount))."
        bjState = .done
        showResult = true
    }

    func runDealerTurn() {
        dealerHidden = false
        // Avslöja dealerens dolda kort med flip
        withAnimation { cardFlipStates[101] = true }
        dealerTotal  = handValue(dealerCards)
        bjState      = .dealerTurn
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.dealerDraw() }
    }

    func dealerDraw() {
        let soft = isSoft(dealerCards)
        if dealerTotal < 17 || (dealerTotal == 17 && soft) {
            if let card = deck.deal() {
                let idx = dealerCards.count + 100
                dealerCards.append(card)
                dealerTotal = handValue(dealerCards)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { cardFlipStates[idx] = true }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.dealerDraw() }
        } else {
            determineOutcome()
        }
    }

    func determineOutcome() {
        bjState = .done
        let taxRate = gameState.currentZone.taxRate

        if splitActive {
            let h1 = handValue(playerCards)
            let h2 = handValue(splitCards)
            var msgs: [String] = []
            var netGain: TimeInterval = 0

            for (label, hTotal) in [("Hand 1", h1), ("Hand 2", h2)] {
                if hTotal > 21 {
                    msgs.append("\(label): Bust — förlust")
                } else if dealerTotal > 21 || hTotal > dealerTotal {
                    let win = betAmount * 2.0 * (1.0 - taxRate)
                    TimeEngine.shared.addTime(win)
                    netGain += win - betAmount
                    MissionsManager.incrementProgress("casino_total_wins")
                    msgs.append("\(label): Vinst! +\(TimeEngine.shortFormatted(win - betAmount))")
                } else if hTotal == dealerTotal {
                    TimeEngine.shared.addTime(betAmount)
                    msgs.append("\(label): Lika — insatsen tillbaka")
                } else {
                    msgs.append("\(label): Förlust")
                }
            }
            if netGain > 0 { GameState.shared.recordEarning(netGain) }
            resultMessage = msgs.joined(separator: "\n")
            outcome = netGain > 0 ? .win : .loss
        } else {
            let pTotal = handValue(playerCards)
            if pTotal > 21 {
                outcome = .loss
                resultMessage = "Bust! Du förlorade \(TimeEngine.shortFormatted(betAmount))."
                TransactionLedger.shared.record(label: "Blackjack — bust", amount: -betAmount)
            } else if pTotal == 21 && playerCards.count == 2 {
                let net = betAmount * 2.5 * (1.0 - taxRate)
                TimeEngine.shared.addTime(net)
                GameState.shared.recordEarning(net - betAmount)
                MissionsManager.incrementProgress("casino_total_wins")
                TransactionLedger.shared.record(label: "Blackjack — blackjack!", amount: net - betAmount)
                resultMessage = "BLACKJACK! +\(TimeEngine.shortFormatted(net - betAmount)) (efter \(Int(taxRate * 100))% skatt)"
                outcome = .win
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showConfetti = false }
            } else if dealerTotal > 21 || pTotal > dealerTotal {
                let net = betAmount * 2.0 * (1.0 - taxRate)
                TimeEngine.shared.addTime(net)
                GameState.shared.recordEarning(net - betAmount)
                MissionsManager.incrementProgress("casino_total_wins")
                TransactionLedger.shared.record(label: "Blackjack — vinst", amount: net - betAmount)
                resultMessage = "Du vann! +\(TimeEngine.shortFormatted(net - betAmount)) (efter skatt)"
                outcome = .win
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showConfetti = false }
            } else if pTotal == dealerTotal {
                TimeEngine.shared.addTime(betAmount)
                TransactionLedger.shared.record(label: "Blackjack — lika", amount: 0)
                resultMessage = "Lika! (\(pTotal) vs \(dealerTotal)) — insatsen återbetalad."
                outcome = .push
            } else {
                TransactionLedger.shared.record(label: "Blackjack — förlust", amount: -betAmount)
                resultMessage = "Dealer vann (\(dealerTotal) mot \(pTotal)). Förlust: \(TimeEngine.shortFormatted(betAmount))."
                outcome = .loss
            }
        }
        showResult = true
    }

    func canSplit() -> Bool {
        guard !splitActive, playerCards.count == 2 else { return false }
        guard engine.balance >= betAmount else { return false }
        let v1 = min(playerCards[0].rank.rawValue, 10)
        let v2 = min(playerCards[1].rank.rawValue, 10)
        return v1 == v2
    }

    func activeHandCardCount() -> Int {
        playingSplit ? splitCards.count : playerCards.count
    }

    func resetGame() {
        playerCards  = []
        splitCards   = []
        dealerCards  = []
        splitActive  = false
        playingSplit = false
        playerTotal  = 0
        dealerTotal  = 0
        dealerHidden = true
        betAmount    = 600
        bjState      = .betting
        outcome      = .none
        cardFlipStates = [:]
    }
}

#Preview {
    BlackjackView()
        .preferredColorScheme(.dark)
}
