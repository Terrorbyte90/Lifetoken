import SwiftUI

// MARK: - PlayingCardView

struct PlayingCardView: View {
    let rank: String   // "A", "K", "Q", "J", "10", "2"-"9"
    let suit: String   // "♠", "♥", "♦", "♣"
    var faceDown: Bool = false
    var large: Bool = false

    var isRed: Bool { suit == "♥" || suit == "♦" }

    var body: some View {
        if faceDown {
            RoundedRectangle(cornerRadius: large ? 10 : 7)
                .fill(LinearGradient(
                    colors: [Color(red: 0.05, green: 0.25, blue: 0.1), Color(red: 0.02, green: 0.15, blue: 0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: large ? 64 : 40, height: large ? 90 : 56)
                .overlay(RoundedRectangle(cornerRadius: large ? 10 : 7).stroke(Color.green.opacity(0.5), lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 4)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: large ? 10 : 7)
                    .fill(Color.white)
                    .frame(width: large ? 64 : 40, height: large ? 90 : 56)
                    .shadow(color: .black.opacity(0.7), radius: 5, y: 3)

                VStack(spacing: 0) {
                    HStack {
                        VStack(spacing: -2) {
                            Text(rank)
                                .font(.system(size: large ? 16 : 10, weight: .bold, design: .default))
                                .foregroundColor(isRed ? .red : Color(white: 0.08))
                            Text(suit)
                                .font(.system(size: large ? 12 : 8))
                                .foregroundColor(isRed ? .red : Color(white: 0.08))
                        }
                        Spacer()
                    }
                    Spacer()
                    Text(suit)
                        .font(.system(size: large ? 28 : 18))
                        .foregroundColor(isRed ? .red : Color(white: 0.08))
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: -2) {
                            Text(suit)
                                .font(.system(size: large ? 12 : 8))
                                .foregroundColor(isRed ? .red : Color(white: 0.08))
                            Text(rank)
                                .font(.system(size: large ? 16 : 10, weight: .bold, design: .default))
                                .foregroundColor(isRed ? .red : Color(white: 0.08))
                        }
                        .rotationEffect(.degrees(180))
                    }
                }
                .padding(large ? 5 : 3)
                .frame(width: large ? 64 : 40, height: large ? 90 : 56)
            }
        }
    }
}

// MARK: - ChipView

struct ChipView: View {
    let amount: TimeInterval
    let label: String
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 48, height: 48)
            .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 2))
            .overlay(
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            )
            .shadow(color: .black.opacity(0.5), radius: 3)
    }
}

// MARK: - Helpers to convert Card to PlayingCardView inputs

private extension Card {
    var pvRank: String { rank.display }
    var pvSuit: String { suit.rawValue }
}

// MARK: - Blackjack Game State

enum BJGameState {
    case betting
    case playing
    case dealerTurn
    case done
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
    @State private var dealerHidden: Bool = true
    @State private var playerTotal:  Int = 0
    @State private var dealerTotal:  Int = 0
    @State private var splitActive:  Bool = false
    @State private var playingSplit: Bool = false

    // Chip definitions: (amount, label, color)
    private let chips: [(TimeInterval, String, Color)] = [
        (300, "5m", Color(red: 0.7, green: 0.45, blue: 0.2)),
        (1800, "30m", Color(red: 0.7, green: 0.7, blue: 0.7)),
        (3600, "1h", Color(red: 0.8, green: 0.7, blue: 0.1)),
        (21600, "6h", Color(red: 0.1, green: 0.4, blue: 0.9)),
        (86400, "1d", Color(red: 0.6, green: 0.1, blue: 0.8))
    ]

