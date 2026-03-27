import Foundation

// MARK: - Yatzy Category

enum MultiYatzyCategory: String, CaseIterable, Identifiable {
    case ettor       = "ettor"
    case tvaor       = "tvaor"
    case treor       = "treor"
    case fyror       = "fyror"
    case femmor      = "femmor"
    case sexor       = "sexor"
    case par         = "par"
    case tvaPar      = "tvaPar"
    case triss       = "triss"
    case fyrtal      = "fyrtal"
    case litenStege  = "litenStege"
    case storStege   = "storStege"
    case kas         = "kas"
    case chans       = "chans"
    case yatzy       = "yatzy"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ettor:      return "Ettor"
        case .tvaor:      return "Tvåor"
        case .treor:      return "Treor"
        case .fyror:      return "Fyror"
        case .femmor:     return "Femmor"
        case .sexor:      return "Sexor"
        case .par:        return "Par"
        case .tvaPar:     return "Två Par"
        case .triss:      return "Triss"
        case .fyrtal:     return "Fyrtal"
        case .litenStege: return "Liten Stege"
        case .storStege:  return "Stor Stege"
        case .kas:        return "Kåk"
        case .chans:      return "Chans"
        case .yatzy:      return "Yatzy"
        }
    }

    var isUpperSection: Bool {
        switch self {
        case .ettor, .tvaor, .treor, .fyror, .femmor, .sexor: return true
        default: return false
        }
    }

    var upperFaceValue: Int? {
        switch self {
        case .ettor: return 1
        case .tvaor: return 2
        case .treor: return 3
        case .fyror: return 4
        case .femmor: return 5
        case .sexor: return 6
        default: return nil
        }
    }

    var maximumScore: Int {
        switch self {
        case .ettor:      return 5
        case .tvaor:      return 10
        case .treor:      return 15
        case .fyror:      return 20
        case .femmor:     return 25
        case .sexor:      return 30
        case .par:        return 12
        case .tvaPar:     return 22
        case .triss:      return 18
        case .fyrtal:     return 24
        case .litenStege: return 15
        case .storStege:  return 20
        case .kas:        return 28
        case .chans:      return 30
        case .yatzy:      return 50
        }
    }
}

// MARK: - Score Calculator

func multiYatzyScore(for category: MultiYatzyCategory, dice: [Int]) -> Int {
    guard dice.count == 5 else { return 0 }
    let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
    let sum = dice.reduce(0, +)

    switch category {
    case .ettor:  return dice.filter { $0 == 1 }.reduce(0, +)
    case .tvaor:  return dice.filter { $0 == 2 }.reduce(0, +)
    case .treor:  return dice.filter { $0 == 3 }.reduce(0, +)
    case .fyror:  return dice.filter { $0 == 4 }.reduce(0, +)
    case .femmor: return dice.filter { $0 == 5 }.reduce(0, +)
    case .sexor:  return dice.filter { $0 == 6 }.reduce(0, +)

    case .par:
        let pairs = counts.filter { $0.value >= 2 }.keys.sorted(by: >)
        return pairs.isEmpty ? 0 : pairs[0] * 2

    case .tvaPar:
        let pairs = counts.filter { $0.value >= 2 }.keys.sorted(by: >)
        return pairs.count >= 2 ? (pairs[0] + pairs[1]) * 2 : 0

    case .triss:
        let three = counts.filter { $0.value >= 3 }.keys.sorted(by: >).first ?? 0
        return three * 3

    case .fyrtal:
        let four = counts.filter { $0.value >= 4 }.keys.sorted(by: >).first ?? 0
        return four * 4

    case .litenStege:
        let s = Set(dice).sorted()
        return ([1,2,3,4,5].allSatisfy { s.contains($0) }) ? 15 : 0

    case .storStege:
        let s = Set(dice).sorted()
        return ([2,3,4,5,6].allSatisfy { s.contains($0) }) ? 20 : 0

    case .kas:
        let has3 = counts.values.contains(3)
        let has2 = counts.values.contains(2)
        return (has3 && has2) ? sum : 0

    case .chans:
        return sum

    case .yatzy:
        return Set(dice).count == 1 ? 50 : 0
    }
}

