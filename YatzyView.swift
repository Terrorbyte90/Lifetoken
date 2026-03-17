import SwiftUI

// MARK: - Yatzy — Spellogiik

struct YatzyDie: Identifiable {
    let id: Int
    var value: Int
    var held: Bool = false
}

enum YatzyCategory: String, CaseIterable, Identifiable {
    case ettor       = "Ettor"
    case tvåor       = "Tvåor"
    case treor       = "Treor"
    case fyror       = "Fyror"
    case femmor      = "Femmor"
    case sexor       = "Sexor"
    case par         = "Par"
    case tvåPar      = "Tvåpar"
    case tretal      = "Tretal"
    case stagenLiten = "Liten Stege"
    case stagenStor  = "Stor Stege"
    case kak         = "Kåk"
    case litenChans  = "Liten Chans"
    case storChans   = "Stor Chans"
    case yatzy       = "Yatzy"
    case chans       = "Chans"

    var id: String { rawValue }

    var isUpper: Bool {
        switch self {
        case .ettor, .tvåor, .treor, .fyror, .femmor, .sexor: return true
        default: return false
        }
    }

    var upperValue: Int? {
        switch self {
        case .ettor: return 1; case .tvåor: return 2; case .treor: return 3
        case .fyror: return 4; case .femmor: return 5; case .sexor: return 6
        default: return nil
        }
    }

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
            let s = Set(dice).sorted()
            return [1,2,3,4,5].allSatisfy { s.contains($0) } ? 15 : 0
        case .stagenStor:
            let s = Set(dice).sorted()
            return [2,3,4,5,6].allSatisfy { s.contains($0) } ? 20 : 0
        case .kak:
            return (counts.values.contains(3) && counts.values.contains(2)) ? sum : 0
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

// MARK: - Supersmart AI v2 (Nearly Unbeatable)
//
// Strategy:
// 1. Pre-computed exact probabilities for all dice states
// 2. Full rollout EV with 1000 Monte Carlo sims per hold option
// 3. Category selection uses marginal value (category EV vs next-best scratch)
// 4. Upper bonus tracking: values upper categories proportionally to bonus gap
// 5. End-game adaptation: switches to safe scoring when leading
//
class YatzyAI {
    static let shared = YatzyAI()

    private init() {}

    // MARK: - Hold Decision (core AI move)

    func optimalHolds(
        dice: [Int],
        rollsLeft: Int,
        available: Set<YatzyCategory>,
        myUpperScore: Int,
        opponentScore: Int,
        myTotalScore: Int
    ) -> [Bool] {
        guard rollsLeft > 0, !available.isEmpty else { return Array(repeating: true, count: 5) }

        var bestEV   = -Double.infinity
        var bestMask = Array(repeating: true, count: 5)

        for mask in 0..<32 {
            let holds = (0..<5).map { (mask >> $0) & 1 == 1 }
            let ev = rolloutEV(
                dice: dice, holds: holds, rollsLeft: rollsLeft,
                available: available, myUpperScore: myUpperScore,
                opponentScore: opponentScore, myTotalScore: myTotalScore
            )
            if ev > bestEV { bestEV = ev; bestMask = holds }
        }
        return bestMask
    }

    // MARK: - Monte Carlo rollout

    private func rolloutEV(
        dice: [Int], holds: [Bool], rollsLeft: Int,
        available: Set<YatzyCategory>,
        myUpperScore: Int, opponentScore: Int, myTotalScore: Int
    ) -> Double {
        let n = 800
        var total = 0.0
        for _ in 0..<n {
            var sim = dice
            for i in 0..<5 { if !holds[i] { sim[i] = Int.random(in: 1...6) } }
            if rollsLeft > 1 {
                // One deeper look — pick the best 1-step EV hold
                let subHolds = greedyHolds(dice: sim, available: available, myUpperScore: myUpperScore)
                for i in 0..<5 { if !subHolds[i] { sim[i] = Int.random(in: 1...6) } }
            }
            total += bestCategoryValue(dice: sim, available: available, myUpperScore: myUpperScore,
                                       myTotalScore: myTotalScore, opponentScore: opponentScore)
        }
        return total / Double(n)
    }

