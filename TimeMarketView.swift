import SwiftUI

// MARK: - Store Item

struct StoreItem: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let costSeconds: TimeInterval
    let requiredZoneIndex: Int     // minimum zone index needed (0 = all zones)
    let accentColor: Color
    let category: ItemCategory

    enum ItemCategory: String, CaseIterable {
        case skydd     = "Skydd"
        case boost     = "Boost"
        case verktyg   = "Verktyg"
        case premium   = "Premium"

        var color: Color {
            switch self {
            case .skydd:   return Color(red: 0.2, green: 0.7, blue: 1.0)
            case .boost:   return Color(red: 0.2, green: 0.9, blue: 0.4)
            case .verktyg: return Color(red: 0.9, green: 0.6, blue: 0.1)
            case .premium: return Color(red: 1.0, green: 0.84, blue: 0.0)
            }
        }

        var icon: String {
            switch self {
            case .skydd:   return "shield.fill"
            case .boost:   return "bolt.fill"
            case .verktyg: return "wrench.fill"
            case .premium: return "star.fill"
            }
        }
    }
}

// MARK: - Market Manager

class MarketManager: ObservableObject {
    static let shared = MarketManager()

    @Published var purchasedIds: Set<String> = []

    private let purchasedKey = "market_purchased_ids"

    private init() {
        if let data = UserDefaults.standard.stringArray(forKey: purchasedKey) {
            purchasedIds = Set(data)
        }
    }

    func canPurchase(_ item: StoreItem, zone: ZoneProfile, balance: TimeInterval) -> PurchaseResult {
        if zone.index < item.requiredZoneIndex { return .zoneLocked }
        if balance < item.costSeconds { return .insufficientFunds }
        return .available
    }

    func purchase(_ item: StoreItem) -> Bool {
        let zone    = GameState.shared.currentZone
        let balance = TimeEngine.shared.balance
        guard canPurchase(item, zone: zone, balance: balance) == .available else { return false }
        guard TimeEngine.shared.deductTime(item.costSeconds) else { return false }
        applyEffect(item)
        purchasedIds.insert(item.id)
        UserDefaults.standard.set(Array(purchasedIds), forKey: purchasedKey)
        return true
    }

    private func applyEffect(_ item: StoreItem) {
        switch item.id {
        case "orakel":
            UserDefaults.standard.set(true, forKey: "orakel_active")
        case "tidsstopp":
            let expiry = Date().addingTimeInterval(300)
            UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: "tidsstopp_expiry")
        default:
            let key = "activeBoosts"
            var active = UserDefaults.standard.stringArray(forKey: key) ?? []
            active.append(item.name)
            UserDefaults.standard.set(active, forKey: key)
        }
    }

    enum PurchaseResult: Equatable {
        case available, zoneLocked, insufficientFunds
    }
}

// MARK: - Time Market View

struct TimeMarketView: View {
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var market    = MarketManager.shared

    @State private var selectedCategory: StoreItem.ItemCategory? = nil
    @State private var showAlert   = false
    @State private var alertTitle  = ""
    @State private var alertMessage = ""
    @State private var lastPurchasedId: String? = nil

