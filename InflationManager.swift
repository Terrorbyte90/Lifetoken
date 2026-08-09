import Foundation
import Combine

class InflationManager: ObservableObject {
    static let shared = InflationManager()

    @Published var currentMultiplier: Double = 1.0

    private let dateEnteredKey = "inflation_zone_entry_date"
    private let zoneNameKey = "inflation_zone_name"
    private var timer: Timer?

    private init() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    func recordZoneEntry(_ zone: ZoneProfile) {
        UserDefaults.standard.set(Date(), forKey: dateEnteredKey)
        UserDefaults.standard.set(zone.name, forKey: zoneNameKey)
        currentMultiplier = 1.0
    }

    func update() {
        let zone = GameState.shared.currentZone
        guard let entryDate = UserDefaults.standard.object(forKey: dateEnteredKey) as? Date else {
            currentMultiplier = 1.0
            return
        }
        let savedZone = UserDefaults.standard.string(forKey: zoneNameKey) ?? ""
        if savedZone != zone.name {
            recordZoneEntry(zone)
            return
        }
        let days = Date().timeIntervalSince(entryDate) / 86400
        currentMultiplier = pow(1 + zone.inflationRatePerDay, days)
    }

    /// Cost multiplied by inflation
    func inflatedCost(_ base: TimeInterval) -> TimeInterval {
        return base * currentMultiplier
    }

    /// Earnings reduced by inflation (jobs get less valuable)
    func deflatedEarnings(_ base: TimeInterval) -> TimeInterval {
        return base / currentMultiplier
    }

    var isWarning: Bool { currentMultiplier > 1.10 }
    var isCritical: Bool { currentMultiplier > 1.30 }

    /// Daily inflation cost in seconds for UI display
    var dailyInflationCostSeconds: TimeInterval {
        let baseDaily: TimeInterval = 86400 // 1 day drain
        return baseDaily * (currentMultiplier - 1.0)
    }

    /// Estimated days until inflation makes zone unsustainable
    var daysUntilUnsustainable: Int {
        let zone = GameState.shared.currentZone
        let rate = zone.inflationRatePerDay
        guard rate > 0 else { return 999 }
        // At rate r per day, costs double every ln(2)/ln(1+r) days
        let doublingDays = log(2.0) / log(1.0 + rate)
        return Int(doublingDays)
    }

    var percentageString: String { String(format: "+%.1f%%", (currentMultiplier - 1) * 100) }
}
