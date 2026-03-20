import SwiftUI
import AVKit

// MARK: - ZoneVisual — vertikal lista med zonkort

struct ZoneVisual: View {
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var server    = ServerSync.shared
    @Environment(\.dismiss) var dismiss

    private var zones: [ZoneProfile] { ZoneProfile.allZones }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(zones.indices, id: \.self) { index in
                        ZoneCardView(
                            zone: zones[index],
                            zoneIndex: index,
                            currentZoneIndex: gameState.currentZone.index,
                            playerCount: playerCount(for: zones[index])
                        )
                    }
                }
                .padding(.horizontal, LTSpacing.horizontal)
                .padding(.top, LTSpacing.sm)
                .padding(.bottom, LTSpacing.scrollBottom)
            }
        }
        .navigationTitle("ZONER")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Stäng") { dismiss() }
                    .font(LTFont.label(12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    // Antal spelare i en given zon (endast synligt om zonen är nådd eller är nästa)
    private func playerCount(for zone: ZoneProfile) -> Int? {
        guard zone.index <= gameState.currentZone.index + 1 else { return nil }
        return server.zoneMembers.filter { $0.zone == zone.name }.count
    }
}

// MARK: - ZoneCardView

struct ZoneCardView: View {
    let zone: ZoneProfile
    let zoneIndex: Int
    let currentZoneIndex: Int
    let playerCount: Int?

    @State private var player: AVPlayer?  = nil
    @State private var showMigration: Bool = false

    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var zoneManager = ZoneManager.shared

    var isCurrent: Bool   { zoneIndex == currentZoneIndex }
    var isBelow: Bool     { zoneIndex < currentZoneIndex }
    var isNext: Bool      { zoneIndex == currentZoneIndex + 1 }
    var isRevealed: Bool  { zoneIndex <= currentZoneIndex }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            videoHeader
            statsPanel
        }
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.sm)
                .stroke(
                    isCurrent ? zone.color.opacity(0.7) : Color.white.opacity(0.08),
                    lineWidth: isCurrent ? 2 : 1
                )
        )
        .onAppear  { setupVideo() }
        .onDisappear { player?.pause(); player = nil }
        .sheet(isPresented: $showMigration) {
            MigrationConfirmView(zone: zone)
        }
    }

    // MARK: - Video / Header

    private var videoHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // Videoyta eller zonfärgad fallback
            Group {
                if let player = player {
                    VideoPlayer(player: player)
                        .disabled(true)
                } else {
                    zone.color.opacity(0.15)
                }
            }
            .frame(height: 160)
            .clipped()

            // Mörkningsgradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            // Rubrikinnehåll
            VStack(alignment: .leading, spacing: 6) {
                if isCurrent {
                    Label("DIN ZON", systemImage: "location.fill")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(zone.color)
                        .tracking(2)
                }
                HStack(spacing: 6) {
                    Image(systemName: zone.zoneIcon)
                        .font(.system(size: 16, weight: .bold))
                    Text(zone.name.uppercased())
                        .font(LTFont.displayTitle(20))
                }
                .foregroundColor(.white)

                Text(zone.shortLore)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
            }
            .padding(LTSpacing.md)
        }
        // Rundade hörn endast upptill
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: LTRadius.sm,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: LTRadius.sm
            )
        )
    }

    // MARK: - Statistikpanel

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: LTSpacing.md) {
            HStack(spacing: LTSpacing.xl) {
                // Spelarantal
                statCell(
                    icon: "person.2.fill",
                    label: "SPELARE",
                    value: playerCount.map { "\($0)" } ?? "???",
                    color: .cyan
                )

                if isNext {
                    // Visa inträde och skatt för nästa zon
                    statCell(
                        icon: "arrow.right.circle",
                        label: "INTRÄDE",
                        value: TimeEngine.shortFormatted(zone.entryCostSeconds),
                        color: zone.color
                    )
                    statCell(
                        icon: "percent",
                        label: "SKATT",
                        value: "\(Int(zone.taxRate * 100))%",
                        color: .orange
                    )
                } else if !isRevealed {
                    // Låst — dolda värden
                    lockedStatCell(icon: "lock.fill", label: "INTRÄDE")
                    lockedStatCell(icon: "lock.fill", label: "SKATT")
                }
                // Passerade och nuvarande zon: inga intradeskostnader visas
            }

            // Migrationsknapp (endast för nästa zon)
            if isNext {
                Button {
                    showMigration = true
                } label: {
                    HStack(spacing: LTSpacing.sm) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 13))
                        Text("MIGRERA — \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
                            .font(LTFont.label(11))
                    }
                    .foregroundColor(zone.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(zone.color.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: LTRadius.xs)
                            .stroke(zone.color.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                }
                .buttonStyle(LTPressEffect())
            }
        }
        .padding(LTSpacing.md)
        .background(Color.white.opacity(0.04))
        // Rundade hörn endast nedtill
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: LTRadius.sm,
                bottomTrailingRadius: LTRadius.sm,
                topTrailingRadius: 0
            )
        )
    }

    // MARK: - Hjälpvyer

    private func statCell(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(LTFont.heading(15))
                .foregroundColor(color)
        }
    }

    private func lockedStatCell(icon: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
            Text("???")
                .font(LTFont.heading(15))
                .foregroundColor(.white.opacity(0.25))
        }
    }

    // MARK: - Video-setup

    private func setupVideo() {
        let videoName = "zon\(zoneIndex + 1)"
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else { return }
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem,
            queue: .main
        ) { _ in
            p.seek(to: .zero)
            p.play()
        }
        p.play()
        player = p
    }
}

