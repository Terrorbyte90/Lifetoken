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
        case .kronvakten: return "100% ÄKTA"
        case .graman:     return "50% CHANS"
        case .namlose:    return "OKÄND RISK"
        }
    }

    var priceMultiplier: Double {
        switch self {
        case .kronvakten: return 2.5
        case .graman:     return 1.3
        case .namlose:    return 0.4
        }
    }

    var accentColor: Color {
        switch self {
        case .kronvakten: return Color(red: 0.95, green: 0.72, blue: 0.1)
        case .graman:     return Color(red: 0.55, green: 0.58, blue: 0.68)
        case .namlose:    return Color(red: 0.62, green: 0.18, blue: 0.85)
        }
    }

    var backgroundGradient: [Color] {
        switch self {
        case .kronvakten:
            return [Color(red:0.12, green:0.10, blue:0.02), Color(red:0.06, green:0.05, blue:0.01)]
        case .graman:
            return [Color(red:0.07, green:0.08, blue:0.12), Color(red:0.03, green:0.04, blue:0.07)]
        case .namlose:
            return [Color(red:0.08, green:0.03, blue:0.14), Color(red:0.04, green:0.02, blue:0.08)]
        }
    }

    var icon: String {
        switch self {
        case .kronvakten: return "crown.fill"
        case .graman:     return "questionmark.circle.fill"
        case .namlose:    return "eye.slash.fill"
        }
    }

    var reliabilityBadgeColor: Color {
        switch self {
        case .kronvakten: return Color(red: 0.1, green: 0.7, blue: 0.3)
        case .graman:     return Color(red: 0.8, green: 0.6, blue: 0.1)
        case .namlose:    return Color(red: 0.9, green: 0.15, blue: 0.15)
        }
    }
}

struct NightMarketOffer: Identifiable {
    let id: String
    let seller: NightSeller
    let itemName: String
    let basePrice: TimeInterval
    var currentPrice: TimeInterval
    let boostType: String
    let boostDuration: TimeInterval
    var buyCount: Int = 0
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