    let allItems: [StoreItem] = [
        // Skydd
        StoreItem(id: "tidsskold",      name: "Tidssköld Enkel",
                  description: "Skydd i 10 min om du når 0 sek. Aktiveras automatiskt vid kritisk nivå.",
                  icon: "shield",             costSeconds: 36000,  requiredZoneIndex: 0,  accentColor: .cyan,   category: .skydd),
        StoreItem(id: "tidsskold_pro",  name: "Tidssköld Pro",
                  description: "Skydd i 30 min vid kritisk tid. Absorberar upp till 50% av dagskostnad.",
                  icon: "shield.lefthalf.filled", costSeconds: 86400, requiredZoneIndex: 5, accentColor: .cyan, category: .skydd),
        StoreItem(id: "tidsskold_elit", name: "Tidssköld Elite",
                  description: "Full immunitetsperiod 60 min. Ingen tidsdrain under aktivering.",
                  icon: "shield.fill",        costSeconds: 259200, requiredZoneIndex: 9,  accentColor: .blue,  category: .skydd),
        StoreItem(id: "natverksskydd",  name: "Nätverksskydd",
                  description: "Blockerar serverbaserade tidsjusteringar i 24h. Anti-cheat-skydd.",
                  icon: "lock.shield",        costSeconds: 72000,  requiredZoneIndex: 5,  accentColor: .cyan,  category: .skydd),
        StoreItem(id: "sparningsskydd", name: "Spårningsskydd",
                  description: "Döljer din balans från andra spelare och servern i 12h.",
                  icon: "eye.slash",          costSeconds: 43200,  requiredZoneIndex: 6,  accentColor: .gray,  category: .skydd),

        // Boost
        StoreItem(id: "boost_10",       name: "Intäktsbooster 10%",
                  description: "+10% på all dagsintjäning i 24h. Inkluderar hälso- och jobbinkomst.",
                  icon: "bolt",              costSeconds: 43200,  requiredZoneIndex: 3,  accentColor: .green,  category: .boost),
        StoreItem(id: "boost_20",       name: "Intäktsbooster 20%",
                  description: "+20% på all dagsintjäning i 24h.",
                  icon: "bolt.fill",         costSeconds: 86400,  requiredZoneIndex: 5,  accentColor: .green,  category: .boost),
        StoreItem(id: "boost_30",       name: "Intäktsbooster 30%",
                  description: "+30% på all dagsintjäning i 24h. Stark effekt, hög kostnad.",
                  icon: "bolt.badge.a",      costSeconds: 144000, requiredZoneIndex: 7,  accentColor: .yellow, category: .boost),
        StoreItem(id: "boost_50",       name: "Intäktsbooster 50%",
                  description: "+50% på all dagsintjäning i 24h. Solara-klass effekt.",
                  icon: "bolt.circle.fill",  costSeconds: 432000, requiredZoneIndex: 12, accentColor: .orange, category: .boost),
        StoreItem(id: "tidsbatteri",    name: "Tidsbatteri",
                  description: "Lagra upp till 8h tid utanför tidsmätaren. Frys din balans vid ett givet värde.",
                  icon: "battery.100",       costSeconds: 57600,  requiredZoneIndex: 4,  accentColor: .green,  category: .boost),
        StoreItem(id: "dna_boost",      name: "DNA-Boost",
                  description: "Dubbel hälsoinkomst nästa 24h. Steg, kalorier och sömn räknas dubbelt.",
                  icon: "dna",               costSeconds: 172800, requiredZoneIndex: 8,  accentColor: .pink,   category: .boost),

        // Verktyg
        StoreItem(id: "tidsstopp",      name: "Tidsstopp",
                  description: "Pausa tidsdrain i 5 minuter. Nödbroms för krissituationer.",
                  icon: "pause.circle",      costSeconds: 21600,  requiredZoneIndex: 5,  accentColor: .orange, category: .verktyg),
        StoreItem(id: "orakel",         name: "Orakel",
                  description: "Avslöjar kraschpunkt i nästa Crash-runda. Engångsanvändning.",
                  icon: "eye.trianglebadge.exclamationmark", costSeconds: 28800, requiredZoneIndex: 8, accentColor: .purple, category: .verktyg),

        // Premium
        StoreItem(id: "immunitetsmod",  name: "Immunitetsmod",
                  description: "Immun mot zonfall i 72h. Ingen automatisk nedgradering vid låg balans.",
                  icon: "checkmark.shield.fill", costSeconds: 518400, requiredZoneIndex: 11, accentColor: Color(red:1,green:0.84,blue:0), category: .premium),
        StoreItem(id: "solarakarna",    name: "Solarakärna",
                  description: "Passiv inkomst +86400s/dag under 3 dagar. Solara-exklusivt.",
                  icon: "sun.max.fill",      costSeconds: 1036800, requiredZoneIndex: 13, accentColor: .yellow, category: .premium),
    ]