    var body: some View {
        ZStack {
            // Green felt background
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.25, blue: 0.1), Color(red: 0.02, green: 0.18, blue: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
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
    }

    // MARK: Sub-views

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.7))
                    .padding(8)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }
            Spacer()
            Text("BLACKJACK")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.3))
                .clipShape(Capsule())
        }
        .padding()
        .padding(.top, 20)
    }

    private var dealerSection: some View {
        VStack(spacing: 10) {
            Text(dealerHidden ? "DEALER" : "DEALER: \(dealerTotal)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            HStack(spacing: 8) {
                ForEach(Array(dealerCards.enumerated()), id: \.offset) { idx, card in
                    if idx == 1 && dealerHidden {
                        PlayingCardView(rank: "?", suit: "?", faceDown: true, large: true)
                    } else {
                        PlayingCardView(rank: card.pvRank, suit: card.pvSuit, large: true)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: dealerCards.count)
        }
    }

    private var playerSection: some View {
        VStack(spacing: 10) {
            if splitActive {
                HStack(spacing: 24) {
                    splitHandDisplay(cards: playerCards, total: handValue(playerCards), label: "HAND 1", active: !playingSplit)
                    splitHandDisplay(cards: splitCards, total: handValue(splitCards), label: "HAND 2", active: playingSplit)
                }
            } else {
                Text("DU: \(playerTotal)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(playerTotal > 21 ? .red : .white)
                HStack(spacing: 8) {
                    ForEach(playerCards) { card in
                        PlayingCardView(rank: card.pvRank, suit: card.pvSuit, large: true)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: playerCards.count)
            }
        }
    }

    private func splitHandDisplay(cards: [Card], total: Int, label: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Text("\(label): \(total)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(active ? .green : .white.opacity(0.4))
            HStack(spacing: 6) {
                ForEach(cards) { card in
                    PlayingCardView(rank: card.pvRank, suit: card.pvSuit, large: false)
                }
            }
        }
        .padding(8)
        .background(active ? Color.green.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(active ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    private var betAndControls: some View {
        VStack(spacing: 14) {
            Text("Insats: \(TimeEngine.shortFormatted(betAmount))")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.yellow)

            switch bjState {
            case .betting:    bettingControls
            case .playing:    playingControls
            case .dealerTurn:
                Text("Dealer drar...")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            case .done:
                Button { resetGame() } label: {
                    Text("NY HAND")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    private var bettingControls: some View {
        VStack(spacing: 12) {
            // Chip row
            HStack(spacing: 12) {
                ForEach(chips, id: \.0) { chip in
                    Button {
                        betAmount = min(chip.0, engine.balance)
                    } label: {
                        ChipView(amount: chip.0, label: chip.1, color: chip.2)
                    }
                }
            }
            .padding(.horizontal)

            Slider(
                value: $betAmount,
                in: 60...max(120, min(engine.balance, 86400 * 10)),
                step: 60
            )
            .tint(.green)
            .padding(.horizontal)

            Button { startGame() } label: {
                Text("SPELA  (\(TimeEngine.shortFormatted(betAmount)))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(betAmount > engine.balance ? Color.gray : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(betAmount > engine.balance)
            .padding(.horizontal)
        }
    }

    private var playingControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ActionButton(label: "HIT", color: .green) { playerHit() }
                ActionButton(label: "STAND", color: .gray) { playerStand() }
            }
            .padding(.horizontal)

            HStack(spacing: 10) {
                if activeHandCardCount() == 2 && engine.balance >= betAmount {
                    ActionButton(label: "DOUBLE", color: .yellow) { playerDouble() }
                }
                if canSplit() {
                    ActionButton(label: "SPLIT", color: .purple) { playerSplit() }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Game Logic

    func startGame() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        deck.reset()
        playerCards  = []
        splitCards   = []
        dealerCards  = []
        splitActive  = false
        playingSplit = false
        dealerHidden = true

        guard let pc1 = deck.deal(), let dc1 = deck.deal(),
              let pc2 = deck.deal(), let dc2 = deck.deal() else { return }
        playerCards.append(pc1)
        dealerCards.append(dc1)
        playerCards.append(pc2)
        dealerCards.append(dc2)

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
            playerCards.append(card)
            playerTotal = handValue(playerCards)
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
        resultMessage = "Bust! \(playerTotal) — Du förlorade \(TimeEngine.shortFormatted(betAmount))."
        bjState = .done
        showResult = true
    }

    func runDealerTurn() {
        dealerHidden = false
        dealerTotal  = handValue(dealerCards)
        bjState      = .dealerTurn
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.dealerDraw() }
    }

    func dealerDraw() {
        let soft = isSoft(dealerCards)
        if dealerTotal < 17 || (dealerTotal == 17 && soft) {
            if let card = deck.deal() { dealerCards.append(card) }
            dealerTotal = handValue(dealerCards)
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
        } else {
            let pTotal = handValue(playerCards)
            if pTotal > 21 {
                resultMessage = "Bust! Du förlorade \(TimeEngine.shortFormatted(betAmount))."
            } else if pTotal == 21 && playerCards.count == 2 {
                let net = betAmount * 2.5 * (1.0 - taxRate)
                TimeEngine.shared.addTime(net)
                GameState.shared.recordEarning(net - betAmount)
                resultMessage = "BLACKJACK! +\(TimeEngine.shortFormatted(net - betAmount)) (efter \(Int(taxRate * 100))% skatt)"
            } else if dealerTotal > 21 || pTotal > dealerTotal {
                let net = betAmount * 2.0 * (1.0 - taxRate)
                TimeEngine.shared.addTime(net)
                GameState.shared.recordEarning(net - betAmount)
                resultMessage = "Du vann! +\(TimeEngine.shortFormatted(net - betAmount)) (efter skatt)"
            } else if pTotal == dealerTotal {
                TimeEngine.shared.addTime(betAmount)
                resultMessage = "Lika! (\(pTotal) vs \(dealerTotal)) — insatsen återbetalad."
            } else {
                resultMessage = "Dealer vann (\(dealerTotal) mot \(pTotal)). Förlust: \(TimeEngine.shortFormatted(betAmount))."
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
    }
}

#Preview {
    BlackjackView()
        .preferredColorScheme(.dark)
}
