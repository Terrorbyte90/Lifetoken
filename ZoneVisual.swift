import SwiftUI

// MARK: - ZoneVisual (Redesigned Map)

struct ZoneVisual: View {
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @StateObject  private var zoneManager = ZoneManager.shared

    @State private var showMigrationSheet  = false
    @State private var migrationTarget: ZoneProfile? = nil
    @State private var migrationResult     = ""
    @State private var showMigrationResult = false
    @State private var mapOffset: CGFloat  = 0

    private var currentZone: ZoneProfile {
        ZoneProfile.currentZone(forTime: engine.balance)
    }

    var body: some View {
        ZStack {
            mapBackground
            VStack(spacing: 0) {
                mapHeader
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(ZoneProfile.allZones.reversed(), id: \.name) { zone in
                            zoneRow(zone: zone)
                        }
                        Spacer(minLength: 120)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .sheet(isPresented: $showMigrationSheet) {
            if let target = migrationTarget { migrationSheet(zone: target) }
        }
        .alert("Migration", isPresented: $showMigrationResult) {
            Button("OK") {}
        } message: { Text(migrationResult) }
    }

    // MARK: - Background

    private var mapBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Grid overlay
            Canvas { ctx, sz in
                let spacing: CGFloat = 28
                for x in stride(from: 0.0, to: sz.width, by: spacing) {
                    var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: sz.height))
                    ctx.stroke(p, with: .color(Color.white.opacity(0.03)), lineWidth: 1)
                }
                for y in stride(from: 0.0, to: sz.height, by: spacing) {
                    var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: sz.width, y: y))
                    ctx.stroke(p, with: .color(Color.white.opacity(0.03)), lineWidth: 1)
                }
            }
            .ignoresSafeArea()
            // Atmospheric glow at top
            LinearGradient(
                colors: [currentZone.color.opacity(0.08), .clear],
                startPoint: .top, endPoint: .center
            ).ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var mapHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("ZONKARTA")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)
                Text("14 TERRITORIER • KLASSIFICERAT")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
                    .tracking(2)
            }
            Spacer()
            // Current zone badge
            HStack(spacing: 5) {
                Image(systemName: currentZone.zoneIcon)
                    .font(.system(size: 10))
                Text(currentZone.name)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(currentZone.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(currentZone.color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(currentZone.color.opacity(0.5), lineWidth: 1))
            .shadow(color: currentZone.color.opacity(0.3), radius: 6)
        }
        .padding(.horizontal)
        .padding(.top, 60)
        .padding(.bottom, 14)
        .background(
            LinearGradient(colors: [Color.black, Color.black.opacity(0)], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Zone Row

    @ViewBuilder
    func zoneRow(zone: ZoneProfile) -> some View {
        let rel = zoneRelation(zone)
        switch rel {
        case .current:   currentZoneRow(zone: zone)
        case .nextUp:    nextZoneRow(zone: zone)
        case .lockedNear, .lockedFar: lockedZoneRow(zone: zone, near: rel == .lockedNear)
        case .below:     completedZoneRow(zone: zone)
        }
    }

    // Current zone — large glowing card
    func currentZoneRow(zone: ZoneProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Connector line above
            connectorLine(color: zone.color, height: 20)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(zone.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .shadow(color: zone.color.opacity(0.6), radius: 10)
                        Image(systemName: zone.zoneIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(zone.color)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(zone.name.uppercased())
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundColor(zone.color)
                            Text("DIN ZON")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(zone.color)
                                .clipShape(Capsule())
                        }
                        Text(zone.description)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                    }
                }

                Divider().background(zone.color.opacity(0.2))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    mapStatCell(label: "SKATT", value: "\(Int(zone.taxRate * 100))%", icon: "percent", color: .yellow)
                    mapStatCell(label: "ARBETE ×", value: String(format: "%.1f", zone.workMultiplier), icon: "hammer.fill", color: .cyan)
                    mapStatCell(label: "INFLATION", value: String(format: "%.1f%%", zone.inflationRatePerDay * 100), icon: "chart.line.uptrend.xyaxis", color: .orange)
                    mapStatCell(label: "PASSIV/DAG", value: TimeEngine.shortFormatted(TimeInterval(zone.passiveBonusSecondsPerDay)), icon: "clock.arrow.circlepath", color: .green)
                }

                if !zone.protections.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(zone.protections, id: \.self) { p in
                            Text("🛡 \(p)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(18)
            .background(
                ZStack {
                    LinearGradient(colors: [zone.color.opacity(0.12), Color.black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    LinearGradient(colors: [Color.white.opacity(0.04), .clear], startPoint: .top, endPoint: .center)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(
                LinearGradient(colors: [zone.color.opacity(0.7), zone.color.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5
            ))
            .shadow(color: zone.color.opacity(0.25), radius: 16, x: 0, y: 6)
            .padding(.horizontal)

            connectorLine(color: zone.color, height: 20)
        }
    }

    // Next zone — tappable upgrade card
    func nextZoneRow(zone: ZoneProfile) -> some View {
        VStack(spacing: 0) {
            connectorLine(color: .orange.opacity(0.4), height: 10)
            Button {
                migrationTarget = zone
                showMigrationSheet = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(Color.orange.opacity(0.4), lineWidth: 1))
                        Image(systemName: zone.zoneIcon)
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(zone.name)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("NÄSTA NIVÅ")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text("Inträde: \(TimeEngine.shortFormatted(zone.entryCostSeconds)) • Skatt: \(Int(zone.taxRate * 100))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange.opacity(0.7))
                }
                .padding(14)
                .background(LinearGradient(colors: [Color.orange.opacity(0.1), Color.black.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.35), lineWidth: 1))
                .shadow(color: .orange.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal)
            connectorLine(color: .white.opacity(0.1), height: 10)
        }
    }

    // Locked zone
    func lockedZoneRow(zone: ZoneProfile, near: Bool) -> some View {
        VStack(spacing: 0) {
            connectorLine(color: .white.opacity(0.06), height: 8)
            HStack(spacing: 12) {
                Image(systemName: near ? "lock.open" : "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(near ? 0.3 : 0.15))
                    .frame(width: 30)
                Text(zone.name)
                    .font(.system(size: near ? 12 : 11, design: .monospaced))
                    .foregroundColor(.white.opacity(near ? 0.35 : 0.18))
                Spacer()
                if near {
                    Text(TimeEngine.shortFormatted(zone.entryCostSeconds))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                } else {
                    Text("???")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.1))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            connectorLine(color: .white.opacity(0.06), height: 8)
        }
    }

    // Completed zone (below current)
    func completedZoneRow(zone: ZoneProfile) -> some View {
        VStack(spacing: 0) {
            connectorLine(color: .white.opacity(0.1), height: 6)
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.2))
                    .frame(width: 30)
                Text(zone.name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.22))
                    .strikethrough(true, color: .white.opacity(0.12))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
            connectorLine(color: .white.opacity(0.1), height: 6)
        }
    }

    // Vertical connector line between zones
    func connectorLine(color: Color, height: CGFloat) -> some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(color)
                .frame(width: 2, height: height)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // Stat cell for current zone card
    func mapStatCell(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Zone Relations

    enum ZoneRelation { case current, nextUp, lockedNear, lockedFar, below }

    func zoneRelation(_ zone: ZoneProfile) -> ZoneRelation {
        let cur = currentZone
        if zone.index == cur.index     { return .current   }
        if zone.index == cur.index + 1 { return .nextUp    }
        if zone.index == cur.index + 2 { return .lockedNear }
        if zone.index > cur.index      { return .lockedFar  }
        return .below
    }

    // MARK: - Migration Sheet

    func migrationSheet(zone: ZoneProfile) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                HStack {
                    Button { showMigrationSheet = false } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("MIGRERA")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal)
                .padding(.top, 40)

                Text(zone.name.uppercased())
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(zone.color)

                let minRequired = zone.entryCostSeconds + zone.fallThresholdSeconds
                let canAfford   = engine.balance >= minRequired

                VStack(spacing: 12) {
                    migrationRow(label: "Inträdesavgift", value: TimeEngine.shortFormatted(zone.entryCostSeconds), color: .orange)
                    migrationRow(label: "Buffert krävs", value: TimeEngine.shortFormatted(zone.fallThresholdSeconds), color: .yellow)
                    Divider().background(Color.white.opacity(0.1))
                    migrationRow(label: "Totalt behövs", value: TimeEngine.shortFormatted(minRequired), color: canAfford ? .green : .red)
                    migrationRow(label: "Ditt saldo", value: TimeEngine.shortFormatted(engine.balance), color: canAfford ? .green : .red)
                    Divider().background(Color.white.opacity(0.1))
                    migrationRow(label: "Ny skattesats", value: "\(Int(zone.taxRate * 100))%", color: .yellow)
                    migrationRow(label: "Ny inflation/dag", value: String(format: "%.1f%%", zone.inflationRatePerDay * 100), color: .orange)
                }
                .padding(16)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                Text(zone.description)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
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
                    Text(canAfford ? "MIGRERA TILL \(zone.name.uppercased())" : "OTILLRÄCKLIGA MEDEL")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canAfford ? zone.color : Color.gray)
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
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

#Preview {
    ZoneVisual().preferredColorScheme(.dark)
}
