import SwiftUI

// MARK: - Color Extensions

private extension Color {
    static let goldYatzy = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let accentGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
}

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

// MARK: - AI Strategy (Probability-based expert system)

// Category rarity score (higher = harder to achieve = more valuable)
private func aiCategoryRarity(_ cat: MultiYatzyCategory) -> Int {
    switch cat {
    case .yatzy:      return 100
    case .storStege:  return 90
    case .litenStege: return 80
    case .kas:        return 70
    case .fyrtal:     return 60
    case .triss:      return 50
    case .tvaPar:     return 40
    case .par:        return 30
    case .sexor:      return 25
    case .femmor:     return 22
    case .fyror:      return 18
    case .treor:      return 15
    case .tvaor:      return 12
    case .chans:      return 8
    case .ettor:      return 5
    }
}

/// Choose the best category to score. Uses score + strategic weighting.
/// Never wastes high-value combos on low-value categories.
private func aiChooseCategory(dice: [Int], available: Set<MultiYatzyCategory>) -> MultiYatzyCategory? {
    guard !available.isEmpty else { return nil }

    let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
    let maxCount = counts.values.max() ?? 0

    // Rule 1: ALWAYS score Yatzy if we have 5-of-a-kind and it's available
    if maxCount == 5 && available.contains(.yatzy) { return .yatzy }

    // Rule 2: Score large/small straight immediately if available
    if multiYatzyScore(for: .storStege, dice: dice) == 20 && available.contains(.storStege) { return .storStege }
    if multiYatzyScore(for: .litenStege, dice: dice) == 15 && available.contains(.litenStege) { return .litenStege }

    // Rule 3: Score full house immediately if available
    if multiYatzyScore(for: .kas, dice: dice) > 0 && available.contains(.kas) { return .kas }

    // Score all available categories
    var candidates: [(cat: MultiYatzyCategory, score: Int, strategicValue: Double)] = []

    for cat in available {
        let score = multiYatzyScore(for: cat, dice: dice)
        var sv = Double(score)

        // Never use upper section to score a Yatzy-potential hand (4+ of a kind)
        if cat.isUpperSection && maxCount >= 4 && available.contains(.yatzy) { continue }

        // Upper section: only desirable if 3+ matching dice
        if cat.isUpperSection, let faceVal = cat.upperFaceValue {
            let cnt = counts[faceVal] ?? 0
            switch cnt {
            case 5: sv *= 2.5   // perfect
            case 4: sv *= 1.8
            case 3: sv *= 1.0   // acceptable
            case 2: sv *= 0.3   // weak — avoid if better options exist
            default: sv *= 0.05 // terrible — only scratch here
            }
        }

        // Bonus weight for rare/hard-to-score categories when scored well
        if score > 0 {
            sv += Double(aiCategoryRarity(cat)) * 0.4
        }

        // Four-of-a-kind: avoid scoring it as upper section
        if cat == .fyrtal && maxCount == 4 { sv += 30 }
        if cat == .triss   && maxCount >= 3 { sv += 15 }

        candidates.append((cat, score, sv))
    }

    // Sort: highest strategic value first
    candidates.sort { $0.strategicValue > $1.strategicValue }

    // Pick best scoring category (score > 0)
    if let best = candidates.first, best.score > 0 { return best.cat }

    // All zero — scratch least valuable category (preserve best for later turns)
    // Scratch order: lowest-value upper sections first, then lower sections, save high-value last
    let scratchOrder: [MultiYatzyCategory] = [
        .ettor, .tvaor, .treor, .fyror,           // Low upper section (max 5–20 pts) scratch first
        .par,                                       // Low lower section
        .femmor, .sexor,                            // Higher upper section
        .tvaPar, .triss, .chans,                    // Medium combos
        .kas, .fyrtal,                              // Valuable combos — scratch reluctantly
        .litenStege, .storStege, .yatzy             // Never scratch these if avoidable
    ]
    for cat in scratchOrder where available.contains(cat) { return cat }
    return available.first
}

