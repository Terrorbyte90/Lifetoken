import SwiftUI

// MARK: - Yatzy Game Logic

struct YatzyDie: Identifiable {
    let id: Int
    var value: Int        // 1-6
    var held: Bool = false
}

enum YatzyCategory: String, CaseIterable, Identifiable {
    // Upper section
    case ettor      = "Ettor"
    case tvåor      = "Tvåor"
    case treor      = "Treor"
    case fyror      = "Fyror"
    case femmor     = "Femmor"
    case sexor      = "Sexor"
    // Lower section
    case par        = "Par"
    case tvåPar     = "Tvåpar"
    case tretal     = "Tretal"
    case stagenLiten = "Liten Stege"
    case stagenStor  = "Stor Stege"
    case kak         = "Kåk"
    case litenChans  = "Liten Chans"
    case storChans   = "Stor Chans"
    case yatzy       = "Yatzy"
    case chans       = "Chans"

    var id: String { rawValue }

    // Score in points (then multiplied to seconds)
    func score(dice: [Int]) -> Int {
        let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
        let sum = dice.reduce(0, +)
        switch self {
        case .ettor:      return dice.filter { $0 == 1 }.reduce(0, +)
        case .tvåor:      return dice.filter { $0 == 2 }.reduce(0, +)
        case .treor:      return dice.filter { $0 == 3 }.reduce(0, +)
        case .fyror:      return dice.filter { $0 == 4 }.reduce(0, +)
        case .femmor:     return dice.filter { $0 == 5 }.reduce(0, +)
        case .sexor:      return dice.filter { $0 == 6 }.reduce(0, +)
        case .par:
            let pairs = counts.filter { $0.value >= 2 }.keys.sorted().reversed()
            return (pairs.first.map { $0 * 2 }) ?? 0
        case .tvåPar:
            let pairs = counts.filter { $0.value >= 2 }.keys.sorted()
            return pairs.count >= 2 ? (pairs[pairs.count-1] + pairs[pairs.count-2]) * 2 : 0
        case .tretal:
            let three = counts.first(where: { $0.value >= 3 })?.key ?? 0
            return three * 3
        case .stagenLiten:
            let sorted = Set(dice).sorted()
            return ([1,2,3,4,5].allSatisfy { sorted.contains($0) }) ? 15 : 0
        case .stagenStor:
            let sorted = Set(dice).sorted()
            return ([2,3,4,5,6].allSatisfy { sorted.contains($0) }) ? 20 : 0
        case .kak:
            let has3 = counts.values.contains(3)
            let has2 = counts.values.contains(2)
            return (has3 && has2) ? sum : 0
        case .litenChans:
            return dice.filter { $0 <= 3 }.reduce(0, +)
        case .storChans:
            return dice.filter { $0 >= 4 }.reduce(0, +)
        case .yatzy:
            return Set(dice).count == 1 ? 50 : 0
        case .chans:
            return sum
        }
    }
}

// MARK: - AI Strategy
private func aiBestScore(dice: [Int], availableCategories: Set<YatzyCategory>) -> (YatzyCategory, Int)? {
    var best: (YatzyCategory, Int)? = nil
    for cat in availableCategories {
        let s = cat.score(dice: dice)
        if best == nil || s > best!.1 {
            best = (cat, s)
        }
    }
    return best
}

// MARK: - YatzyView

