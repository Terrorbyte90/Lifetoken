//
//  Boostmanager.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//

import Foundation

class BoostManager {
    static let shared = BoostManager()

    func purchase(_ item: StoreItem, currentZone: ZoneProfile?, currentTime: inout TimeInterval) -> Bool {
        // Kontrollera zonkrav
        if let required = item.requiredZone,
           required != currentZone?.name {
            print("❌ Du måste befinna dig i zonen \(required) för att köpa detta.")
            return false
        }

        // Kontrollera att tillräckligt med tid finns
        if currentTime < Double(item.costSeconds) {
            print("❌ Du har inte tillräckligt med tid.")
            return false
        }

        // Dra tid
        currentTime -= Double(item.costSeconds)
        print("💸 \(item.costSeconds) sekunder dragna för \(item.name)")

        // Spara aktiverad boost
        saveBoost(item)

        return true
    }

    private func saveBoost(_ item: StoreItem) {
        let key = "activeBoosts"
        var active = UserDefaults.standard.stringArray(forKey: key) ?? []
        active.append(item.name)
        UserDefaults.standard.set(active, forKey: key)
        print("✅ Boost aktiverad: \(item.name)")
    }

    func getActiveBoosts() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "activeBoosts") ?? []
    }

    func boosterMultiplier() -> Double {
        let boosts = getActiveBoosts()
        if boosts.contains(where: { $0.contains("30%") }) {
            return 1.3
        } else if boosts.contains(where: { $0.contains("20%") }) {
            return 1.2
        } else if boosts.contains(where: { $0.contains("10%") }) {
            return 1.1
        }
        return 1.0
    }

    func activeBoosterLabel() -> String? {
        let boosts = getActiveBoosts()
        if boosts.contains(where: { $0.contains("30%") }) {
            return "🧾 Booster 30%"
        } else if boosts.contains(where: { $0.contains("20%") }) {
            return "🧾 Booster 20%"
        } else if boosts.contains(where: { $0.contains("10%") }) {
            return "🧾 Booster 10%"
        }
        return nil
    }

    func calculatedEarnings(baseSeconds: TimeInterval) -> TimeInterval {
        return baseSeconds * boosterMultiplier()
    }
}
