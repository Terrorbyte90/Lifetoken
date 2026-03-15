import SwiftUI
import Foundation

// MARK: - Nattmarknaden — Tre Källor
// Öppnar 00:00–05:00 Stockholmstid. Stänger utan förvarning.
// Tre anonyma säljare — du vet aldrig vad du köper förrän det är för sent.

// MARK: - Modeller

enum NightSeller: String, CaseIterable, Identifiable {
    case kronvakten  = "Kronvaktens Skugga"
    case graman      = "Gråmarknadsmannen"
    case namlose     = "Den Namnlöse"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .kronvakten: return "Dyr men pålitlig. Säljer äkta boosts från högre zoner."
        case .graman:     return "Varannan boost äkta, varannan utspädd — halv effekt."
        case .namlose:    return "Löjligt billigt. Jackpot eller bluff. Ibland stjäl han din insats."
        }
    }

    var reliabilityText: String {
        switch self {
        case .kronvakten: return "100% äkta"
        case .graman:     return "50% chans"
        case .namlose:    return "Okänd"
        }
    }

    var priceMultiplier: Double {
        switch self {
        case .kronvakten: return 2.5
        case .graman:     return 1.3
        case .namlose:    return 0.4
        }
    }

    var color: Color {
        switch self {
        case .kronvakten: return Color(red: 0.9, green: 0.7, blue: 0.1)
        case .graman:     return Color(red: 0.6, green: 0.6, blue: 0.7)
        case .namlose:    return Color(red: 0.5, green: 0.3, blue: 0.9)
        }
    }

    var icon: String {
        switch self {
        case .kronvakten: return "crown.fill"
        case .graman:     return "questionmark.circle.fill"
        case .namlose:    return "eye.slash.fill"
        }
    }
}

struct NightMarketOffer: Identifiable {
    let id: String
    let seller: NightSeller
    let itemName: String
    let basePrice: TimeInterval   // pris i sekunder
    var currentPrice: TimeInterval // kan fluktuera
    let boostType: String
    let boostDuration: TimeInterval // i sekunder
    var buyCount: Int = 0           // antal köp denna natt
}

struct NightMarketPurchase: Identifiable, Codable {
    let id: String
    let sellerName: String
    let itemName: String
    let pricePaid: TimeInterval
    let outcome: String
    let timestamp: Date
}

// MARK: - Night Market Manager

class NightMarketManager: ObservableObject {
    static let shared = NightMarketManager()

    @Published var isOpen: Bool = false
    @Published var offers: [NightMarketOffer] = []
    @Published var purchaseHistory: [NightMarketPurchase] = []

    private var checkTimer: Timer?
    static let stockholmTZ = TimeZone(identifier: "Europe/Stockholm")!

    private init() {
        updateOpenStatus()
        startCheckTimer()
        generateNightOffers()
        loadHistory()
    }

    // MARK: - Öppettider (00:00–05:00 Stockholmstid)

    func updateOpenStatus() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let hour = cal.component(.hour, from: Date())
        isOpen = hour < 5
    }

    private func startCheckTimer() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.updateOpenStatus()
        }
    }

    // MARK: - Generera erbjudanden varje natt

    func generateNightOffers() {
        let baseBoosts: [(String, TimeInterval)] = [
            ("Tidsboost 10%",   3600 * 6),
            ("Tidsboost 20%",   3600 * 4),
            ("Tidsboost 30%",   3600 * 3),
            ("Tidsboost 50%",   3600 * 2),
            ("DNA-Boost 2x",    3600 * 1),
            ("Tidsstopp 1h",    3600 * 1),
            ("Zonboost",        3600 * 8),
        ]

        let basePrice: TimeInterval = 3600 * 2 // 2h basispris

        offers = NightSeller.allCases.map { seller in
            let boost = baseBoosts.randomElement()!
            let price = basePrice * seller.priceMultiplier
            return NightMarketOffer(
                id: UUID().uuidString,
                seller: seller,
                itemName: boost.0,
                basePrice: price,
                currentPrice: price,
                boostType: boost.0,
                boostDuration: boost.1
            )
        }
    }

    // MARK: - Köp logik

    func purchase(offerIndex: Int, completion: @escaping (String) -> Void) {
        guard isOpen else { completion("Nattmarknaden är stängd."); return }
        guard offerIndex < offers.count else { return }

        let offer = offers[offerIndex]
        guard TimeEngine.shared.balance >= offer.currentPrice else {
            completion("Otillräcklig balans.")
            return
        }

        // Dra priset
        TimeEngine.shared.deductTime(offer.currentPrice)

        // Öka priset pga köptryck
        offers[offerIndex].buyCount += 1
        offers[offerIndex].currentPrice = offer.basePrice * (1 + Double(offers[offerIndex].buyCount) * 0.15)

        // Avgör utfall beroende på säljare
        let outcome = resolveOutcome(seller: offer.seller, offer: offer)
        let purchase = NightMarketPurchase(
            id: UUID().uuidString,
            sellerName: offer.seller.rawValue,
            itemName: offer.itemName,
            pricePaid: offer.currentPrice,
            outcome: outcome,
            timestamp: Date()
        )
        purchaseHistory.insert(purchase, at: 0)
        saveHistory()
        NewsManager.shared.addNightMarketEvent(sellerName: offer.seller.rawValue, outcome: outcome)
        completion(outcome)
    }

    private func resolveOutcome(seller: NightSeller, offer: NightMarketOffer) -> String {
        switch seller {
        case .kronvakten:
            // Alltid äkta
            applyBoost(offer.boostType, duration: offer.boostDuration)
            return "✅ Du fick \(offer.itemName). Äkta vara från en pålitlig källa."

        case .graman:
            // 50/50: äkta eller halverad effekt
            if Bool.random() {
                applyBoost(offer.boostType, duration: offer.boostDuration)
                return "✅ Du fick \(offer.itemName). Den här gången var varan äkta."
            } else {
                applyBoost(offer.boostType, duration: offer.boostDuration / 2)
                return "⚠️ Utspädd vara. \(offer.itemName) med halv effekt aktiverades."
            }

        case .namlose:
            let roll = Int.random(in: 1...10)
            if roll <= 3 {
                // Jackpot — något exklusivt
                let bonus: TimeInterval = 3600 * Double.random(in: 5...24)
                TimeEngine.shared.addTime(bonus)
                return "💥 JACKPOT! Den Namnlöse gav dig \(TimeEngine.shortFormatted(bonus)) i ren tid."
            } else if roll <= 5 {
                // Stöld — säljaren försvinner med insatsen
                return "💀 Den Namnlöse tog din insats och försvann. Inget annat hände."
            } else if roll <= 8 {
                // Falsk vara — ingenting händer
                return "🌫️ Varan existerade inte. Du betalade för luft."
            } else {
                // Riktig vara
                applyBoost(offer.boostType, duration: offer.boostDuration)
                return "✅ Du fick \(offer.itemName). Otroligt tur att Den Namnlöse levererade."
            }
        }
    }

    private func applyBoost(_ type: String, duration: TimeInterval) {
        BoostManager.shared.activateBoost(named: type, duration: duration)
    }

    // MARK: - Persistence

    private let historyKey = "nightMarketHistory"

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([NightMarketPurchase].self, from: data) else { return }
        purchaseHistory = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(Array(purchaseHistory.prefix(50))) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}