// MARK: - Player State

struct YatzyPlayerState {
    var name: String
    var scores: [MultiYatzyCategory: Int] = [:]

    var upperTotal: Int {
        MultiYatzyCategory.allCases
            .filter { $0.isUpperSection }
            .compactMap { scores[$0] }
            .reduce(0, +)
    }

    var hasBonus: Bool { upperTotal >= 63 }
    var bonusPoints: Int { hasBonus ? 50 : 0 }

    var lowerTotal: Int {
        MultiYatzyCategory.allCases
            .filter { !$0.isUpperSection }
            .compactMap { scores[$0] }
            .reduce(0, +)
    }

    var grandTotal: Int { upperTotal + bonusPoints + lowerTotal }

    var isFilled: Bool {
        MultiYatzyCategory.allCases.allSatisfy { scores[$0] != nil }
    }

    var availableCategories: Set<MultiYatzyCategory> {
        Set(MultiYatzyCategory.allCases.filter { scores[$0] == nil })
    }
}

// MARK: - Game Phase

enum MultiYatzyPhase: Equatable {
    case lobby
    case handoff(toPlayerIndex: Int)
    case playing
    case gameOver
}

// MARK: - Game Mode

enum MultiYatzyMode: Equatable {
    case vsAI
    case onlineOneVsOne
    case onlineThreePlayer
}

// MARK: - Game Engine

@MainActor
final class YatzyGameEngine: ObservableObject {

    // MARK: Published — Game State
    @Published var phase: MultiYatzyPhase = .lobby
    @Published var players: [YatzyPlayerState] = []
    @Published var currentPlayerIndex: Int = 0
    @Published var dice: [Int] = [1, 2, 3, 4, 5]
    @Published var heldDice: [Bool] = [false, false, false, false, false]
    @Published var rollsUsed: Int = 0
    @Published var isRolling: Bool = false
    @Published var isAIThinking: Bool = false
    @Published var statusMessage: String = ""
    @Published var lastScoreMessage: String = ""
    @Published var handoffReady: Bool = false

    // MARK: Published — Result
    @Published var winnerIndex: Int? = nil
    @Published var isTie: Bool = false
    @Published var resultAnimating: Bool = false

    // MARK: Computed

