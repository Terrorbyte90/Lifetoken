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
        // Gameplay tips
        "Du förlorar 1 sekund varje sekund. Tjäna tillbaka dem.",
        "Varje 7 steg ger dig 1 sekund livstid.",
        "Din tid är din valuta. Använd den klokt.",
        "Zoner låser upp fördelar — ju längre du överlever, desto starkare.",
        "Boosts kan dubbla din inkomst. Använd dem rätt.",
        "Daglig inloggning ger streak-bonus.",
        "Kasino finns i rikare zoner. Odds gynnar alltid huset.",
        "Investera tid i Time Bank — men marknaden kraschar ibland.",
        "Minutmännen är ute på gatorna. Vakta din tid.",
        // Filmcitat (In Time, 2011) — fritt översatta
        "\"Ingen slösar med sin tid som inte har tillräckligt av den.\"",
        "\"De rika lever för evigt — de fattiga dör unga.\"",
        "\"Stäl inte min tid.\"",
        "\"Det finns tillräckligt med tid för alla — systemet är riggat.\"",
        "\"Du lever — så länge din klocka tickar.\"",
        "\"Tid är det enda som verkligen räknas.\"",
        "\"Om du hade en evighet — vad skulle du göra med den?\"",
        "\"De som bor i de rika zonerna glömmer att klockan tickar.\"",
        "\"Överleva idag. Planera för imorgon.\"",
    ]

    var body: some View {
        ZStack {
            // Bakgrundsgradie — mörkare nere mot rött när tid tar slut
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    engine.balance < 3600 ? Color.red.opacity(0.12) : Color.black
                ]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2), value: engine.balance < 3600)

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LIFETOKEN")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text(gameState.username.isEmpty ? "Okänd" : gameState.username)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 4) {
                                Image(systemName: gameState.currentZone.zoneIcon)
                                    .font(.system(size: 12))
                                    .foregroundColor(gameState.currentZone.color)
                                Text(gameState.currentZone.name)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(gameState.currentZone.color)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text("Streak: \(gameState.loginStreakDays) dagar")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)

                    // ══════════════════════════════════════
                    // ARM-KLOCKA SEKTION — Inspirerad av filmen
                    // ══════════════════════════════════════
                    ArmClockView(balance: engine.balance, clockColor: clockColor, pulseScale: pulseScale)
                        .padding(.horizontal)
                        .onAppear {
                            if engine.balance < 3600 { pulseScale = 1.05 }
                        }
                        .onChange(of: engine.balance) { newVal in
                            pulseScale = newVal < 3600 ? 1.05 : 1.0
                        }

                    if engine.cheatingDetected {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("TIDMANIPULATION DETEKTERAD")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }

                    // Stats-rad
                    HStack(spacing: 0) {
                        StatPill(label: "Skatt", value: "\(Int(gameState.currentZone.taxRate * 100))%", color: .yellow)
                        Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                        StatPill(label: "Idag", value: TimeEngine.shortFormatted(incomeManager.earnedSeconds), color: .green)
                        Divider().background(Color.white.opacity(0.1)).frame(height: 36)
                        StatPill(label: "Server", value: engine.ntpVerified ? "✓ Sync" : "⟳ Sync", color: engine.ntpVerified ? .green : .yellow)
                    }
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Active Boosts
                    if !BoostManager.shared.getActiveBoosts().isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                Text("AKTIVA BOOSTS")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.green.opacity(0.8))
                            }
                            ForEach(BoostManager.shared.getActiveBoosts(), id: \.self) { boost in
                                HStack(spacing: 6) {
                                    Circle().fill(Color.green).frame(width: 5, height: 5)
                                    Text(boost)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.green.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal)
                    }

                    // Shortcut buttons
                    HStack(spacing: 12) {
                        ShortcutButton(icon: "cart.fill", label: "Tidsmarknad") { showTimeMarket = true }
                        ShortcutButton(icon: "map.fill", label: "Zonkarta") { showZoneMap = true }
                    }
                    .padding(.horizontal)

                    // Scrollande citat — filmcitat & tips
                    VStack(spacing: 6) {
                        Text(quotes[currentQuoteIndex])
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.4), value: currentQuoteIndex)
                        HStack(spacing: 4) {
                            ForEach(0..<min(5, quotes.count), id: \.self) { i in
                                Circle()
                                    .fill(i == currentQuoteIndex % 5 ? Color.white.opacity(0.6) : Color.white.opacity(0.15))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .onReceive(quoteTimer) { _ in
                        withAnimation { currentQuoteIndex = (currentQuoteIndex + 1) % quotes.count }
                    }

                    Spacer(minLength: 100)
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
        } message: { Text("Din enhetstid stämmer inte med servertiden. Ogiltig tid har dragits av.") }
    }

    private var clockColor: Color {
        if engine.balance <= 0 { return .red }
        if engine.balance < 3600 { return .red }
        if engine.balance < 21600 { return .yellow }
        return .green
    }
}

// MARK: - Arm Clock View (inspirerad av filmens handleds-klocka)

struct ArmClockView: View {
    let balance: TimeInterval
    let clockColor: Color
    let pulseScale: CGFloat

