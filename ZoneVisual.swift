import SwiftUI

// MARK: - ZoneVisual (Zone Map)

struct ZoneVisual: View {
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @StateObject private var zoneManager = ZoneManager.shared

    @State private var showMigrationSheet = false
    @State private var migrationTarget: ZoneProfile? = nil
    @State private var migrationResult: String = ""
    @State private var showMigrationResult = false

    private var currentZone: ZoneProfile {
        ZoneProfile.currentZone(forTime: engine.balance)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ZONKARTA")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Klassificerad information")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: currentZone.zoneIcon)
                            .font(.system(size: 11))
                        Text(currentZone.name)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(currentZone.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(currentZone.color.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(currentZone.color.opacity(0.4), lineWidth: 1))
                }
                .padding(.horizontal)
                .padding(.top, 60)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        // Vertical timeline line
                        VStack(spacing: 0) {
                            ForEach(ZoneProfile.allZones.reversed(), id: \.name) { zone in
                                let rel = zoneRelation(zone)
                                VStack(spacing: 0) {
                                    timelineDot(zone: zone, relation: rel)
                                    if zone.index > 0 {
                                        Rectangle()
                                            .fill(timelineLineColor(zone: zone, relation: rel))
                                            .frame(width: 2, height: zoneCardHeight(rel))
                                    }
                                }
                            }
                        }
                        .frame(width: 36)
                        .padding(.leading, 16)

                        // Zone cards
                        LazyVStack(spacing: 12) {
                            ForEach(ZoneProfile.allZones.reversed(), id: \.name) { zone in
                                let rel = zoneRelation(zone)
                                zoneCard(zone: zone, relation: rel)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.leading, 8)
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showMigrationSheet) {
            if let target = migrationTarget {
                migrationSheet(zone: target)
            }
        }
        .alert("Migration", isPresented: $showMigrationResult) {
            Button("OK") {}
        } message: { Text(migrationResult) }
    }

    // MARK: - Zone Relations
    enum ZoneRelation { case current, nextUp, lockedNear, lockedFar, below }

    func zoneRelation(_ zone: ZoneProfile) -> ZoneRelation {
        let cur = currentZone
        if zone.index == cur.index { return .current }
        if zone.index == cur.index + 1 { return .nextUp }
        if zone.index == cur.index + 2 { return .lockedNear }
        if zone.index > cur.index { return .lockedFar }
        return .below
    }

    // MARK: - Timeline Components
    func timelineDot(zone: ZoneProfile, relation: ZoneRelation) -> some View {
        ZStack {
            switch relation {
            case .current:
                Circle()
                    .fill(Color.green)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.green.opacity(0.5), lineWidth: 4))
                    .shadow(color: .green, radius: 6)
            case .nextUp:
                Circle()
                    .fill(Color.orange)
                    .frame(width: 10, height: 10)
                    .shadow(color: .orange.opacity(0.5), radius: 4)
            case .lockedNear:
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            case .lockedFar:
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 6, height: 6)
            case .below:
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 7, height: 7)
            }
        }
        .frame(width: 20, height: 20)
    }

    func timelineLineColor(zone: ZoneProfile, relation: ZoneRelation) -> Color {
        switch relation {
        case .current, .below: return Color.white.opacity(0.2)
        case .nextUp: return Color.orange.opacity(0.5)
        default: return Color.white.opacity(0.08)
        }
    }

    func zoneCardHeight(_ relation: ZoneRelation) -> CGFloat {
        switch relation {
        case .current: return 220
        case .nextUp: return 90
        case .lockedNear: return 52
        default: return 44
        }
    }

    // MARK: - Zone Cards
    @ViewBuilder
    func zoneCard(zone: ZoneProfile, relation: ZoneRelation) -> some View {
        switch relation {
        case .current:
            currentZoneCard(zone: zone)
        case .nextUp:
            nextZoneCard(zone: zone)
        case .lockedNear:
            lockedNearCard(zone: zone)
        case .lockedFar:
            lockedFarCard(zone: zone)
        case .below:
            belowCard(zone: zone)
        }
    }

    func currentZoneCard(zone: ZoneProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: zone.zoneIcon)
                    .font(.system(size: 18))
                    .foregroundColor(zone.color)
                Text(zone.name.uppercased())
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(zone.color)
                Spacer()
                Text("DIN ZON")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
            }

            Text(zone.description)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .italic()

            Divider().background(Color.white.opacity(0.1))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                zoneStatItem(label: "Skatt", value: "\(Int(zone.taxRate * 100))%", icon: "percent", color: .yellow)
                zoneStatItem(label: "Arbetsmult", value: "×\(String(format: "%.1f", zone.workMultiplier))", icon: "hammer.fill", color: .cyan)
                zoneStatItem(label: "Inflation/dag", value: "\(String(format: "%.1f", zone.inflationRatePerDay * 100))%", icon: "chart.line.uptrend.xyaxis", color: .orange)
                zoneStatItem(label: "Passiv/dag", value: TimeEngine.shortFormatted(TimeInterval(zone.passiveBonusSecondsPerDay)), icon: "clock.arrow.circlepath", color: .green)
            }

            if !zone.protections.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SKYDD")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    HStack(spacing: 6) {
                        ForEach(zone.protections, id: \.self) { p in
                            Text(p)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [zone.color.opacity(0.12), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(zone.color.opacity(0.4), lineWidth: 1.5))
    }

    func nextZoneCard(zone: ZoneProfile) -> some View {
        Button {
            migrationTarget = zone
            showMigrationSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: zone.zoneIcon)
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(zone.name)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("NÄSTA")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text("Inträde: \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.6))
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        }
    }

    func lockedNearCard(zone: ZoneProfile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
            Text(zone.name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Spacer()
            Text("???")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func lockedFarCard(zone: ZoneProfile) -> some View {
        HStack(spacing: 8) {
            Text(zone.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    func belowCard(zone: ZoneProfile) -> some View {
        HStack(spacing: 8) {
            Text(zone.name)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))
                .strikethrough(true, color: .white.opacity(0.15))
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    func zoneStatItem(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
    }

    // MARK: - Migration Sheet
    func migrationSheet(zone: ZoneProfile) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 28) {
                HStack {
                    Spacer()
                    Text("MIGRERA TILL \(zone.name.uppercased())")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.top, 40)

                let minRequired = zone.entryCostSeconds + zone.fallThresholdSeconds
                let canAfford = engine.balance >= minRequired
                VStack(spacing: 16) {
                    migrationRow(label: "Inträdesavgift", value: TimeEngine.shortFormatted(zone.entryCostSeconds), color: .orange)
                    migrationRow(label: "Buffert (stannar kvar)", value: TimeEngine.shortFormatted(zone.fallThresholdSeconds), color: .yellow)
                    migrationRow(label: "Totalt behövs", value: TimeEngine.shortFormatted(minRequired), color: canAfford ? .green : .red)
                    migrationRow(label: "Ditt saldo", value: TimeEngine.shortFormatted(engine.balance), color: canAfford ? .green : .red)
                    migrationRow(label: "Ny skattesats", value: "\(Int(zone.taxRate * 100))%", color: .yellow)
                    migrationRow(label: "Ny inflation/dag", value: "\(String(format: "%.1f", zone.inflationRatePerDay * 100))%", color: .orange)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Text(zone.description)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    let result = zoneManager.migrateToZone(zone)
                    migrationResult = result.message
                    showMigrationSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showMigrationResult = true
                        if result.success {
                            InflationManager.shared.recordZoneEntry(zone)
                            gameState.updateZone()
                        }
                    }
                } label: {
                    Text(canAfford ? "MIGRERA" : "OTILLRÄCKLIGA MEDEL")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAfford ? Color.orange : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canAfford)
                .padding(.horizontal)

                Spacer()
            }
        }
    }

    func migrationRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

#Preview {
    ZoneVisual()
        .preferredColorScheme(.dark)
}
