import Foundation
import Combine

// MARK: - Faction Mission

struct FactionMission: Codable, Identifiable {
    let id: String
    let title: String
    let targetType: String
    var currentProgress: Int
    let targetValue: Int
    let weekStart: Date
    var isCompleted: Bool { currentProgress >= targetValue }
}

struct Faction: Codable, Identifiable {
    let id: String
    var name: String
    var memberIDs: [String]
    var treasurySeconds: Int
    var weeklyContributions: [String: Int]
    var activeWarID: String?

    static let maxMembers = 5
}

struct FactionWar: Codable, Identifiable {
    let id: String
    let faction1ID: String
    let faction2ID: String
    let startDate: Date
    let endDate: Date
    var scores: [String: Int]
    var isResolved: Bool
}

@MainActor
final class FactionManager: ObservableObject {
    static let shared = FactionManager()

    @Published private(set) var currentFaction: Faction? = nil
    @Published private(set) var activeWar: FactionWar? = nil
    @Published private(set) var isOnline: Bool = false

    private var syncTimer: AnyCancellable?

    init() {
        loadCached()
        startSyncTimer()
    }

    private let missionTemplates: [(String, String, Int)] = [
        ("Stegjägare", "steps", 500_000),
        ("Kasinokollektiv", "casinoWins", 50),
        ("Yrkesmässigt", "jobs", 100),
        ("Massiva steg", "steps", 1_000_000),
        ("Spelveckan", "casinoWins", 100),
        ("Arbetslaget", "jobs", 200),
        ("Snabbfötterna", "steps", 250_000),
        ("Lyckodragarna", "casinoWins", 25),
        ("Skiftarbetarna", "jobs", 50),
        ("Ultralöparna", "steps", 2_000_000),
    ]

    func currentWeekMission() -> FactionMission {
        let week = Calendar.current.component(.weekOfYear, from: Date.now)
        let template = missionTemplates[week % missionTemplates.count]
        let weekStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date.now)
        ) ?? Calendar.current.startOfDay(for: Date.now)
        return FactionMission(id: "mission_week_\(week)", title: template.0, targetType: template.1, currentProgress: 0, targetValue: template.2, weekStart: weekStart)
    }

    func canJoin(faction: Faction) -> Bool {
        faction.memberIDs.count < Faction.maxMembers
    }

    func contribute(seconds: Int, to factionID: String) {
        guard TimeEngine.shared.deductTime(Double(seconds)) else { return }
        currentFaction?.treasurySeconds += seconds
        currentFaction?.weeklyContributions[GameState.shared.username, default: 0] += seconds
        saveCache()
        Task {
            try? await ServerSync.shared.pushFactionContribution(factionID: factionID, seconds: seconds)
        }
    }

    private func startSyncTimer() {
        syncTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                Task { await self?.syncFromBackend() }
            }
    }

    private func syncFromBackend() async {
        do {
            if let faction = try await ServerSync.shared.fetchFaction() {
                self.currentFaction = faction
                self.isOnline = true
                self.saveCache()
            }
        } catch {
            self.isOnline = false
        }
    }

    private func saveCache() {
        if let data = try? JSONEncoder().encode(currentFaction) {
            UserDefaults.standard.set(data, forKey: "cachedFaction")
        }
    }

    private func loadCached() {
        if let data = UserDefaults.standard.data(forKey: "cachedFaction"),
           let faction = try? JSONDecoder().decode(Faction.self, from: data) {
            currentFaction = faction
        }
    }
}
