import Foundation

// MARK: - AI Strategy (Advanced, non-cheating)

struct YatzyAILogic {

    // MARK: Category Rarity

    /// Category rarity score (higher = harder to achieve = strategically expensive to scratch)
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

    /// Chooses the best available category for the current dice.
    /// AI only uses visible dice and legal options (no hidden information).
    static func chooseCategory(dice: [Int], available: Set<MultiYatzyCategory>) -> MultiYatzyCategory? {
        guard !available.isEmpty else { return nil }

        let ranked = rankedCategories(dice: dice, available: available)
        if let best = ranked.first {
            if best.rawScore > 0 {
                return best.category
            }
            return scratchCategory(available: available)
        }
        return available.first
    }

    // MARK: Select Dice to Keep

    /// Picks hold-mask by exact expected-value search (non-cheating).
    /// rollsRemaining: roll decisions left including this one.
    static func selectDiceToKeep(
        dice: [Int],
        available: Set<MultiYatzyCategory>,
        rollsRemaining: Int = 1
    ) -> [Bool] {
        guard dice.count == 5 else { return [Bool](repeating: false, count: 5) }
        guard rollsRemaining > 0 else { return [Bool](repeating: true, count: 5) }
        guard !available.isEmpty else { return [Bool](repeating: true, count: 5) }

        let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
        let maxCount = counts.values.max() ?? 0
        if maxCount == 5 { return [Bool](repeating: true, count: 5) } // already Yatzy

        var memo: [RollStateKey: Double] = [:]
        let (bestMask, _) = bestMaskAndExpectedValue(
            dice: dice,
            available: available,
            rollsRemaining: rollsRemaining,
            memo: &memo
        )
        return bestMask
    }

    // MARK: Should Stop Rolling

    /// Returns true if the hand is strategically strong enough to bank now.
    static func shouldStopRolling(dice: [Int], available: Set<MultiYatzyCategory>, rollsLeft: Int) -> Bool {
        if rollsLeft == 0 { return true }
        guard !available.isEmpty else { return true }

        let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
        let maxCnt = counts.values.max() ?? 0

        if maxCnt == 5 && available.contains(.yatzy) { return true }
        if multiYatzyScore(for: .storStege, dice: dice) == 20 && available.contains(.storStege) { return true }
        if multiYatzyScore(for: .litenStege, dice: dice) == 15 && available.contains(.litenStege) { return true }
        if multiYatzyScore(for: .kas, dice: dice) > 0 && available.contains(.kas) { return true }

        // Stop only when no meaningful EV gain remains, or best play is to keep all dice.
        let currentBest = bestStrategicBoardValue(dice: dice, available: available)
        var memo: [RollStateKey: Double] = [:]
        let (bestMask, bestFutureValue) = bestMaskAndExpectedValue(
            dice: dice,
            available: available,
            rollsRemaining: rollsLeft,
            memo: &memo
        )
        let noGain = bestFutureValue <= currentBest + 0.01
        let keepAll = bestMask.allSatisfy { $0 }
        return keepAll || noGain
    }
}

// MARK: - Internals

private extension YatzyAILogic {
    struct RollStateKey: Hashable {
        let rollsRemaining: Int
        let dice: [Int]

        init(dice: [Int], rollsRemaining: Int) {
            self.rollsRemaining = rollsRemaining
            self.dice = dice.sorted()
        }
    }

    struct RankedCategory {
        let category: MultiYatzyCategory
        let rawScore: Int
        let strategicScore: Double
    }

