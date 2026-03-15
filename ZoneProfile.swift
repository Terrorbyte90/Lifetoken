import Foundation
import SwiftUI

struct ZoneProfile: Equatable {
    let name: String
    let taxRate: Double
    let dailyCostMultiplier: Double
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
    let zoneIcon: String
    let zoneColor: String
    let casinoAccess: Bool
    let workMultiplier: Double
    let drainRate: Double
    let inflationRatePerDay: Double
    let description: String
    let index: Int

    // MARK: - Zone Definitions (14 zoner per specifikation)

    static let askan = ZoneProfile(
        name: "Askan",
        taxRate: 0.02,
        dailyCostMultiplier: 1.0,
        stepBonusMultiplier: 1.0,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 0,
        boostEffectMultiplier: 1.0,
        allowBoosts: false,
        maxActiveBoosts: 0,
        fallThresholdSeconds: 0,
        unlockRequirementSeconds: 0,
        entryCostSeconds: 0,
        protections: [],
        zoneIcon: "flame",
        zoneColor: "#333333",
        casinoAccess: false,
        workMultiplier: 1.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.006,
        description: "Du börjar i ruinerna.",
        index: 0
    )

    static let spillrorna = ZoneProfile(
        name: "Spillrorna",
        taxRate: 0.04,
        dailyCostMultiplier: 1.1,
        stepBonusMultiplier: 1.05,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 180,
        boostEffectMultiplier: 1.0,
        allowBoosts: false,
        maxActiveBoosts: 0,
        fallThresholdSeconds: 75600,           // 21h
        unlockRequirementSeconds: 108000,      // 30h
        entryCostSeconds: 10800,               // 3h
        protections: [],
        zoneIcon: "arrow.up",
        zoneColor: "#3d3d4a",
        casinoAccess: false,
        workMultiplier: 1.3,
        drainRate: 1.0,
        inflationRatePerDay: 0.008,
        description: "Knappt uppåt.",
        index: 1
    )

    static let betongen = ZoneProfile(
        name: "Betongen",
        taxRate: 0.06,
        dailyCostMultiplier: 1.2,
        stepBonusMultiplier: 1.08,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 360,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 1,
        fallThresholdSeconds: 122400,          // 34h
        unlockRequirementSeconds: 172800,      // 48h
        entryCostSeconds: 14400,               // 4h
        protections: [],
        zoneIcon: "building.2",
        zoneColor: "#4a4a5a",
        casinoAccess: false,
        workMultiplier: 1.6,
        drainRate: 1.0,
        inflationRatePerDay: 0.010,
        description: "Grå, tung, oförlåtande.",
        index: 2
    )

    static let dimman = ZoneProfile(
        name: "Dimman",
        taxRate: 0.08,
        dailyCostMultiplier: 1.3,
        stepBonusMultiplier: 1.10,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 720,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 1,
        fallThresholdSeconds: 180000,          // 50h
        unlockRequirementSeconds: 259200,      // 72h
        entryCostSeconds: 21600,               // 6h
        protections: [],
        zoneIcon: "cloud.fog",
        zoneColor: "#505060",
        casinoAccess: false,
        workMultiplier: 2.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.012,
        description: "Ser inte vart du är på väg.",
        index: 3
    )

    static let halvmorkret = ZoneProfile(
        name: "Halvmörkret",
        taxRate: 0.10,
        dailyCostMultiplier: 1.4,
        stepBonusMultiplier: 1.12,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 1440,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 1,
        fallThresholdSeconds: 273600,          // 76h
        unlockRequirementSeconds: 388800,      // 108h
        entryCostSeconds: 36000,               // 10h
        protections: [],
        zoneIcon: "moon.stars",
        zoneColor: "#556070",
        casinoAccess: false,
        workMultiplier: 2.5,
        drainRate: 1.0,
        inflationRatePerDay: 0.014,
        description: "Ljuset skymtar.",
        index: 4
    )

