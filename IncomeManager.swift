import Foundation
import SwiftUI

// MARK: - Health Income Breakdown

struct HealthIncomeBreakdown {
    // Generösa men realistiska värden — du måste anstränga dig för att överleva.
    var stepsSeconds: TimeInterval = 0       // 20 000 steg → 21 600s (1.08s/steg)
    var caloriesSeconds: TimeInterval = 0    // 600 kcal → 1 200s (2s/kcal)
    var exerciseSeconds: TimeInterval = 0    // 60 min → 3 600s (60s/min)
    var sleepSeconds: TimeInterval = 0       // 8–10h → 14 400s (4h); 7–8h → 7 200s (2h); 6–7h → 1 800s (30m); <6h → 0
    var standSeconds: TimeInterval = 0       // 12 h stående → 2 160s (180s/h)
    var mindfulSeconds: TimeInterval = 0     // 20 min → 1 800s (90s/min)
    var hrvBonus: TimeInterval = 0           // >50 ms → +3 600s; >70 ms → +7 200s

    var total: TimeInterval {
        stepsSeconds + caloriesSeconds + exerciseSeconds +
        sleepSeconds + standSeconds + mindfulSeconds + hrvBonus
    }

    /// Human-readable summary
    var summaryLines: [String] {
        var lines: [String] = []
        if stepsSeconds > 0   { lines.append("🦶 Steg:        +\(TimeEngine.shortFormatted(stepsSeconds))") }
        if caloriesSeconds > 0 { lines.append("🔥 Kalorier:    +\(TimeEngine.shortFormatted(caloriesSeconds))") }
        if exerciseSeconds > 0 { lines.append("🏃 Träning:     +\(TimeEngine.shortFormatted(exerciseSeconds))") }
        if sleepSeconds > 0    { lines.append("😴 Sömn:        +\(TimeEngine.shortFormatted(sleepSeconds))") }
        if standSeconds > 0    { lines.append("🧍 Stående:     +\(TimeEngine.shortFormatted(standSeconds))") }
        if mindfulSeconds > 0  { lines.append("🧘 Mindfulness: +\(TimeEngine.shortFormatted(mindfulSeconds))") }
        if hrvBonus > 0        { lines.append("❤️ HRV-bonus:   +\(TimeEngine.shortFormatted(hrvBonus))") }
        return lines
    }
}

// MARK: - Income Manager

class IncomeManager: ObservableObject {
    static let shared = IncomeManager()

    @Published var todayBreakdown = HealthIncomeBreakdown()
    @Published var dailySteps: Int = 0
    @Published var earnedSeconds: TimeInterval = 0
    @Published var showDailySummary = false
    @Published var summaryMessage = ""
    @Published var lastAwardedDate: String = ""

    private var refreshTimer: Timer?
    private var midnightTimer: Timer?

    // Swedish timezone for daily reset
    static let stockholmTZ = TimeZone(identifier: "Europe/Stockholm")!

    private init() {
        lastAwardedDate = UserDefaults.standard.string(forKey: "hk_last_awarded_date") ?? ""
        loadAndRefresh()
        startRefreshTimer()
        scheduleMidnightCheck()
    }

    // MARK: - Timers

