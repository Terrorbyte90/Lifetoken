import SwiftUI

// MARK: - Poker View

struct PokerView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    // MARK: Game state
    @State private var deck          = Deck()
    @State private var playerHand:   [Card] = []
    @State private var communityCards: [Card] = []
    @State private var aiPlayers:    [AIPlayer] = []
    @State private var pot:          TimeInterval = 0
    @State private var playerStack:  TimeInterval = 0
    @State private var currentBet:   TimeInterval = 0
    @State private var playerBet:    TimeInterval = 0
    @State private var gamePhase:    PokerPhase = .waiting
    @State private var betAmount:    TimeInterval = 0
    @State private var statusMessage: String = ""
    @State private var showResult:   Bool = false
    @State private var resultMessage: String = ""
    @State private var round:        Int = 0   // 0=preflop, 1=flop, 2=turn, 3=river
    @State private var aiThinking:   Bool = false
    @State private var handRankDisplay: String = ""

    enum PokerPhase { case waiting, playerTurn, aiTurn, showdown, gameOver }

    // MARK: Derived values
    private var buyIn: TimeInterval      { 3600 * gameState.currentZone.workMultiplier }
    private var smallBlind: TimeInterval { buyIn * 0.05 }
    private var bigBlind: TimeInterval   { smallBlind * 2.0 }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                ScrollView {
                    VStack(spacing: 16) {
                        aiPlayersRow
                        potDisplay
                        communityCardRow
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

    // MARK: Sub-views

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Text("ARM POKER")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text(TimeEngine.shortFormatted(playerStack))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.yellow)
        }
        .padding()
        .padding(.top, 20)
    }

    private var aiPlayersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(aiPlayers) { ai in
                    AIPlayerCard(player: ai, inPot: !ai.folded)
                }
            }
            .padding(.horizontal)
        }
    }

    private var potDisplay: some View {
        Text("POT: \(TimeEngine.shortFormatted(pot))")
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundColor(.yellow)
    }

    private var communityCardRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                if i < communityCards.count {
                    CardView(card: communityCards[i])
                } else {
                    CardBackView()
                }
            }
        }
    }

    private var handRankLabel: some View {
        Group {
            if !handRankDisplay.isEmpty {
                Text(handRankDisplay)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
    }

    private var statusLabel: some View {
        Text(statusMessage)
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    private var playerHandSection: some View {
        VStack(spacing: 8) {
            Text("DIN HAND")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            HStack(spacing: 12) {
                if playerHand.isEmpty {
                    CardBackView(large: true)
                    CardBackView(large: true)
                } else {
                    ForEach(playerHand) { card in
                        CardView(card: card, large: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var controlSection: some View {
        if gamePhase == .waiting || gamePhase == .gameOver {
            Button { startNewHand() } label: {
                Text(playerStack <= 0
                     ? "KÖPA IN (\(TimeEngine.shortFormatted(buyIn)))"
                     : "DELA KORT")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }

        if gamePhase == .playerTurn {
            playerControls
        }
    }

    private var playerControls: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Insats: \(TimeEngine.shortFormatted(betAmount))")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)

            Slider(
                value: $betAmount,
                in: bigBlind...max(bigBlind * 2, playerStack),
                step: bigBlind
            )
            .tint(.green)
            .padding(.horizontal)

            HStack(spacing: 10) {
                ActionButton(label: "FOLD", color: .red)    { playerFold() }
                if currentBet <= playerBet {
                    ActionButton(label: "CHECK", color: .gray) { playerCheck() }
                } else {
                    ActionButton(
                        label: "CALL\n\(TimeEngine.shortFormatted(currentBet - playerBet))",
                        color: .blue
                    ) { playerCall() }
                }
                ActionButton(label: "RAISE", color: .green) { playerRaise() }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Game Logic

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

        // Pick 3 AI opponents
        aiPlayers = Array(AIPlayer.roster.shuffled().prefix(3)).map {
            var p = $0
            p.folded     = false
            p.currentBet = 0
            p.holeCards  = []
            p.isAllIn    = false
            return p
        }

        // Deal hole cards
        guard let ph1 = deck.deal(), let ph2 = deck.deal() else { return }
        playerHand = [ph1, ph2]
        for i in 0..<aiPlayers.count {
            guard let ah1 = deck.deal(), let ah2 = deck.deal() else { return }
            aiPlayers[i].holeCards = [ah1, ah2]
        }

        // Post blinds: player = small blind, first AI = big blind
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
            if bestAI == nil || result > bestAI!.result {
                bestAI = (ai, result)
            }
        }

        if let best = bestAI, best.result > playerResult {
            showdown(playerWins: false,
                     winnerName: best.player.name,
                     winnerHand: best.result.rank.name)
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
            resultMessage = "Du vann!\nHand: \(playerHandName)\nPott: \(TimeEngine.shortFormatted(winnings))\nEfter skatt (\(Int(taxRate * 100))%): \(TimeEngine.shortFormatted(taxed))"
        } else {
            resultMessage = "\(winnerName) vann med \(winnerHand).\nDu förlorade potten."
        }
        showResult = true
    }
}

// MARK: - Card Views

struct CardView: View {
    let card: Card
    var large: Bool = false

    var body: some View {
        let w: CGFloat       = large ? 42 : 30
        let h: CGFloat       = large ? 60 : 42
        let rankSize: CGFloat = large ? 16 : 11
        let suitSize: CGFloat = large ? 13 : 9
        let cardColor: Color  = card.isRed ? .red : Color(white: 0.1)

        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: w, height: h)
            VStack(spacing: 1) {
                Text(card.rank.display)
                    .font(.system(size: rankSize, weight: .bold, design: .monospaced))
                    .foregroundColor(cardColor)
                Text(card.suit.rawValue)
                    .font(.system(size: suitSize, design: .monospaced))
                    .foregroundColor(cardColor)
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 3)
    }
}

struct CardBackView: View {
    var large: Bool = false

    var body: some View {
        let w: CGFloat = large ? 42 : 30
        let h: CGFloat = large ? 60 : 42

        RoundedRectangle(cornerRadius: 6)
            .fill(Color(red: 0.06, green: 0.22, blue: 0.12))
            .frame(width: w, height: h)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.green.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 3)
    }
}

struct AIPlayerCard: View {
    let player: AIPlayer
    let inPot: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(player.avatar)
                .font(.system(size: 24))
                .opacity(player.folded ? 0.3 : 1.0)
            Text(player.name)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(player.folded ? .gray : .white)
            Text(TimeEngine.shortFormatted(player.stack))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.yellow)
            if player.folded {
                Text("LADE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
        .padding(8)
        .background(Color.white.opacity(player.folded ? 0.02 : 0.08))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(inPot ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct ActionButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.8))
                .cornerRadius(10)
        }
    }
}

#Preview {
    PokerView()
        .preferredColorScheme(.dark)
}
