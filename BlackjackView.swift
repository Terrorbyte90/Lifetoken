import SwiftUI

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
    @State private var splitCards:   [Card] = []          // split hand (if used)
    @State private var dealerCards:  [Card] = []
    @State private var betAmount:    TimeInterval = 600   // 10 minutes default
    @State private var bjState:      BJGameState = .betting
    @State private var resultMessage: String = ""
    @State private var showResult:   Bool = false
    @State private var dealerHidden: Bool = true
    @State private var playerTotal:  Int = 0
    @State private var dealerTotal:  Int = 0
    @State private var splitActive:  Bool = false
    @State private var playingSplit: Bool = false          // true = acting on split hand

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                Spacer()

                dealerSection
                    .padding(.top, 8)

                Spacer()

                playerSection

                betAndControls
                    .padding(.bottom, 20)
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
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Text("BLACKJACK")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.yellow)
        }
        .padding()
        .padding(.top, 20)
    }

    private var dealerSection: some View {
        VStack(spacing: 10) {
            Text("DEALER\(dealerHidden ? "" : ": \(dealerTotal)")")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 8) {
                ForEach(Array(dealerCards.enumerated()), id: \.offset) { idx, card in
                    if idx == 1 && dealerHidden {
                        CardBackView(large: true)
                    } else {
                        CardView(card: card, large: true)
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
                    handDisplay(cards: playerCards,
                                total: handValue(playerCards),
                                label: "HAND 1",
                                active: !playingSplit)
                    handDisplay(cards: splitCards,
                                total: handValue(splitCards),
                                label: "HAND 2",
                                active: playingSplit)
                }
            } else {
                let total = playerTotal
                Text("DU: \(total)")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(total > 21 ? .red : .green)
                HStack(spacing: 8) {
                    ForEach(playerCards) { card in
                        CardView(card: card, large: true)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: playerCards.count)
            }
        }
    }

    private func handDisplay(cards: [Card], total: Int, label: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            Text("\(label): \(total)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(active ? .green : .white.opacity(0.4))
            HStack(spacing: 6) {
                ForEach(cards) { card in
                    CardView(card: card, large: false)
                }
            }
        }
        .padding(8)
        .background(active ? Color.green.opacity(0.08) : Color.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(active ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var betAndControls: some View {
        VStack(spacing: 14) {
            // Bet display
            Text("Insats: \(TimeEngine.shortFormatted(betAmount))")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.yellow)

            switch bjState {
            case .betting:
                bettingControls
            case .playing:
                playingControls
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
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }

    private var bettingControls: some View {
        VStack(spacing: 10) {
            // Quick bet chips
            HStack(spacing: 10) {
                ForEach([300.0, 1800.0, 3600.0, 18000.0, 86400.0], id: \.self) { chip in
                    Button {
                        betAmount = min(chip, engine.balance)
                    } label: {
                        Text(TimeEngine.shortFormatted(chip))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.10))
                            .cornerRadius(8)
                    }
                }
            }

            Slider(
                value: $betAmount,
                in: 60...max(60, min(engine.balance, 86400 * 10)),
                step: 60
            )
            .accentColor(.green)
            .padding(.horizontal)

            Button { startGame() } label: {
                Text("SPELA  (\(TimeEngine.shortFormatted(betAmount)))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(betAmount > engine.balance ? Color.gray : Color.green)
                    .cornerRadius(12)
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
                // Double Down — only on first two cards, if funds available
                if activeHandCardCount() == 2 && engine.balance >= betAmount {
                    ActionButton(label: "DOUBLE", color: .yellow) { playerDouble() }
                }
                // Split — only if the two cards have equal rank value and not already split
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

        // Deal in order: player, dealer, player, dealer
        playerCards.append(deck.deal()!)
        dealerCards.append(deck.deal()!)
        playerCards.append(deck.deal()!)
        dealerCards.append(deck.deal()!)

        playerTotal  = handValue(playerCards)
        dealerTotal  = handValue(dealerCards)
        bjState      = .playing

        // Natural blackjack check
        if playerTotal == 21 {
            runDealerTurn()
        }
    }

    // MARK: Hand value (Ace = 11 or 1)

    func handValue(_ cards: [Card]) -> Int {
        var value = 0
        var aces  = 0
        for card in cards {
            switch card.rank {
            case .ace:
                value += 11; aces += 1
            case .jack, .queen, .king:
                value += 10
            default:
                value += card.rank.rawValue
            }
        }
        while value > 21 && aces > 0 { value -= 10; aces -= 1 }
        return value
    }

    func isSoft(_ cards: [Card]) -> Bool {
        var value = 0; var aces = 0
        for card in cards {
            switch card.rank {
            case .ace:               value += 11; aces += 1
            case .jack, .queen, .king: value += 10
            default:                 value += card.rank.rawValue
            }
        }
        return aces > 0 && value <= 21
    }

    // MARK: Player actions

    func playerHit() {
        guard let card = deck.deal() else { return }
        if playingSplit {
            splitCards.append(card)
            let total = handValue(splitCards)
            if total > 21 {
                // Split hand busted — switch back or resolve
                if !splitCards.isEmpty {
                    runDealerTurn()
                }
            }
        } else {
            playerCards.append(card)
            playerTotal = handValue(playerCards)
            if playerTotal > 21 { bustPlayer() }
        }
    }

    func playerStand() {
        if splitActive && !playingSplit {
            // Done with first hand — move to split hand
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

        // Deal one card to each hand
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

    // MARK: Dealer turn

    func runDealerTurn() {
        dealerHidden = false
        dealerTotal  = handValue(dealerCards)
        bjState      = .dealerTurn

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dealerDraw()
        }
    }

    func dealerDraw() {
        // Dealer hits soft 17
        let soft = isSoft(dealerCards)
        if dealerTotal < 17 || (dealerTotal == 17 && soft) {
            if let card = deck.deal() { dealerCards.append(card) }
            dealerTotal = handValue(dealerCards)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dealerDraw()
            }
        } else {
            determineOutcome()
        }
    }

    // MARK: Outcome

    func determineOutcome() {
        bjState = .done
        let taxRate  = gameState.currentZone.taxRate

        if splitActive {
            // Evaluate both hands
            let h1 = handValue(playerCards)
            let h2 = handValue(splitCards)
            var msgs: [String] = []
            var netGain: TimeInterval = 0

            for (label, hTotal) in [("Hand 1", h1), ("Hand 2", h2)] {
                if hTotal > 21 {
                    msgs.append("\(label): Bust — förlust")
                } else if dealerTotal > 21 || hTotal > dealerTotal {
                    let gross = betAmount * (1.0 - taxRate)  // win = bet * (1-tax) net profit
                    let win   = betAmount * 2.0 * (1.0 - taxRate)
                    TimeEngine.shared.addTime(win)
                    netGain += win - betAmount
                    msgs.append("\(label): Vinst! +\(TimeEngine.shortFormatted(win - betAmount))")
                } else if hTotal == dealerTotal {
                    TimeEngine.shared.addTime(betAmount)    // push
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
                // Blackjack — 3:2
                let gross = betAmount * 2.5
                let net   = gross * (1.0 - taxRate)
                TimeEngine.shared.addTime(net)
                GameState.shared.recordEarning(net - betAmount)
                resultMessage = "BLACKJACK! +\(TimeEngine.shortFormatted(net - betAmount)) (efter \(Int(taxRate * 100))% skatt)"

            } else if dealerTotal > 21 || pTotal > dealerTotal {
                let gross = betAmount * 2.0
                let net   = gross * (1.0 - taxRate)
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

    // MARK: Helpers

    func canSplit() -> Bool {
        guard !splitActive, playerCards.count == 2 else { return false }
        guard engine.balance >= betAmount else { return false }
        // Split on equal rank value
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
