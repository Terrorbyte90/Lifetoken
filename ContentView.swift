import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    @ObservedObject private var engine       = TimeEngine.shared
    @ObservedObject private var gameState    = GameState.shared
    @ObservedObject private var incomeManager = IncomeManager.shared
    @ObservedObject private var inflation    = InflationManager.shared
    @ObservedObject private var server       = ServerSync.shared
    @ObservedObject private var board        = BoardManager.shared

    @State private var showOnboarding    = !UserDefaults.standard.bool(forKey: "hasLaunched")
    @State private var showTimeMarket    = false
    @State private var showZoneMap       = false
    @State private var showMissions      = false
    @State private var showBank          = false
    @State private var showStepBet       = false
    @State private var showNightMarket   = false
    @State private var showPvPRaid       = false
    @State private var showBoard         = false
    @State private var showNewsFeed      = false
    @State private var showMiniJobs      = false
    @State private var pulseAnim: Bool   = false

    // Mikrotexts per kontext
    private let microTexts = [
        "Du arbetar för att leva. Inte tvärtom.",
        "Klockan stannar inte för någon.",
        "De svaga förlorar sin tid. De starka tar den.",
        "Oddsen gynnar alltid huset.",
        "De flesta dör i Stigarnas Dal.",
        "Din tid är deras kapital.",
        "Systemet bryr sig inte."
    ]
    @State private var microIndex: Int = 0
    @State private var microTimer = Timer.publish(every: 25, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    topHeader
                    clockSection
                    if engine.balance > 0 && engine.balance < 86400 {
                        lowBalanceBanner
                    }
                    if inflation.isWarning { inflationBanner }
                    payrollSection
                    BoardWidget()
                        .padding(.horizontal)
                    NewsFeedWidget(maxItems: 3)
                        .padding(.horizontal)
                    statsRow
                    shortcutGrid
                    activeBoostsSection
                    microTextBar
                    Spacer(minLength: 100)
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            gameState.updateZone()
            inflation.update()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(showOnboarding: $showOnboarding)
        }
        .sheet(isPresented: $showTimeMarket)  { TimeMarketView() }
        .sheet(isPresented: $showZoneMap)     { ZoneVisual() }
        .sheet(isPresented: $showMissions)    { MissionsView() }
        .sheet(isPresented: $showBank)        { BankView() }
        .sheet(isPresented: $showStepBet)     { StepBetView() }
        .sheet(isPresented: $showNightMarket) { NightMarketView() }
        .sheet(isPresented: $showPvPRaid)     { PvPRaidView() }
        .sheet(isPresented: $showNewsFeed) {
            NavigationStack { NewsFeedView() }
        }
        .sheet(isPresented: $showBoard) {
            NavigationStack { BoardDetailView() }
        }
        .sheet(isPresented: $showMiniJobs) {
            NavigationStack { MiniJobsView() }
        }
        .alert("Streak Bonus!", isPresented: $gameState.showStreakBonus) {
            Button("Tack!", role: .cancel) {}
        } message: { Text(gameState.streakBonusMessage) }
        .alert("Fusk Detekterat", isPresented: $engine.cheatingDetected) {
            Button("OK") {}
        } message: { Text("Din enhetstid stämmer inte med servertiden. Ogiltig tid har dragits av.") }
        .alert("🌅 Daglig Hälsoinkomst", isPresented: $incomeManager.showDailySummary) {
            Button("Tack!", role: .cancel) {}
        } message: { Text(incomeManager.summaryMessage) }
        .onReceive(microTimer) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                microIndex = (microIndex + 1) % microTexts.count
            }
        }
    }

    // MARK: - Top Header

    private var topHeader: some View {
        HStack(alignment: .center) {
            Text("LIFETOKEN")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: gameState.currentZone.zoneIcon)
                        .font(.system(size: 10))
                    Text(gameState.currentZone.name)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(gameState.currentZone.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(gameState.currentZone.color.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(gameState.currentZone.color.opacity(0.4), lineWidth: 1))

                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                    Text("\(gameState.loginStreakDays)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.top, 60)
    }

    // MARK: - Klocka (ÅÅÅ:DDD:TT:MM:SS — alltid synlig i sin helhet)

    private var clockSection: some View {
        VStack(spacing: 8) {
            if engine.balance <= 0 {
                Text("TIMED OUT")
                    .font(.system(size: 42, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            } else {
                InTimeClockView(balance: engine.balance, pulseAnim: pulseAnim)
                    .animation(
                        engine.balance < 3600
                            ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                            : .default,
                        value: pulseAnim
                    )
                    .onChange(of: engine.balance < 3600) { isLow in pulseAnim = isLow }
                    .onAppear { pulseAnim = engine.balance < 3600 }
            }
            if engine.cheatingDetected {
                Text("TIDMANIPULATION DETEKTERAD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(clockColor.opacity(0.3), lineWidth: 1))
        .padding(.horizontal)
    }

    // MARK: - Förväntad lön (realtid) + nedräkning till utbetalning

    private var payrollSection: some View {
        HStack(spacing: 12) {
            // Intjänat idag
            VStack(spacing: 4) {
                Text("HÄLSOINKOMST IDAG")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .tracking(2)
                Text(TimeEngine.shortFormatted(incomeManager.projectedDailyIncome))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                Text("projicerat efter skatt")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.05, green: 0.07, blue: 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.1, green: 0.4, blue: 0.15), lineWidth: 1))

            // Nästa utbetalning
            VStack(spacing: 4) {
                Text("UTBETALNING")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .tracking(2)
                Text(countdownToMidnight())
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.9, green: 0.8, blue: 0.2))
                Text("till 00:00")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(red: 0.06, green: 0.06, blue: 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.35, green: 0.3, blue: 0.05), lineWidth: 1))
        }
        .padding(.horizontal)
    }

    // MARK: - Banners

    private var inflationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text("INFLATION: \(inflation.percentageString) — Migrera uppåt")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(12)
        .background(LinearGradient(colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)], startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        .padding(.horizontal)
    }

    private var lowBalanceBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
            Text("Du har mindre än en dag kvar.")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.red)
            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4), lineWidth: 1))
        .padding(.horizontal)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(
                icon: "percent",
                label: "SKATT",
                value: "\(Int(gameState.currentZone.taxRate * 100))%",
                color: .yellow
            )
            statDivider
            statColumn(
                icon: "figure.walk",
                label: "STEG",
                value: "\(incomeManager.dailySteps)",
                color: .green
            )
            statDivider
            statColumn(
                icon: "antenna.radiowaves.left.and.right",
                label: "SERVER",
                value: server.isOnline ? "● LIVE" : "○ OFF",
                color: server.isOnline ? Color(red:0.2,green:0.9,blue:0.2) : .red
            )
            statDivider
            statColumn(
                icon: "person.2.fill",
                label: "ONLINE",
                value: "\(max(1, server.onlineCount))",
                color: .cyan
            )
        }
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(red:0.04,green:0.05,blue:0.07)
                // Subtle grid texture
                Canvas { ctx, sz in
                    for x in stride(from: 0.0, to: sz.width, by: 40) {
                        var p = Path()
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: sz.height))
                        ctx.stroke(p, with: .color(Color.white.opacity(0.025)), lineWidth: 1)
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(width: 1, height: 36)
    }

    private func statColumn(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color.opacity(0.7))
            Text(value)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Kortkommandon

    private var shortcutGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ShortcutButton(icon: "cart.fill", label: "Butik", color: .cyan) { showTimeMarket = true }
            ShortcutButton(icon: "map.fill", label: "Zoner", color: .green) { showZoneMap = true }
            ShortcutButton(icon: "target", label: "Uppdrag", color: .yellow) { showMissions = true }
            ShortcutButton(icon: "building.columns.fill", label: "Time Bank", color: .blue) { showBank = true }
            ShortcutButton(icon: "figure.run", label: "Stegduell", color: Color(red: 0.1, green: 0.9, blue: 0.5)) { showStepBet = true }
            ShortcutButton(icon: "moon.stars.fill", label: "Nattmarknaden", color: Color(red: 0.5, green: 0.3, blue: 0.9)) { showNightMarket = true }
            ShortcutButton(icon: "bolt.fill", label: "Rånet", color: Color(red: 0.9, green: 0.3, blue: 0.1)) { showPvPRaid = true }
            ShortcutButton(icon: "crown.fill", label: "Styrelsen", color: Color(red: 0.9, green: 0.7, blue: 0.1)) { showBoard = true }
            ShortcutButton(icon: "newspaper.fill", label: "Nyheter", color: Color(red: 0.4, green: 0.7, blue: 0.9)) { showNewsFeed = true }
            ShortcutButton(icon: "wrench.and.screwdriver.fill", label: "Arbete", color: Color(red: 0.2, green: 0.8, blue: 0.5)) { showMiniJobs = true }
        }
        .padding(.horizontal)
    }

    // MARK: - Aktiva Boosts

    @ViewBuilder
    private var activeBoostsSection: some View {
        let boosts = BoostManager.shared.getActiveBoosts()
        if !boosts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("AKTIVA BOOSTS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
                    .padding(.horizontal, 14)
                    .tracking(2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(boosts, id: \.self) { boost in
                            Text(boost)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.green.opacity(0.3), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    // MARK: - Dystopisk mikrotext

    private var microTextBar: some View {
        HStack(spacing: 8) {
            // Blinking terminal dot
            Circle()
                .fill(Color(red:0.3,green:0.8,blue:0.3).opacity(0.7))
                .frame(width: 5, height: 5)
                .shadow(color: Color.green.opacity(0.5), radius: 3)

            Text(microTexts[microIndex])
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(red: 0.38, green: 0.4, blue: 0.45))
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
                .id(microIndex)

            Spacer()

            Text("SYS//\(String(format: "%04d", (microIndex * 137 + 3721) % 9999))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(red:0.2,green:0.35,blue:0.2))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.05)
                LinearGradient(
                    colors: [Color.green.opacity(0.03), Color.clear],
                    startPoint: .leading, endPoint: .trailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red:0.1,green:0.25,blue:0.1).opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var clockColor: Color {
        if engine.balance <= 0      { return .red }
        if engine.balance < 3600    { return .red }
        if engine.balance < 21600   { return .yellow }
        return .green
    }

    private func countdownToMidnight() -> String {
        let secs = incomeManager.secondsUntilNextPayout
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        let s = Int(secs) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - ShortcutButton

struct ShortcutButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Hem", systemImage: "clock.fill") }
            WorkView()
                .tabItem { Label("Arbete", systemImage: "hammer.fill") }
            CasinoHubView()
                .tabItem { Label("Kasino", systemImage: "suit.spade.fill") }
            ZoneVisual()
                .tabItem { Label("Zoner", systemImage: "map.fill") }
            SocialView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }
        }
        .accentColor(.green)
        .preferredColorScheme(.dark)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}

// MARK: - InfoRow

struct InfoRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.green)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

// MARK: - Previews

#Preview("Dashboard") {
    DashboardView().preferredColorScheme(.dark)
}

#Preview("Main Tabs") {
    MainTabView().preferredColorScheme(.dark)
}