    static let granslandet = ZoneProfile(
        name: "Gränslandet",
        taxRate: 0.13,
        dailyCostMultiplier: 1.5,
        stepBonusMultiplier: 1.15,
        appCostReduction: 0.05,
        passiveBonusSecondsPerDay: 2880,
        boostEffectMultiplier: 1.1,
        allowBoosts: true,
        maxActiveBoosts: 2,
        fallThresholdSeconds: 403200,          // 112h
        unlockRequirementSeconds: 576000,      // 160h
        entryCostSeconds: 57600,               // 16h
        protections: ["Tidssköld Enkel"],
        zoneIcon: "cloud.sun",
        zoneColor: "#5a6478",
        casinoAccess: false,
        workMultiplier: 3.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.017,
        description: "Varken här eller där.",
        index: 5
    )

    static let stigarnasDal = ZoneProfile(
        name: "Stigarnas Dal",
        taxRate: 0.16,
        dailyCostMultiplier: 1.8,
        stepBonusMultiplier: 1.18,
        appCostReduction: 0.10,
        passiveBonusSecondsPerDay: 5400,
        boostEffectMultiplier: 1.2,
        allowBoosts: true,
        maxActiveBoosts: 2,
        fallThresholdSeconds: 579600,          // 161h
        unlockRequirementSeconds: 828000,      // 230h
        entryCostSeconds: 82800,               // 23h
        protections: ["Tidssköld Enkel"],
        zoneIcon: "road.lanes",
        zoneColor: "#5a6e82",
        casinoAccess: false,
        workMultiplier: 3.8,
        drainRate: 1.0,
        inflationRatePerDay: 0.020,
        description: "De flesta fastnar här.",
        index: 6
    )

    static let uppgangen = ZoneProfile(
        name: "Uppgången",
        taxRate: 0.20,
        dailyCostMultiplier: 2.2,
        stepBonusMultiplier: 1.22,
        appCostReduction: 0.15,
        passiveBonusSecondsPerDay: 10800,
        boostEffectMultiplier: 1.3,
        allowBoosts: true,
        maxActiveBoosts: 2,
        fallThresholdSeconds: 856800,          // 238h
        unlockRequirementSeconds: 1224000,     // 340h
        entryCostSeconds: 122400,              // 34h
        protections: ["Tidssköld Enkel"],
        zoneIcon: "arrow.up.forward",
        zoneColor: "#4a7090",
        casinoAccess: false,
        workMultiplier: 4.8,
        drainRate: 1.0,
        inflationRatePerDay: 0.024,
        description: "Du rör dig äntligen.",
        index: 7
    )

    static let troskeln = ZoneProfile(
        name: "Tröskeln",
        taxRate: 0.25,
        dailyCostMultiplier: 2.8,
        stepBonusMultiplier: 1.28,
        appCostReduction: 0.20,
        passiveBonusSecondsPerDay: 18000,
        boostEffectMultiplier: 1.5,
        allowBoosts: true,
        maxActiveBoosts: 3,
        fallThresholdSeconds: 1260000,         // 350h
        unlockRequirementSeconds: 1800000,     // 500h
        entryCostSeconds: 180000,              // 50h
        protections: ["Tidssköld Enkel", "Minutvakt"],
        zoneIcon: "antenna.radiowaves.left.and.right",
        zoneColor: "#3d80a0",
        casinoAccess: true,
        workMultiplier: 6.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.029,
        description: "Kasinodörren öppnas.",
        index: 8
    )

    static let klarljuset = ZoneProfile(
        name: "Klarljuset",
        taxRate: 0.30,
        dailyCostMultiplier: 3.5,
        stepBonusMultiplier: 1.32,
        appCostReduction: 0.30,
        passiveBonusSecondsPerDay: 32400,
        boostEffectMultiplier: 1.8,
        allowBoosts: true,
        maxActiveBoosts: 3,
        fallThresholdSeconds: 1864800,         // 518h
        unlockRequirementSeconds: 2664000,     // 740h
        entryCostSeconds: 266400,              // 74h
        protections: ["Tidssköld Pro", "Minutvakt"],
        zoneIcon: "star",
        zoneColor: "#2090b8",
        casinoAccess: true,
        workMultiplier: 7.5,
        drainRate: 1.0,
        inflationRatePerDay: 0.035,
        description: "Välkommen till eliten.",
        index: 9
    )

