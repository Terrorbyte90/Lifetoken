//
//  Boostmanager.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//

import Foundation

// BoostManager delegerar nu till ShopManager för korrekt logik.
// Gamla BoostManager.purchase() används inte längre — ShopManager.purchase() används direkt.

class BoostManager {
    static let shared = BoostManager()

    // Kvar för bakåtkompatibilitet med gamla StoreItem-anrop
    func purchase(_ item: StoreItem, currentZone: ZoneProfile?, currentTime: inout TimeInterval) -> Bool {
        let shopItem = ShopItem(
            id: item.name.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: item.name,
            icon: item.icon,
            description: item.description,
            effect: item.description,
            costSeconds: TimeInterval(item.costSeconds),
            category: .boosts,
            requiredZone: item.requiredZone,
            durationSeconds: 86400
        )
        let (success, _) = ShopManager.shared.purchase(shopItem, currentZone: currentZone)
        if success { currentTime = TimeEngine.shared.balance }
        return success
    }

    func getActiveBoosts() -> [String] {
        ShopManager.shared.activeEffects
            .filter { !$0.isExpired }
            .map { $0.name }
    }

    /// Returnerar inkomst-multiplikator baserat på ShopManager
    func boosterMultiplier() -> Double {
        ShopManager.shared.incomeMultiplier()
    }

    func activeBoosterLabel() -> String? {
        let m = boosterMultiplier()
        if m > 1.0 { return "Boost x\(String(format: "%.1f", m))" }
        return nil
    }

    func calculatedEarnings(baseSeconds: TimeInterval) -> TimeInterval {
        return baseSeconds * boosterMultiplier()
    }
}

