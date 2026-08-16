import SwiftUI

struct PlayHubView: View {
    @State private var showCasino = false
    @State private var showMiniJobs = false
    @State private var showPvP = false

    var body: some View {
        hubShell(title: "SPELA", subtitle: "Välj risknivå") {
            hubButton("Kasino", "suit.spade.fill", .yellow) { showCasino = true }
            hubButton("Minispel", "gamecontroller.fill", .cyan) { showMiniJobs = true }
            hubButton("PvP", "figure.fencing", .red) { showPvP = true }
        }
        .sheet(isPresented: $showCasino) { CasinoHubView() }
        .sheet(isPresented: $showMiniJobs) { NavigationStack { MiniJobsView() } }
        .sheet(isPresented: $showPvP) { PvPRaidView() }
    }
}

struct WorldHubView: View {
    @State private var showZones = false
    @State private var showMissions = false
    @State private var showNews = false

    var body: some View {
        hubShell(title: "VÄRLDEN", subtitle: "Aktuell zon: \(ZoneManager.shared.currentZone.name)") {
            hubButton("Zoner", "map.fill", ZoneManager.shared.currentZone.color) { showZones = true }
            hubButton("Uppdrag", "target", .orange) { showMissions = true }
            hubButton("Nyheter", "newspaper.fill", .white.opacity(0.75)) { showNews = true }
        }
        .sheet(isPresented: $showZones) { NavigationStack { ZoneVisual() } }
        .sheet(isPresented: $showMissions) { MissionsView() }
        .sheet(isPresented: $showNews) { NavigationStack { NewsFeedView() } }
    }
}

struct ProfileHubView: View {
    @ObservedObject private var engine = TimeEngine.shared
    @State private var showBank = false
    @State private var showSettings = false

    var body: some View {
        hubShell(title: "PROFIL", subtitle: "Din tid, dina val") {
            VStack(alignment: .leading, spacing: 8) {
                Text("AKTUELL LIVSTID").font(LTFont.caption(9)).foregroundColor(.white.opacity(0.45))
                Text(TimeEngine.formatted(engine.balance)).font(LTFont.value(26)).foregroundColor(.white)
                Text("Historik och balans följer din överlevnad genom zonerna.")
                    .font(LTFont.body(12)).foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .ltCard(color: .white, opacity: 0.06, radius: LTRadius.md, borderOpacity: 0.14)
            hubButton("Bank", "building.columns.fill", .green) { showBank = true }
            hubButton("Inställningar", "gearshape.fill", .white.opacity(0.75)) { showSettings = true }
        }
        .sheet(isPresented: $showBank) { BankView() }
        .sheet(isPresented: $showSettings) { AccountSettingsView() }
    }
}

private func hubShell<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
    ZStack {
        LTScreenBackground(style: .neutral)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(LTFont.displayTitle(28)).foregroundColor(.white)
                Text(subtitle).font(LTFont.body(13)).foregroundColor(.white.opacity(0.55))
                content()
                Spacer(minLength: LTSpacing.scrollBottom)
            }
            .padding(.horizontal, LTSpacing.horizontal)
            .padding(.top, 58)
        }
    }
}

private func hubButton(_ title: String, _ icon: String, _ tint: Color, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 24)
            Text(title).font(LTFont.heading(15))
            Spacer()
            Image(systemName: "chevron.right").font(.caption).opacity(0.5)
        }
        .foregroundColor(tint)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.md).stroke(tint.opacity(0.2), lineWidth: 1))
    }
    .buttonStyle(LTPressEffect())
}
