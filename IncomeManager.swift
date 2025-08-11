//
//  IncomeManager.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//


import Foundation
import SwiftUI

class IncomeManager: ObservableObject {
    static let shared = IncomeManager()
    
    @Published var dailySteps: Int = 0
    @Published var earnedSeconds: TimeInterval = 0
    @Published var showDailySummary = false
    @Published var summaryMessage = ""

    private let stepReward: Double = 1.0 / 7.0 // 7 steg = 1 sekund

    private var timer: Timer?

    init() {
        HealthKitManager.shared.requestAuthorization { granted in
            if granted {
                DispatchQueue.main.async {
                    self.refreshSteps()
                }
            } else {
                print("❌ HealthKit-åtkomst nekad")
            }
        }
        startTimer()
    }

    func addSteps(_ steps: Int) {
        dailySteps += steps
        earnedSeconds = Double(dailySteps) * stepReward
    }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            self.checkForNoon()
        }
    }

    private func checkForNoon() {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        if components.hour == 12 && components.minute == 0 {
            presentSummary()
        }
    }

    private func presentSummary() {
        let summary = "👟 Steg idag: \(dailySteps)\n⏱️ Intjänad tid: \(Int(earnedSeconds)) sek"
        summaryMessage = summary
        showDailySummary = true
        resetDay()
    }

    func resetDay() {
        dailySteps = 0
        earnedSeconds = 0
    }
    
    func refreshSteps() {
        HealthKitManager.shared.fetchTodayStepCount { steps in
            DispatchQueue.main.async {
                print("✅ Hämtade steg från HealthKit: \(steps)")
                self.addSteps(steps)
            }
        }
    }
}
