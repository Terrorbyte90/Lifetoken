//
//  ZoneProfile.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//

import Foundation

struct ZoneProfile {
    let name: String
    let taxRate: Double // 0.3 = 30%
    let dailyCostMultiplier: Double // För framtida användning
    let stepBonusMultiplier: Double
    let appCostReduction: Double
    let passiveBonusSecondsPerDay: Int
    let boostEffectMultiplier: Double
    let allowBoosts: Bool
    let maxActiveBoosts: Int
    let fallThresholdSeconds: TimeInterval
    let unlockRequirementSeconds: TimeInterval
    let entryCostSeconds: TimeInterval
    let protections: [String]

    static let duskline = ZoneProfile(
        name: "Duskline",
        taxRate: 0.0,
        dailyCostMultiplier: 1.0,
        stepBonusMultiplier: 1.0,
        appCostReduction: 0.0,
        passiveBonusSecondsPerDay: 0,
        boostEffectMultiplier: 1.0,
        allowBoosts: false,
        maxActiveBoosts: 0,
        fallThresholdSeconds: 0,
        unlockRequirementSeconds: 0,
        entryCostSeconds: 0,
        protections: []
    )

    static let midgrey = ZoneProfile(
        name: "Midgrey",
        taxRate: 0.05,
        dailyCostMultiplier: 1.05,
        stepBonusMultiplier: 1.0,
        appCostReduction: 0.0,
        passiveBonusSecondsPerDay: 0,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 1,
        fallThresholdSeconds: 129600, // 36h
        unlockRequirementSeconds: 144000, // 40h
        entryCostSeconds: 72000,
        protections: []
    )

    static let risefield = ZoneProfile(
        name: "Risefield",
        taxRate: 0.10,
        dailyCostMultiplier: 1.10,
        stepBonusMultiplier: 1.10,
        appCostReduction: 0.0,
        passiveBonusSecondsPerDay: 0,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 2,
        fallThresholdSeconds: 388800, // 108h
        unlockRequirementSeconds: 432000, // 120h
        entryCostSeconds: 216000,
        protections: []
    )

    static let aetherpoint = ZoneProfile(
        name: "Aetherpoint",
        taxRate: 0.20,
        dailyCostMultiplier: 1.15,
        stepBonusMultiplier: 1.0,
        appCostReduction: 0.2,
        passiveBonusSecondsPerDay: 300,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 2,
        fallThresholdSeconds: 777600, // 216h
        unlockRequirementSeconds: 864000, // 240h
        entryCostSeconds: 432000,
        protections: []
    )

    static let novalux = ZoneProfile(
        name: "Novalux",
        taxRate: 0.30,
        dailyCostMultiplier: 1.25,
        stepBonusMultiplier: 1.0,
        appCostReduction: 0.5,
        passiveBonusSecondsPerDay: 3600,
        boostEffectMultiplier: 2.0,
        allowBoosts: true,
        maxActiveBoosts: 3,
        fallThresholdSeconds: 1944000, // 540h
        unlockRequirementSeconds: 2160000, // 600h
        entryCostSeconds: 1080000,
        protections: []
    )

    static let vaultum = ZoneProfile(
        name: "Vaultum",
        taxRate: 0.40,
        dailyCostMultiplier: 1.30,
        stepBonusMultiplier: 1.0,
        appCostReduction: 0.3,
        passiveBonusSecondsPerDay: 600,
        boostEffectMultiplier: 1.5,
        allowBoosts: true,
        maxActiveBoosts: 3,
        fallThresholdSeconds: 3600000, // 1000h
        unlockRequirementSeconds: 3600000, // 1000h
        entryCostSeconds: 1800000,
        protections: []
    )

    static let solara = ZoneProfile(
        name: "Solara",
        taxRate: 0.50,
        dailyCostMultiplier: 1.50,
        stepBonusMultiplier: 1.0,
        appCostReduction: 1.0,
        passiveBonusSecondsPerDay: 0,
        boostEffectMultiplier: 2.0,
        allowBoosts: true,
        maxActiveBoosts: 4,
        fallThresholdSeconds: 4860000, // 1500h * 0.9
        unlockRequirementSeconds: 5400000, // 1500h
        entryCostSeconds: 2700000,
        protections: []
    )
    
    static let allZones: [ZoneProfile] = [
        .duskline, .midgrey, .risefield, .aetherpoint, .novalux, .vaultum, .solara
    ]

    static func currentZone(forTime seconds: TimeInterval) -> ZoneProfile {
        // (Retain original order for currentZone logic if needed)
        let zones: [ZoneProfile] = [.solara, .vaultum, .novalux, .aetherpoint, .risefield, .midgrey, .duskline]
        
        for zone in zones {
            let cost = zone.entryCostSeconds
            let minRemaining = zone.unlockRequirementSeconds * 1.1
            if seconds >= (cost + minRemaining) {
                return zone
            }
        }
        return .duskline
    }
}
