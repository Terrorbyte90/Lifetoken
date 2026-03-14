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
    let zoneColor: String   // hex
    let casinoAccess: Bool
    let workMultiplier: Double
    let drainRate: Double    // seconds drained per real second

    // MARK: - Zone Definitions (KEEP THESE NAMES)

    static let duskline = ZoneProfile(
        name: "Duskline",
        taxRate: 0.05, dailyCostMultiplier: 1.0, stepBonusMultiplier: 1.0,
        appCostReduction: 0, passiveBonusSecondsPerDay: 0, boostEffectMultiplier: 1.0,
        allowBoosts: false, maxActiveBoosts: 0,
        fallThresholdSeconds: 0, unlockRequirementSeconds: 0, entryCostSeconds: 0,
        protections: [], zoneIcon: "building.2", zoneColor: "#444444",
        casinoAccess: false, workMultiplier: 1.0, drainRate: 1.0
    )

    static let midgrey = ZoneProfile(
        name: "Midgrey",
        taxRate: 0.08, dailyCostMultiplier: 1.2, stepBonusMultiplier: 1.0,
        appCostReduction: 0, passiveBonusSecondsPerDay: 0, boostEffectMultiplier: 1.0,
        allowBoosts: true, maxActiveBoosts: 1,
        fallThresholdSeconds: 36000, unlockRequirementSeconds: 144000, entryCostSeconds: 72000,
        protections: [], zoneIcon: "building.columns", zoneColor: "#667788",
        casinoAccess: false, workMultiplier: 1.3, drainRate: 1.0
    )

    static let risefield = ZoneProfile(
        name: "Risefield",
        taxRate: 0.12, dailyCostMultiplier: 1.5, stepBonusMultiplier: 1.1,
        appCostReduction: 0, passiveBonusSecondsPerDay: 600, boostEffectMultiplier: 1.0,
        allowBoosts: true, maxActiveBoosts: 2,
        fallThresholdSeconds: 108000, unlockRequirementSeconds: 432000, entryCostSeconds: 216000,
        protections: [], zoneIcon: "building.2.crop.circle", zoneColor: "#556688",
        casinoAccess: false, workMultiplier: 1.7, drainRate: 1.0
    )

    static let aetherpoint = ZoneProfile(
        name: "Aetherpoint",
        taxRate: 0.20, dailyCostMultiplier: 2.0, stepBonusMultiplier: 1.15,
        appCostReduction: 0.2, passiveBonusSecondsPerDay: 300, boostEffectMultiplier: 1.2,
        allowBoosts: true, maxActiveBoosts: 2,
        fallThresholdSeconds: 432000, unlockRequirementSeconds: 864000, entryCostSeconds: 432000,
        protections: ["Minute Man Shield"], zoneIcon: "building.fill", zoneColor: "#4488AA",
        casinoAccess: true, workMultiplier: 2.2, drainRate: 1.0
    )

    static let novalux = ZoneProfile(
        name: "Novalux",
        taxRate: 0.30, dailyCostMultiplier: 3.0, stepBonusMultiplier: 1.25,
        appCostReduction: 0.5, passiveBonusSecondsPerDay: 3600, boostEffectMultiplier: 2.0,
        allowBoosts: true, maxActiveBoosts: 3,
        fallThresholdSeconds: 1080000, unlockRequirementSeconds: 2160000, entryCostSeconds: 1080000,
        protections: ["Minute Man Shield", "Time Lock Basic"], zoneIcon: "star.fill", zoneColor: "#2299BB",
        casinoAccess: true, workMultiplier: 3.0, drainRate: 1.0
    )

    static let vaultum = ZoneProfile(
        name: "Vaultum",
        taxRate: 0.40, dailyCostMultiplier: 5.0, stepBonusMultiplier: 1.3,
        appCostReduction: 0.6, passiveBonusSecondsPerDay: 600, boostEffectMultiplier: 1.5,
        allowBoosts: true, maxActiveBoosts: 3,
        fallThresholdSeconds: 1800000, unlockRequirementSeconds: 3600000, entryCostSeconds: 1800000,
        protections: ["Minute Man Shield", "Time Lock Pro"], zoneIcon: "lock.shield.fill", zoneColor: "#11AACC",
        casinoAccess: true, workMultiplier: 4.0, drainRate: 1.0
    )

    static let solara = ZoneProfile(
        name: "Solara",
        taxRate: 0.50, dailyCostMultiplier: 8.0, stepBonusMultiplier: 1.5,
        appCostReduction: 1.0, passiveBonusSecondsPerDay: 0, boostEffectMultiplier: 2.0,
        allowBoosts: true, maxActiveBoosts: 4,
        fallThresholdSeconds: 2700000, unlockRequirementSeconds: 5400000, entryCostSeconds: 2700000,
        protections: ["Minute Man Shield", "Time Lock Elite", "Immunity Core"],
        zoneIcon: "sun.max.fill", zoneColor: "#00CCFF",
        casinoAccess: true, workMultiplier: 5.5, drainRate: 1.0
    )

    static let allZones: [ZoneProfile] = [.duskline, .midgrey, .risefield, .aetherpoint, .novalux, .vaultum, .solara]

    static func currentZone(forTime seconds: TimeInterval) -> ZoneProfile {
        let zones: [ZoneProfile] = [.solara, .vaultum, .novalux, .aetherpoint, .risefield, .midgrey]
        for zone in zones {
            if seconds >= zone.entryCostSeconds + zone.unlockRequirementSeconds { return zone }
        }
        return .duskline
    }

    static func == (lhs: ZoneProfile, rhs: ZoneProfile) -> Bool {
        lhs.name == rhs.name
    }

    var color: Color {
        switch name {
        case "Duskline":    return Color(hex: zoneColor) ?? .gray
        case "Midgrey":     return Color(hex: zoneColor) ?? .blue
        case "Risefield":   return Color(hex: zoneColor) ?? .blue
        case "Aetherpoint": return Color(hex: zoneColor) ?? .cyan
        case "Novalux":     return Color(hex: zoneColor) ?? .cyan
        case "Vaultum":     return Color(hex: zoneColor) ?? .cyan
        case "Solara":      return Color(hex: zoneColor) ?? .white
        default:            return .gray
        }
    }

    var description: String {
        switch name {
        case "Duskline":    return "Startzonen. Skattefri och trygg. Perfekt for nybörjare. Knappt möjligt att ga plus."
        case "Midgrey":     return "Lag skatt och första steget mot okad frihet. Boosts tillgangliga."
        case "Risefield":   return "Stegbonus aktiveras. Passiv inkomst borjar ticka. En dynamisk zon."
        case "Aetherpoint": return "Kasino oppnar. Passiva bonussekunder. Reducerade appkostnader."
        case "Novalux":     return "Stark boosteffekt och passiv inkomst. Avancerad zon med risk."
        case "Vaultum":     return "Skyddad zon med balans mellan kostnad och beloning. Hog skatt."
        case "Solara":      return "Ultimat zon. Maxade förmaner men 50% skatt. Bara de starkaste overlever."
        default:            return "Okand zon."
        }
    }
}

// Color hex extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
