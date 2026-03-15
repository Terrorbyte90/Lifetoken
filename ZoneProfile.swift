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

    // MARK: - Zone Definitions (14 zones, helt på svenska)

    static let grundskiftet = ZoneProfile(
        name: "Grundskiftet",
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
        zoneIcon: "house",
        zoneColor: "#333333",
        casinoAccess: false,
        workMultiplier: 1.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.003,
        description: "Bottenvåningen. Ingen har valt att vara här.",
        index: 0
    )

    static let krypdalen = ZoneProfile(
        name: "Krypdalen",
        taxRate: 0.04,
        dailyCostMultiplier: 1.1,
        stepBonusMultiplier: 1.05,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 120,
        boostEffectMultiplier: 1.0,
        allowBoosts: false,
        maxActiveBoosts: 0,
        fallThresholdSeconds: 64800,
        unlockRequirementSeconds: 194400,
        entryCostSeconds: 64800,
        protections: [],
        zoneIcon: "arrow.up",
        zoneColor: "#3d3d4a",
        casinoAccess: false,
        workMultiplier: 1.2,
        drainRate: 1.0,
        inflationRatePerDay: 0.005,
        description: "Steget upp från botten. Lite mer luft att andas.",
        index: 1
    )

    static let grabotten = ZoneProfile(
        name: "Gråbotten",
        taxRate: 0.06,
        dailyCostMultiplier: 1.2,
        stepBonusMultiplier: 1.08,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 300,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 1,
        fallThresholdSeconds: 172800,
        unlockRequirementSeconds: 518400,
        entryCostSeconds: 172800,
        protections: [],
        zoneIcon: "cloud",
        zoneColor: "#4a4a5a",
        casinoAccess: false,
        workMultiplier: 1.5,
        drainRate: 1.0,
        inflationRatePerDay: 0.008,
        description: "Grå. Trött. Men levande.",
        index: 2
    )

    static let skymring = ZoneProfile(
        name: "Skymring",
        taxRate: 0.08,
        dailyCostMultiplier: 1.3,
        stepBonusMultiplier: 1.10,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 600,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 1,
        fallThresholdSeconds: 432000,
        unlockRequirementSeconds: 1296000,
        entryCostSeconds: 432000,
        protections: [],
        zoneIcon: "moon",
        zoneColor: "#505060",
        casinoAccess: false,
        workMultiplier: 1.8,
        drainRate: 1.0,
        inflationRatePerDay: 0.010,
        description: "Gryningens kant. Fortfarande mörkt, men hoppfullt.",
        index: 3
    )

    static let halvmorker = ZoneProfile(
        name: "Halvmörker",
        taxRate: 0.10,
        dailyCostMultiplier: 1.4,
        stepBonusMultiplier: 1.12,
        appCostReduction: 0,
        passiveBonusSecondsPerDay: 1200,
        boostEffectMultiplier: 1.0,
        allowBoosts: true,
        maxActiveBoosts: 1,
        fallThresholdSeconds: 1008000,
        unlockRequirementSeconds: 3024000,
        entryCostSeconds: 1008000,
        protections: [],
        zoneIcon: "moon.stars",
        zoneColor: "#556070",
        casinoAccess: false,
        workMultiplier: 2.2,
        drainRate: 1.0,
        inflationRatePerDay: 0.013,
        description: "Halvvägs till ljuset. Håll ut.",
        index: 4
    )

    static let duskline = ZoneProfile(
        name: "Skymningsgränsen",
        taxRate: 0.13,
        dailyCostMultiplier: 1.5,
        stepBonusMultiplier: 1.15,
        appCostReduction: 0.05,
        passiveBonusSecondsPerDay: 2400,
        boostEffectMultiplier: 1.1,
        allowBoosts: true,
        maxActiveBoosts: 2,
        fallThresholdSeconds: 2160000,
        unlockRequirementSeconds: 6480000,
        entryCostSeconds: 2160000,
        protections: ["Tidssköld Enkel"],
        zoneIcon: "cloud.sun",
        zoneColor: "#5a6478",
        casinoAccess: false,
        workMultiplier: 2.6,
        drainRate: 1.0,
        inflationRatePerDay: 0.016,
        description: "Gränszonen. Varken upp eller ner — än.",
        index: 5
    )

    static let midgrey = ZoneProfile(
        name: "Gråtaket",
        taxRate: 0.16,
        dailyCostMultiplier: 1.8,
        stepBonusMultiplier: 1.18,
        appCostReduction: 0.10,
        passiveBonusSecondsPerDay: 3600,
        boostEffectMultiplier: 1.2,
        allowBoosts: true,
        maxActiveBoosts: 2,
        fallThresholdSeconds: 4320000,
        unlockRequirementSeconds: 12960000,
        entryCostSeconds: 4320000,
        protections: ["Tidssköld Enkel"],
        zoneIcon: "cloud.bolt",
        zoneColor: "#5a6e82",
        casinoAccess: false,
        workMultiplier: 3.1,
        drainRate: 1.0,
        inflationRatePerDay: 0.020,
        description: "Taket på gråzonen. Majoriteten fastnar här.",
        index: 6
    )

    static let risefield = ZoneProfile(
        name: "Stegningsfältet",
        taxRate: 0.20,
        dailyCostMultiplier: 2.2,
        stepBonusMultiplier: 1.22,
        appCostReduction: 0.15,
        passiveBonusSecondsPerDay: 7200,
        boostEffectMultiplier: 1.3,
        allowBoosts: true,
        maxActiveBoosts: 2,
        fallThresholdSeconds: 8640000,
        unlockRequirementSeconds: 25920000,
        entryCostSeconds: 8640000,
        protections: ["Tidssköld Enkel"],
        zoneIcon: "waveform",
        zoneColor: "#4a7090",
        casinoAccess: false,
        workMultiplier: 3.8,
        drainRate: 1.0,
        inflationRatePerDay: 0.025,
        description: "Stigande mark. Risken ökar. Belöningarna med.",
        index: 7
    )

    static let aetherpoint = ZoneProfile(
        name: "Eterpunkten",
        taxRate: 0.25,
        dailyCostMultiplier: 2.8,
        stepBonusMultiplier: 1.28,
        appCostReduction: 0.20,
        passiveBonusSecondsPerDay: 14400,
        boostEffectMultiplier: 1.5,
        allowBoosts: true,
        maxActiveBoosts: 3,
        fallThresholdSeconds: 17280000,
        unlockRequirementSeconds: 51840000,
        entryCostSeconds: 17280000,
        protections: ["Tidssköld Enkel", "Minutvakt"],
        zoneIcon: "antenna.radiowaves.left.and.right",
        zoneColor: "#3d80a0",
        casinoAccess: true,
        workMultiplier: 4.5,
        drainRate: 1.0,
        inflationRatePerDay: 0.030,
        description: "Kasinodörren öppnas. Möjligheter — och faror.",
        index: 8
    )

    static let novalux = ZoneProfile(
        name: "Nylysningen",
        taxRate: 0.30,
        dailyCostMultiplier: 3.5,
        stepBonusMultiplier: 1.32,
        appCostReduction: 0.30,
        passiveBonusSecondsPerDay: 28800,
        boostEffectMultiplier: 1.8,
        allowBoosts: true,
        maxActiveBoosts: 3,
        fallThresholdSeconds: 32400000,
        unlockRequirementSeconds: 97200000,
        entryCostSeconds: 32400000,
        protections: ["Tidssköld Pro", "Minutvakt"],
        zoneIcon: "star",
        zoneColor: "#2090b8",
        casinoAccess: true,
        workMultiplier: 5.5,
        drainRate: 1.0,
        inflationRatePerDay: 0.035,
        description: "Nytt ljus. Nytt pris. Välkommen till eliten.",
        index: 9
    )

    static let kronvakt = ZoneProfile(
        name: "Kronvakt",
        taxRate: 0.35,
        dailyCostMultiplier: 4.5,
        stepBonusMultiplier: 1.38,
        appCostReduction: 0.40,
        passiveBonusSecondsPerDay: 57600,
        boostEffectMultiplier: 2.0,
        allowBoosts: true,
        maxActiveBoosts: 3,
        fallThresholdSeconds: 57600000,
        unlockRequirementSeconds: 172800000,
        entryCostSeconds: 57600000,
        protections: ["Tidssköld Pro", "Minutvakt"],
        zoneIcon: "crown",
        zoneColor: "#10a0c8",
        casinoAccess: true,
        workMultiplier: 6.5,
        drainRate: 1.0,
        inflationRatePerDay: 0.040,
        description: "Kronvakterna vill inte att du stannar. Gör det ändå.",
        index: 10
    )

    static let vaultum = ZoneProfile(
        name: "Valvet",
        taxRate: 0.40,
        dailyCostMultiplier: 5.5,
        stepBonusMultiplier: 1.44,
        appCostReduction: 0.50,
        passiveBonusSecondsPerDay: 86400,
        boostEffectMultiplier: 2.2,
        allowBoosts: true,
        maxActiveBoosts: 4,
        fallThresholdSeconds: 108000000,
        unlockRequirementSeconds: 270000000,
        entryCostSeconds: 108000000,
        protections: ["Tidssköld Elite", "Minutvakt", "Immunitetsmod"],
        zoneIcon: "lock.shield",
        zoneColor: "#08b0d8",
        casinoAccess: true,
        workMultiplier: 7.5,
        drainRate: 1.0,
        inflationRatePerDay: 0.050,
        description: "Valvet. De rikaste gömmer sin tid här. Djupt.",
        index: 11
    )

    static let zenit = ZoneProfile(
        name: "Zenit",
        taxRate: 0.44,
        dailyCostMultiplier: 7.0,
        stepBonusMultiplier: 1.50,
        appCostReduction: 0.65,
        passiveBonusSecondsPerDay: 172800,
        boostEffectMultiplier: 2.5,
        allowBoosts: true,
        maxActiveBoosts: 4,
        fallThresholdSeconds: 198000000,
        unlockRequirementSeconds: 495000000,
        entryCostSeconds: 198000000,
        protections: ["Tidssköld Elite", "Minutvakt", "Immunitetsmod"],
        zoneIcon: "scope",
        zoneColor: "#00c0e8",
        casinoAccess: true,
        workMultiplier: 8.5,
        drainRate: 1.0,
        inflationRatePerDay: 0.060,
        description: "Toppen av det möjliga. Nästan. En sista nivå väntar.",
        index: 12
    )

    static let solara = ZoneProfile(
        name: "Solara",
        taxRate: 0.48,
        dailyCostMultiplier: 9.0,
        stepBonusMultiplier: 1.60,
        appCostReduction: 1.0,
        passiveBonusSecondsPerDay: 345600,
        boostEffectMultiplier: 3.0,
        allowBoosts: true,
        maxActiveBoosts: 5,
        fallThresholdSeconds: 360000000,
        unlockRequirementSeconds: 900000000,
        entryCostSeconds: 360000000,
        protections: ["Tidssköld Elite", "Minutvakt", "Immunitetsmod", "Solarakärna"],
        zoneIcon: "sun.max",
        zoneColor: "#00d8ff",
        casinoAccess: true,
        workMultiplier: 10.0,
        drainRate: 1.0,
        inflationRatePerDay: 0.070,
        description: "Solen. De flesta dör innan de når hit. Du klarade det.",
        index: 13
    )

    static let allZones: [ZoneProfile] = [
        .grundskiftet, .krypdalen, .grabotten, .skymring, .halvmorker,
        .duskline, .midgrey, .risefield, .aetherpoint, .novalux,
        .kronvakt, .vaultum, .zenit, .solara
    ]

    /// Auto-assign zone purely by unlockRequirement (used for initial placement)
    static func currentZone(forTime seconds: TimeInterval) -> ZoneProfile {
        for zone in allZones.reversed() {
            if seconds >= zone.unlockRequirementSeconds { return zone }
        }
        return .grundskiftet
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
