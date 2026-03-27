import SwiftUI
import Foundation

// MARK: - Reputation

@MainActor
final class ZoneReputationManager: ObservableObject {
    static let shared = ZoneReputationManager()

    @Published private(set) var reputationByZone: [String: Int] = [:]   // 0...50
    @Published private(set) var lastReason: String = ""

    private let storageKey = "zone_reputation_v1"
    private let minRep = 0
    private let maxRep = 50
    private let defaultRep = 25

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            reputationByZone = decoded
        }
        // Ensure all zones have a value
        for zone in ZoneProfile.allZones where reputationByZone[zone.name] == nil {
            reputationByZone[zone.name] = defaultRep
        }
        save()
    }

    func reputation(for zoneName: String) -> Int {
        reputationByZone[zoneName] ?? defaultRep
    }

    func adjust(zoneName: String, delta: Int, reason: String) {
        let current = reputation(for: zoneName)
        let updated = max(minRep, min(maxRep, current + delta))
        reputationByZone[zoneName] = updated
        lastReason = reason
        save()
    }

    func adjustForRaid(wonRaid: Bool) {
        let zoneName = GameState.shared.currentZone.name
        if wonRaid {
            adjust(zoneName: zoneName, delta: -2, reason: "Rån i \(zoneName) försämrade ryktet.")
        } else {
            adjust(zoneName: zoneName, delta: -1, reason: "Misslyckat rån gav negativt eko i \(zoneName).")
        }
    }

    func adjustForLoanRepayment(onTime: Bool) {
        let zoneName = GameState.shared.currentZone.name
        if onTime {
            adjust(zoneName: zoneName, delta: 3, reason: "Lån återbetalt i tid ökade ryktet i \(zoneName).")
        } else {
            adjust(zoneName: zoneName, delta: -3, reason: "Försenad betalning sänkte ryktet i \(zoneName).")
        }
    }

    // 0 rep => +20% dyrare, 50 rep => -20% billigare
    func priceMultiplier(for zoneName: String) -> Double {
        let rep = Double(reputation(for: zoneName))
        let normalized = rep / 50.0
        return 1.20 - (0.40 * normalized)
    }

    func npcTone(for zoneName: String) -> String {
        let rep = reputation(for: zoneName)
        if rep >= 40 { return "Vänlig ton" }
        if rep >= 20 { return "Neutral ton" }
        return "Fientlig ton"
    }

    private func save() {
        if let data = try? JSONEncoder().encode(reputationByZone) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Governance

enum GovernanceRuleType: String, CaseIterable, Codable, Identifiable {
    case marketTaxCut
    case marketTaxHike
    case loanAmnesty
    case raidCrackdown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .marketTaxCut: return "Marknadssubvention"
        case .marketTaxHike: return "Marknadsskatt"
        case .loanAmnesty: return "Lånelättnad"
        case .raidCrackdown: return "Rånrestriktion"
        }
    }

    var description: String {
        switch self {
        case .marketTaxCut: return "Alla marknadspriser -10% i 24h."
        case .marketTaxHike: return "Alla marknadspriser +10% i 24h."
        case .loanAmnesty: return "Låneräntor -25% i 24h."
        case .raidCrackdown: return "Max råninsats -25% i 24h."
        }
    }
}

struct GovernanceProposal: Codable, Identifiable {
    let id: String
    let type: GovernanceRuleType
    let createdBy: String
    let createdAt: Date
    let endsAt: Date
    var yesVotes: [String]
    var noVotes: [String]
}

struct ActiveGlobalRule: Codable {
    let type: GovernanceRuleType
    let activatedAt: Date
    let expiresAt: Date
}

@MainActor
final class GovernanceManager: ObservableObject {
    static let shared = GovernanceManager()

    @Published private(set) var activeProposal: GovernanceProposal? = nil
    @Published private(set) var activeRule: ActiveGlobalRule? = nil

    private let proposalKey = "governance_proposal_v1"
    private let ruleKey = "governance_rule_v1"

    private init() {
        load()
        cleanupExpired()
    }

    func canPropose(from zone: ZoneProfile) -> Bool {
        zone.index >= 12
    }

    func propose(rule: GovernanceRuleType, by username: String) -> Bool {
        cleanupExpired()
        guard activeProposal == nil else { return false }
        let proposal = GovernanceProposal(
            id: UUID().uuidString,
            type: rule,
            createdBy: username,
            createdAt: Date(),
            endsAt: Date().addingTimeInterval(6 * 3600),
            yesVotes: [username],
            noVotes: []
        )
        activeProposal = proposal
        save()
        return true
    }

    func vote(yes: Bool, by username: String) {
        guard var proposal = activeProposal, Date() < proposal.endsAt else { return }
        proposal.yesVotes.removeAll { $0 == username }
        proposal.noVotes.removeAll { $0 == username }
        if yes {
            proposal.yesVotes.append(username)
        } else {
            proposal.noVotes.append(username)
        }
        activeProposal = proposal
        resolveIfReady()
        save()
    }

