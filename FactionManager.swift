import Foundation
import Combine

struct FactionMission: Codable, Identifiable {
    let id: String
    let title: String
    let targetType: String
    var currentProgress: Int
    let targetValue: Int
    let weekStart: Date
    var isCompleted: Bool { currentProgress >= targetValue }
}

enum FactionRole: String, Codable, CaseIterable, Identifiable {
    case leader
    case officer
    case member

    var id: String { rawValue }
    var label: String {
        switch self {
        case .leader: return "Leader"
        case .officer: return "Officer"
        case .member: return "Member"
        }
    }
}

struct FactionMember: Codable, Identifiable, Equatable {
    let id: String
    var username: String
    var role: FactionRole
    let joinedAt: Date
}

struct FactionLedgerEntry: Codable, Identifiable {
    let id: String
    let actor: String
    let label: String
    let amount: Int
    let createdAt: Date
}

struct Faction: Codable, Identifiable {
    let id: String
    var name: String
    var members: [FactionMember]
    var joinRequests: [String]
    var treasurySeconds: Int
    var weeklyContributions: [String: Int]
    var ledger: [FactionLedgerEntry]
    var activeWarID: String?

    static let maxMembers = 20
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

    @Published private(set) var factions: [Faction] = []
    @Published private(set) var currentFactionID: String? = nil
    @Published private(set) var activeWar: FactionWar? = nil
    @Published private(set) var isOnline: Bool = false
    @Published private(set) var feedbackMessage: String = ""

    var currentFaction: Faction? {
        guard let currentFactionID else { return nil }
        return factions.first(where: { $0.id == currentFactionID })
    }

    var currentMember: FactionMember? {
        guard let faction = currentFaction else { return nil }
        return faction.members.first(where: { usernamesMatch($0.username, GameState.shared.username) })
    }

    var canDistributeFunds: Bool {
        guard let role = currentMember?.role else { return false }
        return role == .leader || role == .officer
    }

    private var syncTimer: AnyCancellable?
    private let storageKey = "factions_v2"
    private let currentFactionKey = "current_faction_id_v2"
    private let pendingPayoutsKey = "faction_pending_payouts_v1"

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

    init() {
        loadCache()
        claimPendingPayoutsIfAny()
        startSyncTimer()
    }

