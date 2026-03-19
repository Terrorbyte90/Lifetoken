import Foundation

struct MiniJobStat: Codable {
    var totalPlays: Int = 0
    var wins: Int = 0
    var losses: Int = 0
    var avgCompletionSeconds: Double = 0
    var currentLossStreak: Int = 0
    var consecutiveWinsOnExpert: Int = 0
    var lastPlayedDate: Date = Date()
}

struct CasinoStat: Codable {
    var totalSessions: Int = 0
    var totalSecondsWon: Int = 0
    var totalSecondsLost: Int = 0
    var lastPlayedDate: Date = Date()
}

struct SessionPattern: Codable {
    var date: Date
    var hourOfDay: Int
    var durationSeconds: Int
    var primaryActivity: String
}

enum PlayerArchetype: String, Codable, Equatable {
    case gambler, worker, trader, socialite
}

@MainActor
final class BehaviorTracker: ObservableObject {
    static let shared = BehaviorTracker()

    @Published private(set) var miniJobStats: [String: MiniJobStat] = [:]
    @Published private(set) var casinoStats: [String: CasinoStat] = [:]
    @Published private(set) var sessionPatterns: [SessionPattern] = []
    @Published private(set) var playerArchetype: PlayerArchetype = .worker
    @Published private(set) var lastOpenDate: Date = Date()

    private let filename = "behavior_tracker.json"

    struct TrackerData: Codable {
        var miniJobStats: [String: MiniJobStat]
        var casinoStats: [String: CasinoStat]
        var sessionPatterns: [SessionPattern]
        var playerArchetype: PlayerArchetype
        var lastOpenDate: Date
        var lastArchetypeCalculation: Date
    }

    private var lastArchetypeCalculation: Date = .distantPast

    init() { load() }

    func recordMiniJob(name: String, won: Bool, durationSeconds: Int) {
        var stat = miniJobStats[name, default: MiniJobStat()]
        stat.totalPlays += 1
        if won {
            stat.wins += 1
            stat.currentLossStreak = 0
            stat.consecutiveWinsOnExpert += 1
        } else {
            stat.losses += 1
            stat.currentLossStreak += 1
            stat.consecutiveWinsOnExpert = 0
        }
        let totalDuration = stat.avgCompletionSeconds * Double(stat.totalPlays - 1) + Double(durationSeconds)
        stat.avgCompletionSeconds = totalDuration / Double(stat.totalPlays)
        stat.lastPlayedDate = .now
        miniJobStats[name] = stat
        save()
    }

    func recordCasino(name: String, wonSeconds: Int, lostSeconds: Int) {
        var stat = casinoStats[name, default: CasinoStat()]
        stat.totalSessions += 1
        stat.totalSecondsWon += wonSeconds
        stat.totalSecondsLost += lostSeconds
        stat.lastPlayedDate = .now
        casinoStats[name] = stat
        save()
    }

    func recordSession(hourOfDay: Int, durationSeconds: Int, primaryActivity: String) {
        let pattern = SessionPattern(date: .now, hourOfDay: hourOfDay, durationSeconds: durationSeconds, primaryActivity: primaryActivity)
        sessionPatterns.insert(pattern, at: 0)
        if sessionPatterns.count > 30 { sessionPatterns.removeLast() }
        lastOpenDate = .now
        save()
        recalculateArchetypeIfNeeded()
    }

    func recalculateArchetypeIfNeeded() {
        guard Date.now.timeIntervalSince(lastArchetypeCalculation) > 604800 else { return }
        recalculateArchetype()
    }

    func recalculateArchetype() {
        let recent = sessionPatterns.filter { Date.now.timeIntervalSince($0.date) < 604800 }
        var counts: [String: Int] = [:]
        for s in recent { counts[s.primaryActivity, default: 0] += 1 }
        let dominant = counts.max(by: { $0.value < $1.value })?.key ?? "work"
        switch dominant {
        case "casino": playerArchetype = .gambler
        case "investment": playerArchetype = .trader
        case "social": playerArchetype = .socialite
        default: playerArchetype = .worker
        }
        lastArchetypeCalculation = .now
        save()
    }

    private func save() {
        guard let url = documentsURL else { return }
        let data = TrackerData(
            miniJobStats: miniJobStats,
            casinoStats: casinoStats,
            sessionPatterns: sessionPatterns,
            playerArchetype: playerArchetype,
            lastOpenDate: lastOpenDate,
            lastArchetypeCalculation: lastArchetypeCalculation
        )
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: url)
        }
    }

    private func load() {
        guard let url = documentsURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(TrackerData.self, from: data)
        else { return }
        miniJobStats = decoded.miniJobStats
        casinoStats = decoded.casinoStats
        sessionPatterns = decoded.sessionPatterns
        playerArchetype = decoded.playerArchetype
        lastOpenDate = decoded.lastOpenDate
        lastArchetypeCalculation = decoded.lastArchetypeCalculation
    }

    private var documentsURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent(filename)
    }
}