    private var urgencyGlow: Color {
        if balance < 3600 { return .red }
        if balance < 21600 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(spacing: 12) {
            // Övre rad — "handleden"
            HStack {
                VStack(spacing: 2) {
                    Text("◄ ARM KLOCKA ►")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                    // Bioluminescent arm-linje (inspirerad av filmen)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [urgencyGlow.opacity(0.1), urgencyGlow.opacity(0.5), urgencyGlow.opacity(0.1)]),
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(urgencyGlow.opacity(0.6), lineWidth: 1)
                        )
                }
            }

            // Huvud-klocka
            Text(balance <= 0 ? "TIMED OUT" : TimeEngine.formatted(balance))
                .font(.system(size: balance <= 0 ? 38 : 48, weight: .bold, design: .monospaced))
                .foregroundColor(clockColor)
                .scaleEffect(pulseScale)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: balance < 3600)
                .shadow(color: urgencyGlow.opacity(0.4), radius: 8, x: 0, y: 0)

            // Progress-bar — visar hur nära döden man är
            if balance > 0 {
                let fraction = min(1.0, balance / 86400) // 24h = full
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.07))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [clockColor.opacity(0.6), clockColor]),
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 5)

                Text(balance < 86400 ? "VARNING: Mindre än 24h kvar" : "Tid kvar tills kritiskt läge: \(TimeEngine.shortFormatted(max(0, balance - 86400)))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(balance < 21600 ? .red.opacity(0.9) : .white.opacity(0.3))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(urgencyGlow.opacity(balance < 3600 ? 0.5 : 0.15), lineWidth: 1)
        )
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
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
    @ObservedObject private var timekeeperEvents = TimekeeperEventManager.shared

    var body: some View {
        ZStack {
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
                MissionsView()
                    .tabItem {
                        Label("Uppdrag", systemImage: "flag.fill")
                    }
                SocialView()
                    .tabItem {
                        Label("Social", systemImage: "person.2.fill")
                    }
            }
            .accentColor(.green)
            .preferredColorScheme(.dark)

            // Game Over overlay — visas ovanpå allt när spelaren är timed out
            if engine.isTimedOut {
                TimedOutOverlay()
            }
        }
        // Timekeeper events — slumpmässiga filminspierade händelser
        .sheet(isPresented: $timekeeperEvents.showEvent) {
            if let event = timekeeperEvents.currentEvent {
                TimekeeperEventSheet(event: event) {
                    timekeeperEvents.resolveEvent(accepted: true)
                } onDecline: {
                    timekeeperEvents.resolveEvent(accepted: false)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var username: String = ""
    @State private var animating = false
    @State private var showRules = false
    @State private var countdownDisplay: TimeInterval = 86400

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Subtil bakgrundsgradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0, green: 0.15, blue: 0.05), Color.black]),
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 60)

                    // Logo
                    VStack(spacing: 8) {
                        Text("LIFETOKEN")
                            .font(.system(size: 42, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .scaleEffect(animating ? 1.03 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animating)

                        Text("Baserad på världen i")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                        Text("IN TIME (2011)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.5))
                    }

                    // Klocka
                    VStack(spacing: 6) {
                        Text(TimeEngine.formatted(countdownDisplay))
                            .font(.system(size: 52, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                            .shadow(color: .green.opacity(0.4), radius: 10)
                        Text("Tid kvar")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .onAppear {
                        // Simulera countdown i onboarding
                        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
                            if countdownDisplay > 0 {
                                countdownDisplay -= 1
                            } else {
                                t.invalidate()
                            }
                        }
                    }

                    // Filmcitat
                    VStack(spacing: 4) {
                        Text("\"Du lever — så länge din tid inte tar slut.\"")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .italic()
                        Text("— LifeToken")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .padding(.horizontal)

                    // Regler
                    VStack(alignment: .leading, spacing: 14) {
                        Text("HUR DET FUNGERAR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))

                        InfoRow(icon: "clock.fill", text: "Din klocka tickar alltid — även när appen är stängd.")
                        InfoRow(icon: "figure.walk", text: "Varje 7 steg = 1 sekund livstid. Rörelse är överlevnad.")
                        InfoRow(icon: "map.fill", text: "7 zoner att låsa upp. Ju högre zon, desto mer risk och belöning.")
                        InfoRow(icon: "suit.spade.fill", text: "Kasino finns i de rika zonerna. Oddsen gynnar alltid huset.")
                        InfoRow(icon: "person.badge.plus", text: "Lån tid av NPC-spelare — med ränta. Hög risk, hög belöning.")
                        InfoRow(icon: "shield.lefthalf.filled", text: "Tidsvakter patrullerar. Minutmän stjäl. Vakta din tid.")
                        InfoRow(icon: "exclamationmark.triangle.fill", text: "Klockan kan inte fuskas. Servertid verifieras alltid.")
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)
                    .padding(.horizontal)

                    // Namnfält
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DITT NAMN I SYSTEMET")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal)

                        TextField("Ange ditt namn", text: $username)
                            .font(.system(size: 17, design: .monospaced))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(username.isEmpty ? Color.white.opacity(0.1) : Color.green.opacity(0.4), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }

                    Button {
                        guard !username.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        UserDefaults.standard.set(true, forKey: "hasLaunched")
                        UserDefaults.standard.set(username, forKey: "username")
                        UserDefaults.standard.set(Date(), forKey: "absoluteStartTimeUTC")
                        GameState.shared.username = username
                        showOnboarding = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                            Text("STARTA LIVET")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(username.isEmpty ? Color.gray.opacity(0.4) : Color.green)
                        .cornerRadius(14)
                        .animation(.easeInOut(duration: 0.2), value: username.isEmpty)
                    }
                    .disabled(username.isEmpty)
                    .padding(.horizontal)

                    Text("Du startar med 24 timmar. Klockan börjar ticka nu.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer(minLength: 40)
                }
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
