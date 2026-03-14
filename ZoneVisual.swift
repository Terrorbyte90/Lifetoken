import SwiftUI
import Combine

// MARK: - Zone Visual — Animerad Zonkarta
// Varje zon har sin egen atmosfär, animerade borders och unik karaktär.

struct ZoneVisual: View {
    @ObservedObject private var engine      = TimeEngine.shared
    @ObservedObject private var gameState   = GameState.shared
    @ObservedObject private var zoneManager = ZoneManager.shared
    @ObservedObject private var inflation   = InflationManager.shared

    @State private var selectedZone: ZoneProfile? = nil
    @State private var migrateResult: (show: Bool, message: String, success: Bool) = (false, "", false)
    @State private var animateOrbs = false

    private var zones: [ZoneProfile] { ZoneProfile.allZones.reversed() }

    var body: some View {
        ZStack {
            // Atmosfärisk bakgrund — graderar med nuvarande zon
            ZStack {
                Color.black
                RadialGradient(
                    gradient: Gradient(colors: [
                        zoneManager.currentZone.color.opacity(0.15),
                        Color.clear
                    ]),
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZoneMapHeader(
                    currentZone: zoneManager.currentZone,
                    inflation: inflation
                )

                // Vertikal zonhierarki
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(zones.enumerated()), id: \.element.name) { idx, zone in
                            let isCurrent = zone.name == zoneManager.currentZone.name
                            let isNext = zone.name == zoneManager.nextZone?.name
                            let isUnlocked = engine.balance >= zone.unlockRequirementSeconds

                            ZoneTimelineRow(
                                zone: zone,
                                isCurrent: isCurrent,
                                isNext: isNext,
                                isUnlocked: isUnlocked,
                                isLast: idx == zones.count - 1,
                                canMigrate: isNext && zoneManager.canMigrateToNext()
                            ) {
                                selectedZone = zone
                            } onMigrate: {
                                let result = zoneManager.migrateToNextZone()
                                migrateResult = (true, result.message, result.success)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        // Zone detail overlay
        .overlay {
            if let zone = selectedZone {
                ZoneDetailOverlay(
                    zone: zone,
                    isCurrent: zone.name == zoneManager.currentZone.name,
                    isNext: zone.name == zoneManager.nextZone?.name,
                    isUnlocked: engine.balance >= zone.unlockRequirementSeconds,
                    canMigrate: zone.name == zoneManager.nextZone?.name && zoneManager.canMigrateToNext(),
                    inflation: inflation
                ) {
                    selectedZone = nil
                } onMigrate: {
                    let result = zoneManager.migrateToNextZone()
                    migrateResult = (true, result.message, result.success)
                    selectedZone = nil
                }
            }
        }
        .alert(migrateResult.success ? "Migration klar ✓" : "Migration misslyckades",
               isPresented: .init(
                   get: { migrateResult.show },
                   set: { migrateResult.show = $0 }
               )) {
            Button("OK") {}
        } message: {
            Text(migrateResult.message)
        }
        .onAppear { animateOrbs = true }
    }
}

// MARK: - Header

private struct ZoneMapHeader: View {
    let currentZone: ZoneProfile
    let inflation: InflationManager
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 6) {
            Text("ZONKARTA")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top, 50)

            HStack(spacing: 8) {
                Image(systemName: currentZone.zoneIcon)
                    .font(.system(size: 13))
                    .foregroundColor(currentZone.color)
                Text("Nu: \(currentZone.name.uppercased())")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(currentZone.color)
                    .scaleEffect(pulse ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
            }
            .onAppear { pulse = true }

            // Inflation strip
            HStack(spacing: 6) {
                Image(systemName: inflation.severity.icon)
                    .font(.system(size: 10))
                    .foregroundColor(inflation.severity.color)
                Text("Inflation: \(inflation.percentLabel)  •  \(inflation.daysLabel) i zonen")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(inflation.severity.color.opacity(0.9))
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(inflation.severity.color.opacity(0.08))
            .clipShape(Capsule())

            Text("Varje zon kräver mer — inflation pressar dig uppåt")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .padding(.bottom, 14)
        }
    }
}

// MARK: - Zone Timeline Row

private struct ZoneTimelineRow: View {
    let zone: ZoneProfile
    let isCurrent: Bool
    let isNext: Bool
    let isUnlocked: Bool
    let isLast: Bool
    let canMigrate: Bool
    let onTap: () -> Void
    let onMigrate: () -> Void

    @State private var borderPhase: CGFloat = 0
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onTap) {
                ZoneCard(
                    zone: zone,
                    isCurrent: isCurrent,
                    isNext: isNext,
                    isUnlocked: isUnlocked,
                    canMigrate: canMigrate,
                    onMigrate: onMigrate
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Connector line to next zone
            if !isLast {
                ZoneConnector(zone: zone, isActive: isCurrent || isUnlocked)
            }
        }
    }
}

// MARK: - Zone Card

private struct ZoneCard: View {
    let zone: ZoneProfile
    let isCurrent: Bool
    let isNext: Bool
    let isUnlocked: Bool
    let canMigrate: Bool
    let onMigrate: () -> Void

    @State private var animatedBorder: CGFloat = 0
    @State private var glowAmount: CGFloat = 0.3
    @State private var orbOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // Zone-specific background
            RoundedRectangle(cornerRadius: 18)
                .fill(cardBackground)

            // Animated border for current zone
            if isCurrent {
                AnimatedZoneBorder(zone: zone)
            } else {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isNext ? zone.color.opacity(0.5) : (isUnlocked ? zone.color.opacity(0.2) : Color.white.opacity(0.06)),
                        lineWidth: isNext ? 1.5 : 1
                    )
            }

            // Ambient orb for current zone
            if isCurrent {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [zone.color.opacity(0.3), Color.clear]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: orbOffset, y: -20)
                    .blur(radius: 30)
                    .clipped()
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: orbOffset)
            }

            // Content
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Zone icon
                    ZoneIconBadge(zone: zone, isCurrent: isCurrent, isUnlocked: isUnlocked)

                    // Zone info
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(zone.name.uppercased())
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(isCurrent ? zone.color : (isUnlocked ? .white : .white.opacity(0.3)))

                            if isCurrent {
                                ZoneBadge(text: "DU ÄR HÄR", color: zone.color)
                            } else if isNext {
                                ZoneBadge(text: "NÄSTA", color: .yellow)
                            }
                        }

                        Text(zone.description)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(isUnlocked ? 0.5 : 0.2))
                            .lineLimit(2)

                        // Key stats row
                        HStack(spacing: 10) {
                            ZoneStatChip(icon: "percent", value: "\(Int(zone.taxRate * 100))%", color: .yellow)
                            ZoneStatChip(icon: "bolt.fill", value: "x\(String(format: "%.1f", zone.workMultiplier))", color: .green)
                            if zone.casinoAccess {
                                ZoneStatChip(icon: "suit.spade.fill", value: "Kasino", color: .cyan)
                            }
                            if zone.entryCostSeconds > 0 {
                                ZoneStatChip(icon: "lock.fill", value: TimeEngine.shortFormatted(zone.entryCostSeconds), color: .orange)
                            }
                        }
                    }

                    Spacer()

                    // Lock/unlocked indicator
                    if !isUnlocked && zone.entryCostSeconds > 0 {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.15))
                    } else if isCurrent {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16))
                            .foregroundColor(zone.color)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                .padding(16)

                // Migration button for next zone
                if isNext && canMigrate {
                    Divider()
                        .background(zone.color.opacity(0.2))

                    Button(action: onMigrate) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 15))
                            Text("FLYTTA TILL \(zone.name.uppercased())")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            Text("— \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
                                .font(.system(size: 11, design: .monospaced))
                                .opacity(0.7)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(zone.color)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 0))
                    .clipShape(
                        .rect(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 18,
                            bottomTrailingRadius: 18,
                            topTrailingRadius: 0
                        )
                    )
                } else if isNext && !canMigrate {
                    Divider().background(zone.color.opacity(0.15))
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.7))
                        Text("Kräver \(TimeEngine.shortFormatted(zone.entryCostSeconds)) för inträde")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .shadow(color: isCurrent ? zone.color.opacity(0.25) : .clear, radius: 16, y: 4)
        .onAppear {
            if isCurrent {
                withAnimation { orbOffset = 30 }
            }
        }
    }

    private var cardBackground: some ShapeStyle {
        if isCurrent {
            return AnyShapeStyle(
                LinearGradient(
                    gradient: Gradient(colors: [
                        zone.color.opacity(0.15),
                        zone.color.opacity(0.06),
                        Color.white.opacity(0.03)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else if isNext {
            return AnyShapeStyle(Color.white.opacity(0.06))
        } else if isUnlocked {
            return AnyShapeStyle(Color.white.opacity(0.04))
        } else {
            return AnyShapeStyle(Color.white.opacity(0.02))
        }
    }
}

// MARK: - Animated Zone Border

private struct AnimatedZoneBorder: View {
    let zone: ZoneProfile
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        zone.color,
                        zone.color.opacity(0.3),
                        zone.color.opacity(0.8),
                        zone.color.opacity(0.15),
                        zone.color,
                    ]),
                    center: .center,
                    angle: .degrees(phase)
                ),
                lineWidth: 2
            )
            .onAppear {
                withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                    phase = 360
                }
            }
    }
}

