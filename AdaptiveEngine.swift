import Foundation

@MainActor
final class AdaptiveEngine: ObservableObject {
    static let shared = AdaptiveEngine(tracker: BehaviorTracker.shared)

    private let tracker: BehaviorTracker

    init(tracker: BehaviorTracker) {
        self.tracker = tracker
    }

    // MARK: - Mini-job rules
    func shouldRecommendEasy(for game: String) -> Bool {
        (tracker.miniJobStats[game]?.currentLossStreak ?? 0) >= 3
    }

    func legendeUnlocked(for game: String) -> Bool {
        (tracker.miniJobStats[game]?.consecutiveWinsOnExpert ?? 0) >= 5
    }

    func recommendationMessage(for game: String) -> String? {
        if shouldRecommendEasy(for: game) { return "Systemet justerar sig" }
        if legendeUnlocked(for: game) { return "Legendenivå upplåst" }
        return nil
    }

    // MARK: - Job queue rules
    func isNightShiftHour(_ hour: Int) -> Bool {
        hour == 22 || hour == 23
    }

    func currentHour() -> Int {
        Calendar.current.component(.hour, from: Date.now)
    }

    func shouldMarkJobsUrgent(lastOpen: Date) -> Bool {
        Date.now.timeIntervalSince(lastOpen) > 172800 // 48h
    }

    // MARK: - Rescue mechanic
    func shouldOfferRescue(balance: Double, lastOpen: Date) -> Bool {
        guard balance < 7200 else { return false }
        guard Date.now.timeIntervalSince(lastOpen) > 172800 else { return false }
        if let lastBoost = UserDefaults.standard.object(forKey: "lastRescueBoostDate") as? Date {
            return Date.now.timeIntervalSince(lastBoost) > 604800
        }
        return true
    }

    func applyRescueBoost() {
        TimeEngine.shared.addTime(1800)
        UserDefaults.standard.set(Date.now, forKey: "lastRescueBoostDate")
    }

    func scheduleRescueNotificationIfNeeded() {
        let balance = TimeEngine.shared.balance
        let lastOpen = BehaviorTracker.shared.lastOpenDate
        guard shouldOfferRescue(balance: balance, lastOpen: lastOpen) else { return }
        NotificationManager.shared.scheduleRescueNotification()
    }
}