// MARK: - Night Market View

struct NightMarketView: View {
    @ObservedObject private var market  = NightMarketManager.shared
    @ObservedObject private var engine  = TimeEngine.shared
    @Environment(\.dismiss) var dismiss

    @State private var purchaseResult: String = ""
    @State private var showResult: Bool = false
    @State private var confirmIndex: Int? = nil
    @State private var showHistory: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if !market.isOpen {
                    closedView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            headerSection
                            ForEach(market.offers.indices, id: \.self) { idx in
                                sellerCard(idx)
                            }
                            historySection
                            Spacer(minLength: 60)
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("NATTMARKNADEN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") { dismiss() }.foregroundColor(.white).font(.system(size: 13, design: .monospaced))
                }
            }
        }
        .alert("Nattmarknaden", isPresented: $showResult) {
            Button("OK", role: .cancel) {}
        } message: { Text(purchaseResult) }
        .confirmationDialog(
            "Bekräfta köp",
            isPresented: Binding(get: { confirmIndex != nil }, set: { if !$0 { confirmIndex = nil } }),
            titleVisibility: .visible
        ) {
            if let idx = confirmIndex {
                Button("Köp för \(TimeEngine.shortFormatted(market.offers[idx].currentPrice))") {
                    market.purchase(offerIndex: idx) { result in
                        DispatchQueue.main.async {
                            purchaseResult = result
                            showResult = true
                            confirmIndex = nil
                        }
                    }
                }
                Button("Avbryt", role: .cancel) { confirmIndex = nil }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Stängd vy

    private var closedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.5))
            Text("NATTMARKNADEN ÄR STÄNGD")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.6))
            Text("Öppnar 00:00–05:00 Stockholmstid.\nStänger utan förvarning.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.4))
                .multilineTextAlignment(.center)
            historySection
            Spacer()
        }
        .padding(20)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(Color(red: 0.1, green: 0.9, blue: 0.3))
                    .frame(width: 8, height: 8)
                Text("ÖPPEN — STÄNGER UTAN FÖRVARNING")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.7, blue: 0.4))
                    .tracking(2)
            }
            Text("Tre säljare. Okänd kvalitet. Handla på egen risk.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(red: 0.05, green: 0.08, blue: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Säljar-kort

    private func sellerCard(_ idx: Int) -> some View {
        let offer = market.offers[idx]
        let seller = offer.seller
        let canAfford = engine.balance >= offer.currentPrice

        return VStack(spacing: 0) {
            // Säljarhuvud
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(seller.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: seller.icon)
                        .font(.system(size: 18))
                        .foregroundColor(seller.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(seller.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(seller.reliabilityText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(seller.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeEngine.shortFormatted(offer.currentPrice))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(canAfford ? .white : Color(red: 0.6, green: 0.3, blue: 0.3))
                    if offer.buyCount > 0 {
                        Text("Pris steg +\(Int(offer.buyCount * 15))%")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.1))
                    }
                }
            }
            .padding(14)

            Divider().background(Color(red: 0.12, green: 0.12, blue: 0.18))

            // Varabeskrivning
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("? ? ? MYSTISK VARA ? ? ?")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
                    Text(seller.description)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                        .lineSpacing(3)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().background(Color(red: 0.12, green: 0.12, blue: 0.18))

            // Köpknapp
            Button {
                confirmIndex = idx
            } label: {
                Text(canAfford ? "KÖPA" : "OTILLRÄCKLIG BALANS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(canAfford ? .black : Color(red: 0.5, green: 0.5, blue: 0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canAfford ? seller.color : Color(red: 0.12, green: 0.12, blue: 0.16))
            }
            .disabled(!canAfford)
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(seller.color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Historik

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KÖPHISTORIK")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
                .tracking(3)

            if market.purchaseHistory.isEmpty {
                Text("Inga köp ännu.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.4))
            } else {
                ForEach(market.purchaseHistory.prefix(5)) { p in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.sellerName)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(p.outcome)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("−\(TimeEngine.shortFormatted(p.pricePaid))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(red: 0.8, green: 0.3, blue: 0.1))
                    }
                    .padding(10)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}