// MARK: - Zone Icon Badge

private struct ZoneIconBadge: View {
    let zone: ZoneProfile
    let isCurrent: Bool
    let isUnlocked: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            // Outer glow ring for current zone
            if isCurrent {
                Circle()
                    .stroke(zone.color.opacity(pulse ? 0.6 : 0.2), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)
            }

            Circle()
                .fill(
                    isCurrent
                    ? AnyShapeStyle(RadialGradient(gradient: Gradient(colors: [zone.color.opacity(0.4), zone.color.opacity(0.1)]), center: .center, startRadius: 0, endRadius: 30))
                    : AnyShapeStyle(Color.white.opacity(isUnlocked ? 0.07 : 0.03))
                )
                .frame(width: 50, height: 50)

            Image(systemName: isUnlocked ? zone.zoneIcon : "lock.fill")
                .font(.system(size: 20))
                .foregroundColor(
                    isCurrent ? zone.color :
                    (isUnlocked ? .white.opacity(0.7) : .white.opacity(0.2))
                )
        }
        .onAppear { if isCurrent { pulse = true } }
    }
}

// MARK: - Zone Connector

private struct ZoneConnector: View {
    let zone: ZoneProfile
    let isActive: Bool

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isActive ? zone.color.opacity(0.5) : Color.white.opacity(0.08),
                                Color.white.opacity(0.04)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: 20)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(isActive ? zone.color.opacity(0.6) : .white.opacity(0.12))
                    .padding(.vertical, 2)
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 2, height: 20)
            }
            Spacer()
        }
    }
}