// MARK: - MigrationConfirmView

struct MigrationConfirmView: View {
    let zone: ZoneProfile
    @Environment(\.dismiss) var dismiss

    @ObservedObject private var engine      = TimeEngine.shared
    @ObservedObject private var gameState   = GameState.shared
    @ObservedObject private var zoneManager = ZoneManager.shared

    @State private var migrationResult:      String = ""
    @State private var showMigrationResult:  Bool   = false

    private let hapticNotif  = UINotificationFeedbackGenerator()
    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Rubrik
                HStack {
                    Button {
                        hapticLight.impactOccurred()
                        dismiss()
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
                            migrationRow(label: "Inträdesavgift", value: TimeEngine.shortFormatted(zone.entryCostSeconds), color: .orange)
                            migrationRow(label: "Buffert krävs",  value: TimeEngine.shortFormatted(zone.fallThresholdSeconds), color: .yellow)
                            Divider().background(Color.white.opacity(0.1))
                            migrationRow(label: "Totalt behövs", value: TimeEngine.shortFormatted(minRequired), color: canAfford ? .green : .red)
                            migrationRow(label: "Ditt saldo",    value: TimeEngine.shortFormatted(engine.balance), color: canAfford ? .green : .red)
                            Divider().background(Color.white.opacity(0.1))
                            migrationRow(label: "Ny skattesats",    value: "\(Int(zone.taxRate * 100))%", color: .yellow)
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
                            migrationRow(label: "Jobbmultiplikator",  value: String(format: "×%.1f", zone.workMultiplier), color: .green)
                            migrationRow(label: "Passiv inkomst/dag", value: TimeEngine.shortFormatted(TimeInterval(zone.passiveBonusSecondsPerDay)), color: .cyan)
                            migrationRow(label: "Stegbonus",          value: String(format: "×%.2f", zone.stepBonusMultiplier), color: .teal)
                            if zone.allowBoosts {
                                migrationRow(label: "Max boosts",   value: "\(zone.maxActiveBoosts) aktiva", color: .purple)
                                migrationRow(label: "Boosteffekt",  value: String(format: "×%.1f", zone.boostEffectMultiplier), color: .purple)
                            }
                            if zone.casinoAccess {
                                migrationRow(label: "Kasinoaccess", value: "Upplåst", color: LTPalette.gold)
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

                        // Migreringsknapp
                        Button {
                            hapticNotif.notificationOccurred(canAfford ? .success : .error)
                            guard canAfford else { return }
                            let result = zoneManager.migrateToZone(zone)
                            migrationResult = result.message
                            dismiss()
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
        .alert("Migration", isPresented: $showMigrationResult) {
            Button("OK") {}
        } message: {
            Text(migrationResult)
        }
    }

    private func migrationRow(label: String, value: String, color: Color) -> some View {
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

// MARK: - Preview

#Preview {
    ZoneVisual()
        .preferredColorScheme(.dark)
}
