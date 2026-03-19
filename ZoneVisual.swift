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
    @State private var headerPulse: Bool   = false
    @State private var showLoreSheet: Bool = false

    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticNotif  = UINotificationFeedbackGenerator()

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
                        Spacer(minLength: LTSpacing.scrollBottom)
                    }
                    .padding(.top, LTSpacing.sm)
                }
            }
        }
        .sheet(isPresented: $showMigrationSheet) {
            if let target = migrationTarget { migrationSheet(zone: target) }
        }
        .sheet(isPresented: $showLoreSheet) {
            NavigationStack {
                ZoneLoreView(zoneID: currentZone.name
                    .lowercased()
                    .replacingOccurrences(of: " ", with: "")
                    .folding(options: .diacriticInsensitive, locale: .current))
            }
        }
        .alert("Migration", isPresented: $showMigrationResult) {
            Button("OK") {}
        } message: { Text(migrationResult) }
        .onAppear { headerPulse = true }
    }

    // MARK: - Background

    private var mapBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
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
            LinearGradient(
                colors: [currentZone.color.opacity(0.08), .clear],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()
            .animation(LTAnimation.springSmooth, value: currentZone.name)
        }
    }

    // MARK: - Header

    private var mapHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("ZONKARTA")
                    .font(LTFont.displayTitle(20))
                    .foregroundColor(.white)
                    .tracking(4)
                Text("14 TERRITORIER • KLASSIFICERAT")
                    .font(LTFont.caption(8))
                    .foregroundColor(.white.opacity(0.25))
                    .tracking(2)
            }
            Spacer()
            HStack(spacing: LTSpacing.xs + 1) {
                Image(systemName: currentZone.zoneIcon)
                    .font(.system(size: 10))
                Text(currentZone.name)
                    .font(LTFont.label(10))
            }
            .foregroundColor(currentZone.color)
            .padding(.horizontal, LTSpacing.sm + 2)
            .padding(.vertical, LTSpacing.xs + 2)
            .background(currentZone.color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(currentZone.color.opacity(0.5), lineWidth: 1))
            .shadow(color: currentZone.color.opacity(0.3), radius: 6)
            .neonGlow(currentZone.color, intensity: 0.25)
            .animation(LTAnimation.springSmooth, value: currentZone.name)
            .accessibilityLabel("Din nuvarande zon: \(currentZone.name)")
        }
        .padding(.horizontal, LTSpacing.horizontal)
        .padding(.top, 60)
        .padding(.bottom, LTSpacing.md)
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
            connectorLine(color: zone.color, height: 20)

            VStack(alignment: .leading, spacing: LTSpacing.md) {
                HStack(spacing: LTSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(zone.color.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .shadow(color: zone.color.opacity(0.6), radius: 10)
                        Image(systemName: zone.zoneIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(zone.color)
                    }
                    .neonGlow(zone.color, intensity: 0.4)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: LTSpacing.xs) {
                        HStack(spacing: LTSpacing.sm) {
                            Text(zone.name.uppercased())
                                .font(LTFont.heading(16))
                                .foregroundColor(zone.color)
                            Text("DIN ZON")
                                .font(LTFont.caption(8))
                                .foregroundColor(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(zone.color)
                                .clipShape(Capsule())
                        }
                        Text(zone.description)
                            .font(LTFont.body(11))
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                    }
                }

                Divider().background(zone.color.opacity(0.2))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LTSpacing.sm) {
                    mapStatCell(label: "SKATT",      value: "\(Int(zone.taxRate * 100))%",
                                icon: "percent",                     color: .yellow)
                    mapStatCell(label: "ARBETE ×",   value: String(format: "%.1f", zone.workMultiplier),
                                icon: "hammer.fill",                  color: .cyan)
                    mapStatCell(label: "INFLATION",  value: String(format: "%.1f%%", zone.inflationRatePerDay * 100),
                                icon: "chart.line.uptrend.xyaxis",    color: .orange)
                    mapStatCell(label: "PASSIV/DAG", value: TimeEngine.shortFormatted(TimeInterval(zone.passiveBonusSecondsPerDay)),
                                icon: "clock.arrow.circlepath",       color: .green)
                }

                if !zone.protections.isEmpty {
                    HStack(spacing: LTSpacing.xs + 2) {
                        ForEach(zone.protections, id: \.self) { p in
                            Text("🛡 \(p)")
                                .font(LTFont.body(9))
                                .foregroundColor(.green)
                                .padding(.horizontal, LTSpacing.sm)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                Button {
                    hapticLight.impactOccurred()
                    showLoreSheet = true
                } label: {
                    HStack(spacing: LTSpacing.sm) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 11))
                        Text("LORE & HISTORIA")
                            .font(LTFont.label(11))
                            .tracking(1)
                    }
                    .foregroundColor(zone.color.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LTSpacing.sm + 2)
                    .background(zone.color.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm + 2))
                    .overlay(RoundedRectangle(cornerRadius: LTRadius.sm + 2).stroke(zone.color.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Läs lore för \(zone.name)")
            }
            .padding(LTSpacing.lg + 2)
            .background(
                ZStack {
                    LinearGradient(colors: [zone.color.opacity(0.12), Color.black.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    LinearGradient(colors: [Color.white.opacity(0.04), .clear], startPoint: .top, endPoint: .center)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xl))
            .overlay(RoundedRectangle(cornerRadius: LTRadius.xl).stroke(
                LinearGradient(colors: [zone.color.opacity(0.7), zone.color.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5
            ))
            .shadow(color: zone.color.opacity(0.25), radius: 16, x: 0, y: 6)
            .padding(.horizontal, LTSpacing.horizontal)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Din zon: \(zone.name). \(zone.description)")

            connectorLine(color: zone.color, height: 20)
        }
    }

    // Next zone — tappable upgrade card
    func nextZoneRow(zone: ZoneProfile) -> some View {
        VStack(spacing: 0) {
            connectorLine(color: .orange.opacity(0.4), height: 10)
            Button {
                hapticMedium.impactOccurred()
                migrationTarget = zone
                showMigrationSheet = true
            } label: {
                HStack(spacing: LTSpacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(Color.orange.opacity(0.4), lineWidth: 1))
                        Image(systemName: zone.zoneIcon)
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: LTSpacing.sm) {
                            Text(zone.name)
                                .font(LTFont.heading(14))
                                .foregroundColor(.white)
                            Text("NÄSTA NIVÅ")
                                .font(LTFont.caption(8))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text("Inträde: \(TimeEngine.shortFormatted(zone.entryCostSeconds)) • Skatt: \(Int(zone.taxRate * 100))%")
                            .font(LTFont.body(10))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.orange.opacity(0.7))
                }
                .padding(LTSpacing.md)
                .background(LinearGradient(colors: [Color.orange.opacity(0.1), Color.black.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: LTRadius.md - 2))
                .overlay(RoundedRectangle(cornerRadius: LTRadius.md - 2).stroke(Color.orange.opacity(0.35), lineWidth: 1))
                .shadow(color: .orange.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(LTPressEffect())
            .padding(.horizontal, LTSpacing.horizontal)
            .accessibilityLabel("Migrera till \(zone.name). Inträdesavgift: \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
            .accessibilityHint("Öppnar migreringsdetaljer")

            connectorLine(color: .white.opacity(0.1), height: 10)
        }
    }

    // Locked zone
    func lockedZoneRow(zone: ZoneProfile, near: Bool) -> some View {
        VStack(spacing: 0) {
            connectorLine(color: .white.opacity(0.06), height: 8)
            HStack(spacing: LTSpacing.md) {
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
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.2))
                } else {
                    Text("???")
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.1))
                }
            }
            .padding(.horizontal, LTSpacing.xxl)
            .padding(.vertical, LTSpacing.sm)
            .accessibilityLabel("\(zone.name): låst zon")
            .accessibilityHint(near ? "Inträdesavgift: \(TimeEngine.shortFormatted(zone.entryCostSeconds))" : "Kräver fler tillgångar")

            connectorLine(color: .white.opacity(0.06), height: 8)
        }
    }

    // Completed zone (below current)
    func completedZoneRow(zone: ZoneProfile) -> some View {
        VStack(spacing: 0) {
            connectorLine(color: .white.opacity(0.1), height: 6)
            HStack(spacing: LTSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.2))
                    .frame(width: 30)
                Text(zone.name)
                    .font(LTFont.body(11))
                    .foregroundColor(.white.opacity(0.22))
                    .strikethrough(true, color: .white.opacity(0.12))
                Spacer()
            }
            .padding(.horizontal, LTSpacing.xxl)
            .padding(.vertical, LTSpacing.xs + 2)
            .accessibilityLabel("\(zone.name): passerad zon")

            connectorLine(color: .white.opacity(0.1), height: 6)
        }
    }

    func connectorLine(color: Color, height: CGFloat) -> some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(color)
                .frame(width: 2, height: height)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    func mapStatCell(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: LTSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 16)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(LTFont.caption(7))
                    .foregroundColor(.white.opacity(0.35))
                Text(value)
                    .font(LTFont.heading(12))
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, LTSpacing.sm + 2)
        .padding(.vertical, LTSpacing.sm)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Zone Relations

    enum ZoneRelation { case current, nextUp, lockedNear, lockedFar, below }

    func zoneRelation(_ zone: ZoneProfile) -> ZoneRelation {
        let cur = currentZone
        if zone.index == cur.index     { return .current    }
        if zone.index == cur.index + 1 { return .nextUp     }
        if zone.index == cur.index + 2 { return .lockedNear }
        if zone.index > cur.index      { return .lockedFar  }
        return .below
    }

    // MARK: - Migration Sheet

    func migrationSheet(zone: ZoneProfile) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button {
                        hapticLight.impactOccurred()
                        showMigrationSheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(LTSpacing.sm)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(LTPressEffect())
                    .accessibilityLabel("Stäng migreringsvy")
                    Spacer()
                    Text("MIGRERA")
                        .font(LTFont.heading(16))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, LTSpacing.horizontal)
                .padding(.top, LTSpacing.xxxl + LTSpacing.sm)
                .padding(.bottom, LTSpacing.lg)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: LTSpacing.xxl) {

                        Text(zone.name.uppercased())
                            .font(LTFont.displayHero(28))
                            .foregroundColor(zone.color)
                            .neonGlow(zone.color, intensity: 0.4)

                        let minRequired = zone.entryCostSeconds + zone.fallThresholdSeconds
                        let canAfford   = engine.balance >= minRequired

                        // Kostnader
                        VStack(alignment: .leading, spacing: LTSpacing.md) {
                            Text("KOSTNADER")
                                .font(LTFont.label(9))
                                .foregroundColor(.white.opacity(0.3))
                                .tracking(3)
                            migrationRow(label: "Inträdesavgift",  value: TimeEngine.shortFormatted(zone.entryCostSeconds), color: .orange)
                            migrationRow(label: "Buffert krävs",   value: TimeEngine.shortFormatted(zone.fallThresholdSeconds), color: .yellow)
                            Divider().background(Color.white.opacity(0.1))
                            migrationRow(label: "Totalt behövs",   value: TimeEngine.shortFormatted(minRequired), color: canAfford ? .green : .red)
                            migrationRow(label: "Ditt saldo",      value: TimeEngine.shortFormatted(engine.balance), color: canAfford ? .green : .red)
                            Divider().background(Color.white.opacity(0.1))
                            migrationRow(label: "Ny skattesats",   value: "\(Int(zone.taxRate * 100))%", color: .yellow)
                            migrationRow(label: "Ny inflation/dag", value: String(format: "%.1f%%", zone.inflationRatePerDay * 100), color: .orange)
                        }
                        .padding(LTSpacing.lg)
                        .ltCard(radius: LTRadius.sm)
                        .padding(.horizontal, LTSpacing.horizontal)

                        // Fördelar
                        VStack(alignment: .leading, spacing: LTSpacing.md) {
                            Text("FÖRDELAR")
                                .font(LTFont.label(9))
                                .foregroundColor(.white.opacity(0.3))
                                .tracking(3)
                            migrationRow(label: "Jobbmultiplikator",   value: String(format: "×%.1f", zone.workMultiplier), color: .green)
                            migrationRow(label: "Passiv inkomst/dag",   value: TimeEngine.shortFormatted(TimeInterval(zone.passiveBonusSecondsPerDay)), color: .cyan)
                            migrationRow(label: "Stegbonus",            value: String(format: "×%.2f", zone.stepBonusMultiplier), color: .teal)
                            if zone.allowBoosts {
                                migrationRow(label: "Max boosts",       value: "\(zone.maxActiveBoosts) aktiva", color: .purple)
                                migrationRow(label: "Boosteffekt",      value: String(format: "×%.1f", zone.boostEffectMultiplier), color: .purple)
                            }
                            if zone.casinoAccess {
                                migrationRow(label: "Kasinoaccess",     value: "Upplåst", color: LTPalette.gold)
                            }
                            if !zone.protections.isEmpty {
                                Divider().background(Color.white.opacity(0.1))
                                VStack(alignment: .leading, spacing: LTSpacing.xs + 2) {
                                    Text("SKYDD")
                                        .font(LTFont.label(9))
                                        .foregroundColor(.white.opacity(0.3))
                                        .tracking(2)
                                    ForEach(zone.protections, id: \.self) { prot in
                                        HStack(spacing: LTSpacing.xs + 2) {
                                            Image(systemName: "shield.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.blue)
                                            Text(prot)
                                                .font(LTFont.body(11))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(LTSpacing.lg)
                        .ltCard(radius: LTRadius.sm)
                        .padding(.horizontal, LTSpacing.horizontal)

                        Text(zone.description)
                            .font(LTFont.body(12))
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, LTSpacing.xxl)

                        Button {
                            hapticNotif.notificationOccurred(canAfford ? .success : .error)
                            guard canAfford else { return }
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
                                .font(LTFont.heading(15))
                                .foregroundColor(canAfford ? .black : .white.opacity(0.35))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, LTSpacing.lg)
                                .background(canAfford ? zone.color : Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                                .shadow(color: canAfford ? zone.color.opacity(0.3) : .clear, radius: 10, y: 4)
                        }
                        .buttonStyle(LTPressEffect())
                        .disabled(!canAfford)
                        .padding(.horizontal, LTSpacing.horizontal)
                        .accessibilityLabel(canAfford ? "Migrera till \(zone.name)" : "Otillräckliga medel för migration")
                        .accessibilityHint(canAfford ? "Debiterar inträdesavgift och startar migration" : "Du behöver \(TimeEngine.shortFormatted(minRequired)) totalt")

                        Spacer(minLength: LTSpacing.xxxl + LTSpacing.xl)
                    }
                }
            }
        }
    }

    func migrationRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(LTFont.body(12))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(LTFont.heading(13))
                .foregroundColor(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

#Preview {
    ZoneVisual().preferredColorScheme(.dark)
}
