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

    static let grundskiftet = ZoneProfile(name:"Grundskiftet", taxRate:0.02, dailyCostMultiplier:1.0, stepBonusMultiplier:1.0, appCostReduction:0, passiveBonusSecondsPerDay:0, boostEffectMultiplier:1.0, allowBoosts:false, maxActiveBoosts:0, fallThresholdSeconds:0, unlockRequirementSeconds:0, entryCostSeconds:0, protections:[], zoneIcon:"house", zoneColor:"#333333", casinoAccess:false, workMultiplier:1.0, drainRate:1.0, inflationRatePerDay:0.005, description:"Bottenvåningen. Ingen har valt att vara här.", index:0)

    static let krypdalen = ZoneProfile(name:"Krypdalen", taxRate:0.05, dailyCostMultiplier:1.1, stepBonusMultiplier:1.0, appCostReduction:0, passiveBonusSecondsPerDay:0, boostEffectMultiplier:1.0, allowBoosts:false, maxActiveBoosts:0, fallThresholdSeconds:21600, unlockRequirementSeconds:43200, entryCostSeconds:21600, protections:[], zoneIcon:"arrow.up", zoneColor:"#3d3d4a", casinoAccess:false, workMultiplier:1.2, drainRate:1.0, inflationRatePerDay:0.005, description:"Steget upp från botten. Ingen mer.", index:1)

    static let grabotten = ZoneProfile(name:"Gråbotten", taxRate:0.08, dailyCostMultiplier:1.2, stepBonusMultiplier:1.0, appCostReduction:0, passiveBonusSecondsPerDay:0, boostEffectMultiplier:1.0, allowBoosts:true, maxActiveBoosts:1, fallThresholdSeconds:64800, unlockRequirementSeconds:129600, entryCostSeconds:64800, protections:[], zoneIcon:"cloud", zoneColor:"#4a4a5a", casinoAccess:false, workMultiplier:1.4, drainRate:1.0, inflationRatePerDay:0.005, description:"Grå. Trött. Men levande.", index:2)

    static let skymring = ZoneProfile(name:"Skymring", taxRate:0.10, dailyCostMultiplier:1.3, stepBonusMultiplier:1.05, appCostReduction:0, passiveBonusSecondsPerDay:120, boostEffectMultiplier:1.0, allowBoosts:true, maxActiveBoosts:1, fallThresholdSeconds:172800, unlockRequirementSeconds:345600, entryCostSeconds:172800, protections:[], zoneIcon:"moon", zoneColor:"#505060", casinoAccess:false, workMultiplier:1.6, drainRate:1.0, inflationRatePerDay:0.008, description:"Gryningens kant. Fortfarande mörkt.", index:3)

    static let halvmorker = ZoneProfile(name:"Halvmörker", taxRate:0.12, dailyCostMultiplier:1.4, stepBonusMultiplier:1.08, appCostReduction:0, passiveBonusSecondsPerDay:300, boostEffectMultiplier:1.0, allowBoosts:true, maxActiveBoosts:1, fallThresholdSeconds:432000, unlockRequirementSeconds:864000, entryCostSeconds:432000, protections:[], zoneIcon:"moon.stars", zoneColor:"#556070", casinoAccess:false, workMultiplier:1.9, drainRate:1.0, inflationRatePerDay:0.008, description:"Halvvägs till ljuset. Eller halvvägs ner.", index:4)

    static let duskline = ZoneProfile(name:"Duskline", taxRate:0.15, dailyCostMultiplier:1.5, stepBonusMultiplier:1.1, appCostReduction:0.1, passiveBonusSecondsPerDay:600, boostEffectMultiplier:1.1, allowBoosts:true, maxActiveBoosts:2, fallThresholdSeconds:864000, unlockRequirementSeconds:1728000, entryCostSeconds:864000, protections:["Tidssköld Enkel"], zoneIcon:"cloud.sun", zoneColor:"#5a6478", casinoAccess:false, workMultiplier:2.2, drainRate:1.0, inflationRatePerDay:0.010, description:"Gränszonen. Varken upp eller ner.", index:5)

    static let midgrey = ZoneProfile(name:"Midgrey", taxRate:0.18, dailyCostMultiplier:1.8, stepBonusMultiplier:1.12, appCostReduction:0.15, passiveBonusSecondsPerDay:900, boostEffectMultiplier:1.2, allowBoosts:true, maxActiveBoosts:2, fallThresholdSeconds:1728000, unlockRequirementSeconds:3456000, entryCostSeconds:1728000, protections:["Tidssköld Enkel"], zoneIcon:"cloud.bolt", zoneColor:"#5a6e82", casinoAccess:false, workMultiplier:2.6, drainRate:1.0, inflationRatePerDay:0.010, description:"Mittzonen. Majoriteten bor här.", index:6)

    static let risefield = ZoneProfile(name:"Risefield", taxRate:0.22, dailyCostMultiplier:2.2, stepBonusMultiplier:1.15, appCostReduction:0.2, passiveBonusSecondsPerDay:1800, boostEffectMultiplier:1.3, allowBoosts:true, maxActiveBoosts:2, fallThresholdSeconds:3456000, unlockRequirementSeconds:6912000, entryCostSeconds:3456000, protections:["Tidssköld Enkel"], zoneIcon:"waveform", zoneColor:"#4a7090", casinoAccess:false, workMultiplier:3.2, drainRate:1.0, inflationRatePerDay:0.012, description:"Stigande mark. Risken ökar.", index:7)

    static let aetherpoint = ZoneProfile(name:"Aetherpoint", taxRate:0.28, dailyCostMultiplier:2.8, stepBonusMultiplier:1.2, appCostReduction:0.25, passiveBonusSecondsPerDay:3600, boostEffectMultiplier:1.5, allowBoosts:true, maxActiveBoosts:3, fallThresholdSeconds:6480000, unlockRequirementSeconds:12960000, entryCostSeconds:6480000, protections:["Tidssköld Enkel","Minutvakt"], zoneIcon:"antenna.radiowaves.left.and.right", zoneColor:"#3d80a0", casinoAccess:true, workMultiplier:4.0, drainRate:1.0, inflationRatePerDay:0.015, description:"Första steget mot makten. Kasinodörren öppnas.", index:8)

    static let novalux = ZoneProfile(name:"Novalux", taxRate:0.33, dailyCostMultiplier:3.5, stepBonusMultiplier:1.25, appCostReduction:0.35, passiveBonusSecondsPerDay:7200, boostEffectMultiplier:1.8, allowBoosts:true, maxActiveBoosts:3, fallThresholdSeconds:12960000, unlockRequirementSeconds:25920000, entryCostSeconds:12960000, protections:["Tidssköld Pro","Minutvakt"], zoneIcon:"star", zoneColor:"#2090b8", casinoAccess:true, workMultiplier:5.0, drainRate:1.0, inflationRatePerDay:0.015, description:"Nytt ljus. Nytt pris.", index:9)

    static let kronvakt = ZoneProfile(name:"Kronvakt", taxRate:0.38, dailyCostMultiplier:4.5, stepBonusMultiplier:1.3, appCostReduction:0.45, passiveBonusSecondsPerDay:14400, boostEffectMultiplier:2.0, allowBoosts:true, maxActiveBoosts:3, fallThresholdSeconds:25920000, unlockRequirementSeconds:51840000, entryCostSeconds:25920000, protections:["Tidssköld Pro","Minutvakt"], zoneIcon:"crown", zoneColor:"#10a0c8", casinoAccess:true, workMultiplier:6.0, drainRate:1.0, inflationRatePerDay:0.018, description:"Kronvakterna vill inte att du stannar länge.", index:10)

    static let vaultum = ZoneProfile(name:"Vaultum", taxRate:0.42, dailyCostMultiplier:5.5, stepBonusMultiplier:1.35, appCostReduction:0.55, passiveBonusSecondsPerDay:21600, boostEffectMultiplier:2.2, allowBoosts:true, maxActiveBoosts:4, fallThresholdSeconds:51840000, unlockRequirementSeconds:103680000, entryCostSeconds:51840000, protections:["Tidssköld Elite","Minutvakt","Immunitetsmod"], zoneIcon:"lock.shield", zoneColor:"#08b0d8", casinoAccess:true, workMultiplier:7.0, drainRate:1.0, inflationRatePerDay:0.018, description:"Valvet. De rikaste gömmer sin tid här.", index:11)

    static let zenit = ZoneProfile(name:"Zenit", taxRate:0.46, dailyCostMultiplier:7.0, stepBonusMultiplier:1.4, appCostReduction:0.7, passiveBonusSecondsPerDay:43200, boostEffectMultiplier:2.5, allowBoosts:true, maxActiveBoosts:4, fallThresholdSeconds:103680000, unlockRequirementSeconds:207360000, entryCostSeconds:103680000, protections:["Tidssköld Elite","Minutvakt","Immunitetsmod"], zoneIcon:"scope", zoneColor:"#00c0e8", casinoAccess:true, workMultiplier:7.8, drainRate:1.0, inflationRatePerDay:0.020, description:"Toppen av det möjliga. Nästan.", index:12)

    static let solara = ZoneProfile(name:"Solara", taxRate:0.50, dailyCostMultiplier:9.0, stepBonusMultiplier:1.5, appCostReduction:1.0, passiveBonusSecondsPerDay:86400, boostEffectMultiplier:3.0, allowBoosts:true, maxActiveBoosts:5, fallThresholdSeconds:207360000, unlockRequirementSeconds:414720000, entryCostSeconds:207360000, protections:["Tidssköld Elite","Minutvakt","Immunitetsmod","Solarakärna"], zoneIcon:"sun.max", zoneColor:"#00d8ff", casinoAccess:true, workMultiplier:9.0, drainRate:1.0, inflationRatePerDay:0.025, description:"Solen. De flesta dör innan de når hit.", index:13)

    static let allZones: [ZoneProfile] = [
        .grundskiftet, .krypdalen, .grabotten, .skymring, .halvmorker,
        .duskline, .midgrey, .risefield, .aetherpoint, .novalux,
        .kronvakt, .vaultum, .zenit, .solara
    ]

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
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        guard Scanner(string: h).scanHexInt64(&rgb) else { return nil }
        self.init(red: Double((rgb>>16)&0xFF)/255, green: Double((rgb>>8)&0xFF)/255, blue: Double(rgb&0xFF)/255)
    }
}