/// Decide which dice to keep. Uses probability-aware heuristics.
/// rollsRemaining: how many rerolls the AI still has after this keep decision.
private func aiSelectDiceToKeep(dice: [Int], available: Set<MultiYatzyCategory>, rollsRemaining: Int = 1) -> [Bool] {
    let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
    let maxCount = counts.values.max() ?? 0
    let uniqueVals = Set(dice)

    // --- Keep ALL if Yatzy ---
    if maxCount == 5 { return [Bool](repeating: true, count: 5) }

    // --- Keep 4-of-a-kind: chase Yatzy (probability 1/6 per reroll) ---
    if maxCount == 4 {
        let quadVal = counts.first(where: { $0.value == 4 })!.key
        return dice.map { $0 == quadVal }
    }

    // --- Full house: keep it if Kas is available ---
    let triples   = counts.filter { $0.value >= 3 }.keys.sorted(by: >)
    let pairs     = counts.filter { $0.value >= 2 }.keys.sorted(by: >)
    let _ = pairs.count >= 2 || (pairs.count == 1 && (counts[pairs[0]] ?? 0) >= 3)

    if let _ = triples.first, pairs.count >= 2, available.contains(.kas) {
        // Already have full house — keep all 5
        return [Bool](repeating: true, count: 5)
    }

    // --- Straight potential: keep straight dice ---
    let storSetVals = Set([2, 3, 4, 5, 6])
    let litenSetVals = Set([1, 2, 3, 4, 5])
    let inStor  = uniqueVals.intersection(storSetVals)
    let inLiten = uniqueVals.intersection(litenSetVals)

    // Complete straight: keep all
    if inStor.count == 5 && available.contains(.storStege) { return [Bool](repeating: true, count: 5) }
    if inLiten.count == 5 && available.contains(.litenStege) { return [Bool](repeating: true, count: 5) }

    // 4 values of a straight — worth chasing on 1+ rerolls
    if inStor.count == 4 && available.contains(.storStege) {
        // Keep the 4 straight values, replace the one that doesn't fit
        return dice.map { storSetVals.contains($0) && inStor.contains($0) }
    }
    if inLiten.count == 4 && available.contains(.litenStege) {
        return dice.map { litenSetVals.contains($0) && inLiten.contains($0) }
    }

    // 3-of-a-kind: keep them (chase 4-of-a-kind or full house)
    if let triple = triples.first {
        let tripleVal = triple
        // If we also have a pair, keep all 5 (full house)
        if pairs.count >= 2 { return [Bool](repeating: true, count: 5) }
        return dice.map { $0 == tripleVal }
    }

    // Two pairs — keep both pairs (chase full house or tvaPar)
    if pairs.count >= 2 {
        let keepPairs = Set(pairs.prefix(2))
        return dice.map { keepPairs.contains($0) }
    }

    // One pair — keep it (chase triss)
    if let topPair = pairs.first {
        return dice.map { $0 == topPair }
    }

    // --- Straight potential with 3 consecutive values ---
    if inStor.count == 3 && available.contains(.storStege) && rollsRemaining >= 2 {
        return dice.map { storSetVals.contains($0) }
    }
    if inLiten.count == 3 && available.contains(.litenStege) && rollsRemaining >= 2 {
        return dice.map { litenSetVals.contains($0) }
    }

    // --- Chase best available upper section ---
    // Find which upper value has most dice showing
    let upperAvailable = MultiYatzyCategory.allCases.filter { $0.isUpperSection && available.contains($0) }
    if !upperAvailable.isEmpty {
        let bestUpper = upperAvailable.max { cat1, cat2 in
            let v1 = cat1.upperFaceValue ?? 0
            let v2 = cat2.upperFaceValue ?? 0
            let c1 = counts[v1] ?? 0
            let c2 = counts[v2] ?? 0
            if c1 != c2 { return c1 < c2 }
            return v1 < v2   // prefer higher face value on tie
        }
        if let cat = bestUpper, let faceVal = cat.upperFaceValue {
            let cnt = counts[faceVal] ?? 0
            if cnt >= 2 { return dice.map { $0 == faceVal } }
        }
    }

    // --- Default: keep the 2 highest unique dice (for Chans) ---
    let top2Vals = Set(dice.sorted(by: >).prefix(2))
    return dice.map { top2Vals.contains($0) }
}

// MARK: - Die Dot View

private struct DieDotView: View {
    let value: Int
    let size: CGFloat

    // Dot layout per face value: positions as (x, y) in a 3x3 grid (0-based)
    private func dotPositions(for value: Int) -> [(Int, Int)] {
        switch value {
        case 1: return [(1,1)]
        case 2: return [(0,0),(2,2)]
        case 3: return [(0,0),(1,1),(2,2)]
        case 4: return [(0,0),(2,0),(0,2),(2,2)]
        case 5: return [(0,0),(2,0),(1,1),(0,2),(2,2)]
        case 6: return [(0,0),(2,0),(0,1),(2,1),(0,2),(2,2)]
        default: return []
        }
    }