struct YatzyView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    // Bet
    @State private var betAmount: TimeInterval = 1800

    // Game state
    @State private var dice: [YatzyDie] = (0..<5).map { YatzyDie(id: $0, value: Int.random(in: 1...6)) }
    @State private var rollsLeft: Int = 3
    @State private var isPlayerTurn: Bool = true
    @State private var playerScores: [YatzyCategory: Int] = [:]
    @State private var aiScores: [YatzyCategory: Int] = [:]
    @State private var aiDice: [Int] = [1,1,1,1,1]
    @State private var gamePhase: YatzyPhase = .betting
    @State private var statusMessage: String = ""
    @State private var isRolling: Bool = false
    @State private var showResult: Bool = false
    @State private var resultMessage: String = ""
    @State private var currentRound: Int = 0
    @State private var selectedCategory: YatzyCategory? = nil

    enum YatzyPhase { case betting, playerRoll, selectCategory, aiTurn, gameOver }

    private let totalRounds = 16
    private let pointsToSeconds: Double = 60 // each point = 60s

    var playerTotalScore: Int { playerScores.values.reduce(0, +) }
    var aiTotalScore: Int { aiScores.values.reduce(0, +) }

    var availableCategories: Set<YatzyCategory> {
        Set(YatzyCategory.allCases.filter { !playerScores.keys.contains($0) })
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                if gamePhase == .betting {
                    bettingView
                } else {
                    gameplayView
                }
            }
        }
        .alert("Spelresultat", isPresented: $showResult) {
            Button("OK") { dismiss() }
            Button("Spela igen") { resetGame() }
        } message: { Text(resultMessage) }
    }

    // MARK: Header
    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.7))
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            Spacer()
            Text("YATZY")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.yellow)
        }
        .padding()
        .padding(.top, 20)
    }

    // MARK: Betting View
    private var bettingView: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("INSATS")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text(TimeEngine.shortFormatted(betAmount))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)

            VStack(spacing: 8) {
                Text("Poäng omvandlas: 1 p = \(Int(pointsToSeconds))s")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text("Yatzy (50p) = \(TimeEngine.shortFormatted(50 * pointsToSeconds))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green.opacity(0.8))
            }

            HStack(spacing: 12) {
                ForEach([900.0, 1800.0, 3600.0, 7200.0, 21600.0], id: \.self) { v in
                    Button { betAmount = min(v, engine.balance) } label: {
                        Text(TimeEngine.shortFormatted(v))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Slider(value: $betAmount, in: 300...max(300, min(engine.balance, 86400 * 7)), step: 300)
                .accentColor(.green)
                .padding(.horizontal)

            Button { startGame() } label: {
                Text("STARTA SPELET")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(betAmount <= engine.balance ? Color.green : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(betAmount > engine.balance)
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: Gameplay View
    private var gameplayView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Score header
                HStack {
                    scorePill(label: "DU", score: playerTotalScore, color: .green)
                    Spacer()
                    Text("Runda \(currentRound)/\(totalRounds)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    scorePill(label: "AI", score: aiTotalScore, color: .red)
                }
                .padding(.horizontal)

                // Dice display
                if isPlayerTurn {
                    Text("DIN TUR — \(rollsLeft) kast kvar")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)

                    HStack(spacing: 12) {
                        ForEach($dice) { $die in
                            dieView(die: $die)
                        }
                    }

                    Button {
                        if rollsLeft > 0 { rollDice() }
                    } label: {
                        Text(rollsLeft > 0 ? "KASTA (\(rollsLeft) kvar)" : "VÄLJ KATEGORI")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(rollsLeft > 0 ? Color.green : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(rollsLeft == 0 || isRolling)
                    .padding(.horizontal)
                } else {
                    Text("AI:S TUR...")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)

                    HStack(spacing: 12) {
                        ForEach(0..<5, id: \.self) { i in
                            aiDieView(value: aiDice[i])
                        }
                    }
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                // Score card
                scorecardView
                    .padding(.horizontal)

                Spacer(minLength: 80)
            }
            .padding(.top, 8)
        }
    }

    private func dieView(die: Binding<YatzyDie>) -> some View {
        Button {
            if rollsLeft < 3 { die.wrappedValue.held.toggle() }
        } label: {
            Text(dieFace(die.wrappedValue.value))
                .font(.system(size: 36))
                .frame(width: 56, height: 56)
                .background(die.wrappedValue.held ? Color.yellow.opacity(0.25) : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(die.wrappedValue.held ? Color.yellow : Color.white.opacity(0.15), lineWidth: 2)
                )
        }
    }

    private func aiDieView(value: Int) -> some View {
        Text(dieFace(value))
            .font(.system(size: 36))
            .frame(width: 56, height: 56)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
    }

    private func dieFace(_ value: Int) -> String {
        let faces = ["⚀","⚁","⚂","⚃","⚄","⚅"]
        return faces[max(0, min(5, value - 1))]
    }

    private func scorePill(label: String, score: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
            Text("\(score)p")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    private var scorecardView: some View {
        VStack(spacing: 0) {
            Text("POÄNGKORT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            ForEach(YatzyCategory.allCases) { cat in
                let playerScore = playerScores[cat]
                let aiScore = aiScores[cat]
                let potential = cat.score(dice: dice.map { $0.value })
                let isAvailable = availableCategories.contains(cat) && isPlayerTurn && rollsLeft < 3

                Button {
                    if isAvailable { selectCategory(cat) }
                } label: {
                    HStack {
                        Text(cat.rawValue)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(isAvailable ? .white : .white.opacity(0.4))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let ps = playerScore {
                            Text("\(ps)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(width: 36)
                        } else if isAvailable {
                            Text("\(potential)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green.opacity(0.5))
                                .frame(width: 36)
                        } else {
                            Text("—")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.2))
                                .frame(width: 36)
                        }

                        if let as_ = aiScore {
                            Text("\(as_)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                                .frame(width: 36)
                        } else {
                            Text("—")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.2))
                                .frame(width: 36)
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(isAvailable && potential > 0 ? Color.green.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .disabled(!isAvailable)

                Divider().background(Color.white.opacity(0.05))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Game Logic

    func startGame() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        playerScores = [:]
        aiScores = [:]
        currentRound = 0
        dice = (0..<5).map { YatzyDie(id: $0, value: Int.random(in: 1...6)) }
        rollsLeft = 3
        isPlayerTurn = true
        gamePhase = .playerRoll
        statusMessage = "Kasta tärningarna!"
    }

    func rollDice() {
        guard rollsLeft > 0, !isRolling else { return }
        isRolling = true
        rollsLeft -= 1

        withAnimation(.easeInOut(duration: 0.3)) {
            for i in 0..<dice.count {
                if !dice[i].held {
                    dice[i].value = Int.random(in: 1...6)
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isRolling = false
            if rollsLeft == 0 {
                statusMessage = "Välj en kategori i poängkortet"
            }
        }
    }

    func selectCategory(_ cat: YatzyCategory) {
        guard isPlayerTurn, availableCategories.contains(cat) else { return }
        let score = cat.score(dice: dice.map { $0.value })
        playerScores[cat] = score
        statusMessage = "\(cat.rawValue): \(score) poäng"
        currentRound += 1

        if currentRound >= totalRounds {
            endGame()
            return
        }

        // AI turn
        isPlayerTurn = false
        aiDice = (0..<5).map { _ in Int.random(in: 1...6) }
        gamePhase = .aiTurn

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // AI rerolls up to 2 more times
            let availableForAI = Set(YatzyCategory.allCases.filter { !self.aiScores.keys.contains($0) })
            var bestDice = self.aiDice

            for _ in 0..<2 {
                if let (bestCat, _) = aiBestScore(dice: bestDice, availableCategories: availableForAI) {
                    // Simple: reroll dice not contributing to best category
                    bestDice = bestDice.map { _ in Int.random(in: 1...6) }
                    _ = bestCat
                }
            }
            self.aiDice = bestDice

            if let (bestCat, bestSc) = aiBestScore(dice: bestDice, availableCategories: availableForAI) {
                self.aiScores[bestCat] = bestSc
                self.statusMessage = "AI väljer \(bestCat.rawValue): \(bestSc) poäng"
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.isPlayerTurn = true
                self.rollsLeft = 3
                for i in 0..<self.dice.count { self.dice[i].held = false; self.dice[i].value = Int.random(in: 1...6) }
                self.gamePhase = .playerRoll
                self.statusMessage = "Din tur — \(self.rollsLeft) kast kvar"
            }
        }
    }

    func endGame() {
        gamePhase = .gameOver
        let playerFinal = playerTotalScore
        let aiFinal = aiTotalScore

        let zone = gameState.currentZone
        let baseSeconds = Double(playerFinal) * pointsToSeconds
        let taxed = baseSeconds * (1 - zone.taxRate)

        if playerFinal > aiFinal {
            let bonus = betAmount * 1.5 * (1 - zone.taxRate)
            TimeEngine.shared.addTime(taxed + bonus)
            GameState.shared.recordEarning(taxed + bonus)
            resultMessage = "DU VANN! \(playerFinal) vs \(aiFinal) poäng\n+\(TimeEngine.shortFormatted(taxed + bonus)) (poäng + vinstbonus, efter skatt)"
        } else if playerFinal == aiFinal {
            TimeEngine.shared.addTime(betAmount)
            resultMessage = "OAVGJORT! \(playerFinal) poäng var\n+\(TimeEngine.shortFormatted(taxed)) (poäng) + insatsen tillbaka"
        } else {
            TimeEngine.shared.addTime(taxed)
            GameState.shared.recordEarning(taxed)
            resultMessage = "AI VANN! \(aiFinal) vs \(playerFinal) poäng\n+\(TimeEngine.shortFormatted(taxed)) (dina poäng, efter skatt)"
        }
        showResult = true
    }

    func resetGame() {
        gamePhase = .betting
        playerScores = [:]
        aiScores = [:]
        currentRound = 0
        rollsLeft = 3
        isPlayerTurn = true
        statusMessage = ""
        betAmount = 1800
    }
}

#Preview {
    YatzyView()
        .preferredColorScheme(.dark)
}