    func currentWeekMission() -> FactionMission {
        let week = Calendar.current.component(.weekOfYear, from: Date.now)
        let template = missionTemplates[week % missionTemplates.count]
        let weekStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date.now)
        ) ?? Calendar.current.startOfDay(for: Date.now)
        return FactionMission(
            id: "mission_week_\(week)",
            title: template.0,
            targetType: template.1,
            currentProgress: 0,
            targetValue: template.2,
            weekStart: weekStart
        )
    }

    func createFaction(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setFeedback("Fraktionsnamn saknas.")
            return
        }
        guard (3...28).contains(trimmed.count) else {
            setFeedback("Fraktionsnamn måste vara 3-28 tecken.")
            return
        }
        guard currentFaction == nil else {
            setFeedback("Du är redan med i en fraktion.")
            return
        }
        guard !factions.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else {
            setFeedback("Det finns redan en fraktion med det namnet.")
            return
        }
        let me = GameState.shared.username
        let newFaction = Faction(
            id: UUID().uuidString,
            name: trimmed,
            members: [
                FactionMember(id: UUID().uuidString, username: me, role: .leader, joinedAt: Date())
            ],
            joinRequests: [],
            treasurySeconds: 0,
            weeklyContributions: [:],
            ledger: [],
            activeWarID: nil
        )
        factions.append(newFaction)
        currentFactionID = newFaction.id
        saveCache()
        setFeedback("Fraktion skapad: \(trimmed)")
    }

    func requestJoin(factionID: String, username: String) {
        guard let idx = factions.firstIndex(where: { $0.id == factionID }) else { return }
        let applicant = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !applicant.isEmpty else {
            setFeedback("Ogiltigt användarnamn.")
            return
        }
        guard currentFaction == nil else {
            setFeedback("Lämna din nuvarande fraktion först.")
            return
        }
        guard factions[idx].members.count < Faction.maxMembers else {
            setFeedback("Fraktionen är full.")
            return
        }
        if factions[idx].joinRequests.contains(where: { usernamesMatch($0, applicant) }) {
            setFeedback("Ansökan finns redan.")
            return
        }
        factions[idx].joinRequests.append(applicant)
        saveCache()
        setFeedback("Ansökan skickad till \(factions[idx].name).")
    }

    func approveJoin(username: String) {
        guard let currentFactionID, canManageMembers,
              let idx = factions.firstIndex(where: { $0.id == currentFactionID }) else { return }
        guard factions[idx].joinRequests.contains(where: { usernamesMatch($0, username) }) else { return }
        guard factions[idx].members.count < Faction.maxMembers else { return }
        if factions.contains(where: { faction in
            faction.id != currentFactionID && faction.members.contains(where: { usernamesMatch($0.username, username) })
        }) {
            factions[idx].joinRequests.removeAll { usernamesMatch($0, username) }
            saveCache()
            setFeedback("\(username) är redan med i en annan fraktion.")
            return
        }
        factions[idx].joinRequests.removeAll { usernamesMatch($0, username) }
        factions[idx].members.append(
            FactionMember(id: UUID().uuidString, username: username, role: .member, joinedAt: Date())
        )
        saveCache()
        setFeedback("\(username) är nu medlem i \(factions[idx].name).")
    }

    func rejectJoin(username: String) {
        guard let currentFactionID, canManageMembers,
              let idx = factions.firstIndex(where: { $0.id == currentFactionID }) else { return }
        factions[idx].joinRequests.removeAll { usernamesMatch($0, username) }
        saveCache()
        setFeedback("Ansökan från \(username) avslogs.")
    }

    func leaveCurrentFaction() {
        guard let currentFactionID,
              let idx = factions.firstIndex(where: { $0.id == currentFactionID }),
              let me = currentMember else { return }

        // Leader cannot leave while others remain; transfer leadership first.
        if me.role == .leader && factions[idx].members.count > 1 {
            setFeedback("Överför ledarrollen innan du lämnar fraktionen.")
            return
        }

        factions[idx].members.removeAll { usernamesMatch($0.username, me.username) }
        if factions[idx].members.isEmpty {
            factions.removeAll { $0.id == currentFactionID }
        } else if me.role == .leader {
            factions[idx].members[0].role = .leader
        }
        self.currentFactionID = nil
        saveCache()
        setFeedback("Du lämnade fraktionen.")
    }

    func setRole(username: String, role: FactionRole) {
        guard let currentFactionID,
              let idx = factions.firstIndex(where: { $0.id == currentFactionID }),
              currentMember?.role == .leader else {
            return
        }
        guard let memberIdx = factions[idx].members.firstIndex(where: { usernamesMatch($0.username, username) }) else { return }
        guard !usernamesMatch(factions[idx].members[memberIdx].username, GameState.shared.username) else { return }
        factions[idx].members[memberIdx].role = role
        saveCache()
        setFeedback("Rollen för \(factions[idx].members[memberIdx].username) uppdaterades till \(role.label).")
    }

    func contribute(seconds: Int, to factionID: String) {
        guard seconds > 0 else { return }
        guard let idx = factions.firstIndex(where: { $0.id == factionID }) else {
            setFeedback("Fraktionen kunde inte hittas.")
            return
        }
        guard factions[idx].members.contains(where: { usernamesMatch($0.username, GameState.shared.username) }) else {
            setFeedback("Du måste vara medlem för att sätta in i fraktionsbanken.")
            return
        }
        guard TimeEngine.shared.deductTime(Double(seconds)) else {
            setFeedback("Otillräcklig balans för insättning.")
            return
        }
        let user = GameState.shared.username
        factions[idx].treasurySeconds += seconds
        factions[idx].weeklyContributions[user, default: 0] += seconds
        factions[idx].ledger.insert(
            FactionLedgerEntry(
                id: UUID().uuidString,
                actor: user,
                label: "Insättning",
                amount: seconds,
                createdAt: Date()
            ),
            at: 0
        )
        TransactionLedger.shared.record(label: "Fraktionsbank — insättning", amount: -Double(seconds))
        saveCache()
        setFeedback("Insättning klar: \(TimeEngine.shortFormatted(Double(seconds))).")
        Task {
            try? await ServerSync.shared.pushFactionContribution(factionID: factionID, seconds: seconds)
        }
    }

    func distribute(seconds: Int, to username: String) {
        guard seconds > 0 else { return }
        let receiver = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !receiver.isEmpty else {
            setFeedback("Ange en mottagare.")
            return
        }
        guard canDistributeFunds else {
            setFeedback("Endast leader/officer kan dela ut tid.")
            return
        }
        guard let currentFactionID,
              let idx = factions.firstIndex(where: { $0.id == currentFactionID }),
              factions[idx].members.contains(where: { usernamesMatch($0.username, receiver) }) else {
            setFeedback("Mottagaren måste vara medlem i fraktionen.")
            return
        }
        guard factions[idx].treasurySeconds >= seconds else {
            setFeedback("Fraktionsbanken saknar tillräcklig tid.")
            return
        }
        factions[idx].treasurySeconds -= seconds
        factions[idx].ledger.insert(
            FactionLedgerEntry(
                id: UUID().uuidString,
                actor: GameState.shared.username,
                label: "Utdelning till \(receiver)",
                amount: -seconds,
                createdAt: Date()
            ),
            at: 0
        )
        if usernamesMatch(receiver, GameState.shared.username) {
            TimeEngine.shared.addTime(Double(seconds))
            TransactionLedger.shared.record(label: "Fraktionsbank — utdelning", amount: Double(seconds))
            setFeedback("Du tog ut \(TimeEngine.shortFormatted(Double(seconds))) från fraktionsbanken.")
        } else {
            enqueuePendingPayout(for: receiver, seconds: seconds)
            setFeedback("Utdelning registrerad till \(receiver).")
        }
        saveCache()
    }

    var canManageMembers: Bool {
        guard let role = currentMember?.role else { return false }
        return role == .leader || role == .officer
    }

    func claimPendingPayoutsIfAny() {
        let username = GameState.shared.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return }
        var pending = loadPendingPayouts()
        guard let amount = pending.removeValue(forKey: normalizedUsername(username)), amount > 0 else {
            return
        }
        TimeEngine.shared.addTime(Double(amount))
        TransactionLedger.shared.record(label: "Fraktionsbank — utdelning mottagen", amount: Double(amount))
        savePendingPayouts(pending)
        setFeedback("Du har mottagit \(TimeEngine.shortFormatted(Double(amount))) från fraktionsbanken.")
    }

    private func usernamesMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalizedUsername(lhs) == normalizedUsername(rhs)
    }

    private func normalizedUsername(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func enqueuePendingPayout(for username: String, seconds: Int) {
        var pending = loadPendingPayouts()
        let key = normalizedUsername(username)
        pending[key, default: 0] += seconds
        savePendingPayouts(pending)
    }

    private func loadPendingPayouts() -> [String: Int] {
        guard let data = UserDefaults.standard.data(forKey: pendingPayoutsKey),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func savePendingPayouts(_ payouts: [String: Int]) {
        if let data = try? JSONEncoder().encode(payouts) {
            UserDefaults.standard.set(data, forKey: pendingPayoutsKey)
        }
    }

    private func setFeedback(_ text: String) {
        feedbackMessage = text
    }

    private func startSyncTimer() {
        syncTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                Task { await self?.syncFromBackend() }
            }
    }

    private func syncFromBackend() async {
        do {
            _ = try await ServerSync.shared.fetchFaction()
            self.isOnline = true
        } catch {
            self.isOnline = false
        }
    }

    private func saveCache() {
        if let data = try? JSONEncoder().encode(factions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        UserDefaults.standard.set(currentFactionID, forKey: currentFactionKey)
    }

    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Faction].self, from: data) {
            factions = decoded
        }
        currentFactionID = UserDefaults.standard.string(forKey: currentFactionKey)
    }
}
