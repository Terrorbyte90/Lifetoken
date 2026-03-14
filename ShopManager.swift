import Foundation
import SwiftUI

// MARK: - Shop Item Types

enum ShopCategory: String, CaseIterable {
    case skydd      = "Skydd"
    case boosts     = "Boosts"
    case verktyg    = "Verktyg"
    case exklusivt  = "Exklusivt"

    var icon: String {
        switch self {
        case .skydd:     return "shield.fill"
        case .boosts:    return "bolt.fill"
        case .verktyg:   return "wrench.fill"
        case .exklusivt: return "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .skydd:     return .blue
        case .boosts:    return .green
        case .verktyg:   return .orange
        case .exklusivt: return .yellow
        }
    }
}

struct ShopItem: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let effect: String          // Kortare effektbeskrivning
    let costSeconds: TimeInterval
    let category: ShopCategory
    let requiredZone: String?   // nil = tillgänglig för alla
    let durationSeconds: TimeInterval? // nil = permanent/engångs

    var accentColor: Color { category.color }
}

// MARK: - Active Effect

struct ActiveEffect: Codable, Identifiable {
    let id: UUID
    let itemId: String
    let name: String
    let expiresAt: Date?        // nil = permanent
    let purchasedAt: Date

    var isExpired: Bool {
        guard let exp = expiresAt else { return false }
        return Date() > exp
    }
    var remainingSeconds: TimeInterval {
        guard let exp = expiresAt else { return -1 }
        return max(0, exp.timeIntervalSince(Date()))
    }
}

// MARK: - Shop Manager

class ShopManager: ObservableObject {
    static let shared = ShopManager()

    @Published var activeEffects: [ActiveEffect] = []

    private let effectsKey = "shop_active_effects"

