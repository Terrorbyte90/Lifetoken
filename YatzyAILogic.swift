import Foundation

// MARK: - AI Strategy (Probability-based expert system)

struct YatzyAILogic {

    // MARK: Category Rarity

    /// Category rarity score (higher = harder to achieve = more valuable)
    static func categoryRarity(_ cat: MultiYatzyCategory) -> Int {
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

    // MARK: Choose Category

    /// Choose the best category to score. Uses score + strategic weighting.
    /// Never wastes high-value combos on low-value categories.
    static func chooseCategory(dice: [Int], available: Set<MultiYatzyCategory>) -> MultiYatzyCategory? {
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
                sv += Double(categoryRarity(cat)) * 0.4
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

    // MARK: Select Dice to Keep

    /// Decide which dice to keep. Uses probability-aware heuristics.
    /// rollsRemaining: how many rerolls the AI still has after this keep decision.
    static func selectDiceToKeep(dice: [Int], available: Set<MultiYatzyCategory>, rollsRemaining: Int = 1) -> [Bool] {
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
        let triples = counts.filter { $0.value >= 3 }.keys.sorted(by: >)
        let pairs   = counts.filter { $0.value >= 2 }.keys.sorted(by: >)

        if let _ = triples.first, pairs.count >= 2, available.contains(.kas) {
            // Already have full house — keep all 5
            return [Bool](repeating: true, count: 5)
        }

        // --- Straight potential: keep straight dice ---
        let storSetVals  = Set([2, 3, 4, 5, 6])
        let litenSetVals = Set([1, 2, 3, 4, 5])
        let inStor  = uniqueVals.intersection(storSetVals)
        let inLiten = uniqueVals.intersection(litenSetVals)

        // Complete straight: keep all
        if inStor.count == 5  && available.contains(.storStege)  { return [Bool](repeating: true, count: 5) }
        if inLiten.count == 5 && available.contains(.litenStege) { return [Bool](repeating: true, count: 5) }

        // 4 values of a straight — worth chasing on 1+ rerolls
        if inStor.count == 4 && available.contains(.storStege) {
            return dice.map { storSetVals.contains($0) && inStor.contains($0) }
        }
        if inLiten.count == 4 && available.contains(.litenStege) {
            return dice.map { litenSetVals.contains($0) && inLiten.contains($0) }
        }

        // 3-of-a-kind: keep them (chase 4-of-a-kind or full house)
        if let triple = triples.first {
            // If we also have a pair, keep all 5 (full house)
            if pairs.count >= 2 { return [Bool](repeating: true, count: 5) }
            return dice.map { $0 == triple }
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

    // MARK: Should Stop Rolling

    /// Returns true if the AI has a result good enough to stop rerolling early.
    static func shouldStopRolling(dice: [Int], available: Set<MultiYatzyCategory>, rollsLeft: Int) -> Bool {
        if rollsLeft == 0 { return true }
        let counts  = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
        let maxCnt  = counts.values.max() ?? 0

        // Always stop on Yatzy
        if maxCnt == 5 && available.contains(.yatzy) { return true }
        // Stop on large straight
        if multiYatzyScore(for: .storStege,  dice: dice) == 20 && available.contains(.storStege)  { return true }
        // Stop on small straight
        if multiYatzyScore(for: .litenStege, dice: dice) == 15 && available.contains(.litenStege) { return true }
        // Stop on full house if Kas available
        if multiYatzyScore(for: .kas, dice: dice) > 0 && available.contains(.kas) { return true }
        // Stop on 4-of-a-kind if Fyrtal available and Yatzy not available
        if maxCnt == 4 && available.contains(.fyrtal) && !available.contains(.yatzy) { return true }

        return false
    }
}
