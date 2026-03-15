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

    enum ItemCategory: String {
        case skydd     = "Skydd"
        case boost     = "Boost"
        case verktyg   = "Verktyg"
        case premium   = "Premium"
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
        let zone = GameState.shared.currentZone
        let balance = TimeEngine.shared.balance
        guard canPurchase(item, zone: zone, balance: balance) == .available else { return false }
        guard TimeEngine.shared.deductTime(item.costSeconds) else { return false }

        // Apply item effect
        applyEffect(item)

        purchasedIds.insert(item.id)
        UserDefaults.standard.set(Array(purchasedIds), forKey: purchasedKey)
        return true
    }

    private func applyEffect(_ item: StoreItem) {
        switch item.id {
        case "orakel":
            // Reveal next crash point hint — stored as a UserDefaults flag for CrashView
            UserDefaults.standard.set(true, forKey: "orakel_active")
        case "tidsstopp":
            // Pause time drain for 5 minutes via flag
            let expiry = Date().addingTimeInterval(300)
            UserDefaults.standard.set(expiry.timeIntervalSince1970, forKey: "tidsstopp_expiry")
        default:
            // Store boost name in active boosts list (compatible with BoostManager)
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
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var market = MarketManager.shared

    @State private var selectedCategory: StoreItem.ItemCategory? = nil
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

    let allItems: [StoreItem] = [
        // Skydd
        StoreItem(id: "tidsskold",      name: "Tidssköld Enkel",       description: "Skydd i 10 min om du når 0 sek. Aktiveras automatiskt vid kritisk nivå.",
                  icon: "shield",             costSeconds: 36000,  requiredZoneIndex: 0, accentColor: .cyan,   category: .skydd),
        StoreItem(id: "tidsskold_pro",  name: "Tidssköld Pro",         description: "Skydd i 30 min vid kritisk tid. Absorberar upp till 50% av dagskostnad.",
                  icon: "shield.lefthalf.filled", costSeconds: 86400, requiredZoneIndex: 5, accentColor: .cyan, category: .skydd),
        StoreItem(id: "tidsskold_elit", name: "Tidssköld Elite",       description: "Full immunitetsperiod 60 min. Ingen tidsdrain under aktivering.",
                  icon: "shield.fill",        costSeconds: 259200, requiredZoneIndex: 9,  accentColor: .blue,  category: .skydd),
        StoreItem(id: "natverksskydd",  name: "Nätverksskydd",         description: "Blockerar serverbaserade tidsjusteringar i 24h. Anti-cheat-skydd.",
                  icon: "lock.shield",        costSeconds: 72000,  requiredZoneIndex: 5,  accentColor: .cyan,  category: .skydd),
        StoreItem(id: "sparningsskydd", name: "Spårningsskydd",        description: "Döljer din balans från andra spelare och servern i 12h.",
                  icon: "eye.slash",          costSeconds: 43200,  requiredZoneIndex: 6,  accentColor: .gray,  category: .skydd),

        // Boost
        StoreItem(id: "boost_10",       name: "Intäktsbooster 10%",    description: "+10% på all dagsintjäning i 24h. Inkluderar hälso- och jobbinkomst.",
                  icon: "bolt",              costSeconds: 43200,  requiredZoneIndex: 3,  accentColor: .green,  category: .boost),
        StoreItem(id: "boost_20",       name: "Intäktsbooster 20%",    description: "+20% på all dagsintjäning i 24h.",
                  icon: "bolt.fill",         costSeconds: 86400,  requiredZoneIndex: 5,  accentColor: .green,  category: .boost),
        StoreItem(id: "boost_30",       name: "Intäktsbooster 30%",    description: "+30% på all dagsintjäning i 24h. Stark effekt, hög kostnad.",
                  icon: "bolt.badge.a",      costSeconds: 144000, requiredZoneIndex: 7,  accentColor: .yellow, category: .boost),
        StoreItem(id: "boost_50",       name: "Intäktsbooster 50%",    description: "+50% på all dagsintjäning i 24h. Solara-klass effekt.",
                  icon: "bolt.circle.fill",  costSeconds: 432000, requiredZoneIndex: 12, accentColor: .orange, category: .boost),
        StoreItem(id: "tidsbatteri",    name: "Tidsbatteri",           description: "Lagra upp till 8h tid utanför tidsmätaren. Frys din balans vid ett givet värde.",
                  icon: "battery.100",       costSeconds: 57600,  requiredZoneIndex: 4,  accentColor: .green,  category: .boost),
        StoreItem(id: "dna_boost",      name: "DNA-Boost",             description: "Dubbel hälsoinkomst nästa 24h. Steg, kalorier och sömn räknas dubbelt.",
                  icon: "dna",               costSeconds: 172800, requiredZoneIndex: 8,  accentColor: .pink,   category: .boost),

        // Verktyg
        StoreItem(id: "tidsstopp",      name: "Tidsstopp",             description: "Pausa tidsdrain i 5 minuter. Nödbroms för krissituationer.",
                  icon: "pause.circle",      costSeconds: 21600,  requiredZoneIndex: 5,  accentColor: .orange, category: .verktyg),
        StoreItem(id: "orakel",         name: "Orakel",                description: "Avslöjar kraschpunkt i nästa Crash-runda. Engångsanvändning.",
                  icon: "eye.trianglebadge.exclamationmark", costSeconds: 28800, requiredZoneIndex: 8, accentColor: .purple, category: .verktyg),

        // Premium
        StoreItem(id: "immunitetsmod",  name: "Immunitetsmod",         description: "Immun mot zonfall i 72h. Ingen automatisk nedgradering vid låg balans.",
                  icon: "checkmark.shield.fill", costSeconds: 518400, requiredZoneIndex: 11, accentColor: .gold, category: .premium),
        StoreItem(id: "solarakarna",    name: "Solarakärna",           description: "Passiv inkomst +86400s/dag under 3 dagar. Solara-exklusivt.",
                  icon: "sun.max.fill",      costSeconds: 1036800, requiredZoneIndex: 13, accentColor: .yellow, category: .premium),
    ]

    var displayItems: [StoreItem] {
        if let cat = selectedCategory {
            return allItems.filter { $0.category == cat }
        }
        return allItems
    }

    var categories: [StoreItem.ItemCategory] { [.skydd, .boost, .verktyg, .premium] }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.05), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    headerSection
                    categoryPicker
                        .padding(.bottom, 16)
                    itemsSection
                    Spacer(minLength: 100)
                }
            }
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {}
        } message: { Text(alertMessage) }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Text("TIDENS MARKNAD")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top, 60)
            Text("Saldo: \(TimeEngine.formatted(engine.balance))")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.yellow)
            Text("Zon: \(gameState.currentZone.name)  (nivå \(gameState.currentZone.index))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
    }

    // MARK: Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(label: "Alla", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categories, id: \.self) { cat in
                    CategoryChip(label: cat.rawValue, isSelected: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Items

    private var itemsSection: some View {
        VStack(spacing: 12) {
            ForEach(displayItems) { item in
                MarketItemCard(
                    item: item,
                    zone: gameState.currentZone,
                    balance: engine.balance
                ) {
                    handlePurchase(item)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: Purchase Logic

    private func handlePurchase(_ item: StoreItem) {
        let result = market.canPurchase(item, zone: gameState.currentZone, balance: engine.balance)
        switch result {
        case .zoneLocked:
            let requiredZone = ZoneProfile.allZones.first(where: { $0.index == item.requiredZoneIndex })?.name ?? "okänd zon"
            alertTitle = "Zon låst"
            alertMessage = "Du måste vara i \(requiredZone) (nivå \(item.requiredZoneIndex)) för att köpa \(item.name)."
        case .insufficientFunds:
            alertTitle = "Otillräcklig tid"
            alertMessage = "Du har inte tillräckligt med tid. Behövs: \(TimeEngine.shortFormatted(item.costSeconds))."
        case .available:
            if market.purchase(item) {
                alertTitle = "Köp bekräftat"
                alertMessage = "\(item.name) har aktiverats."
            } else {
                alertTitle = "Fel"
                alertMessage = "Köpet misslyckades. Försök igen."
            }
        }
        showAlert = true
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .black : .white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.green : Color.white.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Market Item Card

struct MarketItemCard: View {
    let item: StoreItem
    let zone: ZoneProfile
    let balance: TimeInterval
    let onBuy: () -> Void

    var purchaseResult: MarketManager.PurchaseResult {
        MarketManager.shared.canPurchase(item, zone: zone, balance: balance)
    }

    var isZoneLocked: Bool { purchaseResult == .zoneLocked }
    var canAfford: Bool { balance >= item.costSeconds }

    var body: some View {
        HStack(spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(isZoneLocked ? Color.gray.opacity(0.15) : item.accentColor.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isZoneLocked ? .gray : item.accentColor)
                if isZoneLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.7))
                        .offset(x: 12, y: 12)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(isZoneLocked ? .gray : .white)

                    Text(item.category.rawValue.uppercased())
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(item.accentColor.opacity(0.7))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(item.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(item.description)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label(TimeEngine.shortFormatted(item.costSeconds), systemImage: "clock")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(canAfford && !isZoneLocked ? .yellow : .red.opacity(0.7))

                    if isZoneLocked {
                        let reqName = ZoneProfile.allZones.first(where: { $0.index == item.requiredZoneIndex })?.name ?? "?"
                        Label("Kräver \(reqName)", systemImage: "lock")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }

            Spacer()

            Button(action: { if !isZoneLocked { onBuy() } }) {
                Text("KÖP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isZoneLocked ? .gray : .black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isZoneLocked ? Color.gray.opacity(0.3) : (canAfford ? Color.green : Color.red.opacity(0.4)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isZoneLocked)
        }
        .padding(14)
        .background(isZoneLocked ? Color.white.opacity(0.02) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isZoneLocked ? Color.clear : item.accentColor.opacity(0.2), lineWidth: 1)
        )
        .opacity(isZoneLocked ? 0.55 : 1.0)
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