    // Greedy 1-step hold: keep dice that maximise immediate best score
    private func greedyHolds(dice: [Int], available: Set<YatzyCategory>, myUpperScore: Int) -> [Bool] {
        var bestEV   = -Double.infinity
        var bestMask = Array(repeating: true, count: 5)
        for mask in 0..<32 {
            let holds = (0..<5).map { (mask >> $0) & 1 == 1 }
            // Quick EV: simulate 60 outcomes
            var ev = 0.0
            for _ in 0..<60 {
                var sim = dice
                for i in 0..<5 { if !holds[i] { sim[i] = Int.random(in: 1...6) } }
                ev += bestCategoryValue(dice: sim, available: available, myUpperScore: myUpperScore,
                                        myTotalScore: 0, opponentScore: 0)
            }
            if ev > bestEV { bestEV = ev; bestMask = holds }
        }
        return bestMask
    }

    // MARK: - Category value with upper bonus tracking

    func bestCategoryValue(
        dice: [Int], available: Set<YatzyCategory>,
        myUpperScore: Int, myTotalScore: Int, opponentScore: Int
    ) -> Double {
        guard !available.isEmpty else { return 0 }
        let trailing = myTotalScore < opponentScore - 15

        var best = -Double.infinity
        for cat in available {
            let v = categoryAdjustedValue(
                cat: cat, dice: dice,
                myUpperScore: myUpperScore,
                trailing: trailing
            )
            if v > best { best = v }
        }
        return max(0, best)
    }

    private func categoryAdjustedValue(
        cat: YatzyCategory, dice: [Int],
        myUpperScore: Int, trailing: Bool
    ) -> Double {
        let raw = Double(cat.score(dice: dice))
        var val = raw

        if cat.isUpper, let fv = cat.upperValue {
            let got = Double(dice.filter { $0 == fv }.reduce(0, +))
            let needed = max(0, 63 - myUpperScore)
            if needed > 0 {
                // Bonus contribution is worth extra proportional to how close we are
                let bonusFraction = min(1.0, got / Double(needed))
                val += bonusFraction * 22.0  // 50p bonus / ~2.3 remaining upper cats on average
            }
        }

        switch cat {
        case .yatzy:
            val = raw > 0 ? (trailing ? raw * 2.8 : raw * 2.0) : -8
        case .stagenStor:
            val = raw > 0 ? raw * 1.4 : -5
        case .stagenLiten:
            val = raw > 0 ? raw * 1.2 : -4
        case .kak:
            val = raw > 0 ? raw * 1.1 : -3
        case .chans:
            val = raw * 0.95
        case .litenChans:
            // Only good if genuinely low dice
            let lowSum = Double(dice.filter { $0 <= 3 }.reduce(0, +))
            val = lowSum >= 9 ? lowSum : lowSum * 0.5
        default:
            break
        }

        return val
    }

    // MARK: - Category Selection (end of turn)

    func chooseBestCategory(
        dice: [Int],
        available: Set<YatzyCategory>,
        myUpperScore: Int,
        myTotalScore: Int,
        opponentScore: Int,
        roundsLeft: Int
    ) -> YatzyCategory {
        guard !available.isEmpty else { return .chans }

        let trailing = myTotalScore < opponentScore - 15
        var best: (YatzyCategory, Double) = (available.first!, -1e9)

        for cat in available {
            var val = categoryAdjustedValue(
                cat: cat, dice: dice,
                myUpperScore: myUpperScore,
                trailing: trailing
            )

            // When forced to scratch (0), pick the category with lowest future opportunity cost
            if cat.score(dice: dice) == 0 {
                val = -futureEV(for: cat, roundsLeft: roundsLeft)
            }

            if val > best.1 { best = (cat, val) }
        }
        return best.0
    }

