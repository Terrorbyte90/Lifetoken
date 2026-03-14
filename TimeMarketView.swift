import SwiftUI

// MARK: - Time Market View — Tidens Marknad

struct TimeMarketView: View {
    @Binding var timeRemaining: TimeInterval
    var currentZone: ZoneProfile?

    @ObservedObject private var engine  = TimeEngine.shared
    @ObservedObject private var shop    = ShopManager.shared

    @State private var selectedCategory: ShopCategory? = nil
    @State private var showAlert        = false
    @State private var alertMessage     = ""
    @State private var alertSuccess     = false
    @State private var showEffectsSheet = false
    @Environment(\.dismiss) var dismiss

    private var filteredItems: [ShopItem] {
        let items = ShopItem.allItems(for: currentZone)
        guard let cat = selectedCategory else { return items }
        return items.filter { $0.category == cat }
    }

    private var activeEffectCount: Int {
        shop.activeEffects.filter { !$0.isExpired }.count
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ──
                HStack(alignment: .center) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Spacer()

                    VStack(spacing: 3) {
                        Text("TIDENS MARKNAD")
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(TimeEngine.shortFormatted(engine.balance))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                    }

                    Spacer()

                    // Aktiva effekter-knapp
                    Button {
                        showEffectsSheet = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18))
                                .foregroundColor(.yellow.opacity(0.8))
                            if activeEffectCount > 0 {
                                Text("\(activeEffectCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(3)
                                    .background(Color.green)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 14)

                Divider().background(Color.white.opacity(0.08))

                // ── Kategori-filter ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ShopFilterChip(label: "Alla", icon: "square.grid.2x2.fill",
                                       color: .white, isSelected: selectedCategory == nil) {
                            withAnimation(.spring(response: 0.25)) { selectedCategory = nil }
                        }
                        ForEach(ShopCategory.allCases, id: \.self) { cat in
                            ShopFilterChip(label: cat.rawValue, icon: cat.icon,
                                           color: cat.color, isSelected: selectedCategory == cat) {
                                withAnimation(.spring(response: 0.25)) {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }

                Divider().background(Color.white.opacity(0.05))

                // ── Varor ──
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Aktiva effekter-banner
                        if activeEffectCount > 0 {
                            ActiveEffectsBanner(effects: shop.activeEffects.filter { !$0.isExpired })
                                .padding(.horizontal)
                                .padding(.top, 14)
                        }

                        if filteredItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.15))
                                Text("Inga varor i denna kategori")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        } else {
                            ForEach(filteredItems) { item in
                                ShopItemCard(
                                    item: item,
                                    currentZone: currentZone,
                                    balance: engine.balance,
                                    isAlreadyActive: shop.hasEffect(item.id)
                                ) { success, msg in
                                    alertSuccess = success
                                    alertMessage = msg
                                    showAlert = true
                                    let gen = UINotificationFeedbackGenerator()
                                    gen.notificationOccurred(success ? .success : .error)
                                    if success { shop.cleanExpired() }
                                }
                            }
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.top, filteredItems.isEmpty ? 0 : 8)
                }
            }
        }
        .alert(alertSuccess ? "Köp genomfört ✓" : "Köp misslyckades", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showEffectsSheet) {
            ActiveEffectsView()
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Shop Item Card

struct ShopItemCard: View {
    let item: ShopItem
    let currentZone: ZoneProfile?
    let balance: TimeInterval
    let isAlreadyActive: Bool
    let onPurchase: (Bool, String) -> Void

    @State private var pressed = false

    private let zoneOrder = ["Duskline", "Midgrey", "Risefield", "Aetherpoint", "Novalux", "Vaultum", "Solara"]

    private var isZoneLocked: Bool {
        guard let required = item.requiredZone, let zone = currentZone else { return false }
        let playerIdx = zoneOrder.firstIndex(of: zone.name) ?? 0
        let requiredIdx = zoneOrder.firstIndex(of: required) ?? 0
        return playerIdx < requiredIdx
    }

    private var canAfford: Bool { balance >= item.costSeconds }
    private var isAvailable: Bool { !isZoneLocked && canAfford && !isAlreadyActive }

    var body: some View {
        HStack(spacing: 14) {

            // Ikon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isZoneLocked
                          ? Color.white.opacity(0.04)
                          : item.accentColor.opacity(isAlreadyActive ? 0.2 : 0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: isZoneLocked ? "lock.fill" : item.icon)
                    .font(.system(size: 22))
                    .foregroundColor(
                        isZoneLocked ? .white.opacity(0.15) :
                        (isAlreadyActive ? item.accentColor : item.accentColor.opacity(0.9))
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isZoneLocked ? .white.opacity(0.3) : .white)
                    if isAlreadyActive {
                        Text("AKTIV")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(item.accentColor)
                            .clipShape(Capsule())
                    }
                }

                Text(item.effect)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(isZoneLocked ? .white.opacity(0.2) : item.accentColor.opacity(0.85))

                Text(item.description)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(isZoneLocked ? 0.2 : 0.42))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label(TimeEngine.shortFormatted(item.costSeconds), systemImage: "clock")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(canAfford ? .yellow.opacity(0.9) : .red.opacity(0.65))

                    if let req = item.requiredZone, isZoneLocked {
                        Label("Kräver \(req)", systemImage: "map.fill")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                }
            }

            Spacer()

            // Köp-knapp
            Button {
                let (ok, msg) = ShopManager.shared.purchase(item, currentZone: currentZone)
                onPurchase(ok, msg)
            } label: {
                Text(isAlreadyActive ? "✓" : (isZoneLocked ? "LÅST" : "KÖP"))
                    .font(.system(size: isAlreadyActive ? 16 : 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isAvailable ? .black : .white.opacity(0.25))
                    .frame(width: 52, height: 36)
                    .background(isAvailable ? item.accentColor : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .disabled(!isAvailable)
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: pressed)
            .simultaneousGesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in if isAvailable { pressed = true } }
                .onEnded   { _ in pressed = false }
            )
        }
        .padding(14)
        .background(isZoneLocked ? Color.white.opacity(0.02) :
                    (isAlreadyActive ? item.accentColor.opacity(0.06) : Color.white.opacity(0.06)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isAlreadyActive ? item.accentColor.opacity(0.4) :
                    (isAvailable ? item.accentColor.opacity(0.2) : Color.clear),
                    lineWidth: 1
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - Active Effects Banner

struct ActiveEffectsBanner: View {
    let effects: [ActiveEffect]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)
                Text("AKTIVA EFFEKTER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.8))
            }

            ForEach(effects) { effect in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                        .shadow(color: .green, radius: 3)
                    Text(effect.name)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    if effect.remainingSeconds > 0 {
                        Text(TimeEngine.shortFormatted(effect.remainingSeconds))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        Text("Permanent")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.yellow.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Active Effects Sheet

struct ActiveEffectsView: View {
    @ObservedObject private var shop = ShopManager.shared
    @Environment(\.dismiss) var dismiss

    var activeEffects: [ActiveEffect] {
        shop.activeEffects.filter { !$0.isExpired }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("AKTIVA EFFEKTER")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }
                .overlay(alignment: .trailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.trailing)
                }
                .padding()

                Divider().background(Color.white.opacity(0.08))

                if activeEffects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.1))
                        Text("Inga aktiva effekter")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                        Text("Köp varor i butiken för att aktivera effekter.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.2))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(activeEffects) { effect in
                                EffectRow(effect: effect)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

struct EffectRow: View {
    let effect: ActiveEffect

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "sparkle")
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(effect.name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(effect.expiresAt != nil
                     ? "Löper ut om \(TimeEngine.shortFormatted(effect.remainingSeconds))"
                     : "Permanent effekt (engångs)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            if let exp = effect.expiresAt {
                // Cirkulär progress
                let fraction = min(1.0, effect.remainingSeconds / exp.timeIntervalSince(effect.purchasedAt))
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 3)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .trim(from: 0, to: fraction)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    )
            } else {
                Image(systemName: "infinity")
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Filter Chip

struct ShopFilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(isSelected ? color : Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }
}

// MARK: - ShopItem extension — items available for zone

extension ShopItem {
    static func allItems(for zone: ZoneProfile?) -> [ShopItem] {
        ShopManager.allItems
    }
}

// MARK: - Preview

#Preview {
    TimeMarketView(timeRemaining: .constant(82800), currentZone: ZoneProfile.midgrey)
}