    static func rankedCategories(
        dice: [Int],
        available: Set<MultiYatzyCategory>
    ) -> [RankedCategory] {
        let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
        let maxCount = counts.values.max() ?? 0
        let unique = Set(dice)

        return available.map { cat in
            let raw = multiYatzyScore(for: cat, dice: dice)
            var value = Double(raw)

            // Immediate score pressure
            value += Double(raw) * 1.25
            value += Double(categoryRarity(cat)) * (raw > 0 ? 0.30 : -0.20)

            // Normalize by category ceiling to avoid overvaluing cheap points
            value += (Double(raw) / Double(max(1, cat.maximumScore))) * 16

            if cat.isUpperSection, let face = cat.upperFaceValue {
                let cnt = counts[face] ?? 0
                value += Double(cnt * face) * 1.1
                if cnt <= 1 { value -= 6 }
                if cnt >= 4 { value += 8 }
            }

            // Do not waste a potential Yatzy hand on upper section too early.
            if cat.isUpperSection && maxCount >= 4 && available.contains(.yatzy) {
                value -= 40
            }

            // Combo-specific boosts
            if cat == .yatzy && raw == 50 { value += 120 }
            if cat == .storStege && raw == 20 { value += 40 }
            if cat == .litenStege && raw == 15 { value += 28 }
            if cat == .kas && raw > 0 { value += 22 }
            if cat == .fyrtal && raw >= 20 { value += 16 }
            if cat == .chans {
                if raw >= 23 { value += 12 } else if raw <= 17 { value -= 4 }
            }

            // "Near miss" potential keeps options alive, but not as much as real points.
            if raw == 0 {
                switch cat {
                case .yatzy where maxCount == 4: value += 18
                case .yatzy where maxCount == 3: value += 9
                case .storStege where unique.intersection([2,3,4,5,6]).count == 4: value += 9
                case .litenStege where unique.intersection([1,2,3,4,5]).count == 4: value += 8
                case .kas where counts.values.contains(3) && counts.values.contains(1): value += 7
                default: break
                }
            }

            return RankedCategory(category: cat, rawScore: raw, strategicScore: value)
        }
        .sorted { lhs, rhs in
            if lhs.strategicScore == rhs.strategicScore { return lhs.rawScore > rhs.rawScore }
            return lhs.strategicScore > rhs.strategicScore
        }
    }

    static func scratchCategory(available: Set<MultiYatzyCategory>) -> MultiYatzyCategory {
        let scratchOrder: [MultiYatzyCategory] = [
            .ettor, .tvaor, .treor, .fyror,
            .par,
            .femmor, .sexor,
            .tvaPar, .triss, .chans,
            .kas, .fyrtal,
            .litenStege, .storStege, .yatzy
        ]
        return scratchOrder.first(where: { available.contains($0) }) ?? (available.first ?? .ettor)
    }

    static func bestStrategicBoardValue(dice: [Int], available: Set<MultiYatzyCategory>) -> Double {
        rankedCategories(dice: dice, available: available).first?.strategicScore ?? 0
    }

    static func bestMaskAndExpectedValue(
        dice: [Int],
        available: Set<MultiYatzyCategory>,
        rollsRemaining: Int,
        memo: inout [RollStateKey: Double]
    ) -> ([Bool], Double) {
        var bestMask = heuristicKeepMask(dice: dice, available: available, rollsRemaining: rollsRemaining)
        var bestValue = -Double.greatestFiniteMagnitude

        for bits in 0..<32 {
            let mask = decodeMask(bits, count: 5)
            let value = exactExpectedValueAfterMask(
                keepMask: mask,
                dice: dice,
                available: available,
                rollsRemaining: rollsRemaining,
                memo: &memo
            )
            if value > bestValue {
                bestValue = value
                bestMask = mask
            }
        }

        return (bestMask, bestValue)
    }

    static func exactBestExpectedValue(
        dice: [Int],
        available: Set<MultiYatzyCategory>,
        rollsRemaining: Int,
        memo: inout [RollStateKey: Double]
    ) -> Double {
        guard rollsRemaining > 0 else {
            return bestStrategicBoardValue(dice: dice, available: available)
        }

        let key = RollStateKey(dice: dice, rollsRemaining: rollsRemaining)
        if let cached = memo[key] { return cached }

        let (_, value) = bestMaskAndExpectedValue(
            dice: dice,
            available: available,
            rollsRemaining: rollsRemaining,
            memo: &memo
        )
        memo[key] = value
        return value
    }

