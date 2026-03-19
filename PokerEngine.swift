import Foundation

// MARK: - Card Types

enum Suit: String, CaseIterable, Codable {
    case spades   = "♠"
    case hearts   = "♥"
    case diamonds = "♦"
    case clubs    = "♣"
}

enum Rank: Int, CaseIterable, Codable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen = 12, king = 13, ace = 14

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    var display: String {
        switch self {
        case .jack:  return "J"
        case .queen: return "Q"
        case .king:  return "K"
        case .ace:   return "A"
        default:     return "\(rawValue)"
        }
    }
}

struct Card: Identifiable, Codable, Equatable {
    let id: UUID
    let rank: Rank
    let suit: Suit

    init(rank: Rank, suit: Suit) {
        self.id   = UUID()
        self.rank = rank
        self.suit = suit
    }

    var display: String { "\(rank.display)\(suit.rawValue)" }
    var isRed: Bool { suit == .hearts || suit == .diamonds }
}

// MARK: - Hand Evaluation

enum HandRank: Int, Comparable {
    case highCard      = 0
    case onePair       = 1
    case twoPair       = 2
    case threeOfAKind  = 3
    case straight      = 4
    case flush         = 5
    case fullHouse     = 6
    case fourOfAKind   = 7
    case straightFlush = 8
    case royalFlush    = 9

    static func < (lhs: HandRank, rhs: HandRank) -> Bool { lhs.rawValue < rhs.rawValue }

    var name: String {
        switch self {
        case .highCard:      return "Högt Kort"
        case .onePair:       return "Par"
        case .twoPair:       return "Två Par"
        case .threeOfAKind:  return "Triss"
        case .straight:      return "Stege"
        case .flush:         return "Färg"
        case .fullHouse:     return "Kåk"
        case .fourOfAKind:   return "Fyrtal"
        case .straightFlush: return "Stegfärg"
        case .royalFlush:    return "Royal Flush"
        }
    }
}

struct HandResult: Comparable {
    let rank: HandRank
    let tiebreakers: [Int]

    static func < (lhs: HandResult, rhs: HandResult) -> Bool {
        if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
        for (l, r) in zip(lhs.tiebreakers, rhs.tiebreakers) {
            if l != r { return l < r }
        }
        return false
    }

    static func == (lhs: HandResult, rhs: HandResult) -> Bool {
        lhs.rank == rhs.rank && lhs.tiebreakers == rhs.tiebreakers
    }
}

// MARK: - Hand Evaluator

class HandEvaluator {
    /// Evaluate the best 5-card hand from up to 7 cards.
    static func evaluate(cards: [Card]) -> HandResult {
        guard cards.count >= 2 else {
            return HandResult(rank: .highCard, tiebreakers: cards.map { $0.rank.rawValue }.sorted(by: >))
        }
        if cards.count <= 5 { return evalFive(cards) }
        let combos = combinations(of: cards, count: 5)
        guard let best = combos.map({ evalFive($0) }).max() else { return evalFive(cards) }
        return best
    }

