import Foundation
import SwiftUI

class IncomeManager: ObservableObject {
    static let shared = IncomeManager()

    @Published var dailySteps: Int = 0
    @Published var earnedSeconds: TimeInterval = 0
    @Published var showDailySummary = false
    @Published var summaryMessage = ""

    private let stepReward: Double = 1.0 / 7.0   // 7 steps = 1 second
    private var timer: Timer?

    private init() {
        HealthKitManager.shared.requestAuthorization { granted in
            if granted { DispatchQueue.main.async { self.refreshSteps() } }
        }
        startTimer()
    }

    func addSteps(_ steps: Int) {
        let newEarned = Double(steps) * stepReward
        dailySteps += steps
        earnedSeconds = Double(dailySteps) * stepReward
        // Actually add to balance with tax deduction
        let zone = GameState.shared.currentZone
        let afterTax = newEarned * (1 - zone.taxRate)
        let boosted = afterTax * BoostManager.shared.boosterMultiplier()
        TimeEngine.shared.addTime(boosted)
        GameState.shared.recordEarning(boosted)
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in self.checkForNoon() }
    }

    private func checkForNoon() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: Date())
        if components.hour == 12 && components.minute == 0 { presentSummary() }
    }

    private func presentSummary() {
        summaryMessage = "Steg idag: \(dailySteps)\nIntjanad tid: \(Int(earnedSeconds)) sek"
        showDailySummary = true
        resetDay()
    }

    func resetDay() { dailySteps = 0; earnedSeconds = 0 }

    func refreshSteps() {
        HealthKitManager.shared.fetchTodayStepCount { steps in
            DispatchQueue.main.async { self.addSteps(steps) }
        }
    }
}