    static func exactExpectedValueAfterMask(
        keepMask: [Bool],
        dice: [Int],
        available: Set<MultiYatzyCategory>,
        rollsRemaining: Int,
        memo: inout [RollStateKey: Double]
    ) -> Double {
        guard rollsRemaining > 0 else {
            return bestStrategicBoardValue(dice: dice, available: available)
        }

        let rerollIndices = keepMask.enumerated().compactMap { index, keep in
            keep ? nil : index
        }
        if rerollIndices.isEmpty {
            return exactBestExpectedValue(
                dice: dice,
                available: available,
                rollsRemaining: rollsRemaining - 1,
                memo: &memo
            )
        }

        var workingDice = dice
        var total = 0.0

        func enumerateOutcomes(depth: Int) {
            if depth == rerollIndices.count {
                total += exactBestExpectedValue(
                    dice: workingDice,
                    available: available,
                    rollsRemaining: rollsRemaining - 1,
                    memo: &memo
                )
                return
            }

            let idx = rerollIndices[depth]
            for face in 1...6 {
                workingDice[idx] = face
                enumerateOutcomes(depth: depth + 1)
            }
            workingDice[idx] = dice[idx]
        }

        enumerateOutcomes(depth: 0)
        let outcomeCount = powInt(6, rerollIndices.count)
        return total / Double(max(1, outcomeCount))
    }

    static func decodeMask(_ bits: Int, count: Int) -> [Bool] {
        (0..<count).map { ((bits >> $0) & 1) == 1 }
    }

    static func powInt(_ base: Int, _ exponent: Int) -> Int {
        guard exponent > 0 else { return 1 }
        var result = 1
        for _ in 0..<exponent {
            result *= base
        }
        return result
    }

    // Previous deterministic strategy retained as fallback policy for rollouts.
    static func heuristicKeepMask(
        dice: [Int],
        available: Set<MultiYatzyCategory>,
        rollsRemaining: Int
    ) -> [Bool] {
        let counts = Dictionary(grouping: dice, by: { $0 }).mapValues { $0.count }
        let maxCount = counts.values.max() ?? 0
        let uniqueVals = Set(dice)

        if maxCount == 5 { return [Bool](repeating: true, count: 5) }

        if maxCount == 4, let quadVal = counts.first(where: { $0.value == 4 })?.key {
            return dice.map { $0 == quadVal }
        }

        let triples = counts.filter { $0.value >= 3 }.keys.sorted(by: >)
        let pairs = counts.filter { $0.value >= 2 }.keys.sorted(by: >)

        if triples.first != nil, pairs.count >= 2, available.contains(.kas) {
            return [Bool](repeating: true, count: 5)
        }

        let large = Set([2, 3, 4, 5, 6])
        let small = Set([1, 2, 3, 4, 5])
        let inLarge = uniqueVals.intersection(large)
        let inSmall = uniqueVals.intersection(small)

        if inLarge.count == 5, available.contains(.storStege) { return [Bool](repeating: true, count: 5) }
        if inSmall.count == 5, available.contains(.litenStege) { return [Bool](repeating: true, count: 5) }

        if inLarge.count == 4, available.contains(.storStege) {
            return dice.map { inLarge.contains($0) && large.contains($0) }
        }
        if inSmall.count == 4, available.contains(.litenStege) {
            return dice.map { inSmall.contains($0) && small.contains($0) }
        }

        if let triple = triples.first {
            if pairs.count >= 2 { return [Bool](repeating: true, count: 5) }
            return dice.map { $0 == triple }
        }

        if pairs.count >= 2 {
            let keepPairs = Set(pairs.prefix(2))
            return dice.map { keepPairs.contains($0) }
        }

        if let topPair = pairs.first {
            return dice.map { $0 == topPair }
        }

        if inLarge.count == 3, available.contains(.storStege), rollsRemaining >= 2 {
            return dice.map { large.contains($0) }
        }
        if inSmall.count == 3, available.contains(.litenStege), rollsRemaining >= 2 {
            return dice.map { small.contains($0) }
        }

        let upperAvailable = MultiYatzyCategory.allCases.filter { $0.isUpperSection && available.contains($0) }
        if !upperAvailable.isEmpty {
            let bestUpper = upperAvailable.max { c1, c2 in
                let v1 = c1.upperFaceValue ?? 0
                let v2 = c2.upperFaceValue ?? 0
                let cnt1 = counts[v1] ?? 0
                let cnt2 = counts[v2] ?? 0
                if cnt1 != cnt2 { return cnt1 < cnt2 }
                return v1 < v2
            }
            if let cat = bestUpper, let faceVal = cat.upperFaceValue {
                let cnt = counts[faceVal] ?? 0
                if cnt >= 2 { return dice.map { $0 == faceVal } }
            }
        }

        let top2 = Set(dice.sorted(by: >).prefix(2))
        return dice.map { top2.contains($0) }
    }
}