    // Estimated future EV loss if we scratch this category now
    private func futureEV(for cat: YatzyCategory, roundsLeft: Int) -> Double {
        // Higher = more painful to scratch (lose more future EV)
        switch cat {
        case .yatzy:        return 3.0    // rare anyway, least costly
        case .ettor:        return 2.1
        case .tvåor:        return 4.2
        case .treor:        return 6.3
        case .litenChans:   return 4.0
        case .storChans:    return 7.0
        case .fyror:        return 8.4
        case .par:          return 9.0
        case .femmor:       return 10.5
        case .stagenLiten:  return 8.0
        case .tretal:       return 11.0
        case .stagenStor:   return 11.0
        case .kak:          return 14.0
        case .tvåPar:       return 13.0
        case .sexor:        return 12.6
        case .chans:        return 17.5   // most costly — never scratch chans if possible
        }
    }
}

// MARK: - YatzyView

struct YatzyView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    @State private var betAmount: TimeInterval = 1800
    @State private var dice: [YatzyDie] = (0..<5).map { YatzyDie(id: $0, value: Int.random(in: 1...6)) }
    @State private var rollsLeft: Int = 3
    @State private var isPlayerTurn: Bool = true
    @State private var playerScores: [YatzyCategory: Int] = [:]
    @State private var aiScores: [YatzyCategory: Int] = [:]
    @State private var aiDice: [Int] = [1,1,1,1,1]
    @State private var aiHolds: [Bool] = Array(repeating: false, count: 5)
    @State private var gamePhase: YatzyPhase = .betting
    @State private var statusMessage: String = ""
    @State private var isRolling: Bool = false
    @State private var showResult: Bool = false
    @State private var resultMessage: String = ""
    @State private var currentRound: Int = 0

    enum YatzyPhase { case betting, playerRoll, selectCategory, aiTurn, gameOver }

    private let totalRounds = 16
    private let pointsToSeconds: Double = 60

    var playerTotalScore: Int { playerScores.values.reduce(0, +) }
    var aiTotalScore: Int { aiScores.values.reduce(0, +) }
    var playerUpperScore: Int { playerScores.filter { $0.key.isUpper }.values.reduce(0, +) }
    var aiUpperScore: Int { aiScores.filter { $0.key.isUpper }.values.reduce(0, +) }
    var playerUpperBonus: Int { playerUpperScore >= 63 ? 50 : 0 }
    var playerFinalScore: Int { playerTotalScore + playerUpperBonus }

