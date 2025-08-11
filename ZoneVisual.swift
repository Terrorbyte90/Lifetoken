//
//  ZoneVisual.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-17.
//

import SwiftUI
import Combine
import Foundation
import Observation
import SwiftData
// import LifeToken

private struct ZoneRowView: View {
    let zone: ZoneProfile
    let isCurrent: Bool
    let onTap: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: isCurrent ? [Color.green.opacity(0.6), Color.green.opacity(0.3)] : [Color.blue.opacity(0.4), Color.blue.opacity(0.2)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        .blur(radius: 2)
                )

            VStack(spacing: 6) {
                Image(systemName: isCurrent ? "scope" : "globe.americas.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)
                    .foregroundColor(.white)

                Text(zone.name)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 1)

                Text("Inträde: \(zone.entryCostSeconds / 3600, specifier: "%.0f")h")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
        }
        .frame(minWidth: 120, minHeight: 120)
        .onTapGesture {
            onTap()
        }
    }
}

struct ZoneVisual: View {
    let zoneManager = ZoneManager.shared
    let currentTime = 86400.0

    @State private var selectedZone: ZoneProfile? = nil

    private var zones: [ZoneProfile] {
        ZoneProfile.allZones
    }

    @ViewBuilder
    private var zoneListView: some View {
        let columns = [GridItem(.adaptive(minimum: 120), spacing: 24)]
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(zones, id: \.name) { zone in
                ZoneRowView(
                    zone: zone,
                    isCurrent: zoneManager.currentZone(forTime: currentTime).name == zone.name,
                    onTap: {
                        selectedZone = zone
                    }
                )
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Zonkarta")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            ScrollView {
                zoneListView
                    .padding()
            }

            Spacer()
        }
        .padding()
        .background(Color.black)
        .overlay {
            if let zone = selectedZone {
                ZStack {
                    Color.black.opacity(0.6)
                        .ignoresSafeArea()
                        .onTapGesture {
                            selectedZone = nil
                        }

                    VStack(spacing: 20) {
                        Text(zone.name)
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)

                        Text(zoneDescription(for: zone.name))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: 300)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(radius: 10)
                    .onTapGesture {
                        selectedZone = nil
                    }
                }
            }
        }
    }
    
    private func zoneDescription(for name: String) -> String {
        switch name {
        case "Duskline": return "Startzonen. Skattefri och trygg. Perfekt för nybörjare."
        case "Midgrey": return "Låg skatt och första steget mot ökad frihet och boosts."
        case "Risefield": return "Stegbonus aktiveras. En dynamisk zon för utveckling."
        case "Aetherpoint": return "Passiva bonussekunder och reducerade appkostnader."
        case "Novalux": return "Stark boosteffekt och passiv inkomst. Avancerad zon."
        case "Vaultum": return "Skyddad zon med balans mellan kostnad och belöning."
        case "Solara": return "Ultimat zon med maxade boosts, men till högt pris."
        default: return "Det här är en zon i LifeToken."
        }
    }
}

#Preview {
    ZoneVisual()
}
