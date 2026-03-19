import Foundation
import Combine

enum LifetokenTrigger: String {
    case firstCasinoWin
    case zoneUpgrade
    case firstDeath
    case streak7
    case pvpWin
    case investmentLarge // >10h
    case factionWarWon

    var isOneTime: Bool {
        switch self {
        case .firstCasinoWin, .firstDeath, .streak7: return true
        default: return false
        }
    }

    var dailyCooldown: Bool {
        self == .pvpWin
    }

    var weeklyCooldown: Bool {
        self == .investmentLarge
    }
}

struct GameEvent: PlayerEvent {
    let eventID: String
    let occurredAt: Date
    let zoneID: ZoneID
    let isOneTime: Bool
    let headlineTemplate: String
    let category: EventCategory
}

@MainActor
final class EventEngine: ObservableObject {
    static let shared = EventEngine()

    var onEvent: ((GameEvent) -> Void)?
    @Published private(set) var recentEvents: [GameEvent] = []

    func trigger(_ trigger: LifetokenTrigger, zoneID: ZoneID) {
        let key = "eventFired_\(trigger.rawValue)"
        let dailyKey = "eventLastFired_daily_\(trigger.rawValue)"
        let weeklyKey = "eventLastFired_weekly_\(trigger.rawValue)"

        // One-time check
        if trigger.isOneTime && UserDefaults.standard.bool(forKey: key) { return }

        // Daily cooldown check
        if trigger.dailyCooldown, let last = UserDefaults.standard.object(forKey: dailyKey) as? Date {
            if Calendar.current.isDateInToday(last) { return }
        }

        // Weekly cooldown check
        if trigger.weeklyCooldown, let last = UserDefaults.standard.object(forKey: weeklyKey) as? Date {
            if Date.now.timeIntervalSince(last) < 604800 { return } // 7 days
        }

        let event = GameEvent(
            eventID: trigger.rawValue,
            occurredAt: .now,
            zoneID: zoneID,
            isOneTime: trigger.isOneTime,
            headlineTemplate: headlineFor(trigger),
            category: categoryFor(trigger)
        )

        // Persist
        if trigger.isOneTime { UserDefaults.standard.set(true, forKey: key) }
        if trigger.dailyCooldown { UserDefaults.standard.set(Date.now, forKey: dailyKey) }
        if trigger.weeklyCooldown { UserDefaults.standard.set(Date.now, forKey: weeklyKey) }

        recentEvents.insert(event, at: 0)
        if recentEvents.count > 50 { recentEvents.removeLast() }
        onEvent?(event)
    }

    private func headlineFor(_ trigger: LifetokenTrigger) -> String {
        let name = GameState.shared.username.isEmpty ? "En okänd spelare" : GameState.shared.username
        switch trigger {
        case .firstCasinoWin: return "\(name) vann stort i sin zons spelkvartar"
        case .zoneUpgrade: return "\(name) steg till en ny zon"
        case .firstDeath: return "\(name) återuppstod från noll"
        case .streak7: return "\(name) har inte missat en dag på sju"
        case .pvpWin: return "\(name) besegrade en motståndare"
        case .investmentLarge: return "\(name):s portfölj översteg tio timmar"
        case .factionWarWon: return "\(name):s fraktion dominerade veckans krig"
        }
    }

    private func categoryFor(_ trigger: LifetokenTrigger) -> EventCategory {
        switch trigger {
        case .firstCasinoWin: return .casinoWin
        case .zoneUpgrade: return .zoneUpgrade
        case .firstDeath: return .death
        case .streak7: return .streak
        case .pvpWin: return .pvpWin
        case .investmentLarge: return .investment
        case .factionWarWon: return .factionWar
        }
    }
}