    static let vakttornet = ZoneProfile(
        name: "Vakttornet",
        taxRate: 0.35,
        dailyCostMultiplier: 4.5,
        stepBonusMultiplier: 1.38,
        appCostReduction: 0.40,
        passiveBonusSecondsPerDay: 64800,
        boostEffectMultiplier: 2.0,
        allowBoosts: true,
        maxActiveBoosts: 3,
        fallThresholdSeconds: 2772000,         // 770h
        unlockRequirementSeconds: 3960000,     // 1100h
        entryCostSeconds: 396000,              // 110h
        protections: ["Tidssköld Pro", "Minutvakt"],
        zoneIcon: "binoculars",
        zoneColor: "#10a0c8",
        casinoAccess: true,
        workMultiplier: 9.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.040,
        description: "Du ser ner på andra nu.",
        index: 10
    )

    static let valvet = ZoneProfile(
        name: "Valvet",
        taxRate: 0.40,
        dailyCostMultiplier: 5.5,
        stepBonusMultiplier: 1.44,
        appCostReduction: 0.50,
        passiveBonusSecondsPerDay: 100800,
        boostEffectMultiplier: 2.2,
        allowBoosts: true,
        maxActiveBoosts: 4,
        fallThresholdSeconds: 34020000,        // 9450h
        unlockRequirementSeconds: 48600000,    // 13500h
        entryCostSeconds: 4860000,             // 1350h
        protections: ["Tidssköld Elite", "Minutvakt", "Immunitetsmod"],
        zoneIcon: "lock.shield",
        zoneColor: "#08b0d8",
        casinoAccess: true,
        workMultiplier: 11.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.009,
        description: "De rika gömmer sig här.",
        index: 11
    )

    static let kronan = ZoneProfile(
        name: "Kronan",
        taxRate: 0.44,
        dailyCostMultiplier: 7.0,
        stepBonusMultiplier: 1.50,
        appCostReduction: 0.65,
        passiveBonusSecondsPerDay: 187200,
        boostEffectMultiplier: 2.5,
        allowBoosts: true,
        maxActiveBoosts: 4,
        fallThresholdSeconds: 49896000,        // 13860h
        unlockRequirementSeconds: 71280000,    // 19800h
        entryCostSeconds: 7128000,             // 1980h
        protections: ["Tidssköld Elite", "Minutvakt", "Immunitetsmod"],
        zoneIcon: "crown",
        zoneColor: "#00c0e8",
        casinoAccess: true,
        workMultiplier: 13.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.010,
        description: "Nästan ouppnåeligt.",
        index: 12
    )

    static let evigheten = ZoneProfile(
        name: "Evigheten",
        taxRate: 0.48,
        dailyCostMultiplier: 9.0,
        stepBonusMultiplier: 1.60,
        appCostReduction: 1.0,
        passiveBonusSecondsPerDay: 360000,
        boostEffectMultiplier: 3.0,
        allowBoosts: true,
        maxActiveBoosts: 5,
        fallThresholdSeconds: 320040000,       // 88900h
        unlockRequirementSeconds: 457200000,   // 127000h
        entryCostSeconds: 45720000,            // 12700h
        protections: ["Tidssköld Elite", "Minutvakt", "Immunitetsmod", "Evighetskärna"],
        zoneIcon: "infinity",
        zoneColor: "#00d8ff",
        casinoAccess: true,
        workMultiplier: 16.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.011,
        description: "Ingen når hit utan att offra allt.",
        index: 13
    )

    static let allZones: [ZoneProfile] = [
        .askan, .spillrorna, .betongen, .dimman, .halvmorkret,
        .granslandet, .stigarnasDal, .uppgangen, .troskeln, .klarljuset,
        .vakttornet, .valvet, .kronan, .evigheten
    ]

    static func currentZone(forTime seconds: TimeInterval) -> ZoneProfile {
        for zone in allZones.reversed() {
            if seconds >= zone.unlockRequirementSeconds { return zone }
        }
        return .askan
    }

    static func == (lhs: ZoneProfile, rhs: ZoneProfile) -> Bool {
        lhs.name == rhs.name
    }

    var color: Color { Color(hex: zoneColor) ?? .gray }
}

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        self.init(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
    }
}
