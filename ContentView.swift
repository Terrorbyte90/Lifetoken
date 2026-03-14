import SwiftUI

struct DashboardView: View {
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var incomeManager = IncomeManager.shared

    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasLaunched")
    @State private var showTimeMarket = false
    @State private var showZoneMap = false
    @State private var currentQuoteIndex: Int = 0
    @State private var quoteTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var pulseScale: CGFloat = 1.0
    @State private var showCheatingAlert = false

    let quotes = [
        "Du forlorar 1 sekund varje sekund. Tjana tillbaka dem.",
        "Varje 7 steg ger dig 1 sekund livstid.",
        "Din tid ar din valuta. Anvand den klokt.",
        "Zoner laser upp fordelar – ju langre du overlever, desto starkare.",
        "Boosts kan dubbla din inkomst. Anvand dem ratt.",
        "Daglig inloggning ger streak-bonus.",
        "Kasino finns i rikare zoner. Odds gynnar alltid huset.",
        "Investera tid i Time Bank – men marknaden kraschar ibland.",
        "Minutmannen ar ute pa gatorna. Vakta din tid."
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LIFETOKEN")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text(gameState.username.isEmpty ? "Okand" : gameState.username)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(gameState.currentZone.name)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                            Text("Streak: \(gameState.loginStreakDays) dagar")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)

                    // ══════════════════════════════
                    // MAIN CLOCK — DO NOT CHANGE FONT
                    // ══════════════════════════════
                    VStack(spacing: 8) {
                        Text(engine.balance <= 0 ? "TIMED OUT" : TimeEngine.formatted(engine.balance))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(clockColor)
                            .scaleEffect(pulseScale)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: engine.balance < 3600)
                            .onAppear { if engine.balance < 3600 { pulseScale = 1.05 } }
                            .onChange(of: engine.balance) { newVal in
                                pulseScale = newVal < 3600 ? 1.05 : 1.0
                            }

                        if engine.cheatingDetected {
                            Text("TIDMANIPULATION DETEKTERAD")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                        }

                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                Text("Skattesats")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("\(Int(gameState.currentZone.taxRate * 100))%")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                            Divider().background(Color.white.opacity(0.2)).frame(height: 30)
                            VStack(spacing: 2) {
                                Text("Tjanat idag")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(TimeEngine.shortFormatted(incomeManager.earnedSeconds))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            Divider().background(Color.white.opacity(0.2)).frame(height: 30)
                            VStack(spacing: 2) {
                                Text("NTP")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(engine.ntpVerified ? "OK" : "sync")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(engine.ntpVerified ? .green : .yellow)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(16)
                    .padding(.horizontal)

                    // Active Boosts
                    if !BoostManager.shared.getActiveBoosts().isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AKTIVA BOOSTS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.green.opacity(0.7))
                            ForEach(BoostManager.shared.getActiveBoosts(), id: \.self) { boost in
                                Text("• \(boost)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Shortcut buttons
                    HStack(spacing: 12) {
                        ShortcutButton(icon: "cart.fill", label: "Butik") { showTimeMarket = true }
                        ShortcutButton(icon: "map.fill", label: "Zoner") { showZoneMap = true }
                    }
                    .padding(.horizontal)

                    // Quote
                    Text(quotes[currentQuoteIndex])
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .onReceive(quoteTimer) { _ in
                            withAnimation { currentQuoteIndex = (currentQuoteIndex + 1) % quotes.count }
                        }

                    Spacer(minLength: 80)
                }
            }
        }
        .onAppear { gameState.updateZone() }
        .fullScreenCover(isPresented: $showOnboarding) { OnboardingView(showOnboarding: $showOnboarding) }
        .sheet(isPresented: $showTimeMarket) {
            TimeMarketView(timeRemaining: .constant(engine.balance), currentZone: gameState.currentZone)
        }
        .sheet(isPresented: $showZoneMap) { ZoneVisual() }
        .alert("Streak Bonus!", isPresented: $gameState.showStreakBonus) {
            Button("Tack!", role: .cancel) {}
        } message: { Text(gameState.streakBonusMessage) }
        .alert("Fusk Detekterat", isPresented: $engine.cheatingDetected) {
            Button("OK") {}
        } message: { Text("Din enhetstid stammer inte med servertiden. Ogiltig tid har dragits av.") }
    }

    private var clockColor: Color {
        if engine.balance <= 0 { return .red }
        if engine.balance < 3600 { return .red }
        if engine.balance < 21600 { return .yellow }
        return .green
    }
}

struct ShortcutButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label).font(.system(size: 13, weight: .medium, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(Color.white.opacity(0.08))
            .cornerRadius(10)
            .foregroundColor(.white)
        }
    }
}

struct MainTabView: View {
    @ObservedObject private var engine = TimeEngine.shared

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Hem", systemImage: "clock.fill")
                }
            WorkView()
                .tabItem {
                    Label("Arbete", systemImage: "hammer.fill")
                }
            CasinoHubView()
                .tabItem {
                    Label("Kasino", systemImage: "suit.spade.fill")
                }
            ZoneVisual()
                .tabItem {
                    Label("Zoner", systemImage: "map.fill")
                }
            SocialView()
                .tabItem {
                    Label("Social", systemImage: "person.2.fill")
                }
        }
        .accentColor(.green)
        .preferredColorScheme(.dark)
    }
}

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var username: String = ""
    @State private var animating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                Text("LIFETOKEN")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .scaleEffect(animating ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animating)

                Text("00:00:00")
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)

                Text("\"Ingen tid att forlora.\"")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                VStack(alignment: .leading, spacing: 12) {
                    InfoRow(icon: "clock", text: "Din klocka tickar alltid — aven nar appen ar stangd.")
                    InfoRow(icon: "figure.walk", text: "Varje 7 steg = 1 sekund livstid.")
                    InfoRow(icon: "map", text: "7 zoner att lasa upp. Ju hogre zon, desto mer risk och beloning.")
                    InfoRow(icon: "suit.spade.fill", text: "Kasino finns i de rika zonerna. Odsen gynnar alltid huset.")
                    InfoRow(icon: "exclamationmark.triangle", text: "Klockan kan inte fuskas. Servertid verifieras alltid.")
                }
                .padding(.horizontal)

                TextField("Ditt namn", text: $username)
                    .font(.system(size: 18, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                Button {
                    guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    UserDefaults.standard.set(true, forKey: "hasLaunched")
                    UserDefaults.standard.set(username, forKey: "username")
                    UserDefaults.standard.set(Date(), forKey: "absoluteStartTimeUTC")
                    GameState.shared.username = username
                    showOnboarding = false
                } label: {
                    Text("STARTA LIVET")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(username.isEmpty ? Color.gray : Color.green)
                        .cornerRadius(14)
                        .padding(.horizontal)
                }
                .disabled(username.isEmpty)

                Spacer()
            }
        }
        .onAppear { animating = true }
    }
}

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