    // MARK: - Generera erbjudanden

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
        let basePrice: TimeInterval = 3600 * 2
        offers = NightSeller.allCases.map { seller in
            let boost = baseBoosts.randomElement() ?? baseBoosts[0]
            let price = basePrice * seller.priceMultiplier
            return NightMarketOffer(
                id: UUID().uuidString, seller: seller,
                itemName: boost.0, basePrice: price, currentPrice: price,
                boostType: boost.0, boostDuration: boost.1
            )
        }
    }

    // MARK: - Köplogik

    func purchase(offerIndex: Int, completion: @escaping (String) -> Void) {
        guard isOpen else { completion("Nattmarknaden är stängd."); return }
        guard offerIndex < offers.count else { return }
        let offer = offers[offerIndex]
        guard TimeEngine.shared.balance >= offer.currentPrice else {
            completion("Otillräcklig balans."); return
        }
        TimeEngine.shared.deductTime(offer.currentPrice)
        offers[offerIndex].buyCount += 1
        offers[offerIndex].currentPrice = offer.basePrice * (1 + Double(offers[offerIndex].buyCount) * 0.15)
        let outcome = resolveOutcome(seller: offer.seller, offer: offer)
        let purchase = NightMarketPurchase(
            id: UUID().uuidString, sellerName: offer.seller.rawValue,
            itemName: offer.itemName, pricePaid: offer.currentPrice,
            outcome: outcome, timestamp: Date()
        )
        purchaseHistory.insert(purchase, at: 0)
        saveHistory()
        NewsManager.shared.addNightMarketEvent(sellerName: offer.seller.rawValue, outcome: outcome)
        completion(outcome)
    }

    private func resolveOutcome(seller: NightSeller, offer: NightMarketOffer) -> String {
        switch seller {
        case .kronvakten:
            applyBoost(offer.boostType, duration: offer.boostDuration)
            return "✅ Du fick \(offer.itemName). Äkta vara från en pålitlig källa."
        case .graman:
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
                let bonus: TimeInterval = 3600 * Double.random(in: 5...24)
                TimeEngine.shared.addTime(bonus)
                return "💥 JACKPOT! Den Namnlöse gav dig \(TimeEngine.shortFormatted(bonus)) i ren tid."
            } else if roll <= 5 {
                return "💀 Den Namnlöse tog din insats och försvann. Inget annat hände."
            } else if roll <= 8 {
                return "🌫️ Varan existerade inte. Du betalade för luft."
            } else {
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

    // MARK: - Tid till öppning

    var secondsUntilOpen: TimeInterval {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = Self.stockholmTZ
        let now = Date()
        let hour = cal.component(.hour, from: now)
        if hour < 5 { return 0 } // already open
        // Time until next midnight Stockholm
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.day = (comps.day ?? 1) + 1
        comps.hour = 0; comps.minute = 0; comps.second = 0
        let nextMidnight = cal.date(from: comps) ?? now
        return nextMidnight.timeIntervalSince(now)
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
    @State private var particleSeed: Int = 0

    var body: some View {
        ZStack {
            // ── Atmospheric background ──
            nightBackground

            VStack(spacing: 0) {
                // Header bar
                nmHeader

                if !market.isOpen {
                    closedView
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            openStatusBar
                            ForEach(market.offers.indices, id: \.self) { sellerCard($0) }
                            historySection
                            Spacer(minLength: 60)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .alert("Nattmarknaden", isPresented: $showResult) {
            Button("Stäng", role: .cancel) {}
        } message: { Text(purchaseResult) }
        .confirmationDialog(
            "Bekräfta köp",
            isPresented: Binding(get: { confirmIndex != nil }, set: { if !$0 { confirmIndex = nil } }),
            titleVisibility: .visible
        ) {
            if let idx = confirmIndex {
                Button("Köp för \(TimeEngine.shortFormatted(market.offers[idx].currentPrice))") {
                    market.purchase(offerIndex: idx) { result in
                        DispatchQueue.main.async { purchaseResult = result; showResult = true; confirmIndex = nil }
                    }
                }
                Button("Avbryt", role: .cancel) { confirmIndex = nil }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var nightBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Deep purple-blue haze
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.02, blue: 0.10),
                    Color(red: 0.02, green: 0.01, blue: 0.06),
                    Color.black
                ],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Star field
            Canvas { ctx, size in
                let rng = seededRandom(seed: 42)
                for _ in 0..<80 {
                    let x = rng() * size.width
                    let y = rng() * size.height
                    let r = rng() * 1.2 + 0.2
                    let op = rng() * 0.4 + 0.05
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)),
                        with: .color(Color.white.opacity(op))
                    )
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var nmHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(9)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("NATTMARKNADEN")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(3)
                Text(market.isOpen ? "ÖPPEN" : "STÄNGD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(market.isOpen
                        ? Color(red: 0.3, green: 0.95, blue: 0.5)
                        : Color(red: 0.6, green: 0.3, blue: 0.6))
                    .tracking(4)
            }
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.1))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.9, green: 0.8, blue: 0.1).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.top, 58)
        .padding(.bottom, 14)
    }

    // MARK: - Open status bar

    private var openStatusBar: some View {
        HStack(spacing: 10) {
            // Pulsing dot
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.2))
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(Color(red: 0.2, green: 0.9, blue: 0.4))
                    .frame(width: 7, height: 7)
            }
            Text("MARKNADEN ÄR ÖPPEN — STÄNGER KL 05:00 STOCKHOLMSTID")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 0.4))
                .tracking(1)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.10, blue: 0.06), Color.clear],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.1, green: 0.4, blue: 0.2).opacity(0.5), lineWidth: 1))
    }

    // MARK: - Stängd vy

    private var closedView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Moon + atmospheric art
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.08, blue: 0.25).opacity(0.4))
                    .frame(width: 110, height: 110)
                    .blur(radius: 20)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.80))
                    .shadow(color: Color(red: 0.5, green: 0.2, blue: 0.9).opacity(0.5), radius: 16)
            }
            .padding(.bottom, 16)

            Text("NATTMARKNADEN ÄR STÄNGD")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(Color(red: 0.65, green: 0.45, blue: 0.80))
                .tracking(2)
                .padding(.bottom, 6)

            Text("Öppnar 00:00 — Stänger 05:00 Stockholmstid")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.55))
                .padding(.bottom, 4)

            Text("Stänger utan förvarning.")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.45))
                .padding(.bottom, 24)

            // Countdown card
            let secs = market.secondsUntilOpen
            if secs > 0 {
                VStack(spacing: 4) {
                    Text("ÖPPNAR OM")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.5, green: 0.35, blue: 0.6))
                        .tracking(3)
                    let h = Int(secs) / 3600
                    let m = (Int(secs) % 3600) / 60
                    let s = Int(secs) % 60
                    Text(String(format: "%02d:%02d:%02d", h, m, s))
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.95))
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.07, green: 0.04, blue: 0.13))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.4), lineWidth: 1))
                )
                .padding(.horizontal)
                .padding(.bottom, 28)
            }

            // History in closed state
            historySection
                .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Seller Card

    private func sellerCard(_ idx: Int) -> some View {
        let offer = market.offers[idx]
        let seller = offer.seller
        let canAfford = engine.balance >= offer.currentPrice

        return VStack(spacing: 0) {
            // Top: seller identity
            HStack(spacing: 14) {
                // Seller icon with glow
                ZStack {
                    Circle()
                        .fill(seller.accentColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                        .blur(radius: 6)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: seller.backgroundGradient,
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(Circle().stroke(seller.accentColor.opacity(0.4), lineWidth: 1))
                    Image(systemName: seller.icon)
                        .font(.system(size: 20))
                        .foregroundColor(seller.accentColor)
                        .shadow(color: seller.accentColor.opacity(0.6), radius: 4)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(seller.rawValue.uppercased())
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(1)

                    // Reliability badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(seller.reliabilityBadgeColor)
                            .frame(width: 5, height: 5)
                        Text(seller.reliabilityText)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(seller.reliabilityBadgeColor)
                            .tracking(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(seller.reliabilityBadgeColor.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(seller.reliabilityBadgeColor.opacity(0.35), lineWidth: 1))

                    Text(seller.description)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(2)
                }

                Spacer()

                // Price column
                VStack(alignment: .trailing, spacing: 3) {
                    Text(TimeEngine.shortFormatted(offer.currentPrice))
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(canAfford ? seller.accentColor : Color(red: 0.6, green: 0.25, blue: 0.25))
                    if offer.buyCount > 0 {
                        Text("+\(offer.buyCount * 15)%")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.9, green: 0.5, blue: 0.1))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.9, green: 0.5, blue: 0.1).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(16)

            // Middle: mystery item
            HStack(spacing: 10) {
                Image(systemName: "questionmark.square.dashed")
                    .font(.system(size: 16))
                    .foregroundColor(seller.accentColor.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text("??? MYSTISK VARA ???")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(seller.accentColor.opacity(0.6))
                        .tracking(1)
                    Text("Innehållet okänt tills transaktionen är genomförd")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.28))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(seller.accentColor.opacity(0.04))

            // Bottom: buy button
            Button { confirmIndex = idx } label: {
                HStack(spacing: 8) {
                    if !canAfford {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                    }
                    Text(canAfford ? "HANDLA ANONYMT" : "OTILLRÄCKLIG TID")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(canAfford ? .black : Color(red: 0.5, green: 0.3, blue: 0.3))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    canAfford
                        ? seller.accentColor
                        : Color(red: 0.1, green: 0.06, blue: 0.08)
                )
            }
            .disabled(!canAfford)
        }
        .background(
            LinearGradient(
                colors: seller.backgroundGradient.map { $0.opacity(1.4) } + [Color.black.opacity(0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [seller.accentColor.opacity(0.55), seller.accentColor.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: seller.accentColor.opacity(0.12), radius: 12, x: 0, y: 6)
    }

    // MARK: - Historik

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.55))
                Text("TRANSAKTIONSLOGG")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.45, green: 0.35, blue: 0.55))
                    .tracking(3)
                Spacer()
            }

            if market.purchaseHistory.isEmpty {
                HStack {
                    Spacer()
                    Text("Inga transaktioner registrerade.")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.35))
                    Spacer()
                }
                .padding(.vertical, 16)
            } else {
                VStack(spacing: 6) {
                    ForEach(market.purchaseHistory.prefix(5)) { p in
                        HStack(spacing: 10) {
                            // Outcome icon
                            let isGood = p.outcome.hasPrefix("✅") || p.outcome.hasPrefix("💥")
                            Circle()
                                .fill(isGood ? Color(red:0.1,green:0.7,blue:0.3).opacity(0.2) : Color(red:0.7,green:0.15,blue:0.15).opacity(0.2))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Text(p.outcome.hasPrefix("💥") ? "💥" : (isGood ? "✓" : "✗"))
                                        .font(.system(size: p.outcome.hasPrefix("💥") ? 12 : 10, weight: .bold))
                                        .foregroundColor(isGood ? Color(red:0.2,green:0.9,blue:0.4) : Color(red:0.9,green:0.2,blue:0.2))
                                )

                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.sellerName)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                                Text(p.outcome.replacingOccurrences(of: "✅ ", with: "").replacingOccurrences(of: "⚠️ ", with: "").replacingOccurrences(of: "💀 ", with: "").replacingOccurrences(of: "🌫️ ", with: "").replacingOccurrences(of: "💥 ", with: "").prefix(40))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("−\(TimeEngine.shortFormatted(p.pricePaid))")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.8, green: 0.35, blue: 0.15))
                        }
                        .padding(10)
                        .background(Color(red: 0.05, green: 0.03, blue: 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.05), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Seeded random helper for stars

    private func seededRandom(seed: Int) -> () -> Double {
        var state = UInt64(bitPattern: Int64(seed) &* 6364136223846793005 &+ 1442695040888963407)
        return {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 33) / Double(1 << 31)
        }
    }
}
