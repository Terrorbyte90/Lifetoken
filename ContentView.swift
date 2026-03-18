import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    @ObservedObject private var engine        = TimeEngine.shared
    @ObservedObject private var gameState     = GameState.shared
    @ObservedObject private var incomeManager = IncomeManager.shared
    @ObservedObject private var inflation     = InflationManager.shared
    @ObservedObject private var server        = ServerSync.shared
    @ObservedObject private var board         = BoardManager.shared

    @State private var showOnboarding  = !UserDefaults.standard.bool(forKey: "hasLaunched")
    @State private var showTimeMarket  = false
    @State private var showZoneMap     = false
    @State private var showMissions    = false
    @State private var showBank        = false
    @State private var showStepBet     = false
    @State private var showNightMarket = false
    @State private var showPvPRaid     = false
    @State private var showBoard       = false
    @State private var showNewsFeed    = false
    @State private var showMiniJobs    = false
    @State private var pulseAnim: Bool = false

    private let microTexts = [
        "Du arbetar för att leva. Inte tvärtom.",
        "Klockan stannar inte för någon.",
        "De svaga förlorar sin tid. De starka tar den.",
        "Oddsen gynnar alltid huset.",
        "De flesta dör i Stigarnas Dal.",
        "Din tid är deras kapital.",
        "Systemet bryr sig inte."
    ]
    @State private var microIndex = 0
    @State private var microTimer = Timer.publish(every: 25, on: .main, in: .common).autoconnect()

    // MARK: - Body

    var body: some View {
        ZStack {
            dashboardBackground
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    topHeader
                    clockSection
                    if engine.balance > 0 && engine.balance < 86400 { lowBalanceBanner }
                    if inflation.isWarning { inflationBanner }
                    payrollRow
                    statsStrip
                    eliteTicker
                    BoardWidget().padding(.horizontal)
                    NewsFeedWidget(maxItems: 3).padding(.horizontal)
                    navSectionLabel
                    navGrid
                    activeBoostsSection
                    microTextBar
                    Spacer(minLength: LTSpacing.scrollBottom)
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
        .sheet(isPresented: $showNewsFeed)    { NavigationStack { NewsFeedView() } }
        .sheet(isPresented: $showBoard)       { NavigationStack { BoardDetailView() } }
        .sheet(isPresented: $showMiniJobs)    { NavigationStack { MiniJobsView() } }
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
            withAnimation(LTAnimation.fade) {
                microIndex = (microIndex + 1) % microTexts.count
            }
        }
    }

    // MARK: - Background

    private var dashboardBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.03, blue: 0.07), Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Atmospheric glow emanating from top (behind clock)
            RadialGradient(
                colors: [clockColor.opacity(0.06), .clear],
                center: UnitPoint(x: 0.5, y: 0.0),
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            // Subtle horizontal scan lines
            Canvas { ctx, sz in
                for y in stride(from: 0.0, to: sz.height, by: 4) {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: sz.width, y: y))
                    ctx.stroke(p, with: .color(Color.white.opacity(0.009)), lineWidth: 1)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Top Header

    private var topHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            // Branding
            VStack(alignment: .leading, spacing: 2) {
                Text("LIFETOKEN")
                    .font(.system(size: 21, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(3)
                Text(agentName.uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.30))
                    .tracking(2)
            }

            Spacer()

            // Server online indicator
            Circle()
                .fill(server.isOnline ? Color(red: 0.2, green: 1.0, blue: 0.4) : .red)
                .frame(width: 6, height: 6)
                .shadow(color: server.isOnline ? .green : .red, radius: 5)

            // Zone chip
            HStack(spacing: 4) {
                Image(systemName: gameState.currentZone.zoneIcon)
                    .font(.system(size: 9))
                Text(gameState.currentZone.name)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
            }
            .foregroundColor(gameState.currentZone.color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(gameState.currentZone.color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(gameState.currentZone.color.opacity(0.40), lineWidth: 1))

            // Streak chip
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                Text("\(gameState.loginStreakDays)")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.orange.opacity(0.30), lineWidth: 1))
        }
        .padding(.horizontal)
        .padding(.top, 58)
    }

    // MARK: - Clock Section

    private var clockSection: some View {
        VStack(spacing: 0) {
            // Status label
            Text(clockLabel)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(clockColor.opacity(0.6))
                .tracking(3)
                .padding(.bottom, 10)

            // Clock display
            if engine.balance <= 0 {
                Text("TIMED OUT")
                    .font(.system(size: 40, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .neonGlow(.red, intensity: 1.2)
            } else {
                InTimeClockView(balance: engine.balance, pulseAnim: pulseAnim)
                    .neonGlow(clockColor, intensity: engine.balance < 3600 ? 0.8 : 0.3)
                    .animation(
                        engine.balance < 3600
                            ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                            : .default,
                        value: pulseAnim
                    )
                    .onChange(of: engine.balance < 3600) { _, isLow in pulseAnim = isLow }
                    .onAppear { pulseAnim = engine.balance < 3600 }
            }

            // Time progress bar + drain rate
            HStack(spacing: LTSpacing.sm) {
                Image(systemName: "hourglass")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.2))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [clockColor.opacity(0.8), clockColor],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * timePercent, height: 3)
                            .shadow(color: clockColor.opacity(0.5), radius: 4)
                            .animation(LTAnimation.fade, value: timePercent)
                    }
                }
                .frame(height: 3)
                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)

            if engine.cheatingDetected {
                Text("⚠  TIDMANIPULATION DETEKTERAD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.09)
                RadialGradient(
                    colors: [clockColor.opacity(0.07), .clear],
                    center: .center, startRadius: 10, endRadius: 200
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.xl)
                .stroke(clockColor.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: clockColor.opacity(0.22), radius: 20, x: 0, y: 6)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Livsbalans: \(clockLabel.lowercased()). \(TimeEngine.formatted(engine.balance)) återstår.")
    }

    // MARK: - Payroll Row

    private var payrollRow: some View {
        HStack(spacing: LTSpacing.sm + 2) {
            payCard(
                icon: "heart.fill",
                iconColor: Color(red: 0.2, green: 0.9, blue: 0.45),
                title: "HÄLSOINKOMST",
                value: TimeEngine.shortFormatted(incomeManager.projectedDailyIncome),
                sub: "projicerat efter skatt"
            )
            payCard(
                icon: "clock.badge.checkmark.fill",
                iconColor: Color(red: 0.95, green: 0.82, blue: 0.2),
                title: "UTBETALNING",
                value: countdownToMidnight(),
                sub: "tills 00:00"
            )
        }
        .padding(.horizontal)
    }

    private func payCard(
        icon: String,
        iconColor: Color,
        title: String,
        value: String,
        sub: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(iconColor.opacity(0.18))
                        .frame(width: 26, height: 26)
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.60))
                    .tracking(1)
                Spacer(minLength: 0)
            }
            // Value
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(iconColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            // Subtitle
            Text(sub)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.50))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [iconColor.opacity(0.13), iconColor.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(iconColor.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 8) {
            statChip(
                icon: "percent",
                label: "SKATT",
                value: "\(Int(gameState.currentZone.taxRate * 100))%",
                color: .yellow
            )
            statChip(
                icon: "figure.walk",
                label: "STEG",
                value: "\(incomeManager.dailySteps)",
                color: .green
            )
            statChip(
                icon: "antenna.radiowaves.left.and.right",
                label: "SERVER",
                value: server.isOnline ? "LIVE" : "OFF",
                color: server.isOnline ? Color(red: 0.2, green: 0.9, blue: 0.2) : .red
            )
            statChip(
                icon: "person.2.fill",
                label: "ONLINE",
                value: "\(max(1, server.onlineCount))",
                color: .cyan
            )
        }
        .padding(.horizontal)
    }

    private func statChip(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: LTSpacing.xs + 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 4)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(LTAnimation.fadeFast, value: value)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.75))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(
            LinearGradient(
                colors: [color.opacity(0.14), color.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs + 5))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.xs + 5).stroke(color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Nav Section Label

    private var navSectionLabel: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 28, height: 1)
            Text("NAVIGERING")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.22))
                .tracking(3)
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 1)
        }
        .padding(.horizontal)
    }

    // MARK: - Navigation Grid (2-column NavCard layout)

    private var navGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: LTSpacing.sm + 2
        ) {
            NavCard(icon: "cart.fill",
                    title: "Butik",
                    sub: "Köp tid & items",
                    color: .cyan)                                    { showTimeMarket = true }
            NavCard(icon: "map.fill",
                    title: "Zoner",
                    sub: "Migrera & utforska",
                    color: .green)                                   { showZoneMap = true }
            NavCard(icon: "target",
                    title: "Uppdrag",
                    sub: "Tjäna extra tid",
                    color: .yellow)                                  { showMissions = true }
            NavCard(icon: "building.columns.fill",
                    title: "Time Bank",
                    sub: "Räntor & lån",
                    color: .blue)                                    { showBank = true }
            NavCard(icon: "figure.run",
                    title: "Stegduell",
                    sub: "Satsa på steg",
                    color: Color(red: 0.1, green: 0.9, blue: 0.5))  { showStepBet = true }
            NavCard(icon: "moon.stars.fill",
                    title: "Nattmarknaden",
                    sub: "Hemliga affärer",
                    color: Color(red: 0.5, green: 0.3, blue: 0.9))  { showNightMarket = true }
            NavCard(icon: "bolt.fill",
                    title: "Rånet",
                    sub: "PvP — hög risk",
                    color: Color(red: 0.9, green: 0.3, blue: 0.1))  { showPvPRaid = true }
            NavCard(icon: "crown.fill",
                    title: "Styrelsen",
                    sub: "Eliten styr",
                    color: Color(red: 0.9, green: 0.7, blue: 0.1))  { showBoard = true }
            NavCard(icon: "newspaper.fill",
                    title: "Nyheter",
                    sub: "Senaste händelser",
                    color: Color(red: 0.4, green: 0.7, blue: 0.9))  { showNewsFeed = true }
            NavCard(icon: "wrench.and.screwdriver.fill",
                    title: "Arbete",
                    sub: "Mini-jobb & uppdrag",
                    color: Color(red: 0.2, green: 0.8, blue: 0.5))  { showMiniJobs = true }
        }
        .padding(.horizontal)
    }

    // MARK: - Elite Ticker

    private let elitePerks = [
        "Topp 3 rikaste spelare får unika fördelar",
        "★ Plats 1: Skatteimmunitet — betalar 0% skatt",
        "★ Plats 2: Tidsskydd — kan ej rånas",
        "★ Plats 3: Dubbel hälsoinkomst varje dag"
    ]
    @State private var eliteTickerIndex = 0
    @State private var eliteTickerTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private var eliteTicker: some View {
        HStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 9))
                .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.1))
                .shadow(color: Color.yellow.opacity(0.6), radius: 3)
            Text(elitePerks[eliteTickerIndex])
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(eliteTickerIndex == 0
                    ? Color(red: 1.0, green: 0.85, blue: 0.3)
                    : Color.white.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(eliteTickerIndex)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.14, blue: 0.02),
                    Color(red: 0.08, green: 0.06, blue: 0.01)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 1.0, green: 0.8, blue: 0.1).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .onReceive(eliteTickerTimer) { _ in
            withAnimation(LTAnimation.fadeFast) {
                eliteTickerIndex = (eliteTickerIndex + 1) % elitePerks.count
            }
        }
    }

    // MARK: - Banners

    private var inflationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("INFLATION AKTIV")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.orange)
                Text("\(inflation.percentageString) — Migrera till högre zon")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 10))
                .foregroundColor(.orange.opacity(0.4))
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.18), Color.red.opacity(0.08)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.35), lineWidth: 1))
        .padding(.horizontal)
    }

    private var lowBalanceBanner: some View {
        HStack(spacing: LTSpacing.sm + 2) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15))
                .foregroundColor(LTPalette.danger)
                .neonGlow(LTPalette.danger, intensity: 0.6)
            VStack(alignment: .leading, spacing: LTSpacing.xs - 2) {
                Text("KRITISK TIDSNIVÅ")
                    .font(LTFont.label(10))
                    .foregroundColor(LTPalette.danger)
                Text("Du har mindre än en dag kvar.")
                    .font(LTFont.body(10))
                    .foregroundColor(LTPalette.danger.opacity(0.70))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundColor(LTPalette.danger.opacity(0.4))
        }
        .padding(LTSpacing.md)
        .background(LTPalette.danger.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.sm).stroke(LTPalette.danger.opacity(0.35), lineWidth: 1))
        .shadow(color: LTPalette.danger.opacity(0.12), radius: 8)
        .padding(.horizontal)
        .accessibilityLabel("Varning: Kritisk tidsnivå. Du har mindre än en dag kvar.")
        .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Active Boosts

    @ViewBuilder
    private var activeBoostsSection: some View {
        let boosts = BoostManager.shared.getActiveBoosts()
        if !boosts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                    Text("AKTIVA BOOSTS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.70))
                        .tracking(2)
                }
                .padding(.horizontal, 14)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(boosts, id: \.self) { boost in
                            HStack(spacing: 5) {
                                Circle().fill(Color.green).frame(width: 4, height: 4)
                                Text(boost)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.green.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.green.opacity(0.28), lineWidth: 1))
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

    // MARK: - Micro Text Bar

    private var microTextBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 0.3, green: 0.8, blue: 0.3).opacity(0.7))
                .frame(width: 5, height: 5)
                .shadow(color: Color.green.opacity(0.5), radius: 3)
            Text(microTexts[microIndex])
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(red: 0.38, green: 0.40, blue: 0.45))
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
                .foregroundColor(Color(red: 0.20, green: 0.35, blue: 0.20))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.05)
                LinearGradient(
                    colors: [Color.green.opacity(0.03), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.10, green: 0.25, blue: 0.10).opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var clockColor: Color {
        if engine.balance <= 0    { return .red }
        if engine.balance < 3600  { return .red }
        if engine.balance < 21600 { return .yellow }
        return Color(red: 0.2, green: 0.9, blue: 0.4)
    }

    private var clockLabel: String {
        if engine.balance <= 0    { return "SYSTEM OFFLINE" }
        if engine.balance < 3600  { return "KRITISK — UNDER 1 TIMME" }
        if engine.balance < 86400 { return "VARNING — UNDER 24 TIMMAR" }
        return "LIVSBALANS"
    }

    /// Progress fraction capped at 7 days for display
    private var timePercent: CGFloat {
        CGFloat(min(engine.balance / (86400 * 7), 1.0))
    }

    private var agentName: String {
        UserDefaults.standard.string(forKey: "username") ?? "okänd agent"
    }

    private func countdownToMidnight() -> String {
        let secs = incomeManager.secondsUntilNextPayout
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        let s = Int(secs) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - NavCard

struct NavCard: View {
    let icon: String
    let title: String
    let sub: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: LTSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 42, height: 42)
                        .shadow(color: color.opacity(0.55), radius: 8, x: 0, y: 2)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.9), radius: 3)
                }
                VStack(alignment: .leading, spacing: LTSpacing.xs - 1) {
                    Text(title)
                        .font(LTFont.heading(12))
                        .foregroundColor(.white)
                        .tracking(0.3)
                    Text(sub)
                        .font(LTFont.body(8))
                        .foregroundColor(color.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .padding(LTSpacing.lg - 2)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [color.opacity(0.14), Color(red: 0.03, green: 0.04, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    LinearGradient(
                        colors: [Color.white.opacity(0.055), .clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.4)
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: LTRadius.lg)
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.50), color.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: color.opacity(0.15), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(LTPressEffect(scale: 0.95))
        .accessibilityLabel(title)
        .accessibilityHint(sub)
    }
}

// MARK: - ShortcutButton (legacy — kept for compatibility)

struct ShortcutButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            VStack(spacing: LTSpacing.sm - 1) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(LTFont.body(9))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: LTRadius.sm).stroke(color.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(LTPressEffect())
        .accessibilityLabel(label)
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @AppStorage("selectedTab") private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Hem", systemImage: "clock.fill") }
                .tag(0)
            WorkView()
                .tabItem { Label("Arbete", systemImage: "hammer.fill") }
                .tag(1)
            CasinoHubView()
                .tabItem { Label("Kasino", systemImage: "suit.spade.fill") }
                .tag(2)
            ZoneVisual()
                .tabItem { Label("Zoner", systemImage: "map.fill") }
                .tag(3)
            SocialView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }
                .tag(4)
        }
        .tint(LTPalette.neonGreen)
        .preferredColorScheme(.dark)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
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
