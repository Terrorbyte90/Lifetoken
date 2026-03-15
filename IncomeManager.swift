import Foundation
import SwiftUI

struct HealthIncomeBreakdown {
    var stepsSeconds: TimeInterval = 0      // 7 steps = 1s, max 10k steps
    var caloriesSeconds: TimeInterval = 0   // 1 kcal = 0.06s, max 600kcal -> 36s
    var exerciseSeconds: TimeInterval = 0   // 1 min = 2s, max 60 min -> 120s
    var sleepSeconds: TimeInterval = 0      // 7-9h = 1800s, 6-7h = 600s
    var standSeconds: TimeInterval = 0      // each stood hour = 30s, max 360s
    var mindfulSeconds: TimeInterval = 0    // each minute = 6s, max 20 min -> 120s
    var hrvBonus: TimeInterval = 0          // HRV > 50ms -> +300s

    var total: TimeInterval { stepsSeconds + caloriesSeconds + exerciseSeconds + sleepSeconds + standSeconds + mindfulSeconds + hrvBonus }
}

class IncomeManager: ObservableObject {
    static let shared = IncomeManager()

    @Published var todayBreakdown = HealthIncomeBreakdown()
    @Published var dailySteps: Int = 0
    @Published var earnedSeconds: TimeInterval = 0  // total today (steps-based, for compatibility)
    @Published var showDailySummary = false
    @Published var summaryMessage = ""

    private var lastAwardDate: [String: Date] = [:]
    private var refreshTimer: Timer?

    private init() {
        if let d = UserDefaults.standard.object(forKey: "hk_steps_award") as? Date { lastAwardDate["steps"] = d }
        loadAndRefresh()
        startTimer()
    }

    func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.loadAndRefresh()
        }
    }

    func loadAndRefresh() {
        HealthKitManager.shared.requestAuthorization { granted in
            guard granted else { return }
            self.refreshAll()
        }
    }

    func refreshAll() {
        let zone = GameState.shared.currentZone

        HealthKitManager.shared.fetchTodayStepCount { steps in
            DispatchQueue.main.async {
                self.dailySteps = steps
                let raw = min(Double(steps), 10000) / 7.0
                self.todayBreakdown.stepsSeconds = raw * zone.stepBonusMultiplier
                self.earnedSeconds = self.todayBreakdown.stepsSeconds
            }
        }
        HealthKitManager.shared.fetchTodayActiveCalories { kcal in
            DispatchQueue.main.async {
                self.todayBreakdown.caloriesSeconds = min(kcal, 600) * 0.06
            }
        }
        HealthKitManager.shared.fetchTodayExerciseMinutes { mins in
            DispatchQueue.main.async {
                self.todayBreakdown.exerciseSeconds = min(mins, 60) * 2.0
            }
        }
        HealthKitManager.shared.fetchLastNightSleepHours { hours in
            DispatchQueue.main.async {
                if hours >= 7 && hours <= 9 { self.todayBreakdown.sleepSeconds = 1800 }
                else if hours >= 6 { self.todayBreakdown.sleepSeconds = 600 }
                else { self.todayBreakdown.sleepSeconds = 0 }
            }
        }
        HealthKitManager.shared.fetchTodayStandHours { stood in
            DispatchQueue.main.async {
                self.todayBreakdown.standSeconds = Double(min(stood, 12)) * 30.0
            }
        }
        HealthKitManager.shared.fetchTodayMindfulMinutes { mins in
            DispatchQueue.main.async {
                self.todayBreakdown.mindfulSeconds = min(mins, 20) * 6.0
            }
        }
        HealthKitManager.shared.fetchLatestHRV { hrv in
            DispatchQueue.main.async {
                self.todayBreakdown.hrvBonus = (hrv ?? 0) > 50 ? 300 : 0
            }
        }
    }

    // Called once daily at noon to actually award health income
    func awardDailyHealthIncome() {
        let zone = GameState.shared.currentZone
        let income = todayBreakdown.total * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
        TimeEngine.shared.addTime(income)
        GameState.shared.recordEarning(income)
        summaryMessage = "Daglig hälsoinkomst: +\(TimeEngine.shortFormatted(income))"
        showDailySummary = true
        UserDefaults.standard.set(Date(), forKey: "last_daily_health_award")
    }

    var jobTitle: String {
        switch dailySteps {
        case 0..<500:    return "Soffpotatisen"
        case 500..<1000: return "Halvpensionären"
        case 1000..<2500: return "Pendlaren"
        case 2500..<5000: return "Promenören"
        case 5000..<7500: return "Aktiv Medborgare"
        case 7500..<10000: return "Tidsspararen"
        case 10000..<12500: return "Maratonaren"
        default:         return "Tidsmästaren"
        }
    }
}
