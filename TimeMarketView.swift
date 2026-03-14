import SwiftUI

struct StoreItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let costSeconds: Int
    let requiredZone: String?
    let accentColor: Color
}

// MARK: - Time Market View (komplettomdesignad för att matcha app-designspråket)

struct TimeMarketView: View {
    @Binding var timeRemaining: TimeInterval
    var currentZone: ZoneProfile?

    @ObservedObject private var engine = TimeEngine.shared

    let storeItems: [StoreItem] = [
        StoreItem(name: "Tidssäkring", icon: "shield.fill",
                  description: "10 min skydd vid 0 sek. Aktiveras automatiskt.",
                  costSeconds: 36000, requiredZone: nil, accentColor: .blue),
        StoreItem(name: "Intäktsbooster +10%", icon: "bolt.fill",
                  description: "+10% på all dagsintjäning.",
                  costSeconds: 43200, requiredZone: "Midgrey", accentColor: .green),
        StoreItem(name: "Intäktsbooster +20%", icon: "bolt.circle.fill",
                  description: "+20% på all dagsintjäning.",
                  costSeconds: 86400, requiredZone: "Risefield", accentColor: .mint),
        StoreItem(name: "Intäktsbooster +30%", icon: "bolt.square.fill",
                  description: "+30% på all dagsintjäning.",
                  costSeconds: 144000, requiredZone: "Aetherpoint", accentColor: .cyan),
    ]

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertSuccess = false
    @Environment(\.dismiss) var dismiss

    private let zoneOrder = ["Duskline", "Midgrey", "Risefield", "Aetherpoint", "Novalux", "Vaultum", "Solara"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("TIDENS MARKNAD")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Saldo: \(TimeEngine.shortFormatted(engine.balance))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                    Spacer()
                    Color.clear.frame(width: 24)
                }
                .padding(.horizontal)
                .padding(.vertical, 16)

                Divider().background(Color.white.opacity(0.08))

                ScrollView {
                    VStack(spacing: 16) {
                        // Info banner
                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.cyan.opacity(0.7))
                                .font(.system(size: 14))
                            Text("Köpta boosts aktiveras omedelbart. Zoner låser upp bättre varor.")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .padding(12)
                        .background(Color.cyan.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                        .padding(.top, 16)

                        ForEach(storeItems) { item in
                            MarketItemCard(
                                item: item,
                                currentZone: currentZone,
                                zoneOrder: zoneOrder,
                                balance: engine.balance
                            ) { success, message in
                                alertSuccess = success
                                alertMessage = message
                                showAlert = true
                                if success {
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.success)
                                } else {
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.error)
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .alert(alertSuccess ? "Köp genomfört" : "Köp misslyckades", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
}

struct MarketItemCard: View {
    let item: StoreItem
    let currentZone: ZoneProfile?
    let zoneOrder: [String]
    let balance: TimeInterval
    let onPurchase: (Bool, String) -> Void

    @ObservedObject private var engine = TimeEngine.shared

    private var isZoneLocked: Bool {
        guard let required = item.requiredZone, let zone = currentZone else { return false }
        let playerIdx = zoneOrder.firstIndex(of: zone.name) ?? 0
        let requiredIdx = zoneOrder.firstIndex(of: required) ?? 0
        return playerIdx < requiredIdx
    }

    private var canAfford: Bool { balance >= Double(item.costSeconds) }
    private var isAvailable: Bool { !isZoneLocked && canAfford }

    var body: some View {
        HStack(spacing: 16) {
            // Ikon
            ZStack {
                Circle()
                    .fill(isZoneLocked ? Color.white.opacity(0.04) : item.accentColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: isZoneLocked ? "lock.fill" : item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isZoneLocked ? .white.opacity(0.2) : item.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(isZoneLocked ? .white.opacity(0.3) : .white)
                Text(item.description)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(isZoneLocked ? 0.2 : 0.5))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(TimeEngine.shortFormatted(TimeInterval(item.costSeconds)), systemImage: "clock")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(canAfford ? .yellow : .red.opacity(0.7))

                    if let required = item.requiredZone, isZoneLocked {
                        Label("Kräver \(required)", systemImage: "map.fill")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                }
            }

            Spacer()

            Button {
                var mutableTime = engine.balance
                let success = BoostManager.shared.purchase(item, currentZone: currentZone, currentTime: &mutableTime)
                if success {
                    onPurchase(true, "✓ \(item.name) aktiverat!")
                } else if isZoneLocked {
                    onPurchase(false, "Du måste vara i \(item.requiredZone ?? "") för att köpa detta.")
                } else if !canAfford {
                    onPurchase(false, "Inte tillräckligt med tid.\nBehöver: \(TimeEngine.shortFormatted(TimeInterval(item.costSeconds)))")
                } else {
                    onPurchase(false, "Köp misslyckades.")
                }
            } label: {
                Text(isZoneLocked ? "LÅST" : "KÖP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(isAvailable ? .black : .white.opacity(0.3))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isAvailable ? item.accentColor : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(!isAvailable)
        }
        .padding(16)
        .background(isZoneLocked ? Color.white.opacity(0.02) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isAvailable ? item.accentColor.opacity(0.25) : Color.clear, lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

#Preview {
    TimeMarketView(timeRemaining: .constant(82800), currentZone: ZoneProfile.midgrey)
}