    private static func evalFive(_ cards: [Card]) -> HandResult {
        let descRanks   = cards.map { $0.rank.rawValue }.sorted(by: >)
        let ascRanks    = descRanks.reversed() as [Int]
        let suits       = cards.map { $0.suit }
        let rankCounts  = Dictionary(grouping: cards, by: { $0.rank }).mapValues { $0.count }
        let counts      = rankCounts.values.sorted(by: >)
        let isFlush     = Set(suits).count == 1
        let isStraight  = straightCheck(Array(ascRanks))

        // Straight Flush / Royal Flush
        if isFlush && isStraight {
            if descRanks[0] == 14 && descRanks[1] == 13 {
                return HandResult(rank: .royalFlush, tiebreakers: [14])
            }
            return HandResult(rank: .straightFlush, tiebreakers: [descRanks[0]])
        }

        // Four of a Kind
        if counts == [4, 1] {
            let four   = rankCounts.first(where: { $0.value == 4 })?.key.rawValue ?? 0
            let kicker = rankCounts.first(where: { $0.value == 1 })?.key.rawValue ?? 0
            return HandResult(rank: .fourOfAKind, tiebreakers: [four, kicker])
        }

        // Full House
        if counts == [3, 2] {
            let three = rankCounts.first(where: { $0.value == 3 })?.key.rawValue ?? 0
            let pair  = rankCounts.first(where: { $0.value == 2 })?.key.rawValue ?? 0
            return HandResult(rank: .fullHouse, tiebreakers: [three, pair])
        }

        // Flush
        if isFlush { return HandResult(rank: .flush, tiebreakers: descRanks) }

        // Straight
        if isStraight { return HandResult(rank: .straight, tiebreakers: [descRanks[0]]) }

        // Three of a Kind
        if counts == [3, 1, 1] {
            let three   = rankCounts.first(where: { $0.value == 3 })?.key.rawValue ?? 0
            let kickers = rankCounts.filter { $0.value == 1 }.keys.map { $0.rawValue }.sorted(by: >)
            return HandResult(rank: .threeOfAKind, tiebreakers: [three] + kickers)
        }

        // Two Pair
        if counts == [2, 2, 1] {
            let pairs  = rankCounts.filter { $0.value == 2 }.keys.map { $0.rawValue }.sorted(by: >)
            let kicker = rankCounts.first(where: { $0.value == 1 })?.key.rawValue ?? 0
            return HandResult(rank: .twoPair, tiebreakers: pairs + [kicker])
        }

        // One Pair
        if counts == [2, 1, 1, 1] {
            let pair    = rankCounts.first(where: { $0.value == 2 })?.key.rawValue ?? 0
            let kickers = rankCounts.filter { $0.value == 1 }.keys.map { $0.rawValue }.sorted(by: >)
            return HandResult(rank: .onePair, tiebreakers: [pair] + kickers)
        }

        // High Card
        return HandResult(rank: .highCard, tiebreakers: descRanks)
    }

    private static func straightCheck(_ ascRanks: [Int]) -> Bool {
        let unique = Array(Set(ascRanks)).sorted()
        guard unique.count == 5 else { return false }
        // Normal straight
        if unique[4] - unique[0] == 4 { return true }
        // Wheel: A-2-3-4-5
        if unique == [2, 3, 4, 5, 14] { return true }
        return false
    }

    static func combinations<T>(of array: [T], count: Int) -> [[T]] {
        guard count > 0, count <= array.count else { return count == 0 ? [[]] : [] }
        if count == array.count { return [array] }
        var result: [[T]] = []
        for i in 0...(array.count - count) {
            let sub = combinations(of: Array(array[(i + 1)...]), count: count - 1)
            result += sub.map { [array[i]] + $0 }
        }
        return result
    }
}

// MARK: - Deck

class Deck {
    var cards: [Card] = []

    init() { reset() }

    func reset() {
        cards = Suit.allCases.flatMap { suit in
            Rank.allCases.map { Card(rank: $0, suit: suit) }
        }
        cards.shuffle()
    }

    func deal() -> Card? {
        cards.isEmpty ? nil : cards.removeFirst()
    }
}

// MARK: - AI Personality

enum AIPersonality: String {
    case nit           = "Nit"         // Tight-Passive
    case callingStation = "Casual"     // Loose-Passive
    case tag           = "Analytisk"   // Tight-Aggressive
    case lag           = "Aggressiv"   // Loose-Aggressive
    case maniac        = "Galen"       // Ultra-Aggressive
}

// MARK: - AI Action

enum AIAction {
    case fold
    case check
    case call(TimeInterval)
    case raise(TimeInterval)
}

// MARK: - AI Player

struct AIPlayer: Identifiable {
    let id: UUID
    let name: String
    let zone: String
    let personality: AIPersonality
    var stack: TimeInterval
    var holeCards: [Card] = []
    var currentBet: TimeInterval = 0
    var folded: Bool = false
    var isAllIn: Bool = false
    let avatar: String

    init(name: String, zone: String, personality: AIPersonality,
         stack: TimeInterval, avatar: String) {
        self.id          = UUID()
        self.name        = name
        self.zone        = zone
        self.personality = personality
        self.stack       = stack
        self.avatar      = avatar
    }

    // MARK: Personality parameters

    var vpip: Double {
        switch personality {
        case .nit:            return 0.12
        case .callingStation: return 0.55
        case .tag:            return 0.22
        case .lag:            return 0.40
        case .maniac:         return 0.70
        }
    }

    var pfr: Double {
        switch personality {
        case .nit:            return 0.08
        case .callingStation: return 0.05
        case .tag:            return 0.18
        case .lag:            return 0.30
        case .maniac:         return 0.50
        }
    }

    var aggression: Double {
        switch personality {
        case .nit:            return 0.20
        case .callingStation: return 0.15
        case .tag:            return 0.60
        case .lag:            return 0.75
        case .maniac:         return 0.95
        }
    }

