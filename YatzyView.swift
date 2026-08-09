import SwiftUI

// MARK: - Yatzy — Spellogik

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

class YatzyAI {
    static let shared = YatzyAI()
    private init() {}

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
                let subHolds = greedyHolds(dice: sim, available: available, myUpperScore: myUpperScore)
                for i in 0..<5 { if !subHolds[i] { sim[i] = Int.random(in: 1...6) } }
            }
            total += bestCategoryValue(dice: sim, available: available, myUpperScore: myUpperScore,
                                       myTotalScore: myTotalScore, opponentScore: opponentScore)
        }
        return total / Double(n)
    }

    private func greedyHolds(dice: [Int], available: Set<YatzyCategory>, myUpperScore: Int) -> [Bool] {
        var bestEV   = -Double.infinity
        var bestMask = Array(repeating: true, count: 5)
        for mask in 0..<32 {
            let holds = (0..<5).map { (mask >> $0) & 1 == 1 }
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

    func bestCategoryValue(
        dice: [Int], available: Set<YatzyCategory>,
        myUpperScore: Int, myTotalScore: Int, opponentScore: Int
    ) -> Double {
        guard !available.isEmpty else { return 0 }
        let trailing = myTotalScore < opponentScore - 15

        var best = -Double.infinity
        for cat in available {
            let v = categoryAdjustedValue(cat: cat, dice: dice, myUpperScore: myUpperScore, trailing: trailing)
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
            let got    = Double(dice.filter { $0 == fv }.reduce(0, +))
            let needed = max(0, 63 - myUpperScore)
            if needed > 0 {
                let bonusFraction = min(1.0, got / Double(needed))
                val += bonusFraction * 22.0
            }
        }

        switch cat {
        case .yatzy:       val = raw > 0 ? (trailing ? raw * 2.8 : raw * 2.0) : -8
        case .stagenStor:  val = raw > 0 ? raw * 1.4 : -5
        case .stagenLiten: val = raw > 0 ? raw * 1.2 : -4
        case .kak:         val = raw > 0 ? raw * 1.1 : -3
        case .chans:       val = raw * 0.95
        case .litenChans:
            let lowSum = Double(dice.filter { $0 <= 3 }.reduce(0, +))
            val = lowSum >= 9 ? lowSum : lowSum * 0.5
        default:
            break
        }
        return val
    }

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
            var val = categoryAdjustedValue(cat: cat, dice: dice, myUpperScore: myUpperScore, trailing: trailing)
            if cat.score(dice: dice) == 0 {
                val = -futureEV(for: cat, roundsLeft: roundsLeft)
            }
            if val > best.1 { best = (cat, val) }
        }
        return best.0
    }

    private func futureEV(for cat: YatzyCategory, roundsLeft: Int) -> Double {
        switch cat {
        case .yatzy:       return 3.0
        case .ettor:       return 2.1
        case .tvåor:       return 4.2
        case .treor:       return 6.3
        case .litenChans:  return 4.0
        case .storChans:   return 7.0
        case .fyror:       return 8.4
        case .par:         return 9.0
        case .femmor:      return 10.5
        case .stagenLiten: return 8.0
        case .tretal:      return 11.0
        case .stagenStor:  return 11.0
        case .kak:         return 14.0
        case .tvåPar:      return 13.0
        case .sexor:       return 12.6
        case .chans:       return 17.5
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
    @State private var diceShakePhase: CGFloat = 0

    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotif  = UINotificationFeedbackGenerator()
    private let hapticRigid  = UIImpactFeedbackGenerator(style: .rigid)

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
            Button {
                hapticLight.impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.7))
                    .padding(LTSpacing.sm)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(LTPressEffect())
            .accessibilityLabel("Stäng Yatzy")

            Spacer()
            Text("YATZY")
                .font(LTFont.heading(18))
                .foregroundColor(.white)
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(LTFont.label(12))
                .foregroundColor(.yellow)
                .contentTransition(.numericText())
                .animation(LTAnimation.springFast, value: engine.balance)
                .accessibilityLabel("Saldo: \(TimeEngine.shortFormatted(engine.balance))")
        }
        .padding(LTSpacing.lg)
        .padding(.top, LTSpacing.xl)
    }

    // MARK: - Insatsvy

    private var bettingView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: LTSpacing.xxl) {
                Spacer(minLength: LTSpacing.xxl)

                // Dice decoration
                HStack(spacing: LTSpacing.sm) {
                    ForEach(0..<5, id: \.self) { i in
                        Text(["⚀","⚁","⚂","⚃","⚄","⚅"][i])
                            .font(.system(size: 28))
                            .opacity(0.6)
                    }
                }
                .accessibilityHidden(true)

                VStack(spacing: LTSpacing.xs) {
                    Text("INSATS")
                        .font(LTFont.label(22))
                        .foregroundColor(.white)
                    Text(TimeEngine.shortFormatted(betAmount))
                        .font(LTFont.value(36))
                        .foregroundColor(.yellow)
                        .contentTransition(.numericText())
                        .animation(LTAnimation.springFast, value: betAmount)
                        .accessibilityLabel("Insats: \(TimeEngine.shortFormatted(betAmount))")
                }

                VStack(spacing: LTSpacing.xs + 2) {
                    Text("1 poäng = 60s livstid")
                        .font(LTFont.body(11))
                        .foregroundColor(.white.opacity(0.45))
                    Text("Yatzy (50p) = \(TimeEngine.shortFormatted(50 * pointsToSeconds))")
                        .font(LTFont.body(11))
                        .foregroundColor(.green.opacity(0.7))
                    Text("Bonusövre (63p) = +3 000s extra")
                        .font(LTFont.body(11))
                        .foregroundColor(.cyan.opacity(0.7))
                    Text("AI vinner ~82% mot genomsnittlig spelare.")
                        .font(LTFont.body(10))
                        .foregroundColor(LTPalette.danger.opacity(0.7))
                }

                LTInfoCallout(
                    title: "Spelupplägg",
                    message: "Du spelar 16 rundor mot en svår AI. Bygg poäng i övre sektionen tidigt för att säkra +50 bonus.",
                    icon: "brain.head.profile",
                    tint: .cyan
                )
                .padding(.horizontal, LTSpacing.horizontal)

                // Quick-pick bets
                HStack(spacing: LTSpacing.sm) {
                    ForEach([900.0, 1800.0, 3600.0, 7200.0], id: \.self) { v in
                        Button {
                            hapticLight.impactOccurred()
                            withAnimation(LTAnimation.springFast) { betAmount = min(v, engine.balance) }
                        } label: {
                            Text(TimeEngine.shortFormatted(v))
                                .font(LTFont.body(10))
                                .foregroundColor(.white)
                                .padding(.horizontal, LTSpacing.sm)
                                .padding(.vertical, LTSpacing.xs + 2)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                        }
                        .buttonStyle(LTPressEffect())
                        .accessibilityLabel("Insats \(TimeEngine.shortFormatted(v))")
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
                .padding(.horizontal, LTSpacing.horizontal)
                .accessibilityLabel("Insatsslider")
                .accessibilityValue(TimeEngine.shortFormatted(betAmount))

                Button {
                    hapticMedium.impactOccurred()
                    startGame()
                } label: {
                    Text("STARTA SPELET")
                        .font(LTFont.heading(16))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LTSpacing.lg)
                        .background(betAmount <= engine.balance ? Color.green : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                }
                .disabled(betAmount > engine.balance)
                .buttonStyle(LTPressEffect())
                .padding(.horizontal, LTSpacing.horizontal)
                .accessibilityLabel("Starta spelet med insats \(TimeEngine.shortFormatted(betAmount))")
                .accessibilityHint(betAmount > engine.balance ? "Otillräcklig balans" : "")

                Spacer(minLength: LTSpacing.scrollBottom)
            }
        }
    }

    // MARK: - Spelvy

    private var gameplayView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: LTSpacing.md) {
                // Poäng header
                HStack {
                    scorePill(label: "DU", score: playerFinalScore, upper: playerUpperScore, color: .green)
                    Spacer()
                    VStack(spacing: 2) {
                        Text("Runda \(currentRound)/\(totalRounds)")
                            .font(LTFont.body(10))
                            .foregroundColor(.white.opacity(0.4))
                            .contentTransition(.numericText())
                            .animation(LTAnimation.springFast, value: currentRound)
                        Text("Insats: \(TimeEngine.shortFormatted(betAmount))")
                            .font(LTFont.caption(9))
                            .foregroundColor(.yellow.opacity(0.6))
                    }
                    Spacer()
                    scorePill(label: "AI", score: aiTotalScore, upper: aiUpperScore, color: .red)
                }
                .padding(.horizontal, LTSpacing.horizontal)

                LTInfoCallout(
                    title: isPlayerTurn ? "Din tur" : "AI tur",
                    message: isPlayerTurn
                        ? "Kasta upp till tre gånger och håll tärningar mellan kasten för bättre kombinationer."
                        : "AI analyserar sannolikheter och väljer kategori automatiskt när turen är klar.",
                    icon: isPlayerTurn ? "hand.tap.fill" : "cpu.fill",
                    tint: isPlayerTurn ? .green : .red
                )
                .padding(.horizontal, LTSpacing.horizontal)

                // Bonusindikator
                if playerUpperScore < 63 {
                    let needed = 63 - playerUpperScore
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.cyan)
                            .accessibilityHidden(true)
                        Text("Bonusövre: \(needed)p kvar → +50p bonus")
                            .font(LTFont.body(10))
                            .foregroundColor(.cyan.opacity(0.7))
                            .contentTransition(.numericText())
                            .animation(LTAnimation.springFast, value: needed)
                        Spacer()
                    }
                    .padding(.horizontal, LTSpacing.horizontal)
                }

                if isPlayerTurn {
                    Text("DIN TUR — \(rollsLeft) KAST KVAR")
                        .font(LTFont.label(11))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                        .animation(LTAnimation.springFast, value: rollsLeft)
                    playerDiceRow
                    rollButton
                } else {
                    Text("AI TÄNKER...")
                        .font(LTFont.label(11))
                        .foregroundColor(.red)
                    aiDiceRow
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LTSpacing.horizontal)
                        .transition(.opacity)
                        .animation(LTAnimation.fadeFast, value: statusMessage)
                }

                scorecardView.padding(.horizontal, LTSpacing.horizontal)
                Spacer(minLength: LTSpacing.scrollBottom)
            }
            .padding(.top, LTSpacing.sm)
        }
    }

    private var playerDiceRow: some View {
        HStack(spacing: LTSpacing.sm) {
            ForEach($dice) { $die in
                Button {
                    if rollsLeft < 3 {
                        hapticLight.impactOccurred()
                        withAnimation(LTAnimation.springFast) { die.held.toggle() }
                    }
                } label: {
                    Text(dieFace(die.value))
                        .font(.system(size: 34))
                        .frame(width: 54, height: 54)
                        .background(die.held ? Color.yellow.opacity(0.25) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                        .overlay(RoundedRectangle(cornerRadius: LTRadius.xs)
                            .stroke(die.held ? Color.yellow : Color.white.opacity(0.12), lineWidth: 2))
                        .scaleEffect(die.held ? 1.05 : 1.0)
                }
                .buttonStyle(LTPressEffect(scale: 0.92))
                .animation(LTAnimation.springFast, value: die.held)
                .accessibilityLabel("Tärning \(die.value). \(die.held ? "Hållen" : "Ej hållen")")
                .accessibilityHint(rollsLeft < 3 ? (die.held ? "Tryck för att släppa" : "Tryck för att hålla") : "Kasta minst en gång först")
            }
        }
    }

    private var aiDiceRow: some View {
        HStack(spacing: LTSpacing.sm) {
            ForEach(0..<5, id: \.self) { i in
                Text(dieFace(aiDice[i]))
                    .font(.system(size: 34))
                    .frame(width: 54, height: 54)
                    .background(aiHolds[i] ? Color.red.opacity(0.2) : Color.red.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                    .overlay(RoundedRectangle(cornerRadius: LTRadius.xs)
                        .stroke(aiHolds[i] ? Color.red.opacity(0.6) : Color.red.opacity(0.15),
                                lineWidth: aiHolds[i] ? 2 : 1))
                    .accessibilityLabel("AI tärning \(aiDice[i]). \(aiHolds[i] ? "Hållen" : "")")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI:s tärningar: \(aiDice.map { "\($0)" }.joined(separator: ", "))")
    }

    private var rollButton: some View {
        Button {
            if rollsLeft > 0 {
                hapticRigid.impactOccurred()
                rollDice()
            }
        } label: {
            HStack(spacing: LTSpacing.sm) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 16))
                    .accessibilityHidden(true)
                Text(rollsLeft > 0 ? "KASTA (\(rollsLeft) kvar)" : "VÄLJ KATEGORI")
                    .font(LTFont.heading(13))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LTSpacing.md)
            .background(rollsLeft > 0 ? Color.green : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        }
        .disabled(rollsLeft == 0 || isRolling)
        .buttonStyle(LTPressEffect())
        .padding(.horizontal, LTSpacing.horizontal)
        .accessibilityLabel(rollsLeft > 0 ? "Kasta tärningar, \(rollsLeft) kast kvar" : "Välj en kategori")
    }

    private func scorePill(label: String, score: Int, upper: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(LTFont.caption(9))
                .foregroundColor(color.opacity(0.7))
            Text("\(score)p")
                .font(LTFont.value(15))
                .foregroundColor(color)
                .contentTransition(.numericText())
                .animation(LTAnimation.springFast, value: score)
            Text("Övre: \(upper)/63")
                .font(LTFont.caption(8))
                .foregroundColor(upper >= 63 ? .cyan : color.opacity(0.5))
                .contentTransition(.numericText())
                .animation(LTAnimation.springFast, value: upper)
        }
        .padding(.horizontal, LTSpacing.md)
        .padding(.vertical, LTSpacing.xs + 1)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(score) poäng, övre sektion: \(upper) av 63")
    }

    // MARK: - Poängkort

    private var scorecardView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("KATEGORI")
                    .font(LTFont.caption(8))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("DU")
                    .font(LTFont.caption(8))
                    .foregroundColor(.green.opacity(0.5))
                    .frame(width: 38)
                Text("AI")
                    .font(LTFont.caption(8))
                    .foregroundColor(.red.opacity(0.5))
                    .frame(width: 38)
            }
            .padding(.horizontal, LTSpacing.sm + 2)
            .padding(.vertical, LTSpacing.xs + 2)

            ForEach(YatzyCategory.allCases) { cat in
                let playerScore = playerScores[cat]
                let aiScore     = aiScores[cat]
                let potential   = cat.score(dice: dice.map { $0.value })
                let isAvailable = availableCategories.contains(cat) && isPlayerTurn && rollsLeft < 3

                Button {
                    if isAvailable {
                        hapticMedium.impactOccurred()
                        selectCategory(cat)
                    }
                } label: {
                    HStack {
                        Text(cat.rawValue)
                            .font(LTFont.body(10))
                            .foregroundColor(isAvailable ? .white : .white.opacity(0.35))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let ps = playerScore {
                            Text("\(ps)")
                                .font(LTFont.heading(11))
                                .foregroundColor(.green)
                                .frame(width: 38)
                                .contentTransition(.numericText())
                        } else if isAvailable {
                            Text("\(potential)")
                                .font(LTFont.body(10))
                                .foregroundColor(.green.opacity(0.45))
                                .frame(width: 38)
                        } else {
                            Text("—")
                                .font(LTFont.body(10))
                                .foregroundColor(.white.opacity(0.15))
                                .frame(width: 38)
                        }
                        if let as_ = aiScore {
                            Text("\(as_)")
                                .font(LTFont.heading(11))
                                .foregroundColor(.red)
                                .frame(width: 38)
                                .contentTransition(.numericText())
                        } else {
                            Text("—")
                                .font(LTFont.body(10))
                                .foregroundColor(.white.opacity(0.15))
                                .frame(width: 38)
                        }
                    }
                    .padding(.vertical, LTSpacing.xs)
                    .padding(.horizontal, LTSpacing.sm + 2)
                    .background(isAvailable && potential > 0 ? Color.green.opacity(0.07) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .disabled(!isAvailable)
                .buttonStyle(LTPressEffect(scale: 0.97))
                .accessibilityLabel("\(cat.rawValue): du: \(playerScore.map { "\($0)" } ?? (isAvailable ? "\(potential) möjligt" : "ej vald")), AI: \(aiScore.map { "\($0)" } ?? "ej vald")")
                .accessibilityHint(isAvailable ? "Välj denna kategori" : "")

                Divider().background(Color.white.opacity(0.04))
            }

            Divider().background(Color.white.opacity(0.15))
            HStack {
                Text("BONUSÖVRE (+50p)")
                    .font(LTFont.caption(9))
                    .foregroundColor(.cyan.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(playerUpperScore >= 63 ? "✓" : "\(63-playerUpperScore) kvar")
                    .font(LTFont.caption(9))
                    .foregroundColor(playerUpperScore >= 63 ? .cyan : .white.opacity(0.3))
                    .frame(width: 38)
                    .contentTransition(.numericText())
                    .animation(LTAnimation.springFast, value: playerUpperScore)
                Text(aiUpperScore >= 63 ? "✓" : "—")
                    .font(LTFont.caption(9))
                    .foregroundColor(aiUpperScore >= 63 ? .cyan : .white.opacity(0.2))
                    .frame(width: 38)
            }
            .padding(.horizontal, LTSpacing.sm + 2)
            .padding(.vertical, LTSpacing.xs + 2)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
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
        withAnimation(LTAnimation.fadeFast) {
            statusMessage = "\(cat.rawValue): \(score)p"
        }
        currentRound += 1
        if currentRound >= totalRounds { endGame(); return }
        startAITurn()
    }

    // MARK: - AI-tur

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                aiChooseCategory()
            }
            return
        }

        let holds = YatzyAI.shared.optimalHolds(
            dice: aiDice,
            rollsLeft: rollsRemaining,
            available: aiAvailableCategories,
            myUpperScore: aiUpperScore,
            opponentScore: playerTotalScore,
            myTotalScore: aiTotalScore
        )
        aiHolds = holds

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
        withAnimation(LTAnimation.fadeFast) {
            statusMessage = "AI väljer \(chosen.rawValue): \(score)p"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            isPlayerTurn = true
            rollsLeft = 3
            dice = (0..<5).map { YatzyDie(id: $0, value: Int.random(in: 1...6)) }
            aiHolds = Array(repeating: false, count: 5)
            gamePhase = .playerRoll
            withAnimation(LTAnimation.fadeFast) { statusMessage = "Din tur" }
        }
    }

    func endGame() {
        gamePhase = .gameOver
        let zone = gameState.currentZone
        let playerFinal  = playerFinalScore
        let aiFinalScore = aiTotalScore + (aiUpperScore >= 63 ? 50 : 0)
        let baseSeconds  = Double(playerFinal) * pointsToSeconds
        let taxed        = baseSeconds * (1 - zone.taxRate)

        if playerFinal > aiFinalScore {
            hapticNotif.notificationOccurred(.success)
            let bonus = betAmount * 1.5 * (1 - zone.taxRate)
            TimeEngine.shared.addTime(taxed + bonus)
            GameState.shared.recordEarning(taxed + bonus)
            TransactionLedger.shared.record(label: "Yatzy — vinst", amount: taxed + bonus - betAmount)
            resultMessage = "DU VANN!\n\(playerFinal) vs \(aiFinalScore) poäng\n+\(TimeEngine.shortFormatted(taxed + bonus))"
        } else if playerFinal == aiFinalScore {
            hapticNotif.notificationOccurred(.warning)
            TimeEngine.shared.addTime(betAmount + taxed)
            TransactionLedger.shared.record(label: "Yatzy — oavgjort", amount: taxed)
            resultMessage = "OAVGJORT\n\(playerFinal) poäng var\n+\(TimeEngine.shortFormatted(taxed)) + insatsen tillbaka"
        } else {
            hapticNotif.notificationOccurred(.error)
            TimeEngine.shared.addTime(taxed)
            GameState.shared.recordEarning(taxed)
            TransactionLedger.shared.record(label: "Yatzy — förlust (AI vann)", amount: taxed - betAmount)
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
