import SwiftUI

// MARK: - Poker View

struct PokerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    // MARK: Speltillstånd
    @State private var deck            = Deck()
    @State private var playerHand:     [Card] = []
    @State private var communityCards: [Card] = []
    @State private var aiPlayers:      [AIPlayer] = []
    @State private var pot:            TimeInterval = 0
    @State private var playerStack:    TimeInterval = 0
    @State private var currentBet:     TimeInterval = 0
    @State private var playerBet:      TimeInterval = 0
    @State private var gamePhase:      PokerPhase = .waiting
    @State private var betAmount:      TimeInterval = 0
    @State private var statusMessage:  String = ""
    @State private var showResult:     Bool = false
    @State private var resultMessage:  String = ""
    @State private var round:          Int = 0   // 0=preflop, 1=flop, 2=turn, 3=river
    @State private var aiThinking:     Bool = false
    @State private var handRankDisplay: String = ""

    enum PokerPhase { case waiting, playerTurn, aiTurn, showdown, gameOver }

    // MARK: Beräknade värden
    private var buyIn: TimeInterval      { 3600 * gameState.currentZone.workMultiplier }
    private var smallBlind: TimeInterval { buyIn * 0.05 }
    private var bigBlind: TimeInterval   { smallBlind * 2.0 }

    // Mörkgrön bords-bakgrund
    private let tableColor = Color(red: 0.03, green: 0.14, blue: 0.06)

    // MARK: Body

    var body: some View {
        ZStack {
            // Mörkgrön/svart poker-bordsatmosfär
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.10, blue: 0.04), Color(red: 0.01, green: 0.05, blue: 0.02), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            // Oval bordsform som dekorativt element
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.04, green: 0.18, blue: 0.08),
                            Color(red: 0.02, green: 0.10, blue: 0.04)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 280
                    )
                )
                .frame(width: UIScreen.main.bounds.width - 20, height: 580)
                .overlay(
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.5, green: 0.4, blue: 0.05).opacity(0.7), Color(red: 0.3, green: 0.25, blue: 0.03).opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color(red: 0.1, green: 0.5, blue: 0.15).opacity(0.15), radius: 20)
                .offset(y: -30)

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        aiPlayersRow
                            .padding(.top, 8)

                        potDisplay

                        communityCardSection

                        handRankLabel

                        statusLabel

                        playerHandSection

                        controlSection

                        Spacer(minLength: 80)
                    }
                }
            }
        }
        .alert("Resultat", isPresented: $showResult) {
            Button("Ny hand") { startNewHand() }
            Button("Avsluta") { dismiss() }
        } message: {
            Text(resultMessage)
        }
        .onAppear {
            playerStack = buyIn * 10
            betAmount   = bigBlind
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
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("TEXAS HOLD'EM")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("Hus 5% rake")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.6))
            }
            Spacer()
            Text(TimeEngine.shortFormatted(playerStack))
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
        .background(Color.black.opacity(0.3))
    }

    private var aiPlayersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(aiPlayers) { ai in
                    AIPlayerCard(player: ai, inPot: !ai.folded)
                }
            }
            .padding(.horizontal)
        }
    }

    // Pottens belopp centrerat och stort
    private var potDisplay: some View {
        VStack(spacing: 4) {
            Text("POTT")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .tracking(4)
            Text(TimeEngine.shortFormatted(pot))
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.5), radius: 10)
                .monospacedDigit()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.35))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.yellow.opacity(0.25), lineWidth: 1))
        .shadow(color: .yellow.opacity(0.15), radius: 12)
    }

    // Community-kort framträdande i centrum
    private var communityCardSection: some View {
        VStack(spacing: 8) {
            Text("COMMUNITY CARDS")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .tracking(4)

            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in
                    if i < communityCards.count {
                        CardView(card: communityCards[i], large: true)
                    } else {
                        CardBackView(large: true)
                            .opacity(0.4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    private var handRankLabel: some View {
        Group {
            if !handRankDisplay.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                    Text(handRankDisplay)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.cyan)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.cyan.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                .shadow(color: .cyan.opacity(0.25), radius: 8)
            }
        }
    }

    private var statusLabel: some View {
        Group {
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // Spelarens hand nertill, ordentlig storlek
    private var playerHandSection: some View {
        VStack(spacing: 10) {
            Text("DIN HAND")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .tracking(4)

            HStack(spacing: 16) {
                if playerHand.isEmpty {
                    CardBackView(large: true).opacity(0.5)
                    CardBackView(large: true).opacity(0.5)
                } else {
                    ForEach(playerHand) { card in
                        CardView(card: card, large: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var controlSection: some View {
        if gamePhase == .waiting || gamePhase == .gameOver {
            Button { startNewHand() } label: {
                HStack(spacing: 10) {
                    Image(systemName: playerStack <= 0 ? "creditcard.fill" : "suit.spade.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(playerStack <= 0
                         ? "KÖPA IN (\(TimeEngine.shortFormatted(buyIn)))"
                         : "DELA KORT")
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

        if gamePhase == .playerTurn {
            playerControls
        }
    }

    private var playerControls: some View {
        VStack(spacing: 14) {
            HStack {
                Text("INSATS:")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Text(TimeEngine.shortFormatted(betAmount))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.3), radius: 4)
                Spacer()
            }
            .padding(.horizontal)

            Slider(
                value: $betAmount,
                in: bigBlind...max(bigBlind * 2, playerStack),
                step: bigBlind
            )
            .tint(Color(red: 0.7, green: 0.6, blue: 0.1))
            .padding(.horizontal)

            // Premium casino-stilknappar
            HStack(spacing: 10) {
                pokerActionButton(label: "FOLD", icon: "xmark.circle.fill", color: .red) { playerFold() }
                if currentBet <= playerBet {
                    pokerActionButton(label: "CHECK", icon: "checkmark.circle.fill", color: Color(red: 0.4, green: 0.4, blue: 0.5)) { playerCheck() }
                } else {
                    pokerActionButton(
                        label: "CALL\n\(TimeEngine.shortFormatted(currentBet - playerBet))",
                        icon: "equal.circle.fill",
                        color: .blue
                    ) { playerCall() }
                }
                pokerActionButton(label: "RAISE", icon: "arrow.up.circle.fill", color: Color(red: 0.2, green: 0.75, blue: 0.35)) { playerRaise() }
            }
            .padding(.horizontal)
        }
    }

    // Premium casino-stilknapp för pokerkontroller
    private func pokerActionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                Text(label)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.45), radius: 8, y: 4)
        }
        .buttonStyle(LTPressEffect(scale: 0.94))
    }

    // MARK: - Spellogik

    func startNewHand() {
        if playerStack <= 0 {
            guard TimeEngine.shared.deductTime(buyIn) else {
                statusMessage = "Otillräcklig tid för buy-in."
                gamePhase = .waiting
                return
            }
            playerStack = buyIn * 10
        }

        deck.reset()
        communityCards = []
        pot        = 0
        round      = 0
        playerBet  = 0
        currentBet = bigBlind
        handRankDisplay = ""
        resultMessage   = ""

        // Välj 3 AI-motspelare
        aiPlayers = Array(AIPlayer.roster.shuffled().prefix(3)).map {
            var p = $0
            p.folded     = false
            p.currentBet = 0
            p.holeCards  = []
            p.isAllIn    = false
            return p
        }

        // Dela ut hole cards
        guard let ph1 = deck.deal(), let ph2 = deck.deal() else { return }
        playerHand = [ph1, ph2]
        for i in 0..<aiPlayers.count {
            guard let ah1 = deck.deal(), let ah2 = deck.deal() else { return }
            aiPlayers[i].holeCards = [ah1, ah2]
        }

        // Posta blinds: spelare = small blind, första AI = big blind
        playerStack -= smallBlind
        pot        += smallBlind
        playerBet   = smallBlind

        if !aiPlayers.isEmpty {
            let bb = min(bigBlind, aiPlayers[0].stack)
            aiPlayers[0].stack      -= bb
            aiPlayers[0].currentBet  = bb
            pot                     += bb
        }

        statusMessage = "Pre-flop — Big blind: \(TimeEngine.shortFormatted(bigBlind))"
        gamePhase = .playerTurn
        updateHandRank()
    }

    func updateHandRank() {
        let allCards = playerHand + communityCards
        guard allCards.count >= 2 else { return }
        let result = HandEvaluator.evaluate(cards: allCards)
        handRankDisplay = result.rank.name
    }

    func playerFold() {
        pot += playerBet
        resultMessage = "Du la. AI vinner potten: \(TimeEngine.shortFormatted(pot))"
        gamePhase = .gameOver
        showResult = true
    }

    func playerCheck() {
        guard currentBet <= playerBet else { return }
        processAIRound()
    }

    func playerCall() {
        let toCall = min(currentBet - playerBet, playerStack)
        playerStack -= toCall
        pot         += toCall
        playerBet    = currentBet
        processAIRound()
    }

    func playerRaise() {
        let raiseTotal = max(betAmount, currentBet * 2)
        let toAdd      = raiseTotal - playerBet
        guard toAdd > 0, toAdd <= playerStack else { return }
        playerStack -= toAdd
        pot         += toAdd
        playerBet    = raiseTotal
        currentBet   = raiseTotal
        processAIRound()
    }

    func processAIRound() {
        aiThinking    = true
        statusMessage = "AI funderar..."
        gamePhase     = .aiTurn

        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.8...2.0)) {
            for i in 0..<self.aiPlayers.count {
                guard !self.aiPlayers[i].folded else { continue }
                let toCall = max(0, self.currentBet - self.aiPlayers[i].currentBet)
                let action = self.aiPlayers[i].makeDecision(
                    toCall: toCall,
                    pot: self.pot,
                    communityCards: self.communityCards,
                    round: self.round
                )
                switch action {
                case .fold:
                    self.aiPlayers[i].folded = true
                    self.statusMessage = "\(self.aiPlayers[i].name) lade."

                case .check:
                    self.statusMessage = "\(self.aiPlayers[i].name) checkade."

                case .call(let amt):
                    let actual = min(amt, self.aiPlayers[i].stack)
                    self.aiPlayers[i].stack      -= actual
                    self.aiPlayers[i].currentBet += actual
                    self.pot                     += actual
                    self.statusMessage = "\(self.aiPlayers[i].name) callade \(TimeEngine.shortFormatted(actual))."

                case .raise(let amt):
                    let actual = min(amt, self.aiPlayers[i].stack)
                    self.aiPlayers[i].stack      -= actual
                    self.aiPlayers[i].currentBet += actual
                    self.currentBet               = self.aiPlayers[i].currentBet
                    self.pot                     += actual
                    self.statusMessage = "\(self.aiPlayers[i].name) höjde till \(TimeEngine.shortFormatted(self.aiPlayers[i].currentBet))."
                }
            }
            self.aiThinking = false
            self.advanceRound()
        }
    }

    func advanceRound() {
        let activePlayers = aiPlayers.filter { !$0.folded }
        if activePlayers.isEmpty {
            showdown(playerWins: true)
            return
        }

        round     += 1
        playerBet  = 0
        currentBet = 0
        for i in 0..<aiPlayers.count { aiPlayers[i].currentBet = 0 }

        switch round {
        case 1:
            guard let f1 = deck.deal(), let f2 = deck.deal(), let f3 = deck.deal() else { return }
            communityCards = [f1, f2, f3]
            statusMessage  = "Flop"
        case 2:
            if let card = deck.deal() { communityCards.append(card) }
            statusMessage = "Turn"
        case 3:
            if let card = deck.deal() { communityCards.append(card) }
            statusMessage = "River"
        default:
            determineWinner()
            return
        }

        updateHandRank()
        betAmount = bigBlind
        gamePhase = .playerTurn
    }

    func determineWinner() {
        let playerResult = HandEvaluator.evaluate(cards: playerHand + communityCards)
        var bestAI: (player: AIPlayer, result: HandResult)?

        for ai in aiPlayers.filter({ !$0.folded }) {
            let result = HandEvaluator.evaluate(cards: ai.holeCards + communityCards)
            if bestAI.map({ result > $0.result }) ?? true {
                bestAI = (ai, result)
            }
        }

        if let best = bestAI, best.result > playerResult {
            showdown(playerWins: false, winnerName: best.player.name, winnerHand: best.result.rank.name)
        } else {
            showdown(playerWins: true, playerHandName: playerResult.rank.name)
        }
    }

    func showdown(playerWins: Bool,
                  playerHandName: String = "",
                  winnerName: String = "",
                  winnerHand: String = "") {
        gamePhase = .gameOver

        if playerWins {
            let rake     = pot * 0.05
            let winnings = pot - rake
            let taxRate  = gameState.currentZone.taxRate
            let taxed    = winnings * (1.0 - taxRate)
            playerStack += taxed
            TimeEngine.shared.addTime(taxed)
            GameState.shared.recordEarning(taxed)
            MissionsManager.incrementProgress("poker_wins")
            MissionsManager.incrementProgress("casino_total_wins")
            TransactionLedger.shared.record(label: "Poker — vinst (\(playerHandName))", amount: taxed)
            resultMessage = "Du vann!\nHand: \(playerHandName)\nPott: \(TimeEngine.shortFormatted(winnings))\nEfter skatt (\(Int(taxRate * 100))%): \(TimeEngine.shortFormatted(taxed))"
        } else {
            TransactionLedger.shared.record(label: "Poker — förlust", amount: -pot / 2)
            resultMessage = "\(winnerName) vann med \(winnerHand).\nDu förlorade potten."
        }
        showResult = true
    }
}

// MARK: - Kortvyer

struct CardView: View {
    let card: Card
    var large: Bool = false

    var body: some View {
        let w: CGFloat        = large ? 46 : 32
        let h: CGFloat        = large ? 64 : 46
        let rankSize: CGFloat = large ? 16 : 11
        let suitSize: CGFloat = large ? 13 : 9
        let cardColor: Color  = card.isRed ? .red : Color(white: 0.1)

        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white)
                .frame(width: w, height: h)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
                // Subtil röd glöd för hjärter/ruter
                .shadow(color: card.isRed ? Color.red.opacity(0.15) : .clear, radius: 5)

            VStack(spacing: 1) {
                Text(card.rank.display)
                    .font(.system(size: rankSize, weight: .bold, design: .monospaced))
                    .foregroundColor(cardColor)
                Text(card.suit.rawValue)
                    .font(.system(size: suitSize, design: .monospaced))
                    .foregroundColor(cardColor)
            }
        }
    }
}

struct CardBackView: View {
    var large: Bool = false

    var body: some View {
        let w: CGFloat = large ? 46 : 32
        let h: CGFloat = large ? 64 : 46

        RoundedRectangle(cornerRadius: 7)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.04, green: 0.20, blue: 0.10), Color(red: 0.02, green: 0.12, blue: 0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: w, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 3)
    }
}

struct AIPlayerCard: View {
    let player: AIPlayer
    let inPot: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(player.avatar)
                .font(.system(size: 26))
                .opacity(player.folded ? 0.25 : 1.0)
            Text(player.name)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(player.folded ? .gray : .white)
            Text(TimeEngine.shortFormatted(player.stack))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(player.folded ? .gray : .yellow)
            if player.folded {
                Text("LADE")
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(player.folded ? 0.02 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    inPot ? Color(red: 0.5, green: 0.8, blue: 0.3).opacity(0.4) : Color.white.opacity(0.05),
                    lineWidth: 1
                )
        )
        .shadow(color: inPot ? Color.green.opacity(0.1) : .clear, radius: 6)
    }
}

struct ActionButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .shadow(color: color.opacity(0.4), radius: 6, y: 3)
        }
        .buttonStyle(LTPressEffect(scale: 0.94))
    }
}

#Preview {
    PokerView()
        .preferredColorScheme(.dark)
}
