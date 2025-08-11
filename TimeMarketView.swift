//
//  TimeMarketView.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//


import SwiftUI

struct StoreItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let costSeconds: Int
    let requiredZone: String?
}

struct TimeMarketView: View {
    @Binding var timeRemaining: TimeInterval
    var currentZone: ZoneProfile?
    
    @State private var storeItems: [StoreItem] = [
        StoreItem(name: "🛡️ Tidssäkring", description: "Skydd i 10 minuter om du når 0 sek. Aktiveras automatiskt.", costSeconds: 36000, requiredZone: nil),
        StoreItem(name: "🧾 Intäktsbooster 10%", description: "+10% på dagsintjäning", costSeconds: 43200, requiredZone: "Midgrey"),
        StoreItem(name: "🧾 Intäktsbooster 20%", description: "+20% på dagsintjäning", costSeconds: 86400, requiredZone: "Risefield"),
        StoreItem(name: "🧾 Intäktsbooster 30%", description: "+30% på dagsintjäning", costSeconds: 144000, requiredZone: "Aetherpoint")
    ]
    
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(storeItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.white)

                        Text(item.description)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.gray)

                        HStack {
                            Text("Kostnad: 💸 \(item.costSeconds / 3600) h")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.yellow)
                            Spacer()
                            Button("Köp") {
                                let success = BoostManager.shared.purchase(item, currentZone: currentZone, currentTime: &timeRemaining)
                                if success {
                                    alertMessage = "✅ Du har köpt \(item.name)"
                                } else {
                                    if let requiredZone = item.requiredZone, requiredZone != currentZone?.name {
                                        alertMessage = "❌ Du måste vara i zonen \(requiredZone) för att köpa \(item.name)."
                                    } else if timeRemaining < Double(item.costSeconds) {
                                        alertMessage = "❌ Du har inte tillräckligt med tid för att köpa \(item.name)."
                                    } else {
                                        alertMessage = "❌ Köp misslyckades."
                                    }
                                }
                                showAlert = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.black)
                }
            }
            .listStyle(.plain)
            .background(Color.black)
            .navigationTitle("Tidens Marknad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
        }
        .background(Color.black)
        .alert("Butiksnotis", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

#Preview {
    TimeMarketView(timeRemaining: .constant(82800), currentZone: ZoneProfile.midgrey)
}