    // Alla tillgängliga varor — 16 st i 4 kategorier
    static let allItems: [ShopItem] = [

        // ── SKYDD ──
        ShopItem(id: "time_shield",
                 name: "Tidssäkring",
                 icon: "shield.fill",
                 description: "Skyddar dig i 10 minuter om ditt saldo når 0. Aktiveras automatiskt.",
                 effect: "10 min skydd vid 0 sek",
                 costSeconds: 36000, category: .skydd, requiredZone: nil, durationSeconds: 600),

        ShopItem(id: "minuteman_shield",
                 name: "Minutman-sköld",
                 icon: "person.badge.shield.checkmark.fill",
                 description: "Skyddar mot nästa Minutman-raid. Engångsanvändning.",
                 effect: "Blockerar nästa Minutman",
                 costSeconds: 21600, category: .skydd, requiredZone: "Midgrey", durationSeconds: nil),

        ShopItem(id: "drain_reducer",
                 name: "Tidsbromsen",
                 icon: "tortoise.fill",
                 description: "Halverar tidsavrinningen i 1 timme. Perfekt för aktiva sessioner.",
                 effect: "0.5x drain i 1h",
                 costSeconds: 43200, category: .skydd, requiredZone: "Risefield", durationSeconds: 3600),

        ShopItem(id: "time_lock",
                 name: "Tidslås",
                 icon: "lock.shield.fill",
                 description: "Fryser klockan i 30 minuter. Ingen tid dras under perioden.",
                 effect: "Ingen drain i 30 min",
                 costSeconds: 86400, category: .skydd, requiredZone: "Aetherpoint", durationSeconds: 1800),

        // ── BOOSTS ──
        ShopItem(id: "boost_10",
                 name: "Intäktsboost +10%",
                 icon: "bolt.fill",
                 description: "+10% på all inkomst från steg, arbete och kasino i 24 timmar.",
                 effect: "+10% inkomst i 24h",
                 costSeconds: 43200, category: .boosts, requiredZone: "Midgrey", durationSeconds: 86400),

        ShopItem(id: "boost_20",
                 name: "Intäktsboost +20%",
                 icon: "bolt.circle.fill",
                 description: "+20% på all inkomst i 24 timmar.",
                 effect: "+20% inkomst i 24h",
                 costSeconds: 86400, category: .boosts, requiredZone: "Risefield", durationSeconds: 86400),

        ShopItem(id: "boost_30",
                 name: "Intäktsboost +30%",
                 icon: "bolt.square.fill",
                 description: "+30% på all inkomst i 24 timmar.",
                 effect: "+30% inkomst i 24h",
                 costSeconds: 144000, category: .boosts, requiredZone: "Aetherpoint", durationSeconds: 86400),

        ShopItem(id: "step_double",
                 name: "Stegdubbel",
                 icon: "figure.run.circle.fill",
                 description: "Dubblar steg-till-sekund-omvandlingen i 2 timmar. 3.5 steg = 1 sekund.",
                 effect: "2x steg-inkomst i 2h",
                 costSeconds: 28800, category: .boosts, requiredZone: nil, durationSeconds: 7200),

        ShopItem(id: "job_double",
                 name: "Dubbelarbete",
                 icon: "hammer.circle.fill",
                 description: "Nästa avslutade jobb ger dubbel utbetalning.",
                 effect: "2x lön på nästa jobb",
                 costSeconds: 21600, category: .boosts, requiredZone: "Midgrey", durationSeconds: nil),

        ShopItem(id: "casino_boost",
                 name: "Kasinotur",
                 icon: "suit.spade.fill",
                 description: "+25% på alla kasinovinster i 2 timmar.",
                 effect: "+25% kasinovinster i 2h",
                 costSeconds: 36000, category: .boosts, requiredZone: "Aetherpoint", durationSeconds: 7200),

        // ── VERKTYG ──
        ShopItem(id: "instant_hour",
                 name: "Tidsinjektionen",
                 icon: "plus.circle.fill",
                 description: "Lägg till 1 timme direkt på ditt saldo. Dyrt men omedelbart.",
                 effect: "+1 timme direkt",
                 costSeconds: 5400, category: .verktyg, requiredZone: nil, durationSeconds: nil),

        ShopItem(id: "tax_exempt",
                 name: "Skatteamnesti",
                 icon: "doc.text.fill",
                 description: "Noll skatt på nästa jobbavslutning. Engångsanvändning.",
                 effect: "0% skatt på nästa jobb",
                 costSeconds: 28800, category: .verktyg, requiredZone: "Midgrey", durationSeconds: nil),

        ShopItem(id: "casino_insurance",
                 name: "Kasinoförsäkring",
                 icon: "umbrella.fill",
                 description: "Få tillbaka 50% av insatsen om du förlorar nästa kasinospel.",
                 effect: "50% refund vid nästa förlust",
                 costSeconds: 21600, category: .verktyg, requiredZone: "Aetherpoint", durationSeconds: nil),

        ShopItem(id: "interest_boost",
                 name: "Ränteförstärkning",
                 icon: "chart.line.uptrend.xyaxis.circle.fill",
                 description: "+1% extra daglig ränta på alla pågående investeringar i 3 dagar.",
                 effect: "+1% ränta/dag i 3 dagar",
                 costSeconds: 43200, category: .verktyg, requiredZone: "Risefield", durationSeconds: 259200),

        // ── EXKLUSIVT ──
        ShopItem(id: "zone_skip",
                 name: "Zon-snabbkort",
                 icon: "arrow.up.forward.circle.fill",
                 description: "Hoppa över inträdesavgiften till nästa zon en gång.",
                 effect: "Gratis zonbyte (1 gång)",
                 costSeconds: 86400, category: .exklusivt, requiredZone: "Novalux", durationSeconds: nil),

        ShopItem(id: "mega_boost",
                 name: "Mega Boost +50%",
                 icon: "flame.fill",
                 description: "+50% på all inkomst i 12 timmar. Ultimat prestanda-boost.",
                 effect: "+50% inkomst i 12h",
                 costSeconds: 259200, category: .exklusivt, requiredZone: "Vaultum", durationSeconds: 43200),
    ]

    private let zoneOrder = ["Duskline", "Midgrey", "Risefield", "Aetherpoint", "Novalux", "Vaultum", "Solara"]

    private init() {
        loadEffects()
        cleanExpired()
    }

    // MARK: - Köp-logik

