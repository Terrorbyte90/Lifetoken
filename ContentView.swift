import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var incomeManager = IncomeManager.shared
    @ObservedObject private var inflation = InflationManager.shared
    @ObservedObject private var server = ServerSync.shared

    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasLaunched")
    @State private var showTimeMarket = false
    @State private var showZoneMap = false
    @State private var showMissions = false
    @State private var showInvestment = false
    @State private var showBank = false
    @State private var currentQuoteIndex: Int = 0
    @State private var quoteTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseAnim: Bool = false

    let quotes = [
        "Du förlorar 1 sekund varje sekund. Tjäna tillbaka dem.",
        "10 000 steg ger dig 3 timmars livstid. Rör på dig.",
        "Din tid är din valuta. Använd den klokt.",
        "Zoner låser upp fördelar — ju längre du överlever, desto starkare.",
        "Boosts kan dubbla din inkomst. Köp dem i Butiken.",
        "8 timmars sömn ger 4 timmar extra livstid nästa dag.",
        "Kasino öppnar i Eterpunkten. Oddsen gynnar alltid huset.",
        "Investera tid i Time Bank — men marknaden kraschar ibland.",
        "Inflation äter upp din förmögenhet. Migrera uppåt.",
        "Mindfulness ger 90 sekunders liv per tränad minut.",
        "Din HRV avgör om du är frisk. >50ms ger 1 timme bonus.",
        "Träna 60 minuter — tjäna 1 timme liv. Break-even på träning.",
        "Kasino är högrisk. Förlora aldrig mer än du har råd.",
        "Varje 12 minuters träning ger dig 1 extra timmes livstid.",
        "Spela Yatzy mot vänner — satsa tid och dubbla upp.",
        "Migrera uppåt för passiv inkomst och arbetsbonus.",
        "Sov optimalt (7–9h) för maximal hälsobonus vid midnatt."
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    topHeader
                    clockSection
                    if inflation.isWarning { inflationBanner }
                    statsRow
                    shortcutGrid
                    activeBoostsSection
                    quoteCarousel
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
        .sheet(isPresented: $showTimeMarket) {
            TimeMarketView()
        }
        .sheet(isPresented: $showZoneMap) { ZoneVisual() }
        .sheet(isPresented: $showMissions) { MissionsView() }
        .sheet(isPresented: $showInvestment) { InvestmentView() }
        .sheet(isPresented: $showBank) { BankView() }
        .alert("Streak Bonus!", isPresented: $gameState.showStreakBonus) {
            Button("Tack!", role: .cancel) {}
        } message: { Text(gameState.streakBonusMessage) }
        .alert("Fusk Detekterat", isPresented: $engine.cheatingDetected) {
            Button("OK") {}
        } message: { Text("Din enhetstid stämmer inte med servertiden. Ogiltig tid har dragits av.") }
        .alert("🌅 Daglig Hälsoinkomst", isPresented: $incomeManager.showDailySummary) {
            Button("Tack!", role: .cancel) {}
        } message: { Text(incomeManager.summaryMessage) }
    }

    // MARK: Top Header
    private var topHeader: some View {
        HStack(alignment: .center) {
            Text("LIFETOKEN")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 8) {
                // Zone pill
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

                // Streak badge
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

    // MARK: Clock Section
    private var clockSection: some View {
        VStack(spacing: 12) {
            if engine.balance <= 0 {
                Text("TIMED OUT")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            } else {
                Text(TimeEngine.formatted(engine.balance))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(clockColor)
                    .scaleEffect(pulseAnim ? 1.04 : 1.0)
                    .animation(
                        engine.balance < 3600
                            ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                            : .default,
                        value: pulseAnim
                    )
                    .onChange(of: engine.balance < 3600) { isLow in
                        pulseAnim = isLow
                    }
                    .onAppear { pulseAnim = engine.balance < 3600 }
            }

            if engine.cheatingDetected {
                Text("TIDMANIPULATION DETEKTERAD")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(clockColor.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    // MARK: Inflation Banner
    private var inflationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("INFLATION: \(inflation.percentageString) — Migrera uppåt")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.orange)
            Spacer()
        }
        .padding(12)
        .background(
            LinearGradient(colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        .padding(.horizontal)
    }

    // MARK: Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(label: "Skatt", value: "\(Int(gameState.currentZone.taxRate * 100))%", color: .yellow)
            Divider().background(Color.white.opacity(0.15)).frame(height: 36)
            statColumn(label: "Hälsa idag", value: TimeEngine.shortFormatted(incomeManager.todayBreakdown.total), color: .green)
            Divider().background(Color.white.opacity(0.15)).frame(height: 36)
            statColumn(
                label: "Server",
                value: server.isOnline ? "Online" : "Offline",
                color: server.isOnline ? .green : .red
            )
            Divider().background(Color.white.opacity(0.15)).frame(height: 36)
            statColumn(
                label: "Online",
                value: "\(max(1, server.onlineCount))",
                color: .cyan
            )
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func statColumn(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Shortcut Grid
    private var shortcutGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ShortcutButton(icon: "cart.fill", label: "Butik", color: .cyan) { showTimeMarket = true }
            ShortcutButton(icon: "map.fill", label: "Zoner", color: .green) { showZoneMap = true }
            ShortcutButton(icon: "target", label: "Uppdrag", color: .yellow) { showMissions = true }
            ShortcutButton(icon: "building.columns.fill", label: "Time Bank", color: .blue) { showBank = true }
            ShortcutButton(icon: "suit.spade.fill", label: "Kasino", color: gameState.currentZone.casinoAccess ? .purple : .gray) {
                // Tab will handle this
            }
            ShortcutButton(icon: "person.2.fill", label: "Social", color: .teal) {
                // Tab will handle this
            }
        }
        .padding(.horizontal)
    }

    // MARK: Active Boosts
    @ViewBuilder
    private var activeBoostsSection: some View {
        let boosts = BoostManager.shared.getActiveBoosts()
        if !boosts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("AKTIVA BOOSTS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
                    .padding(.horizontal, 14)

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
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    // MARK: Quote Carousel
    private var quoteCarousel: some View {
        Text(quotes[currentQuoteIndex])
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.white.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.4), value: currentQuoteIndex)
            .onReceive(quoteTimer) { _ in
                withAnimation { currentQuoteIndex = (currentQuoteIndex + 1) % quotes.count }
            }
    }

    private var clockColor: Color {
        if engine.balance <= 0 { return .red }
        if engine.balance < 3600 { return .red }
        if engine.balance < 21600 { return .yellow }
        return .green
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
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    @ObservedObject private var engine = TimeEngine.shared

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

// MARK: - OnboardingView (Multi-step)

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var step: Int = 0
    @State private var username: String = ""
    @State private var isRegistering: Bool = false
    @State private var splashPulse: Bool = false
    @State private var healthGranted: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            switch step {
            case 0: splashStep
            case 1: reglerStep
            case 2: zonerStep
            case 3: halsaStep
            case 4: namnStep
            default: namnStep
            }
        }
        .onAppear { splashPulse = true }
    }

    // MARK: Step 0 — Splash
    private var splashStep: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("⏱")
                .font(.system(size: 80))
                .scaleEffect(splashPulse ? 1.1 : 0.95)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: splashPulse)

            Text("LIFETOKEN")
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("Din tid är ditt liv. Bokstavligen.")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            onboardingNextButton(label: "FORTSÄTT") { withAnimation { step = 1 } }
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
    }

    // MARK: Step 1 — Regler
    private var reglerStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("REGLERNA")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 16) {
                InfoRow(icon: "clock.fill", text: "Klockan tickar alltid. Du kan inte pausa livet.")
                InfoRow(icon: "figure.walk", text: "Varje 7 steg ger dig 1 sekund att leva.")
                InfoRow(icon: "suit.spade.fill", text: "Kasino, jobb och investeringar ger också tid.")
                InfoRow(icon: "exclamationmark.triangle.fill", text: "Nollställs din tid — dör du.")
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            onboardingNextButton(label: "FÖRSTÅR") { withAnimation { step = 2 } }
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
    }

    // MARK: Step 2 — Zoner
    private var zonerStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("ZONERNA")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("14 zoner. Klättra uppåt. Eller falla.")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: 8) {
                ForEach([ZoneProfile.solara, ZoneProfile.midgrey, ZoneProfile.grundskiftet], id: \.name) { zone in
                    let isCurrent = zone.name == ZoneProfile.midgrey.name
                    HStack {
                        Image(systemName: zone.zoneIcon)
                            .font(.system(size: 16))
                            .foregroundColor(isCurrent ? zone.color : .white.opacity(0.3))
                            .frame(width: 28)
                        Text(zone.name)
                            .font(.system(size: 13, weight: isCurrent ? .bold : .regular, design: .monospaced))
                            .foregroundColor(isCurrent ? zone.color : .white.opacity(0.3))
                        Spacer()
                        if isCurrent {
                            Text("DIN NIVÅ")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(12)
                    .background(isCurrent ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)

            Text("Högre zon = mer makt, mer möjligheter, mer risk.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            onboardingNextButton(label: "NÄSTA") { withAnimation { step = 3 } }
                .padding(.horizontal)
                .padding(.bottom, 40)
        }
    }

    // MARK: Step 3 — Hälsa
    private var halsaStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("DIN KROPP ÄR DIN BANK")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                healthInfoRow(icon: "figure.walk", text: "Steg omvandlas till sekunder")
                healthInfoRow(icon: "heart.fill", text: "HRV, sömn och kalorier räknas")
                healthInfoRow(icon: "moon.fill", text: "Sov 7-9 timmar för maxbonus")
                healthInfoRow(icon: "figure.mind.and.body", text: "Mindfulness ger extra tid")
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Button {
                HealthKitManager.shared.requestAuthorization { granted in
                    DispatchQueue.main.async {
                        healthGranted = granted
                        withAnimation { step = 4 }
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "heart.fill")
                    Text("GE TILLGÅNG TILL HÄLSA")
                }
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)

            Button { withAnimation { step = 4 } } label: {
                Text("Hoppa över")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .underline()
            }

            Spacer()
        }
    }

    private func healthInfoRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.green)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()
        }
    }

    // MARK: Step 4 — Namn
    private var namnStep: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("VILT ÄR DITT NAMN?")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("Ditt namn visas för andra spelare i din zon.")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            TextField("Ditt namn", text: $username)
                .font(.system(size: 18, design: .monospaced))
                .foregroundColor(.white)
                .padding()
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)

            Button {
                let trimmed = username.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                isRegistering = true
                UserDefaults.standard.set(true, forKey: "hasLaunched")
                UserDefaults.standard.set(trimmed, forKey: "username")
                UserDefaults.standard.set(Date(), forKey: "absoluteStartTimeUTC")
                GameState.shared.username = trimmed
                Task {
                    await ServerSync.shared.loginOrRegister(username: trimmed)
                    DispatchQueue.main.async {
                        isRegistering = false
                        showOnboarding = false
                    }
                }
            } label: {
                HStack {
                    if isRegistering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    }
                    Text("STARTA DITT LIV")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(username.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || isRegistering)
            .padding(.horizontal)

            Spacer()
        }
    }

    private func onboardingNextButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Previews

#Preview("Dashboard") {
    DashboardView()
        .preferredColorScheme(.dark)
}

#Preview("Main Tabs") {
    MainTabView()
        .preferredColorScheme(.dark)
}

#Preview("Onboarding") {
    OnboardingView(showOnboarding: .constant(true))
        .preferredColorScheme(.dark)
}