    func marketPriceMultiplier() -> Double {
        guard let rule = activeRule, Date() < rule.expiresAt else { return 1.0 }
        switch rule.type {
        case .marketTaxCut: return 0.90
        case .marketTaxHike: return 1.10
        default: return 1.0
        }
    }

    func loanRateMultiplier() -> Double {
        guard let rule = activeRule, Date() < rule.expiresAt else { return 1.0 }
        switch rule.type {
        case .loanAmnesty: return 0.75
        default: return 1.0
        }
    }

    func raidStakeMultiplier() -> Double {
        guard let rule = activeRule, Date() < rule.expiresAt else { return 1.0 }
        switch rule.type {
        case .raidCrackdown: return 0.75
        default: return 1.0
        }
    }

    func cleanupExpired() {
        if let proposal = activeProposal, Date() >= proposal.endsAt {
            activateRuleIfApproved(from: proposal)
            activeProposal = nil
        }
        if let rule = activeRule, Date() >= rule.expiresAt {
            activeRule = nil
        }
        save()
    }

    private func resolveIfReady() {
        guard let proposal = activeProposal else { return }
        let totalVotes = proposal.yesVotes.count + proposal.noVotes.count
        if totalVotes >= 5 {
            activateRuleIfApproved(from: proposal)
            activeProposal = nil
        }
    }

    private func activateRuleIfApproved(from proposal: GovernanceProposal) {
        if proposal.yesVotes.count > proposal.noVotes.count {
            activeRule = ActiveGlobalRule(
                type: proposal.type,
                activatedAt: Date(),
                expiresAt: Date().addingTimeInterval(24 * 3600)
            )
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: proposalKey),
           let proposal = try? JSONDecoder().decode(GovernanceProposal.self, from: data) {
            activeProposal = proposal
        }
        if let data = UserDefaults.standard.data(forKey: ruleKey),
           let rule = try? JSONDecoder().decode(ActiveGlobalRule.self, from: data) {
            activeRule = rule
        }
    }

    private func save() {
        if let proposal = activeProposal, let data = try? JSONEncoder().encode(proposal) {
            UserDefaults.standard.set(data, forKey: proposalKey)
        } else {
            UserDefaults.standard.removeObject(forKey: proposalKey)
        }
        if let rule = activeRule, let data = try? JSONEncoder().encode(rule) {
            UserDefaults.standard.set(data, forKey: ruleKey)
        } else {
            UserDefaults.standard.removeObject(forKey: ruleKey)
        }
    }
}

// MARK: - Garden

struct GardenCropType: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let growthSeconds: TimeInterval
    let rewardSeconds: TimeInterval
    let minZoneIndex: Int

    static let all: [GardenCropType] = [
        .init(id: "moss_fruit", name: "Mossfrukt", growthSeconds: 2 * 3600, rewardSeconds: 1800, minZoneIndex: 8),
        .init(id: "aether_root", name: "Aetherrot", growthSeconds: 6 * 3600, rewardSeconds: 7200, minZoneIndex: 10),
        .init(id: "solara_bloom", name: "Solarablom", growthSeconds: 12 * 3600, rewardSeconds: 21600, minZoneIndex: 12)
    ]
}

struct GardenPlot: Identifiable, Codable {
    let id: String
    var cropID: String?
    var plantedAt: Date?

    var isEmpty: Bool { cropID == nil || plantedAt == nil }
}

@MainActor
final class GardenManager: ObservableObject {
    static let shared = GardenManager()

    @Published private(set) var plots: [GardenPlot] = [
        .init(id: "plot_1", cropID: nil, plantedAt: nil),
        .init(id: "plot_2", cropID: nil, plantedAt: nil),
        .init(id: "plot_3", cropID: nil, plantedAt: nil)
    ]

    private let storageKey = "garden_plots_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([GardenPlot].self, from: data),
           !decoded.isEmpty {
            plots = decoded
        }
    }

    func isUnlocked(for zone: ZoneProfile) -> Bool {
        zone.index >= 8
    }

    func plant(crop: GardenCropType, plotID: String) -> Bool {
        guard let idx = plots.firstIndex(where: { $0.id == plotID }), plots[idx].isEmpty else { return false }
        plots[idx].cropID = crop.id
        plots[idx].plantedAt = Date()
        save()
        return true
    }

    func canHarvest(plot: GardenPlot) -> Bool {
        guard let crop = crop(for: plot),
              let plantedAt = plot.plantedAt else { return false }
        return Date().timeIntervalSince(plantedAt) >= crop.growthSeconds
    }

    func harvest(plotID: String) -> TimeInterval {
        guard let idx = plots.firstIndex(where: { $0.id == plotID }),
              let crop = crop(for: plots[idx]),
              canHarvest(plot: plots[idx]) else {
            return 0
        }
        let reward = crop.rewardSeconds
        TimeEngine.shared.addTime(reward)
        plots[idx].cropID = nil
        plots[idx].plantedAt = nil
        save()
        return reward
    }

    func crop(for plot: GardenPlot) -> GardenCropType? {
        guard let id = plot.cropID else { return nil }
        return GardenCropType.all.first(where: { $0.id == id })
    }

    private func save() {
        if let data = try? JSONEncoder().encode(plots) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
