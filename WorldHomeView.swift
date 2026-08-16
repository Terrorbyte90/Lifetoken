import SwiftUI
import AVKit

/// World-first home: the current zone is the scene, the clock is the instrument,
/// and every action answers one question — can I survive here?
struct WorldHomeView: View {
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var zoneManager = ZoneManager.shared
    @ObservedObject private var inflation = InflationManager.shared

    @State private var player: AVPlayer?
    @State private var pulse = false
    @State private var showZones = false
    @State private var showWork = false
    @State private var showRisk = false

    private var zone: ZoneProfile { zoneManager.currentZone }
    private var accent: Color { zone.color }
    private var isCritical: Bool { engine.balance < max(zone.fallThresholdSeconds, 6 * 3600) }

    var body: some View {
        ZStack {
            atmosphere
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    scene
                    clock
                    survivalReadout
                    primaryActions
                    Spacer(minLength: LTSpacing.scrollBottom)
                }
            }
        }
        .sheet(isPresented: $showZones) { NavigationStack { ZoneVisual() } }
        .sheet(isPresented: $showWork) { WorkView() }
        .sheet(isPresented: $showRisk) { CasinoHubView() }
        .onAppear { setupVideo(); gameState.updateZone() }
        .onDisappear { player?.pause() }
        .onChange(of: zone.index) { _, _ in setupVideo() }
    }

    private var atmosphere: some View {
        ZStack {
            LinearGradient(colors: [accent.opacity(0.24), Color.black, Color.black], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [accent.opacity(0.18), .clear], center: .top, startRadius: 20, endRadius: 480)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("LIFETOKEN")
                    .font(LTFont.label(10))
                    .tracking(3)
                    .foregroundColor(.white.opacity(0.45))
                Text(zone.name.uppercased())
                    .font(LTFont.displayTitle(24))
                    .foregroundColor(accent)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("ZON \(zone.index + 1) / \(ZoneProfile.allZones.count)")
                    .font(LTFont.label(10))
                    .foregroundColor(.white.opacity(0.5))
                Text(isCritical ? "KRITISKT" : "AKTIV")
                    .font(LTFont.label(10))
                    .foregroundColor(isCritical ? .red : accent)
            }
        }
        .padding(.horizontal, LTSpacing.horizontal)
        .padding(.top, 58)
        .padding(.bottom, 18)
    }

    private var scene: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let player { LoopingVideoPlayer(player: player) }
                else { Rectangle().fill(accent.opacity(0.16)) }
            }
            .frame(height: 246)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.94)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 7) {
                Text("DU BEFINNER DIG HÄR")
                    .font(LTFont.label(9))
                    .tracking(2)
                    .foregroundColor(accent)
                Text(zone.description)
                    .font(LTFont.body(13))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    worldStat("SKATT", "\(Int(zone.taxRate * 100))%")
                    worldStat("INFLATION", String(format: "+%.1f%%/dygn", zone.inflationRatePerDay * 100))
                    worldStat("FALL", TimeEngine.shortFormatted(zone.fallThresholdSeconds))
                }
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.lg).stroke(accent.opacity(0.45), lineWidth: 1))
        .padding(.horizontal, LTSpacing.horizontal)
        .contentShape(Rectangle())
        .onTapGesture { showZones = true }
    }

    private func worldStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(LTFont.caption(8)).foregroundColor(.white.opacity(0.42))
            Text(value).font(LTFont.label(10)).foregroundColor(.white.opacity(0.8))
        }
    }

    private var clock: some View {
        VStack(spacing: 8) {
            Text("DIN ÅTERSTÅENDE LIVSTID")
                .font(LTFont.label(9))
                .tracking(2.5)
                .foregroundColor(accent.opacity(0.72))
            if engine.balance <= 0 {
                Text("TIMED OUT").font(LTFont.displayHero(38)).foregroundColor(.red)
            } else {
                InTimeClockView(balance: engine.balance, pulseAnim: pulse)
                    .neonGlow(isCritical ? .red : accent, intensity: isCritical ? 0.9 : 0.3)
            }
            Text(TimeEngine.shortFormatted(engine.balance) + " kvar")
                .font(LTFont.label(11))
                .foregroundColor(.white.opacity(0.58))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .onAppear { pulse = isCritical }
        .onChange(of: isCritical) { _, value in pulse = value }
    }

    private var survivalReadout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ÖVERLEVNADSLÄGE").font(LTFont.label(10)).tracking(1.5).foregroundColor(.white.opacity(0.55))
                Spacer()
                Text(inflation.percentageString).font(LTFont.label(11)).foregroundColor(inflation.isCritical ? .red : .orange)
            }
            ProgressView(value: min(1, engine.balance / max(zone.unlockRequirementSeconds, 86400)))
                .tint(accent)
            Text(isCritical
                 ? "Din buffert är för låg för den här zonen. Arbeta eller flytta ned innan klockan når noll."
                 : "Stanna bara om din inkomst överstiger zonens skatt, inflation och dagliga drain.")
                .font(LTFont.body(12))
                .foregroundColor(.white.opacity(0.68))
        }
        .padding(16)
        .ltCard(color: accent, opacity: 0.06, radius: LTRadius.md, borderOpacity: 0.18)
        .padding(.horizontal, LTSpacing.horizontal)
    }

    private var primaryActions: some View {
        HStack(spacing: 10) {
            worldAction("ÖVERLEV", "hammer.fill", accent) { showWork = true }
            worldAction("ZONER", "map.fill", .white.opacity(0.75)) { showZones = true }
            worldAction(zone.casinoAccess ? "RISK" : "PROFIL", zone.casinoAccess ? "suit.spade.fill" : "person.fill", zone.casinoAccess ? .red : .white.opacity(0.75)) { showRisk = true }
        }
        .padding(.horizontal, LTSpacing.horizontal)
        .padding(.top, 14)
    }

    private func worldAction(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 16, weight: .bold))
                Text(title).font(LTFont.label(9)).tracking(1)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: LTRadius.sm).stroke(tint.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(LTPressEffect(scale: 0.95))
    }

    private func setupVideo() {
        let name = "zon\(zone.index + 1)"
        let url = Bundle.main.url(forResource: name, withExtension: "mp4", subdirectory: "Media.bundle/Media")
            ?? Bundle.main.url(forResource: name, withExtension: "mov", subdirectory: "Media.bundle/Media")
        guard let url else { player = nil; return }
        let next = AVPlayer(url: url)
        next.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: next.currentItem, queue: .main) { _ in
            next.seek(to: .zero); next.play()
        }
        next.play()
        player = next
    }
}