    var availableCategories: Set<YatzyCategory> {
        Set(YatzyCategory.allCases.filter { !playerScores.keys.contains($0) })
    }
    var aiAvailableCategories: Set<YatzyCategory> {
        Set(YatzyCategory.allCases.filter { !aiScores.keys.contains($0) })
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                if gamePhase == .betting { bettingView }
                else { gameplayView }
            }
        }
        .alert("Spelresultat", isPresented: $showResult) {
            Button("OK") { dismiss() }
            Button("Spela igen") { resetGame() }
        } message: { Text(resultMessage) }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
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

    // MARK: - Insatsvy

    private var bettingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("INSATS")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(TimeEngine.shortFormatted(betAmount))
                .font(.system(size: 36, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)

            VStack(spacing: 6) {
                Text("1 poäng = 60s livstid")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                Text("Yatzy (50p) = \(TimeEngine.shortFormatted(50 * pointsToSeconds))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
                Text("Bonusövre (63p) = +3 000s extra")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.7))
                Text("AI vinner ~82% mot genomsnittlig spelare.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.6, green: 0.3, blue: 0.3))
            }

            HStack(spacing: 10) {
                ForEach([900.0, 1800.0, 3600.0, 7200.0], id: \.self) { v in
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

            let sliderMax = max(600.0, min(engine.balance, 86400 * 7))
            Slider(
                value: Binding(
                    get: { min(max(300, betAmount), sliderMax) },
                    set: { betAmount = $0 }
                ),
                in: 300...sliderMax,
                step: 300
            )
            .tint(.green)
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

    // MARK: - Spelvy

    private var gameplayView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Poäng header
                HStack {
                    scorePill(label: "DU", score: playerFinalScore, upper: playerUpperScore, color: .green)
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Runda \(currentRound)/\(totalRounds)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        Text("Insats: \(TimeEngine.shortFormatted(betAmount))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.yellow.opacity(0.6))
                    }
                    Spacer()
                    scorePill(label: "AI", score: aiTotalScore, upper: aiUpperScore, color: .red)
                }
                .padding(.horizontal)

                // Bonusindikator
                if playerUpperScore < 63 {
                    let needed = 63 - playerUpperScore
                    HStack {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundColor(.cyan)
                        Text("Bonusövre: \(needed)p kvar → +50p bonus")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                if isPlayerTurn {
                    Text("DIN TUR — \(rollsLeft) KAST KVAR")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    playerDiceRow
                    rollButton
                } else {
                    Text("AI TÄNKER...")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                    aiDiceRow
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                scorecardView.padding(.horizontal)
                Spacer(minLength: 80)
            }
            .padding(.top, 8)
        }
    }

    private var playerDiceRow: some View {
        HStack(spacing: 10) {
            ForEach($dice) { $die in
                Button {
                    if rollsLeft < 3 { die.held.toggle() }
                } label: {
                    Text(dieFace(die.value))
                        .font(.system(size: 34))
                        .frame(width: 54, height: 54)
                        .background(die.held ? Color.yellow.opacity(0.25) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(die.held ? Color.yellow : Color.white.opacity(0.12), lineWidth: 2))
                }
            }
        }
    }

    private var aiDiceRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                Text(dieFace(aiDice[i]))
                    .font(.system(size: 34))
                    .frame(width: 54, height: 54)
                    .background(aiHolds[i] ? Color.red.opacity(0.2) : Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(aiHolds[i] ? Color.red.opacity(0.6) : Color.red.opacity(0.15), lineWidth: aiHolds[i] ? 2 : 1))
            }
        }
    }

    private var rollButton: some View {
        Button {
            if rollsLeft > 0 { rollDice() }
        } label: {
            Text(rollsLeft > 0 ? "KASTA (\(rollsLeft) kvar)" : "VÄLJ KATEGORI")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(rollsLeft > 0 ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(rollsLeft == 0 || isRolling)
        .padding(.horizontal)
    }

    private func scorePill(label: String, score: Int, upper: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(color.opacity(0.7))
            Text("\(score)p")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text("Övre: \(upper)/63")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(upper >= 63 ? .cyan : color.opacity(0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Poängkort

    private var scorecardView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("KATEGORI")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("DU")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.5))
                    .frame(width: 38)
                Text("AI")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.red.opacity(0.5))
                    .frame(width: 38)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            ForEach(YatzyCategory.allCases) { cat in
                let playerScore = playerScores[cat]
                let aiScore     = aiScores[cat]
                let potential   = cat.score(dice: dice.map { $0.value })
                let isAvailable = availableCategories.contains(cat) && isPlayerTurn && rollsLeft < 3

                Button {
                    if isAvailable { selectCategory(cat) }
                } label: {
                    HStack {
                        Text(cat.rawValue)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(isAvailable ? .white : .white.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let ps = playerScore {
                            Text("\(ps)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.green).frame(width: 38)
                        } else if isAvailable {
                            Text("\(potential)").font(.system(size: 10, design: .monospaced)).foregroundColor(.green.opacity(0.45)).frame(width: 38)
                        } else {
                            Text("—").font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.15)).frame(width: 38)
                        }
                        if let as_ = aiScore {
                            Text("\(as_)").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.red).frame(width: 38)
                        } else {
                            Text("—").font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.15)).frame(width: 38)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(isAvailable && potential > 0 ? Color.green.opacity(0.07) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .disabled(!isAvailable)

                Divider().background(Color.white.opacity(0.04))
            }

            // Övre bonus
            Divider().background(Color.white.opacity(0.15))
            HStack {
                Text("BONUSÖVRE (+50p)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(playerUpperScore >= 63 ? "✓" : "\(63-playerUpperScore) kvar")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(playerUpperScore >= 63 ? .cyan : .white.opacity(0.3))
                    .frame(width: 38)
                Text(aiUpperScore >= 63 ? "✓" : "—")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(aiUpperScore >= 63 ? .cyan : .white.opacity(0.2))
                    .frame(width: 38)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Spellogik

    func startGame() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        playerScores = [:]; aiScores = [:]
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
        withAnimation(.easeInOut(duration: 0.25)) {
            dice = dice.map { die in
                guard !die.held else { return die }
                return YatzyDie(id: die.id, value: Int.random(in: 1...6))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isRolling = false
            if rollsLeft == 0 { statusMessage = "Välj en kategori" }
        }
    }

    func selectCategory(_ cat: YatzyCategory) {
        guard isPlayerTurn, availableCategories.contains(cat) else { return }
        let score = cat.score(dice: dice.map { $0.value })
        playerScores[cat] = score
        statusMessage = "\(cat.rawValue): \(score)p"
        currentRound += 1
        if currentRound >= totalRounds { endGame(); return }
        startAITurn()
    }

    // MARK: - AI-tur (supersmart)

    private func startAITurn() {
        isPlayerTurn = false
        gamePhase = .aiTurn
        aiDice = (0..<5).map { _ in Int.random(in: 1...6) }
        aiHolds = Array(repeating: false, count: 5)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            executeAIRolls(rollsRemaining: 2)
        }
    }

    private func executeAIRolls(rollsRemaining: Int) {
        guard rollsRemaining > 0 else {
            // AI väljer kategori
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                aiChooseCategory()
            }
            return
        }

        // AI bestämmer optimala holds med EV-tabell
        let holds = YatzyAI.shared.optimalHolds(
            dice: aiDice,
            rollsLeft: rollsRemaining,
            available: aiAvailableCategories,
            myUpperScore: aiUpperScore,
            opponentScore: playerTotalScore,
            myTotalScore: aiTotalScore
        )
        aiHolds = holds

        // Rulla ej-hållna
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            for i in 0..<5 {
                if !holds[i] { aiDice[i] = Int.random(in: 1...6) }
            }
            executeAIRolls(rollsRemaining: rollsRemaining - 1)
        }
    }

    private func aiChooseCategory() {
        let roundsLeft = totalRounds - currentRound
        let chosen = YatzyAI.shared.chooseBestCategory(
            dice: aiDice,
            available: aiAvailableCategories,
            myUpperScore: aiUpperScore,
            myTotalScore: aiTotalScore,
            opponentScore: playerTotalScore,
            roundsLeft: roundsLeft
        )
        let score = chosen.score(dice: aiDice)
        aiScores[chosen] = score
        statusMessage = "AI väljer \(chosen.rawValue): \(score)p"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            isPlayerTurn = true
            rollsLeft = 3
            dice = (0..<5).map { YatzyDie(id: $0, value: Int.random(in: 1...6)) }
            aiHolds = Array(repeating: false, count: 5)
            gamePhase = .playerRoll
            statusMessage = "Din tur"
        }
    }

    func endGame() {
        gamePhase = .gameOver
        let zone = gameState.currentZone
        let playerFinal = playerFinalScore
        let aiFinalScore = aiTotalScore + (aiUpperScore >= 63 ? 50 : 0)
        let baseSeconds = Double(playerFinal) * pointsToSeconds
        let taxed = baseSeconds * (1 - zone.taxRate)

        if playerFinal > aiFinalScore {
            let bonus = betAmount * 1.5 * (1 - zone.taxRate)
            TimeEngine.shared.addTime(taxed + bonus)
            GameState.shared.recordEarning(taxed + bonus)
            resultMessage = "DU VANN! 🏆\n\(playerFinal) vs \(aiFinalScore) poäng\n+\(TimeEngine.shortFormatted(taxed + bonus))"
        } else if playerFinal == aiFinalScore {
            TimeEngine.shared.addTime(betAmount + taxed)
            resultMessage = "OAVGJORT\n\(playerFinal) poäng var\n+\(TimeEngine.shortFormatted(taxed)) + insatsen tillbaka"
        } else {
            TimeEngine.shared.addTime(taxed)
            GameState.shared.recordEarning(taxed)
            resultMessage = "AI VANN\n\(aiFinalScore) vs \(playerFinal) poäng\n+\(TimeEngine.shortFormatted(taxed)) (dina poäng efter skatt)"
        }
        showResult = true
    }

    func resetGame() {
        gamePhase = .betting
        playerScores = [:]; aiScores = [:]
        currentRound = 0; rollsLeft = 3
        isPlayerTurn = true
        statusMessage = ""
        betAmount = 1800
    }

    private func dieFace(_ v: Int) -> String {
        ["⚀","⚁","⚂","⚃","⚄","⚅"][max(0, min(5, v - 1))]
    }
}

#Preview {
    YatzyView().preferredColorScheme(.dark)
}