    var body: some View {
        let dotSize: CGFloat = size * 0.14
        let padding: CGFloat = size * 0.16

        ZStack {
            ForEach(Array(dotPositions(for: value).enumerated()), id: \.offset) { _, pos in
                let col = CGFloat(pos.0)
                let row = CGFloat(pos.1)
                let cellSize = (size - padding * 2) / 3.0
                let x = padding + cellSize * col + cellSize / 2
                let y = padding + cellSize * row + cellSize / 2

                Circle()
                    .fill(Color.white)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: .white.opacity(0.6), radius: 1)
                    .offset(
                        x: x - size / 2,
                        y: y - size / 2
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Die View

struct MultiDieView: View {
    let value: Int
    var held: Bool = false
    var isRolling: Bool = false
    var isAI: Bool = false
    var size: CGFloat = 60

    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(
                    LinearGradient(
                        colors: heldGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: shadowColor, radius: held ? 8 : 4, x: 0, y: held ? 4 : 2)

            RoundedRectangle(cornerRadius: size * 0.18)
                .stroke(borderColor, lineWidth: held ? 2.5 : 1)
                .frame(width: size, height: size)

            DieDotView(value: max(1, min(6, value)), size: size)
        }
        .rotationEffect(.degrees(rotationAngle))
        .scaleEffect(held ? 1.08 : scale)
        .onChange(of: isRolling) { _, rolling in
            if rolling {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    rotationAngle = Double.random(in: -25...25)
                    scale = 0.88
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    rotationAngle = 0
                    scale = 1.0
                }
            }
        }
    }

    private var heldGradient: [Color] {
        if held {
            return [
                Color(red: 0.12, green: 0.32, blue: 0.18),
                Color(red: 0.06, green: 0.18, blue: 0.10)
            ]
        } else if isAI {
            return [
                Color(red: 0.22, green: 0.06, blue: 0.08),
                Color(red: 0.12, green: 0.03, blue: 0.04)
            ]
        } else {
            return [
                Color(red: 0.18, green: 0.18, blue: 0.22),
                Color(red: 0.08, green: 0.08, blue: 0.12)
            ]
        }
    }

    private var borderColor: Color {
        if held { return Color.accentGreen.opacity(0.85) }
        if isAI { return Color.red.opacity(0.3) }
        return Color.white.opacity(0.15)
    }

    private var shadowColor: Color {
        if held { return Color.accentGreen.opacity(0.5) }
        if isAI { return Color.red.opacity(0.3) }
        return Color.black.opacity(0.5)
    }
}

// MARK: - Game Phase

private enum MultiYatzyPhase: Equatable {
    case lobby
    case handoff(toPlayerIndex: Int)
    case playing
    case gameOver
}

// MARK: - Game Mode

private enum MultiYatzyMode: Equatable {
    case vsAI
    case onlineOneVsOne
    case onlineThreePlayer
}

// MARK: - MultiplayerYatzyView

struct MultiplayerYatzyView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var server = ServerSync.shared

    // MARK: Lobby state
    @State private var player1Name: String = GameState.shared.username.isEmpty ? "Spelare 1" : GameState.shared.username
    @State private var player2Name: String = "Spelare 2"
    @State private var betAmount: TimeInterval = 600
    @State private var gameMode: MultiYatzyMode = .vsAI
    @State private var showInsufficientFundsAlert = false

    // MARK: Game state
    @State private var phase: MultiYatzyPhase = .lobby
    @State private var players: [YatzyPlayerState] = []
    @State private var currentPlayerIndex: Int = 0
    @State private var dice: [Int] = [1, 2, 3, 4, 5]
    @State private var heldDice: [Bool] = [false, false, false, false, false]
    @State private var rollsUsed: Int = 0
    @State private var isRolling: Bool = false
    @State private var isAIThinking: Bool = false
    @State private var statusMessage: String = ""
    @State private var lastScoreMessage: String = ""
    @State private var handoffReady: Bool = false

    // MARK: Online opponent selection
    @State private var selectedOnlineOpponent: ServerUser? = nil
    @State private var useRandomOpponent: Bool = false

    // MARK: Result state
    @State private var winnerIndex: Int? = nil
    @State private var isTie: Bool = false
    @State private var resultAnimating: Bool = false

    // MARK: Computed

    private var currentPlayer: YatzyPlayerState? {
        guard players.indices.contains(currentPlayerIndex) else { return nil }
        return players[currentPlayerIndex]
    }

    private var isCurrentPlayerAI: Bool {
        switch gameMode {
        case .vsAI:               return currentPlayerIndex == 1
        case .onlineOneVsOne:     return currentPlayerIndex == 1
        case .onlineThreePlayer:  return currentPlayerIndex >= 1
        }
    }

    private var canRoll: Bool {
        rollsUsed < 3 && !isRolling && !isAIThinking
    }

    private var canScore: Bool {
        rollsUsed > 0 && !isRolling && !isAIThinking
    }

    private var rollsRemaining: Int { max(0, 3 - rollsUsed) }

    private var betFormatted: String {
        TimeEngine.shortFormatted(betAmount)
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.08), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Game phase routing
            switch phase {
            case .lobby:
                lobbyView
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))