    func startRefreshTimer() {
        refreshTimer?.invalidate()
        // Refresh every 60 seconds for near-real-time health data in UI
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.loadAndRefresh()
        }
    }

    /// Fires at exactly 00:00 Stockholm time each day to award health income
    func scheduleMidnightCheck() {
        midnightTimer?.invalidate()
        let delay = secondsUntilStockholmMidnight()
        midnightTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.checkAndAwardDailyHealthIncome()
            self?.scheduleMidnightCheck() // re-schedule for next midnight
        }
    }

    func secondsUntilStockholmMidnight() -> TimeInterval {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        // next midnight = day+1 at 00:00:00
        comps.day! += 1
        comps.hour = 0; comps.minute = 0; comps.second = 1
        let nextMidnight = cal.date(from: comps) ?? now.addingTimeInterval(86400)
        return max(1, nextMidnight.timeIntervalSince(now))
    }

    func todayStringInStockholm() -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        return "\(comps.year!)-\(comps.month!)-\(comps.day!)"
    }

    // MARK: - App lifecycle hooks

    /// Call from AppDelegate foreground to check missed midnight award
    func checkAndAwardDailyHealthIncome() {
        let today = todayStringInStockholm()
        guard lastAwardedDate != today else { return } // already awarded today
        // Fetch yesterday's health data (the completed day)
        loadAndRefresh()
        // Award after short delay to let HealthKit queries complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.awardDailyHealthIncome()
        }
    }

    // MARK: - HealthKit data fetch

    func loadAndRefresh() {
        HealthKitManager.shared.requestAuthorization { granted in
            guard granted else { return }
            self.refreshAll()
        }
    }

    func refreshAll() {
        let zone = GameState.shared.currentZone

        // Steps: 1.08 s/step, max 10 000 steps
        HealthKitManager.shared.fetchTodayStepCount { steps in
            DispatchQueue.main.async {
                self.dailySteps = steps
                let raw = min(Double(steps), 20000) * 1.08
                self.todayBreakdown.stepsSeconds = raw * zone.stepBonusMultiplier
                self.earnedSeconds = self.todayBreakdown.stepsSeconds
            }
        }

        // Calories: 2 s/kcal, max 600 kcal → 1 200s
        HealthKitManager.shared.fetchTodayActiveCalories { kcal in
            DispatchQueue.main.async {
                self.todayBreakdown.caloriesSeconds = min(kcal, 600) * 2.0
            }
        }

        // Exercise: 60 s/min, max 60 min → 3 600s
        HealthKitManager.shared.fetchTodayExerciseMinutes { mins in
            DispatchQueue.main.async {
                self.todayBreakdown.exerciseSeconds = min(mins, 60) * 60.0
            }
        }

        // Sleep: tiered bonus
        // 8–10h → 14 400s (4h); 7–8h → 7 200s (2h); 6–7h → 1 800s (30m); <6h → 0
        HealthKitManager.shared.fetchLastNightSleepHours { hours in
            DispatchQueue.main.async {
                if hours >= 8 && hours <= 10 {
                    self.todayBreakdown.sleepSeconds = 14400  // 4h
                } else if hours >= 7 {
                    self.todayBreakdown.sleepSeconds = 7200   // 2h
                } else if hours >= 6 {
                    self.todayBreakdown.sleepSeconds = 1800   // 30min
                } else {
                    self.todayBreakdown.sleepSeconds = 0
                }
            }
        }

        // Stand: 180 s/h, max 12 h → 2 160s
        HealthKitManager.shared.fetchTodayStandHours { stood in
            DispatchQueue.main.async {
                self.todayBreakdown.standSeconds = Double(min(stood, 12)) * 180.0
            }
        }

        // Mindful: 90 s/min, max 20 min → 1 800s
        HealthKitManager.shared.fetchTodayMindfulMinutes { mins in
            DispatchQueue.main.async {
                self.todayBreakdown.mindfulSeconds = min(mins, 20) * 90.0
            }
        }

        // HRV: >70 ms → 7 200s; >50 ms → 3 600s
        HealthKitManager.shared.fetchLatestHRV { hrv in
            DispatchQueue.main.async {
                let v = hrv ?? 0
                if v > 70 {
                    self.todayBreakdown.hrvBonus = 7200
                } else if v > 50 {
                    self.todayBreakdown.hrvBonus = 3600
                } else {
                    self.todayBreakdown.hrvBonus = 0
                }
            }
        }
    }

    // MARK: - Award

    /// Awards yesterday's completed health income. Called at midnight (Stockholm).
    func awardDailyHealthIncome() {
        let today = todayStringInStockholm()
        guard lastAwardedDate != today else { return }

        let zone = GameState.shared.currentZone
        let boostMult = BoostManager.shared.boosterMultiplier()
        let gross = todayBreakdown.total * boostMult
        let net = gross * (1.0 - zone.taxRate)

        TimeEngine.shared.addTime(net)
        GameState.shared.recordEarning(net)

        // Build summary
        let lines = todayBreakdown.summaryLines
        let breakdown = lines.joined(separator: "\n")
        summaryMessage = "🌅 Ny dag — hälsoinkomst:\n\(breakdown)\n\n✅ Netto: +\(TimeEngine.shortFormatted(net))\n(Skatt \(Int(zone.taxRate*100))% avdragen)"
        showDailySummary = true

        // Mark awarded
        lastAwardedDate = today
        UserDefaults.standard.set(today, forKey: "hk_last_awarded_date")
    }

    // MARK: - Job title

    var jobTitle: String {
        switch dailySteps {
        case 0..<1000:      return "Soffpotatisen"
        case 1000..<3000:   return "Halvpensionären"
        case 3000..<5000:   return "Pendlaren"
        case 5000..<8000:   return "Promenören"
        case 8000..<12000:  return "Aktiv Medborgare"
        case 12000..<16000: return "Tidsspararen"
        case 16000..<20000: return "Maratonaren"
        default:            return "Tidsmästaren"
        }
    }

    // MARK: - Projected daily income (for UI display)

    var projectedDailyIncome: TimeInterval {
        let zone = GameState.shared.currentZone
        let boostMult = BoostManager.shared.boosterMultiplier()
        return todayBreakdown.total * boostMult * (1.0 - zone.taxRate)
    }
}