// MARK: - Small components

private struct ZoneBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(color)
            .cornerRadius(4)
    }
}

private struct ZoneStatChip: View {
    let icon: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8))
            Text(value).font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundColor(color.opacity(0.9))
    }
}

// MARK: - Zone Detail Overlay

struct ZoneDetailOverlay: View {
    let zone: ZoneProfile
    let isCurrent: Bool
    let isNext: Bool
    let isUnlocked: Bool
    let canMigrate: Bool
    let inflation: InflationManager
    let onDismiss: () -> Void
    let onMigrate: () -> Void

    @State private var borderPhase: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ScrollView {
                VStack(spacing: 20) {
                    // Close
                    HStack {
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    // Zone icon + glow
                    ZStack {
                        Circle()
                            .fill(zone.color.opacity(0.15))
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)

                        Circle()
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [zone.color, zone.color.opacity(0.2), zone.color]),
                                    center: .center,
                                    angle: .degrees(borderPhase)
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 80, height: 80)
                            .onAppear {
                                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                                    borderPhase = 360
                                }
                            }

                        Image(systemName: zone.zoneIcon)
                            .font(.system(size: 36))
                            .foregroundColor(zone.color)
                    }

                    // Name + badge
                    VStack(spacing: 6) {
                        Text(zone.name.uppercased())
                            .font(.system(size: 26, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        if isCurrent {
                            ZoneBadge(text: "DIN NUVARANDE ZON", color: zone.color)
                        } else if isNext {
                            ZoneBadge(text: "NÄSTA ZON", color: .yellow)
                        }
                    }

                    Text(zone.description)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Divider().background(zone.color.opacity(0.2))

                    // Stats grid
                    VStack(spacing: 10) {
                        ZoneStatRow(label: "Skattesats", value: "\(Int(zone.taxRate * 100))%", color: .yellow)
                        ZoneStatRow(label: "Inträdesavgift", value: zone.entryCostSeconds > 0 ? TimeEngine.shortFormatted(zone.entryCostSeconds) : "Gratis", color: .orange)
                        ZoneStatRow(label: "Jobbmultiplikator", value: "x\(String(format: "%.1f", zone.workMultiplier))", color: .green)
                        ZoneStatRow(label: "Kasino", value: zone.casinoAccess ? "Tillgängligt" : "Låst", color: zone.casinoAccess ? .cyan : .gray)
                        ZoneStatRow(label: "Max boosts", value: "\(zone.maxActiveBoosts)", color: .purple)
                        if zone.passiveBonusSecondsPerDay > 0 {
                            ZoneStatRow(label: "Passiv inkomst/dag", value: TimeEngine.shortFormatted(TimeInterval(zone.passiveBonusSecondsPerDay)), color: .mint)
                        }
                        ZoneStatRow(label: "Inflation/dag", value: "\(String(format: "%.1f", zone.inflationRatePerDay * 100))%", color: .red.opacity(0.8))
                    }
                    .padding(.horizontal)

                    // Current inflation (if this is the current zone)
                    if isCurrent {
                        VStack(spacing: 8) {
                            Divider().background(inflation.severity.color.opacity(0.3))
                            HStack {
                                Image(systemName: inflation.severity.icon)
                                    .foregroundColor(inflation.severity.color)
                                Text("AKTUELL INFLATION")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(inflation.severity.color.opacity(0.8))
                            }
                            HStack {
                                Text("Du har bott här \(inflation.daysLabel)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.55))
                                Spacer()
                                Text(inflation.percentLabel)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(inflation.severity.color)
                            }
                            Text("Inflation reducerar dina jobbinkomster. Flytta upp för att nollställa.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.35))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                    }

                    // Migrate button
                    if isNext {
                        if canMigrate {
                            Button(action: onMigrate) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 18))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("FLYTTA TILL \(zone.name.uppercased())")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        Text("Kostnad: \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
                                            .font(.system(size: 10, design: .monospaced))
                                            .opacity(0.75)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(.black)
                                .padding()
                                .background(zone.color)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.orange)
                                    Text("Kräver \(TimeEngine.shortFormatted(zone.entryCostSeconds)) för inträde")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.orange.opacity(0.8))
                                }
                                if zone.unlockRequirementSeconds > 0 {
                                    Text("Minimikrav: \(TimeEngine.shortFormatted(zone.unlockRequirementSeconds))")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .frame(maxWidth: 360)
            .background(
                ZStack {
                    Color(red: 0.06, green: 0.06, blue: 0.09)
                    // Zone-colored corner glow
                    RadialGradient(
                        gradient: Gradient(colors: [zone.color.opacity(0.12), Color.clear]),
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 200
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [zone.color.opacity(0.5), zone.color.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: zone.color.opacity(0.2), radius: 30, y: 10)
            .padding(.horizontal, 16)
            .padding(.vertical, 60)
        }
        .animation(.easeInOut(duration: 0.25), value: zone.name)
    }
}

// MARK: - ZoneStatRow (shared helper, also used by ZoneDetailOverlay)

struct ZoneStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
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
