import Foundation
import SwiftUI

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

    private init() {
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        loginStreakDays = UserDefaults.standard.integer(forKey: "loginStreak")
        totalEarnedAllTime = UserDefaults.standard.double(forKey: "totalEarned")
        if let d = UserDefaults.standard.object(forKey: "lastLoginDate") as? Date {
            lastLoginDate = d
        }
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
        case 1:   bonus = 3600          // 1h
        case 3:   bonus = 14400         // 4h
        case 7:   bonus = 43200         // 12h
        case 14:  bonus = 172800        // 2 days
        case 30:  bonus = 604800        // 1 week
        case 90:  bonus = 2592000       // 30 days
        default:  bonus = loginStreakDays > 90 ? 86400 : 1800  // 1d or 30m
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
        currentZone = ZoneProfile.currentZone(forTime: TimeEngine.shared.balance)
    }
}