    func purchase(_ item: ShopItem, currentZone: ZoneProfile?) -> (success: Bool, message: String) {
        // Zonkontroll — tillåt köp om spelaren är i krav-zonen ELLER högre
        if let required = item.requiredZone, let zone = currentZone {
            let playerIdx = zoneOrder.firstIndex(of: zone.name) ?? 0
            let requiredIdx = zoneOrder.firstIndex(of: required) ?? 0
            if playerIdx < requiredIdx {
                return (false, "Kräver zon \(required) eller högre.")
            }
        }

        // Saldokontroll
        guard TimeEngine.shared.balance >= item.costSeconds else {
            let need = TimeEngine.shortFormatted(item.costSeconds - TimeEngine.shared.balance)
            return (false, "Saknar \(need) för att köpa detta.")
        }

        // Dra tid direkt från TimeEngine (kritisk fix)
        guard TimeEngine.shared.deductTime(item.costSeconds) else {
            return (false, "Köp misslyckades.")
        }

        // Specialhantering per vara
        switch item.id {
        case "instant_hour":
            // Lägg till 1h direkt
            TimeEngine.shared.addTime(3600)
            GameState.shared.recordEarning(3600)
            return (true, "+1 timme tillagd på ditt saldo!")

        case "drain_reducer":
            activateEffect(item)
            TimeEngine.shared.setDrainRate(0.5)
            // Återställ drain efter varaktigheten
            let rate = GameState.shared.currentZone.drainRate
            DispatchQueue.main.asyncAfter(deadline: .now() + (item.durationSeconds ?? 3600)) {
                TimeEngine.shared.setDrainRate(rate)
            }
            return (true, "Tidsbromsen aktiv! 0.5x drain i 1 timme.")

        case "time_lock":
            activateEffect(item)
            TimeEngine.shared.setDrainRate(0)
            let rate = GameState.shared.currentZone.drainRate
            DispatchQueue.main.asyncAfter(deadline: .now() + (item.durationSeconds ?? 1800)) {
                TimeEngine.shared.setDrainRate(rate)
            }
            return (true, "Tidslåset aktiverat! Ingen drain i 30 minuter.")

        default:
            activateEffect(item)
            let durationText = item.durationSeconds.map { " (\(TimeEngine.shortFormatted($0)))" } ?? ""
            return (true, "\(item.name) aktiverat\(durationText)!")
        }
    }

    // MARK: - Aktiva effekter

    func hasEffect(_ itemId: String) -> Bool {
        cleanExpired()
        return activeEffects.contains { $0.itemId == itemId && !$0.isExpired }
    }

    private func activateEffect(_ item: ShopItem) {
        let expiresAt = item.durationSeconds.map { Date().addingTimeInterval($0) }
        let effect = ActiveEffect(
            id: UUID(),
            itemId: item.id,
            name: item.name,
            expiresAt: expiresAt,
            purchasedAt: Date()
        )
        activeEffects.append(effect)
        saveEffects()
    }

    func cleanExpired() {
        let before = activeEffects.count
        activeEffects.removeAll { $0.isExpired }
        if activeEffects.count != before { saveEffects() }
    }

    func removeEffect(_ itemId: String) {
        activeEffects.removeAll { $0.itemId == itemId }
        saveEffects()
    }

    // MARK: - Multiplikatorer (används av BoostManager-logik)

    func incomeMultiplier() -> Double {
        cleanExpired()
        if hasEffect("mega_boost") { return 1.5 }
        if hasEffect("boost_30")   { return 1.3 }
        if hasEffect("boost_20")   { return 1.2 }
        if hasEffect("boost_10")   { return 1.1 }
        return 1.0
    }

    func stepMultiplier() -> Double {
        cleanExpired()
        if hasEffect("step_double") { return 2.0 }
        return incomeMultiplier()
    }

    func casinoMultiplier() -> Double {
        cleanExpired()
        let base = incomeMultiplier()
        return hasEffect("casino_boost") ? base + 0.25 : base
    }

    func jobMultiplier() -> Double {
        cleanExpired()
        let base = incomeMultiplier()
        return hasEffect("job_double") ? base * 2.0 : base
    }

    func hasTaxExemptForJob() -> Bool { hasEffect("tax_exempt") }
    func hasMinutemanShield() -> Bool { hasEffect("minuteman_shield") }
    func hasCasinoInsurance() -> Bool { hasEffect("casino_insurance") }
    func hasZoneSkip() -> Bool        { hasEffect("zone_skip") }

    // Konsumera engångseffekter
    func consumeJobTaxExempt()      { removeEffect("tax_exempt") }
    func consumeMinutemanShield()   { removeEffect("minuteman_shield") }
    func consumeCasinoInsurance()   { removeEffect("casino_insurance") }
    func consumeZoneSkip()          { removeEffect("zone_skip") }

    // MARK: - Persistens

    private func saveEffects() {
        if let data = try? JSONEncoder().encode(activeEffects) {
            UserDefaults.standard.set(data, forKey: effectsKey)
        }
    }

    private func loadEffects() {
        guard let data = UserDefaults.standard.data(forKey: effectsKey),
              let loaded = try? JSONDecoder().decode([ActiveEffect].self, from: data) else { return }
        activeEffects = loaded
        cleanExpired()
    }
}