    var bluffFrequency: Double {
        switch personality {
        case .nit:            return 0.03
        case .callingStation: return 0.08
        case .tag:            return 0.15
        case .lag:            return 0.25
        case .maniac:         return 0.45
        }
    }

    // MARK: Roster

    static let roster: [AIPlayer] = [
        AIPlayer(name: "Viktor R.",   zone: "Duskline",    personality: .callingStation, stack: 7_200,     avatar: "😐"),
        AIPlayer(name: "Mara D.",     zone: "Midgrey",     personality: .nit,            stack: 28_800,    avatar: "🧐"),
        AIPlayer(name: "Sen L.",      zone: "Midgrey",     personality: .callingStation, stack: 21_600,    avatar: "😶"),
        AIPlayer(name: "ARIA-7",      zone: "Aetherpoint", personality: .tag,            stack: 432_000,   avatar: "🤖"),
        AIPlayer(name: "Cressida V.", zone: "Aetherpoint", personality: .lag,            stack: 360_000,   avatar: "😏"),
        AIPlayer(name: "Kai Dusk",    zone: "Novalux",     personality: .lag,            stack: 1_080_000, avatar: "😎"),
        AIPlayer(name: "Lord Voss",   zone: "Vaultum",     personality: .tag,            stack: 2_160_000, avatar: "🧑‍💼"),
        AIPlayer(name: "Syndra Wei",  zone: "Solara",      personality: .maniac,         stack: 5_400_000, avatar: "👑"),
        AIPlayer(name: "The Warden",  zone: "Solara",      personality: .tag,            stack: 7_200_000, avatar: "⚖️"),
        AIPlayer(name: "Echo",        zone: "Novalux",     personality: .maniac,         stack: 900_000,   avatar: "🎭")
    ]

    // MARK: Decision Making

    mutating func makeDecision(
        toCall: TimeInterval,
        pot: TimeInterval,
        communityCards: [Card],
        round: Int
    ) -> AIAction {
        guard !folded else { return .fold }

        let handStrength = estimateHandStrength(community: communityCards)
        let potOdds      = toCall > 0 ? toCall / (pot + toCall) : 0.0
        let bluffing     = Double.random(in: 0...1) < bluffFrequency

        // Preflop
        if round == 0 {
            let shouldPlay = Double.random(in: 0...1) < vpip || handStrength > 0.70
            if !shouldPlay { return .fold }

            let shouldRaise = Double.random(in: 0...1) < pfr && stack > toCall * 3
            if shouldRaise {
                let raiseSize = TimeInterval.random(in: 2...4) * max(toCall, 100)
                return .raise(min(raiseSize, stack * 0.25))
            }
            if toCall == 0 { return .check }
            if toCall < stack * 0.10 { return .call(min(toCall, stack)) }
            return .fold
        }

        // Post-flop
        let effectiveStrength = bluffing ? Double.random(in: 0.60...0.90) : handStrength

        if effectiveStrength > 0.80 {
            if Double.random(in: 0...1) < aggression {
                let betSize = pot * Double.random(in: 0.6...1.0)
                return .raise(min(betSize, stack))
            }
            if toCall > 0 { return .call(min(toCall, stack)) }
            return .check
        } else if effectiveStrength > 0.55 {
            if toCall == 0 { return .check }
            if potOdds < effectiveStrength { return .call(min(toCall, stack)) }
            return .fold
        } else {
            if toCall == 0 { return .check }
            if bluffing && Double.random(in: 0...1) < 0.40 {
                return .raise(min(pot * 0.75, stack))
            }
            return .fold
        }
    }

    private func estimateHandStrength(community: [Card]) -> Double {
        guard !holeCards.isEmpty else { return 0.5 }

        // Preflop strength (simplified Chen-style)
        if community.isEmpty {
            let r1     = holeCards[0].rank.rawValue
            let r2     = holeCards[1].rank.rawValue
            let hi     = Double(max(r1, r2))
            let lo     = Double(min(r1, r2))
            let suited = holeCards[0].suit == holeCards[1].suit
            let paired = r1 == r2

            var score = hi / 14.0
            if paired  { score += 0.30 }
            if suited  { score += 0.10 }
            if hi - lo <= 2 { score += 0.05 }
            return min(1.0, score)
        }

        // Post-flop: evaluate current made hand
        let allCards = holeCards + community
        let result   = HandEvaluator.evaluate(cards: allCards)
        return Double(result.rank.rawValue) / 9.0
    }
}