    var displayItems: [StoreItem] {
        if let cat = selectedCategory { return allItems.filter { $0.category == cat } }
        return allItems
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    marketHeader
                    categoryRow
                        .padding(.bottom, 12)
                    itemsList
                    Spacer(minLength: 100)
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {}
        } message: { Text(alertMessage) }
    }

    // MARK: - Header

    private var marketHeader: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.yellow)
                    Text("TIDENS MARKNAD")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                }
                .padding(.top, 60)

                // Balance chip
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill").font(.system(size: 10))
                        Text(TimeEngine.shortFormatted(engine.balance))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.yellow.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))

                    HStack(spacing: 5) {
                        Image(systemName: gameState.currentZone.zoneIcon).font(.system(size: 10))
                        Text(gameState.currentZone.name)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(gameState.currentZone.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(gameState.currentZone.color.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(gameState.currentZone.color.opacity(0.3), lineWidth: 1))
                }
                .padding(.bottom, 16)
            }

            Divider().background(Color.white.opacity(0.06))
        }
    }

    // MARK: - Category Row

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All chip
                Button { withAnimation { selectedCategory = nil } } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2.fill").font(.system(size: 10))
                        Text("Alla")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(selectedCategory == nil ? .black : .white.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(selectedCategory == nil ? Color.white : Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }

                ForEach(StoreItem.ItemCategory.allCases, id: \.self) { cat in
                    Button { withAnimation { selectedCategory = selectedCategory == cat ? nil : cat } } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon).font(.system(size: 10))
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(selectedCategory == cat ? .black : cat.color.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedCategory == cat ? cat.color : cat.color.opacity(0.1))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(cat.color.opacity(selectedCategory == cat ? 0 : 0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Items List

    private var itemsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(displayItems) { item in
                MarketItemCard(
                    item: item,
                    zone: gameState.currentZone,
                    balance: engine.balance,
                    isPurchased: market.purchasedIds.contains(item.id),
                    isJustBought: lastPurchasedId == item.id
                ) {
                    handlePurchase(item)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .padding(.horizontal, 14)
        .animation(.spring(response: 0.3), value: selectedCategory)
    }

    // MARK: - Purchase Logic

    private func handlePurchase(_ item: StoreItem) {
        let result = market.canPurchase(item, zone: gameState.currentZone, balance: engine.balance)
        switch result {
        case .zoneLocked:
            let reqName = ZoneProfile.allZones.first(where: { $0.index == item.requiredZoneIndex })?.name ?? "okänd zon"
            alertTitle   = "Zon Låst"
            alertMessage = "Du behöver vara i \(reqName) (niv. \(item.requiredZoneIndex)) för att köpa \(item.name)."
        case .insufficientFunds:
            alertTitle   = "Otillräcklig Tid"
            alertMessage = "Du saknar \(TimeEngine.shortFormatted(item.costSeconds - engine.balance)) mer. Behövs totalt: \(TimeEngine.shortFormatted(item.costSeconds))."
        case .available:
            if market.purchase(item) {
                lastPurchasedId = item.id
                alertTitle   = "✓ Köp Bekräftat"
                alertMessage = "\(item.name) är nu aktivt på ditt konto."
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { lastPurchasedId = nil }
            } else {
                alertTitle   = "Fel"
                alertMessage = "Köpet misslyckades. Försök igen."
            }
        }
        showAlert = true
    }
}

// MARK: - Market Item Card

struct MarketItemCard: View {
    let item: StoreItem
    let zone: ZoneProfile
    let balance: TimeInterval
    let isPurchased: Bool
    let isJustBought: Bool
    let onBuy: () -> Void

    var purchaseResult: MarketManager.PurchaseResult {
        MarketManager.shared.canPurchase(item, zone: zone, balance: balance)
    }

    var isZoneLocked: Bool { purchaseResult == .zoneLocked }
    var canAfford:    Bool { balance >= item.costSeconds }

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isZoneLocked
                          ? Color.gray.opacity(0.1)
                          : item.accentColor.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isZoneLocked ? .gray.opacity(0.5) : item.accentColor)

                if isZoneLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.8))
                        .offset(x: 14, y: 14)
                }
                if isJustBought {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                        .offset(x: 14, y: -14)
                }
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isZoneLocked ? .gray.opacity(0.6) : .white)
                        .lineLimit(1)
                    Text(item.category.rawValue.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(item.category.color.opacity(isZoneLocked ? 0.4 : 0.9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(item.category.color.opacity(0.1))
                        .clipShape(Capsule())
                }

                Text(item.description)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock").font(.system(size: 9))
                        Text(TimeEngine.shortFormatted(item.costSeconds))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(canAfford && !isZoneLocked ? .yellow : .red.opacity(0.7))

                    if isZoneLocked {
                        let reqName = ZoneProfile.allZones.first(where: { $0.index == item.requiredZoneIndex })?.name ?? "?"
                        HStack(spacing: 3) {
                            Image(systemName: "lock").font(.system(size: 8))
                            Text("Kräver \(reqName)")
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }

            Spacer(minLength: 4)

            // Buy button
            if isPurchased {
                VStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                    Text("KÖPT")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.7))
                }
                .frame(width: 46)
            } else {
                Button(action: { if !isZoneLocked { onBuy() } }) {
                    Text("KÖP")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(isZoneLocked ? .gray.opacity(0.5) : .black)
                        .frame(width: 46)
                        .padding(.vertical, 9)
                        .background(
                            isZoneLocked
                                ? Color.gray.opacity(0.2)
                                : (canAfford ? item.accentColor : Color.red.opacity(0.35))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .disabled(isZoneLocked)
            }
        }
        .padding(14)
        .background(
            isZoneLocked
                ? Color.white.opacity(0.02)
                : (isJustBought
                   ? Color.green.opacity(0.08)
                   : Color.white.opacity(0.05))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isJustBought
                        ? Color.green.opacity(0.6)
                        : (isZoneLocked ? Color.clear : item.accentColor.opacity(0.2)),
                    lineWidth: 1
                )
        )
        .opacity(isZoneLocked ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isJustBought)
    }
}

// MARK: - Color extension for gold

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

#Preview {
    TimeMarketView()
        .preferredColorScheme(.dark)
}