    var currentPlayer: YatzyPlayerState? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }

    func isPlayerAI(at index: Int, mode: MultiYatzyMode) -> Bool {
        switch mode {
        case .vsAI:               return index == 1
        case .onlineOneVsOne:     return index == 1
        case .onlineThreePlayer:  return index >= 1
        }
    }

    var canRoll: Bool { rollsUsed < 3 && !isRolling && !isAIThinking }
    var canScore: Bool { rollsUsed > 0 && !isRolling && !isAIThinking }
    var rollsRemaining: Int { max(0, 3 - rollsUsed) }

    // MARK: - Start Game

    /// Configures players and transitions to playing.
    /// Returns false if the bet cannot be deducted.
    func startGame(
        player1Name: String,
        gameMode: MultiYatzyMode,
        betAmount: TimeInterval,
        zoneOpponents: [String],
        useRandomOpponent: Bool,
        selectedOpponentName: String?
    ) -> Bool {
        let p1Name = player1Name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalP1 = p1Name.isEmpty ? "Spelare 1" : p1Name

        // 80% bet limit enforcement
        let maxBet = max(100, floor(TimeEngine.shared.balance * 0.8))
        guard betAmount <= maxBet else { return false }
        guard TimeEngine.shared.deductTime(betAmount) else { return false }

        var newPlayers: [YatzyPlayerState]
        switch gameMode {
        case .vsAI:
            newPlayers = [
                YatzyPlayerState(name: finalP1),
                YatzyPlayerState(name: "🤖 AI")
            ]
        case .onlineOneVsOne:
            let opp: String
            if useRandomOpponent || selectedOpponentName == nil {
                opp = zoneOpponents.shuffled().first ?? "Online-AI"
            } else {
                opp = selectedOpponentName ?? zoneOpponents.first ?? "Online-AI"
            }
            newPlayers = [
                YatzyPlayerState(name: finalP1),
                YatzyPlayerState(name: opp)
            ]
            NotificationManager.shared.sendYatzyChallenge(from: finalP1, stake: TimeEngine.shortFormatted(betAmount))
        case .onlineThreePlayer:
            let opp1 = zoneOpponents.first ?? "Online-AI 1"
            let opp2 = zoneOpponents.dropFirst().first ?? "Online-AI 2"
            newPlayers = [
                YatzyPlayerState(name: finalP1),
                YatzyPlayerState(name: opp1),
                YatzyPlayerState(name: opp2)
            ]
        }

        players = newPlayers
        currentPlayerIndex = 0
        resetDice()
        rollsUsed = 0
        statusMessage = "Kasta tärningarna för att börja!"
        resultAnimating = false

        phase = .playing
        return true
    }

    // MARK: - Dice

    func resetDice() {
        dice = (0..<5).map { _ in Int.random(in: 1...6) }
        heldDice = [false, false, false, false, false]
    }

    func rollDice(isCurrentPlayerAI: Bool) {
        guard canRoll && !isCurrentPlayerAI else { return }
        isRolling = true
        rollsUsed += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            guard let self else { return }
            for i in 0..<5 {
                if !self.heldDice[i] {
                    self.dice[i] = Int.random(in: 1...6)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self else { return }
                self.isRolling = false
                let remaining = 3 - self.rollsUsed
                if remaining > 0 {
                    self.statusMessage = "\(remaining) kast kvar — håll tärningar eller välj kategori"
                } else {
                    self.statusMessage = "Inga kast kvar — välj en kategori"
                }
            }
        }
    }

    func toggleHeld(at index: Int) {
        guard rollsUsed > 0 && rollsUsed < 3 && !isRolling else { return }
        heldDice[index].toggle()
    }

    // MARK: - Scoring

    func fillCategory(_ category: MultiYatzyCategory, isCurrentPlayerAI: Bool) {
        guard canScore && !isCurrentPlayerAI else { return }
        guard players.indices.contains(currentPlayerIndex) else { return }
        guard players[currentPlayerIndex].scores[category] == nil else { return }

        let score = multiYatzyScore(for: category, dice: dice)
        players[currentPlayerIndex].scores[category] = score
        statusMessage = "\(category.displayName): \(score) poäng"
        lastScoreMessage = statusMessage

        advanceTurn(gameMode: currentGameMode, betAmount: currentBetAmount)
    }

    // MARK: - Turn Management

    func advanceTurn(gameMode: MultiYatzyMode, betAmount: TimeInterval) {
        if players.allSatisfy({ $0.isFilled }) {
            endGame(gameMode: gameMode, betAmount: betAmount)
            return
        }

        let nextIndex = (currentPlayerIndex + 1) % players.count
        currentPlayerIndex = nextIndex
        resetDice()
        rollsUsed = 0
        statusMessage = ""

        if isPlayerAI(at: currentPlayerIndex, mode: gameMode) {
            triggerAITurn()
        } else {
            statusMessage = "Din tur — kasta tärningarna!"
        }
    }

    // MARK: Internal game mode / bet storage (set at game start)
    private(set) var currentGameMode: MultiYatzyMode = .vsAI
    private(set) var currentBetAmount: TimeInterval = 600

    func setGameContext(mode: MultiYatzyMode, bet: TimeInterval) {
        currentGameMode = mode
        currentBetAmount = bet
    }

    // MARK: - AI Turn

    func triggerAITurn() {
        guard isPlayerAI(at: currentPlayerIndex, mode: currentGameMode) else { return }
        isAIThinking = true
        let aiName = players.indices.contains(currentPlayerIndex) ? players[currentPlayerIndex].name : "AI"
        statusMessage = "🤖 \(aiName) tänker..."
        performAIRoll(rollsLeft: 3)
    }

    private func performAIRoll(rollsLeft: Int) {
        let aiIdx = currentPlayerIndex
        guard rollsLeft > 0, players.indices.contains(aiIdx) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.aiPickCategory() }
            return
        }

        let delay: TimeInterval = rollsLeft == 3 ? 0.55 : 0.70

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.players.indices.contains(aiIdx) else { return }
            let engine = self
            let available = self.players[aiIdx].availableCategories
            let diceSnapshot = self.dice

            Task.detached(priority: .userInitiated) { [engine, available, diceSnapshot] in
                let keepMask = YatzyAILogic.selectDiceToKeep(
                    dice: diceSnapshot,
                    available: available,
                    rollsRemaining: rollsLeft
                )

                await MainActor.run {
                    guard engine.players.indices.contains(aiIdx),
                          engine.currentPlayerIndex == aiIdx,
                          engine.isAIThinking else {
                        return
                    }

                    engine.isRolling = true
                    engine.rollsUsed = 4 - rollsLeft
                    for i in 0..<5 {
                        engine.heldDice[i] = keepMask[i]
                        if !keepMask[i] { engine.dice[i] = Int.random(in: 1...6) }
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { [weak self] in
                        guard let self else { return }
                        let engine = self
                        engine.isRolling = false

                        let postRollDice = engine.dice
                        Task.detached(priority: .userInitiated) { [engine, available, postRollDice] in
                            let shouldStop = YatzyAILogic.shouldStopRolling(
                                dice: postRollDice,
                                available: available,
                                rollsLeft: rollsLeft - 1
                            )

                            await MainActor.run {
                                guard engine.players.indices.contains(aiIdx),
                                      engine.currentPlayerIndex == aiIdx,
                                      engine.isAIThinking else {
                                    return
                                }

                                if shouldStop {
                                    engine.aiPickCategory()
                                    return
                                }
                                engine.performAIRoll(rollsLeft: rollsLeft - 1)
                            }
                        }
                    }
                }
            }
        }
    }

    private func aiPickCategory() {
        let aiIdx = currentPlayerIndex
        guard players.indices.contains(aiIdx) else { return }
        let available = players[aiIdx].availableCategories
        let aiName = players[aiIdx].name
        let diceSnapshot = dice

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            let engine = self

            Task.detached(priority: .userInitiated) { [engine, available, diceSnapshot] in
                let chosen = YatzyAILogic.chooseCategory(dice: diceSnapshot, available: available)

                await MainActor.run {
                    guard engine.players.indices.contains(aiIdx),
                          engine.currentPlayerIndex == aiIdx else {
                        return
                    }

                    if let chosen {
                        let score = multiYatzyScore(for: chosen, dice: engine.dice)
                        engine.players[aiIdx].scores[chosen] = score
                        engine.statusMessage = "🤖 \(aiName) väljer \(chosen.displayName): \(score)p"
                    }

                    engine.isAIThinking = false
                    engine.heldDice = [false, false, false, false, false]

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                        guard let self else { return }
                        self.advanceTurn(gameMode: self.currentGameMode, betAmount: self.currentBetAmount)
                    }
                }
            }
        }
    }

    // MARK: - End Game

    func endGame(gameMode: MultiYatzyMode, betAmount: TimeInterval) {
        guard players.count >= 2 else { return }

        let maxScore = players.map { $0.grandTotal }.max() ?? 0
        let winnerIndices = players.indices.filter { players[$0].grandTotal == maxScore }

        if winnerIndices.count > 1 {
            winnerIndex = nil
            isTie = true
            if winnerIndices.contains(0) {
                TimeEngine.shared.addTime(betAmount)
            }
        } else {
            let w = winnerIndices[0]
            winnerIndex = w
            isTie = false
            if w == 0 {
                let prize = betAmount * Double(players.count)
                TimeEngine.shared.addTime(prize)
            }
        }

        phase = .gameOver
    }

    // MARK: - Reset

    func resetToLobby() {
        players = []
        currentPlayerIndex = 0
        resetDice()
        rollsUsed = 0
        isRolling = false
        isAIThinking = false
        statusMessage = ""
        lastScoreMessage = ""
        winnerIndex = nil
        isTie = false
        handoffReady = false

        phase = .lobby
    }
}
