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
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    @State private var selectedZone: ZoneProfile? = nil

    private var zones: [ZoneProfile] {
        ZoneProfile.allZones.reversed() // Visa rikaste zonen överst
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("ZONKARTA")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.top, 50)
                    Text("Nuvarande zon: \(gameState.currentZone.name)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.green)
                    Text("Ju högre zon, desto mer risk — och mer tid.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.bottom, 12)
                }

                // Vertikal hierarki — rikaste överst som i filmen
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(zones, id: \.name) { zone in
                            ZoneHierarchyRow(
                                zone: zone,
                                isCurrent: gameState.currentZone.name == zone.name,
                                isUnlocked: engine.balance >= zone.unlockRequirementSeconds
                            ) {
                                selectedZone = zone
                            }

                            if zone.name != zones.last?.name {
                                // Pil som visar rörelseriktning (nedåt = fattigare)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.15))
                                    .frame(height: 20)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
        }
        .overlay {
            if let zone = selectedZone {
                ZoneDetailOverlay(zone: zone, isUnlocked: engine.balance >= zone.unlockRequirementSeconds) {
                    selectedZone = nil
                }
            }
        }
    }
}

struct ZoneHierarchyRow: View {
    let zone: ZoneProfile
    let isCurrent: Bool
    let isUnlocked: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Zon-ikon med färg
                ZStack {
                    Circle()
                        .fill(isCurrent ? zone.color.opacity(0.3) : Color.white.opacity(0.05))
                        .frame(width: 44, height: 44)
                    Image(systemName: zone.zoneIcon)
                        .font(.system(size: 18))
                        .foregroundColor(isCurrent ? zone.color : (isUnlocked ? .white.opacity(0.7) : .white.opacity(0.25)))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(zone.name.uppercased())
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(isCurrent ? zone.color : (isUnlocked ? .white : .white.opacity(0.35)))
                        if isCurrent {
                            Text("DU ÄR HÄR")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(zone.color)
                                .cornerRadius(4)
                        }
                    }
                    Text(zone.description)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Label("\(Int(zone.taxRate * 100))% skatt", systemImage: "percent")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.yellow.opacity(0.8))
                        if zone.casinoAccess {
                            Label("Kasino", systemImage: "suit.spade.fill")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.8))
                        }
                        if zone.entryCostSeconds > 0 {
                            Label(TimeEngine.shortFormatted(zone.entryCostSeconds), systemImage: "lock.fill")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                }

                Spacer()

                Image(systemName: isUnlocked ? "chevron.right" : "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isUnlocked ? .white.opacity(0.2) : .white.opacity(0.1))
            }
            .padding(14)
            .background(isCurrent ? zone.color.opacity(0.08) : Color.white.opacity(0.03))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? zone.color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ZoneDetailOverlay: View {
    let zone: ZoneProfile
    let isUnlocked: Bool
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal)

                Image(systemName: zone.zoneIcon)
                    .font(.system(size: 40))
                    .foregroundColor(zone.color)

                Text(zone.name.uppercased())
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text(zone.description)
                    .font(.system(size: 13, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal)

                Divider().background(Color.white.opacity(0.15))

                VStack(spacing: 10) {
                    ZoneStatRow(label: "Skattesats", value: "\(Int(zone.taxRate * 100))%", color: .yellow)
                    ZoneStatRow(label: "Inträdesavgift", value: zone.entryCostSeconds > 0 ? TimeEngine.shortFormatted(zone.entryCostSeconds) : "Gratis", color: .orange)
                    ZoneStatRow(label: "Jobbmultiplikator", value: "x\(String(format: "%.1f", zone.workMultiplier))", color: .green)
                    ZoneStatRow(label: "Kasino", value: zone.casinoAccess ? "Ja" : "Nej", color: zone.casinoAccess ? .cyan : .gray)
                    ZoneStatRow(label: "Max boosts", value: "\(zone.maxActiveBoosts)", color: .purple)
                    if zone.passiveBonusSecondsPerDay > 0 {
                        ZoneStatRow(label: "Passiv inkomst/dag", value: TimeEngine.shortFormatted(TimeInterval(zone.passiveBonusSecondsPerDay)), color: .mint)
                    }
                }
                .padding(.horizontal)

                if !isUnlocked && zone.unlockRequirementSeconds > 0 {
                    Text("Kräver: \(TimeEngine.shortFormatted(zone.unlockRequirementSeconds)) för att låsa upp")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal)
                }
            }
            .padding()
            .frame(maxWidth: 340)
            .background(Color(red: 0.07, green: 0.07, blue: 0.1))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(zone.color.opacity(0.4), lineWidth: 1))
            .shadow(radius: 20)
        }
    }
}

struct ZoneStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

#Preview {
    ZoneVisual()
}