            case .handoff(let idx):
                handoffView(toPlayerIndex: idx)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))

            case .playing:
                gameplayView
                    .transition(.opacity)

            case .gameOver:
                gameOverView
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
        .alert("Otillräckligt saldo", isPresented: $showInsufficientFundsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Du har inte nog med tid för denna insats.\nDitt saldo: \(TimeEngine.shortFormatted(engine.balance))")
        }
    }

    // MARK: - Lobby View

    private var lobbyView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                lobbyHeader

                VStack(spacing: 24) {
                    // Mode selector
                    modeSelectorCard

                    // Player names card
                    playerNamesCard

                    // Bet card
                    betCard

                    // Start button
                    startButton

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    private var lobbyHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                Spacer()
                Text(TimeEngine.shortFormatted(engine.balance))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.goldYatzy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.goldYatzy.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)

            Text("YATZY")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .kerning(8)

            Text("MULTIPLAYER")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.accentGreen.opacity(0.8))
                .kerning(4)
        }
        .padding(.bottom, 20)
    }

    private var modeSelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPELLÄGE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .kerning(2)

            VStack(spacing: 10) {
                modeButton(title: "Mot AI", subtitle: "Spela mot AI", icon: "cpu", mode: .vsAI)
                HStack(spacing: 10) {
                    modeButton(title: "Online 1v1", subtitle: "Samma zon", icon: "wifi", mode: .onlineOneVsOne)
                    modeButton(title: "Online 3P", subtitle: "Tre spelare", icon: "person.3", mode: .onlineThreePlayer)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func modeButton(title: String, subtitle: String, icon: String, mode: MultiYatzyMode) -> some View {
        let selected = gameMode == mode
        return Button { withAnimation(.spring(response: 0.3)) { gameMode = mode } } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(selected ? .black : .white.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(selected ? .black : .white)
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(selected ? .black.opacity(0.6) : .white.opacity(0.4))
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.accentGreen : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var playerNamesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SPELARE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .kerning(2)

            nameField(label: "Spelare 1", placeholder: "Ditt namn", text: $player1Name, color: .accentGreen)

            switch gameMode {
            case .vsAI:
                aiOpponentRow(name: "AI-motståndare", subtitle: "Spelar optimalt")

            case .onlineOneVsOne:
                let opponents = server.zoneMembers.filter { $0.username != player1Name }
                if opponents.isEmpty {
                    onlineOpponentRow(name: "Online-AI", subtitle: "Inga spelare online i din zon", isOnline: false)
                } else {
                    onlinePlayerPickerSection(opponents: opponents)
                }

            case .onlineThreePlayer:
                let opponents = server.zoneMembers.filter { $0.username != player1Name }
                let opp1Name = opponents.first?.username ?? "Online-AI 1"
                let opp1Zone = opponents.first?.zone ?? ""
                let opp2Name = opponents.dropFirst().first?.username ?? "Online-AI 2"
                let opp2Zone = opponents.dropFirst().first?.zone ?? ""
                onlineOpponentRow(name: opp1Name, subtitle: opponents.isEmpty ? "Inga spelare online" : "Online • \(opp1Zone)", isOnline: !opponents.isEmpty)
                onlineOpponentRow(name: opp2Name, subtitle: opponents.count < 2 ? "Inga fler spelare online" : "Online • \(opp2Zone)", isOnline: opponents.count >= 2)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func aiOpponentRow(name: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.red.opacity(0.15)).frame(width: 36, height: 36)
                Text("🤖").font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Text(subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(.horizontal, 4)
    }

    private func onlineOpponentRow(name: String, subtitle: String, isOnline: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(isOnline ? Color.cyan.opacity(0.15) : Color.gray.opacity(0.12)).frame(width: 36, height: 36)
                Text(isOnline ? "👤" : "🤖").font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(isOnline ? .white.opacity(0.85) : .white.opacity(0.5))
                HStack(spacing: 4) {
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 5, height: 5)
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isOnline ? .cyan.opacity(0.7) : .white.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func onlinePlayerPickerSection(opponents: [ServerUser]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Random toggle
            Button {
                withAnimation(.spring(response: 0.3)) {
                    useRandomOpponent.toggle()
                    if useRandomOpponent { selectedOnlineOpponent = nil }
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(useRandomOpponent ? Color.cyan.opacity(0.2) : Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                        Image(systemName: "shuffle")
                            .font(.system(size: 16))
                            .foregroundColor(useRandomOpponent ? .cyan : .white.opacity(0.5))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Slumpmässig motståndare")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(useRandomOpponent ? .white : .white.opacity(0.6))
                        Text("Välj en random spelare i din zon")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    Spacer()
                    if useRandomOpponent {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(useRandomOpponent ? Color.cyan.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if !useRandomOpponent {
                Text("VÄLJ SPECIFIK SPELARE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .tracking(2)
                    .padding(.top, 4)

                ForEach(opponents) { opponent in
                    let isSelected = selectedOnlineOpponent?.id == opponent.id
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            selectedOnlineOpponent = isSelected ? nil : opponent
                        }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.accentGreen.opacity(0.2) : Color.white.opacity(0.06))
                                    .frame(width: 36, height: 36)
                                Text("👤").font(.system(size: 18))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(opponent.username)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 5, height: 5)
                                    Text("Online • \(opponent.zone)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.cyan.opacity(0.7))
                                }
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentGreen)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.accentGreen.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func nameField(label: String, placeholder: String, text: Binding<String>, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 8, height: 8)
            TextField(placeholder, text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .tint(color)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }

    private var betCard: some View {
        let maxBet = max(100, floor(engine.balance * 0.8))
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("INSATS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(2)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(betFormatted)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.goldYatzy)
                    Text("max 80% av saldo")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            Slider(value: Binding(
                get: { min(betAmount, maxBet) },
                set: { betAmount = $0 }
            ), in: 100...maxBet, step: 60)
                .tint(.goldYatzy)

            HStack {
                Text("100s")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
                Text("Max: \(TimeEngine.shortFormatted(maxBet))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }

            VStack(spacing: 6) {
                betInfoRow(icon: "arrow.up.circle.fill", text: "Vinst: +\(TimeEngine.shortFormatted(betAmount * 2))", color: .accentGreen)
                betInfoRow(icon: "equal.circle.fill", text: "Oavgjort: +\(betFormatted) tillbaka", color: .orange)
                betInfoRow(icon: "arrow.down.circle.fill", text: "Förlust: −\(betFormatted)", color: .red.opacity(0.8))
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func betInfoRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(color)
            Spacer()
        }
    }

    private var startButton: some View {
        let maxBet = max(100, floor(engine.balance * 0.8))
        let canAfford = betAmount <= engine.balance && betAmount <= maxBet
        return Button { startGame() } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("STARTA SPELET")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .kerning(2)
            }
            .foregroundColor(canAfford ? .black : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                canAfford
                    ? LinearGradient(colors: [Color.accentGreen, Color(red: 0.1, green: 0.7, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: canAfford ? Color.accentGreen.opacity(0.4) : .clear, radius: 12, y: 4)
        }
        .disabled(!canAfford)
    }

    // MARK: - Handoff View

    private func handoffView(toPlayerIndex idx: Int) -> some View {
        let playerName = players.indices.contains(idx) ? players[idx].name : "Spelare \(idx+1)"
        let isAI = gameMode == .vsAI && idx == 1
        let color: Color = idx == 0 ? .accentGreen : .orange

        return VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 100, height: 100)
                    if isAI {
                        Text("🤖")
                            .font(.system(size: 52))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(color.opacity(0.8))
                    }
                }
                .scaleEffect(handoffReady ? 1 : 0.6)
                .opacity(handoffReady ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: handoffReady)

                VStack(spacing: 6) {
                    Text("LÄMNA ÖVER TILL")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .kerning(3)
                    Text(playerName)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(color)
                    Text("Det är din tur!")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .offset(y: handoffReady ? 0 : 20)
                .opacity(handoffReady ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: handoffReady)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = .playing
                }
            } label: {
                Text("JAG ÄR REDO")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 40)
            }
            .opacity(handoffReady ? 1 : 0)
            .animation(.easeIn(duration: 0.3).delay(0.3), value: handoffReady)
            .padding(.bottom, 60)
        }
        .onAppear {
            handoffReady = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                handoffReady = true
            }
        }
    }

    // MARK: - Gameplay View

    private var gameplayView: some View {
        VStack(spacing: 0) {
            gameHeader
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    turnBanner
                    diceArea
                    if !statusMessage.isEmpty { statusBar }
                    actionButtons
                    scoreCard
                    Spacer(minLength: 40)
                }
                .padding(.top, 10)
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            if isCurrentPlayerAI { triggerAITurn() }
        }
    }

    private var gameHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }

            Spacer()

            VStack(spacing: 1) {
                Text("INSATS")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(1)
                Text(betFormatted)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.goldYatzy)
            }

            Spacer()

            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.goldYatzy.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.goldYatzy.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 10)
    }

    private var turnBanner: some View {
        let idx = currentPlayerIndex
        let name = players.indices.contains(idx) ? players[idx].name : "?"
        let color: Color = idx == 0 ? .accentGreen : .orange
        let isAI = isCurrentPlayerAI

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                if isAI {
                    Text("🤖")
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name.uppercased())
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                Text(isAI ? "AI spelar..." : "Din tur")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(color.opacity(0.6))
            }

            Spacer()

            // Score pills
            HStack(spacing: 8) {
                ForEach(0..<players.count, id: \.self) { i in
                    let p = players[i]
                    let c: Color = i == 0 ? .accentGreen : .orange
                    VStack(spacing: 1) {
                        Text(p.name.prefix(4).uppercased())
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(c.opacity(0.6))
                        Text("\(p.grandTotal)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(c)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(c.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(i == currentPlayerIndex ? c.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var diceArea: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in
                    let isHeld = heldDice[i]
                    let isAI = isCurrentPlayerAI
                    Button {
                        if !isAI && rollsUsed > 0 && rollsUsed < 3 && !isRolling {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                heldDice[i].toggle()
                            }
                        }
                    } label: {
                        MultiDieView(
                            value: dice[i],
                            held: isHeld,
                            isRolling: isRolling,
                            isAI: isAI,
                            size: 62
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isAI || rollsUsed == 0 || isRolling)
                }
            }

            if !isCurrentPlayerAI {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule()
                            .fill(heldDice[i] ? Color.accentGreen.opacity(0.6) : Color.white.opacity(0.1))
                            .frame(width: 16, height: 4)
                            .animation(.easeInOut(duration: 0.2), value: heldDice[i])
                    }
                }

                if rollsUsed > 0 {
                    Text("Tryck på tärning för att hålla/släppa")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentGreen.opacity(0.6))
                .frame(width: 6, height: 6)
            Text(statusMessage)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.accentGreen.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentGreen.opacity(0.15), lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Roll button
            Button {
                rollDice()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dice")
                        .font(.system(size: 14, weight: .semibold))
                    Text(rollsUsed == 0 ? "KASTA" : "KASTA OM")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    if rollsRemaining > 0 {
                        Text("×\(rollsRemaining)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.black.opacity(0.5))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(canRoll && !isCurrentPlayerAI ? .black : .white.opacity(0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    canRoll && !isCurrentPlayerAI
                        ? LinearGradient(colors: [Color.accentGreen, Color(red: 0.1, green: 0.7, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: canRoll && !isCurrentPlayerAI ? Color.accentGreen.opacity(0.3) : .clear, radius: 8, y: 3)
            }
            .disabled(!canRoll || isCurrentPlayerAI)

            // Roll count indicator
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < rollsUsed ? Color.accentGreen.opacity(0.8) : Color.white.opacity(0.12))
                        .frame(width: 6, height: 14)
                }
            }
        }
    }

    // MARK: - Score Card

    private var scoreCard: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("KATEGORI")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(0..<players.count, id: \.self) { i in
                    let color: Color = i == 0 ? .accentGreen : .orange
                    Text(players[i].name.prefix(5).uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(color.opacity(0.7))
                        .kerning(0.5)
                        .frame(width: 48, alignment: .center)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()
                .background(Color.white.opacity(0.08))

            // Upper section
            sectionHeader(title: "ÖVRE SEKTION")

            ForEach(MultiYatzyCategory.allCases.filter { $0.isUpperSection }) { cat in
                scoreRow(category: cat)
            }

            // Bonus row
            bonusRow

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.vertical, 4)

            // Lower section
            sectionHeader(title: "NEDRE SEKTION")

            ForEach(MultiYatzyCategory.allCases.filter { !$0.isUpperSection }) { cat in
                scoreRow(category: cat)
            }

            // Total row
            totalRow
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.25))
            .kerning(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func scoreRow(category: MultiYatzyCategory) -> some View {
        let currentDice = dice
        let isActive = canScore && !isCurrentPlayerAI && currentPlayerIndex < players.count
            && players[currentPlayerIndex].scores[category] == nil
        let potential = multiYatzyScore(for: category, dice: currentDice)

        return Button {
            if isActive { fillCategory(category) }
        } label: {
            HStack(spacing: 0) {
                // Category name
                Text(category.displayName)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(isActive ? .white : .white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Scores for each player
                ForEach(0..<players.count, id: \.self) { i in
                    let p = players[i]
                    let score = p.scores[category]
                    let isCurrent = i == currentPlayerIndex
                    let color: Color = i == 0 ? .accentGreen : .orange

                    Group {
                        if let s = score {
                            Text(s == 0 ? "—" : "\(s)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(s == 0 ? color.opacity(0.25) : color.opacity(0.9))
                                .strikethrough(s == 0, color: color.opacity(0.3))
                        } else if isCurrent && isActive {
                            Text(potential > 0 ? "\(potential)" : "0")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(potential > 0 ? color.opacity(0.55) : .white.opacity(0.2))
                        } else {
                            Text("—")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.12))
                        }
                    }
                    .frame(width: 48, alignment: .center)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isActive && potential > 0
                    ? Color.accentGreen.opacity(0.07)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
    }

    private var bonusRow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Bonus")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.goldYatzy.opacity(0.8))
                Text("≥63p → +50p")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<players.count, id: \.self) { i in
                let p = players[i]
                let upper = p.upperTotal
                let needed = max(0, 63 - upper)
                let color: Color = i == 0 ? .accentGreen : .orange

                VStack(spacing: 1) {
                    if p.hasBonus {
                        Text("+50")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.goldYatzy)
                    } else {
                        Text("\(upper)/63")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(color.opacity(0.5))
                        if needed > 0 {
                            Text("−\(needed)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                        }
                    }
                }
                .frame(width: 48, alignment: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.goldYatzy.opacity(0.04))
    }

    private var totalRow: some View {
        HStack(spacing: 0) {
            Text("TOTAL")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<players.count, id: \.self) { i in
                let p = players[i]
                let color: Color = i == 0 ? .accentGreen : .orange
                Text("\(p.grandTotal)")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                    .frame(width: 48, alignment: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Game Over View

    private var gameOverView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 60)

                resultHeader
                    .padding(.bottom, 32)

                finalScoreCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                actionButtonsGameOver
                    .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                resultAnimating = true
            }
        }
    }

    private var resultHeader: some View {
        let isWin = winnerIndex == 0
        let isLose = winnerIndex == 1
        let tie = isTie

        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(resultColor.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .scaleEffect(resultAnimating ? 1 : 0.5)

                Text(resultEmoji)
                    .font(.system(size: 58))
                    .scaleEffect(resultAnimating ? 1 : 0.3)
                    .opacity(resultAnimating ? 1 : 0)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.65), value: resultAnimating)

            Text(resultTitle)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(resultColor)
                .kerning(3)
                .opacity(resultAnimating ? 1 : 0)
                .offset(y: resultAnimating ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: resultAnimating)

            Text(resultSubtitle)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .opacity(resultAnimating ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.3), value: resultAnimating)

            // Earnings display
            VStack(spacing: 4) {
                Text("RESULTAT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(2)

                HStack(spacing: 6) {
                    Image(systemName: isWin ? "arrow.up.circle.fill" : (tie ? "equal.circle.fill" : "arrow.down.circle.fill"))
                        .font(.system(size: 16))
                        .foregroundColor(resultColor)
                    Text(earningsText)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(resultColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(resultColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(resultColor.opacity(0.25), lineWidth: 1)
            )
            .opacity(resultAnimating ? 1 : 0)
            .scaleEffect(resultAnimating ? 1 : 0.85)
            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4), value: resultAnimating)
        }
        // Silence unused variable warnings
        .onChange(of: isWin) { _, _ in }
        .onChange(of: isLose) { _, _ in }
        .onChange(of: tie) { _, _ in }
    }

    private var resultColor: Color {
        if isTie { return .orange }
        return winnerIndex == 0 ? .accentGreen : .red
    }

    private var resultEmoji: String {
        if isTie { return "🤝" }
        return winnerIndex == 0 ? "🏆" : "💀"
    }

    private var resultTitle: String {
        if isTie { return "OAVGJORT" }
        guard let w = winnerIndex, players.indices.contains(w) else { return "SPELET KLART" }
        if w == 0 {
            return players[0].name.prefix(8).uppercased()
        }
        switch gameMode {
        case .vsAI:           return "AI VANN"
        case .onlineOneVsOne, .onlineThreePlayer:
                              return players[w].name.prefix(8).uppercased()
        }
    }

    private var resultSubtitle: String {
        guard players.count >= 2 else { return "" }
        return players.map { "\($0.name.prefix(6)): \($0.grandTotal)p" }.joined(separator: "  ")
    }

    private var earningsText: String {
        if isTie { return "±0 (insats tillbaka)" }
        if winnerIndex == 0 {
            let opponents = players.count - 1
            return "+\(TimeEngine.shortFormatted(betAmount * Double(opponents)))"
        }
        return "−\(TimeEngine.shortFormatted(betAmount))"
    }

    private var finalScoreCard: some View {
        VStack(spacing: 0) {
            Text("SLUTRESULTAT")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .kerning(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(0..<players.count, id: \.self) { i in
                let p = players[i]
                let color: Color = i == 0 ? .accentGreen : .orange
                let isWinner = winnerIndex == i

                HStack(spacing: 12) {
                    if gameMode == .vsAI && i == 1 {
                        Text("🤖").font(.system(size: 20))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(p.name)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(color)
                            if isWinner && !isTie {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.goldYatzy)
                            }
                        }
                        Text("Övre: \(p.upperTotal)\(p.hasBonus ? " +50 bonus" : "")  Nedre: \(p.lowerTotal)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Spacer()

                    Text("\(p.grandTotal)")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(isWinner && !isTie ? .goldYatzy : color.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isWinner && !isTie ? color.opacity(0.08) : Color.clear)

                if i < players.count - 1 {
                    Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                }
            }

            Divider().background(Color.white.opacity(0.06))

            // Bonus detail
            if players.count > 0 {
                HStack {
                    Text("Bonusgräns (övre ≥63): +50p")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    private var actionButtonsGameOver: some View {
        VStack(spacing: 10) {
            Button {
                resultAnimating = false
                resetToLobby()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("SPELA IGEN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.accentGreen.opacity(0.35), radius: 10, y: 4)
            }

            Button {
                dismiss()
            } label: {
                Text("AVSLUTA")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        let p1Name = player1Name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalP1 = p1Name.isEmpty ? "Spelare 1" : p1Name

        // 80% bet limit enforcement
        let maxBet = max(100, floor(engine.balance * 0.8))
        guard betAmount <= maxBet else {
            showInsufficientFundsAlert = true
            return
        }

        guard TimeEngine.shared.deductTime(betAmount) else {
            showInsufficientFundsAlert = true
            return
        }

        // Build player list based on mode
        let zoneOpponents = server.zoneMembers.filter { $0.username != finalP1 }

        var newPlayers: [YatzyPlayerState]
        switch gameMode {
        case .vsAI:
            newPlayers = [
                YatzyPlayerState(name: finalP1),
                YatzyPlayerState(name: "🤖 AI")
            ]
        case .onlineOneVsOne:
            let opp: String
            if useRandomOpponent || selectedOnlineOpponent == nil {
                opp = zoneOpponents.shuffled().first?.username ?? "Online-AI"
            } else {
                opp = selectedOnlineOpponent?.username ?? zoneOpponents.first?.username ?? "Online-AI"
            }
            newPlayers = [
                YatzyPlayerState(name: finalP1),
                YatzyPlayerState(name: opp)
            ]
            // Send challenge notification to the selected opponent
            NotificationManager.shared.sendYatzyChallenge(from: finalP1, stake: TimeEngine.shortFormatted(betAmount))
        case .onlineThreePlayer:
            let opp1 = zoneOpponents.first?.username ?? "Online-AI 1"
            let opp2 = zoneOpponents.dropFirst().first?.username ?? "Online-AI 2"
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

        withAnimation(.easeInOut(duration: 0.35)) {
            phase = .playing
        }
    }

    private func resetDice() {
        dice = (0..<5).map { _ in Int.random(in: 1...6) }
        heldDice = [false, false, false, false, false]
    }

    private func rollDice() {
        guard canRoll && !isCurrentPlayerAI else { return }
        isRolling = true
        rollsUsed += 1

        // Small haptic-like delay for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            for i in 0..<5 {
                if !self.heldDice[i] {
                    self.dice[i] = Int.random(in: 1...6)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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

    private func fillCategory(_ category: MultiYatzyCategory) {
        guard canScore && !isCurrentPlayerAI else { return }
        guard players.indices.contains(currentPlayerIndex) else { return }
        guard players[currentPlayerIndex].scores[category] == nil else { return }

        let score = multiYatzyScore(for: category, dice: dice)
        players[currentPlayerIndex].scores[category] = score
        statusMessage = "\(category.displayName): \(score) poäng"
        lastScoreMessage = statusMessage

        advanceTurn()
    }

    private func advanceTurn() {
        // Check if game is over
        if players.allSatisfy({ $0.isFilled }) {
            endGame()
            return
        }

        // Move to next player
        let nextIndex = (currentPlayerIndex + 1) % players.count
        currentPlayerIndex = nextIndex
        resetDice()
        rollsUsed = 0
        statusMessage = ""

        if isCurrentPlayerAI {
            // Online or vs AI: trigger AI for current player
            triggerAITurn()
        } else {
            statusMessage = "Din tur — kasta tärningarna!"
        }
    }

    private func triggerAITurn() {
        guard isCurrentPlayerAI else { return }
        isAIThinking = true
        let aiName = players.indices.contains(currentPlayerIndex) ? players[currentPlayerIndex].name : "AI"
        statusMessage = "🤖 \(aiName) tänker..."

        // AI does up to 3 rolls
        performAIRoll(rollsLeft: 3)
    }

    private func performAIRoll(rollsLeft: Int) {
        let aiIdx = currentPlayerIndex
        guard rollsLeft > 0, players.indices.contains(aiIdx) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.aiPickCategory() }
            return
        }

        let delay: TimeInterval = rollsLeft == 3 ? 0.55 : 0.70

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.players.indices.contains(aiIdx) else { return }
            let available = self.players[aiIdx].availableCategories

            // Decide which dice to keep (pass remaining rolls after this one)
            let keepMask = aiSelectDiceToKeep(dice: self.dice, available: available, rollsRemaining: rollsLeft - 1)

            self.isRolling = true
            self.rollsUsed = 4 - rollsLeft
            for i in 0..<5 {
                self.heldDice[i] = keepMask[i]
                if !keepMask[i] { self.dice[i] = Int.random(in: 1...6) }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                self.isRolling = false

                // Early stop if we already have an excellent result
                let shouldStop = self.aiShouldStopRolling(dice: self.dice, available: available, rollsLeft: rollsLeft - 1)
                if shouldStop {
                    self.aiPickCategory()
                    return
                }

                self.performAIRoll(rollsLeft: rollsLeft - 1)
            }
        }
    }

    /// Returns true if the AI has a result good enough to stop rerolling early.
    private func aiShouldStopRolling(dice: [Int], available: Set<MultiYatzyCategory>, rollsLeft: Int) -> Bool {
        if rollsLeft == 0 { return true }  // no rolls left anyway
        let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
        let maxCnt = counts.values.max() ?? 0

        // Always stop on Yatzy
        if maxCnt == 5 && available.contains(.yatzy) { return true }
        // Stop on large straight
        if multiYatzyScore(for: .storStege, dice: dice) == 20 && available.contains(.storStege) { return true }
        // Stop on small straight
        if multiYatzyScore(for: .litenStege, dice: dice) == 15 && available.contains(.litenStege) { return true }
        // Stop on full house if Kas available
        if multiYatzyScore(for: .kas, dice: dice) > 0 && available.contains(.kas) { return true }
        // Stop on 4-of-a-kind if Fyrtal available and Yatzy not available
        if maxCnt == 4 && available.contains(.fyrtal) && !available.contains(.yatzy) { return true }

        return false
    }

    private func aiPickCategory() {
        let aiIdx = currentPlayerIndex
        guard players.indices.contains(aiIdx) else { return }
        let available = players[aiIdx].availableCategories
        let aiName = players[aiIdx].name

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let chosen = aiChooseCategory(dice: self.dice, available: available) {
                let score = multiYatzyScore(for: chosen, dice: self.dice)
                self.players[aiIdx].scores[chosen] = score
                self.statusMessage = "🤖 \(aiName) väljer \(chosen.displayName): \(score)p"
            }

            self.isAIThinking = false
            self.heldDice = [false, false, false, false, false]

            // Advance to next turn after short pause
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.advanceTurn()
            }
        }
    }

    private func endGame() {
        guard players.count >= 2 else { return }

        let maxScore = players.map { $0.grandTotal }.max() ?? 0
        let winnerIndices = players.indices.filter { players[$0].grandTotal == maxScore }

        if winnerIndices.count > 1 {
            // Tie involving player 1
            winnerIndex = nil
            isTie = true
            if winnerIndices.contains(0) {
                TimeEngine.shared.addTime(betAmount) // return player 1's bet
            }
        } else {
            let w = winnerIndices[0]
            winnerIndex = w
            isTie = false
            if w == 0 {
                // Player 1 wins: gets their bet back + opponents' bets
                let prize = betAmount * Double(players.count)
                TimeEngine.shared.addTime(prize)
            }
            // If AI/online player wins, player 1's bet is already lost (already deducted)
        }

        withAnimation(.easeInOut(duration: 0.4)) {
            phase = .gameOver
        }
    }

    private func resetToLobby() {
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

        withAnimation(.easeInOut(duration: 0.35)) {
            phase = .lobby
        }
    }
}

// MARK: - Preview

#Preview {
    MultiplayerYatzyView()
        .preferredColorScheme(.dark)
}
