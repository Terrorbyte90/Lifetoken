import Foundation
import SwiftUI
import Combine

class GameState: ObservableObject {
    static let shared = GameState()

    @Published var username: String = ""
    @Published var currentZone: ZoneProfile = .askan
    @Published var loginStreakDays: Int = 0
    @Published var lastLoginDate: Date? = nil
    @Published var totalEarnedAllTime: TimeInterval = 0
    @Published var activeBoosts: [String] = []
    @Published var cheatingWarnings: Int = 0

    @Published var showStreakBonus: Bool = false
    @Published var streakBonusMessage: String = ""
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        currentZone = ZoneManager.shared.currentZone
        loginStreakDays = UserDefaults.standard.integer(forKey: "loginStreak")
        totalEarnedAllTime = UserDefaults.standard.double(forKey: "totalEarned")
        if let d = UserDefaults.standard.object(forKey: "lastLoginDate") as? Date {
            lastLoginDate = d
        }
        ZoneManager.shared.$currentZone
            .receive(on: RunLoop.main)
            .sink { [weak self] zone in
                self?.currentZone = zone
            }
            .store(in: &cancellables)
        checkLoginStreak()
    }

    func checkLoginStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let last = lastLoginDate {
            let lastDay = calendar.startOfDay(for: last)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                // Consecutive day
                loginStreakDays += 1
                awardStreakBonus()
            } else if daysDiff > 1 {
                // Missed days — reset streak
                loginStreakDays = 1
            }
            // Same day: no change
        } else {
            loginStreakDays = 1
        }

        lastLoginDate = Date()
        UserDefaults.standard.set(loginStreakDays, forKey: "loginStreak")
        UserDefaults.standard.set(Date(), forKey: "lastLoginDate")
    }

    private func awardStreakBonus() {
        let bonus: TimeInterval
        switch loginStreakDays {
        case 1:    bonus = 3_600            // 1h  — first return
        case 2:    bonus = 5_400            // 1.5h
        case 3:    bonus = 14_400           // 4h  — milestone
        case 4:    bonus = 7_200            // 2h
        case 5:    bonus = 10_800           // 3h
        case 6:    bonus = 10_800           // 3h
        case 7:    bonus = 43_200           // 12h — 1-week milestone
        case 8...13:  bonus = 18_000        // 5h  — steady weekly
        case 14:   bonus = 172_800          // 2d  — 2-week milestone
        case 15...29: bonus = 28_800        // 8h  — building toward month
        case 30:   bonus = 604_800          // 1 week — 1-month milestone
        case 31...89: bonus = 43_200        // 12h — sustained play
        case 90:   bonus = 2_592_000        // 30d — 3-month milestone
        default:   bonus = loginStreakDays > 90 ? 86_400 : 3_600  // 1d or 1h
        }
        TimeEngine.shared.addTime(bonus)
        streakBonusMessage = "Streak dag \(loginStreakDays): +\(TimeEngine.shortFormatted(bonus))"
        showStreakBonus = true

        if loginStreakDays >= 7 {
            let zoneName = currentZone.name
            Task { @MainActor in
                EventEngine.shared.trigger(.streak7, zoneID: zoneName)
            }
        }
    }

    func recordEarning(_ seconds: TimeInterval) {
        totalEarnedAllTime += seconds
        UserDefaults.standard.set(totalEarnedAllTime, forKey: "totalEarned")
    }

    func updateZone() {
        currentZone = ZoneManager.shared.currentZone
    }
}
