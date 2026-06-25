import Foundation
import SwiftUI

// MARK: - Health Income Breakdown

struct HealthIncomeBreakdown {
    // Lönesatser per specifikation:
    // Steg:        +0.5s per steg (ingen cap)
    // Sömn:        +1h per sovd timme, hard cap 8h → max 28800s
    // Kalorier:    +3.6s per kcal (ingen cap)
    // Träning:     +120s per träningsminut (ingen cap)
    // Stå:         +600s per timme (ingen cap)
    // Mindfulness: +120s per minut (ingen cap)
    // HRV-bonus:   fast +3600s (1h) vid grönt värde (>50ms)
    var stepsSeconds: TimeInterval = 0
    var caloriesSeconds: TimeInterval = 0
    var exerciseSeconds: TimeInterval = 0
    var sleepSeconds: TimeInterval = 0
    var standSeconds: TimeInterval = 0
    var mindfulSeconds: TimeInterval = 0
    var hrvBonus: TimeInterval = 0

    var total: TimeInterval {
        stepsSeconds + caloriesSeconds + exerciseSeconds +
        sleepSeconds + standSeconds + mindfulSeconds + hrvBonus
    }

    var summaryLines: [String] {
        var lines: [String] = []
        if stepsSeconds > 0    { lines.append("🦶 Steg:        +\(TimeEngine.shortFormatted(stepsSeconds))") }
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

    // Lönesatser (konstanter för enkel åtkomst från UI)
    static let stepRate: Double     = 0.5      // s per steg
    static let sleepRate: Double    = 3600.0   // s per timme sömn
    static let sleepHardCap: Double = 8.0      // max 8h sömn räknas
    static let calorieRate: Double  = 3.6      // s per kcal
    static let exerciseRate: Double = 120.0    // s per träningsminut
    static let standRate: Double    = 600.0    // s per stå-timme
    static let mindfulRate: Double  = 120.0    // s per mindfulness-minut
    static let hrvBonusValue: Double = 3600.0  // fast 1h vid grönt HRV

    private var refreshTimer: Timer?
    private var midnightTimer: Timer?

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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.loadAndRefresh()
        }
    }

    func scheduleMidnightCheck() {
        midnightTimer?.invalidate()
        let delay = secondsUntilStockholmMidnight()
        NotificationManager.shared.scheduleDailyPayoutReminder(secondsUntilMidnight: delay)
        midnightTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.checkAndAwardDailyHealthIncome()
            self?.scheduleMidnightCheck()
        }
    }

    func secondsUntilStockholmMidnight() -> TimeInterval {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.day = (comps.day ?? 1) + 1
        comps.hour = 0; comps.minute = 0; comps.second = 1
        let nextMidnight = cal.date(from: comps) ?? now.addingTimeInterval(86400)
        return max(1, nextMidnight.timeIntervalSince(now))
    }

    func todayStringInStockholm() -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        let y = comps.year ?? 2000
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return "\(y)-\(m)-\(d)"
    }

    // MARK: - App lifecycle

    func checkAndAwardDailyHealthIncome() {
        let today = todayStringInStockholm()
        guard lastAwardedDate != today else { return }
        loadAndRefresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.awardDailyHealthIncome()
        }
    }

    // MARK: - HealthKit fetch

    func loadAndRefresh() {
        HealthKitManager.shared.requestAuthorization { granted in
            guard granted else { return }
            self.refreshAll()
        }
    }

    func refreshAll() {
        let zone = GameState.shared.currentZone
        let phase = TimeOfDayEngine.shared.currentPhase
        // Dygnsfas-mekanik:
        //   Gryningsljus: steglön ×1.20, total hälsolön ×1.10
        //   Dagsljus:     total hälsolön ×1.05
        //   Djupnatt:     total hälsolön ×0.85
        let phaseHealthMult = phase.healthIncomeMultiplier
        let phaseStepMult   = phase.stepBonusMultiplier

        // Steg: 0.5s per steg, ingen cap
        HealthKitManager.shared.fetchTodayStepCount { steps in
            DispatchQueue.main.async {
                self.dailySteps = steps
                let raw = Double(steps) * Self.stepRate
                self.todayBreakdown.stepsSeconds = raw * zone.stepBonusMultiplier * phaseStepMult
                self.earnedSeconds = self.todayBreakdown.total
            }
        }

        // Kalorier: 3.6s per kcal, ingen cap
        HealthKitManager.shared.fetchTodayActiveCalories { kcal in
            DispatchQueue.main.async {
                self.todayBreakdown.caloriesSeconds = kcal * Self.calorieRate
                self.earnedSeconds = self.todayBreakdown.total
            }
        }

        // Träning: 120s per minut, ingen cap
        HealthKitManager.shared.fetchTodayExerciseMinutes { mins in
            DispatchQueue.main.async {
                self.todayBreakdown.exerciseSeconds = mins * Self.exerciseRate
                self.earnedSeconds = self.todayBreakdown.total
            }
        }

        // Sömn: 3600s per timme, hard cap 8h = max 28800s
        // Sover mer än 8h → förlorar vaken tid som kunde ge steg/träning/kalorier
        HealthKitManager.shared.fetchLastNightSleepHours { hours in
            DispatchQueue.main.async {
                let cappedHours = min(hours, Self.sleepHardCap)
                self.todayBreakdown.sleepSeconds = cappedHours * Self.sleepRate
                self.earnedSeconds = self.todayBreakdown.total
            }
        }

        // Stå: 600s per timme, ingen cap
        HealthKitManager.shared.fetchTodayStandHours { stood in
            DispatchQueue.main.async {
                self.todayBreakdown.standSeconds = Double(stood) * Self.standRate
                self.earnedSeconds = self.todayBreakdown.total
            }
        }

        // Mindfulness: 120s per minut, ingen cap
        HealthKitManager.shared.fetchTodayMindfulMinutes { mins in
            DispatchQueue.main.async {
                self.todayBreakdown.mindfulSeconds = mins * Self.mindfulRate
                self.earnedSeconds = self.todayBreakdown.total
            }
        }

        // HRV: fast +3600s (1h) om grönt värde (>50ms)
        HealthKitManager.shared.fetchLatestHRV { hrv in
            DispatchQueue.main.async {
                let v = hrv ?? 0
                self.todayBreakdown.hrvBonus = v > 50 ? Self.hrvBonusValue : 0
                self.earnedSeconds = self.todayBreakdown.total
            }
        }
    }

    // MARK: - Award vid midnatt

    func awardDailyHealthIncome() {
        let today = todayStringInStockholm()
        guard lastAwardedDate != today else { return }

        let zone = GameState.shared.currentZone
        let boostMult = BoostManager.shared.boosterMultiplier()
        // Dygnsfas-bonus appliceras på hela bruttoinkomsten vid utbetalning.
        // phaseHealthMult sätts av TimeOfDayEngine baserat på Stockholmstid.
        let phaseMult = TimeOfDayEngine.shared.currentPhase.healthIncomeMultiplier
        let gross    = todayBreakdown.total * boostMult * phaseMult
        let afterTax = gross * (1.0 - zone.taxRate)
        let net      = InflationManager.shared.deflatedEarnings(afterTax)

        // Ge skatten till Gregor (Styrelsen)
        let taxCollected = gross - afterTax
        if taxCollected > 0 {
            BoardManager.shared.collectTax(amount: taxCollected)
            BoardManager.shared.recordTaxCollection(taxCollected)
        }
        TransactionLedger.shared.record(label: "Hälsoinkomst mottagen", amount: net)

        TimeEngine.shared.addTime(net)
        GameState.shared.recordEarning(net)

        // Passiv zonbonus — tilldelas alltid oavsett hälsodata
        awardPassiveZoneBonus(zone: zone)

        // Notifiera nyhetsflödet
        NewsManager.shared.addHealthIncomeEvent(amount: net, breakdown: todayBreakdown)

        let inflPct   = String(format: "%.1f", (InflationManager.shared.currentMultiplier - 1) * 100)
        let lines     = todayBreakdown.summaryLines
        let breakdown = lines.joined(separator: "\n")
        let passiveBonus = zone.passiveBonusSecondsPerDay
        let passiveLine = passiveBonus > 0 ? "\n🏙 Zonbonus: +\(TimeEngine.shortFormatted(TimeInterval(passiveBonus)))" : ""
        summaryMessage = "🌅 Ny dag — hälsoinkomst:\n\(breakdown)\(passiveLine)\n\n✅ Netto: +\(TimeEngine.shortFormatted(net))\n(Skatt \(Int(zone.taxRate*100))%, Inflation -\(inflPct)% avdragna)"
        showDailySummary = true

        lastAwardedDate = today
        UserDefaults.standard.set(today, forKey: "hk_last_awarded_date")
    }

    // MARK: - Passiv zonbonus

    func awardPassiveZoneBonus(zone: ZoneProfile) {
        let bonus = TimeInterval(zone.passiveBonusSecondsPerDay)
        guard bonus > 0 else { return }

        // Passiv bonus är skattefri — den är en förmån för att befinna sig i zonen
        let deflated = InflationManager.shared.deflatedEarnings(bonus)
        TimeEngine.shared.addTime(deflated)
        GameState.shared.recordEarning(deflated)
        TransactionLedger.shared.record(label: "Passiv zonbonus (\(zone.name))", amount: deflated)
        NewsManager.shared.addItem(
            headline: "PASSIV ZONBONUS UTBETALD",
            body: "\(GameState.shared.username) fick \(TimeEngine.shortFormatted(deflated)) i passiv dagbonus för zonen \(zone.name).",
            category: .healthIncome,
            priority: .low
        )
    }

    // MARK: - Spelarprofiltext per steg

    var jobTitle: String {
        switch dailySteps {
        case 0..<2000:      return "Döende"
        case 2000..<8000:   return "Bottenskrapan"
        case 8000..<15000:  return "Medelmåttan"
        case 15000..<25000: return "Den Drivne"
        case 25000..<40000: return "Tidsmaskinen"
        default:            return "Tidsmästaren"
        }
    }

    // MARK: - Projicerad inkomst (för dashboard)

    var projectedDailyIncome: TimeInterval {
        let zone = GameState.shared.currentZone
        let boostMult = BoostManager.shared.boosterMultiplier()
        let phaseMult = TimeOfDayEngine.shared.currentPhase.healthIncomeMultiplier
        let gross = todayBreakdown.total * boostMult * phaseMult * (1.0 - zone.taxRate)
        return InflationManager.shared.deflatedEarnings(gross)
    }

    /// Projicerar slutlön baserat på nuvarande takt (för "förväntad lön idag"-widget)
    var projectedEndOfDayIncome: TimeInterval {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let now = Date()
        let startOfDay = cal.startOfDay(for: now)
        let secondsElapsed = now.timeIntervalSince(startOfDay)
        guard secondsElapsed > 0 else { return projectedDailyIncome }
        let rate = todayBreakdown.total / secondsElapsed
        let projected = rate * 86400
        let zone = GameState.shared.currentZone
        let boostMult = BoostManager.shared.boosterMultiplier()
        let phaseMult = TimeOfDayEngine.shared.currentPhase.healthIncomeMultiplier
        let gross = projected * boostMult * phaseMult * (1.0 - zone.taxRate)
        return InflationManager.shared.deflatedEarnings(gross)
    }

    /// Sekunder kvar till nästa löneutbetalning (00:00 Stockholmstid)
    var secondsUntilNextPayout: TimeInterval {
        secondsUntilStockholmMidnight()
    }
}
