import SwiftUI

struct DashboardView: View {
    @ObservedObject private var engine        = TimeEngine.shared
    @ObservedObject private var gameState     = GameState.shared
    @ObservedObject private var incomeManager = IncomeManager.shared
    @ObservedObject private var shop          = ShopManager.shared
    @ObservedObject private var zoneManager   = ZoneManager.shared
    @ObservedObject private var inflation     = InflationManager.shared

    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasLaunched")
    @State private var showTimeMarket = false
    @State private var showZoneMap = false
    @State private var showInvestment = false
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

                    // ════════════════════════════════════════
                    // ZON-STATUS KORT — aktuell zon, inflation, nästa zon
                    // ════════════════════════════════════════
                    ZoneStatusCard(
                        zone: zoneManager.currentZone,
                        nextZone: zoneManager.nextZone,
                        inflation: inflation,
                        canMigrate: zoneManager.canMigrateToNext(),
                        onMigrate: {
                            let result = zoneManager.migrateToNextZone()
                            if !result.success {
                                // Feedback om misslyckad migration visas i ZoneVisual
                            }
                        },
                        onViewMap: { showZoneMap = true }
                    )
                    .padding(.horizontal)

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

                    // Aktiva effekter från ShopManager
                    let liveEffects = shop.activeEffects.filter { !$0.isExpired }
                    if !liveEffects.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                    .foregroundColor(.yellow)
                                Text("AKTIVA EFFEKTER (\(liveEffects.count))")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.yellow.opacity(0.85))
                            }
                            FlowLayout(items: liveEffects) { effect in
                                HStack(spacing: 5) {
                                    Circle().fill(Color.green).frame(width: 4, height: 4)
                                    Text(effect.name)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                    if effect.remainingSeconds > 0 {
                                        Text(TimeEngine.shortFormatted(effect.remainingSeconds))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                }
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.white.opacity(0.07))
                                .clipShape(Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.yellow.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.2), lineWidth: 1))
                        .padding(.horizontal)
                    }

                    // Shortcut buttons — 3-kolumns grid
                    HStack(spacing: 10) {
                        ShopShortcutButton { showTimeMarket = true }
                        ShortcutButton(icon: "chart.bar.fill", label: "Time Bank") { showInvestment = true }
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
        .onAppear {
            gameState.updateZone()
            gameState.checkLoginStreak()
        }
        .fullScreenCover(isPresented: $showOnboarding) { OnboardingView(showOnboarding: $showOnboarding) }
        .sheet(isPresented: $showTimeMarket) {
            TimeMarketView(timeRemaining: .constant(engine.balance), currentZone: gameState.currentZone)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showInvestment) {
            InvestmentView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showZoneMap) {
            ZoneVisual()
                .presentationDetents([.large])
        }
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

    private var statusLabel: String {
        if balance <= 0 { return "TIMED OUT" }
        if balance < 3600 { return "KRITISKT — TJÄNA TID NU" }
        if balance < 21600 { return "VARNING — UNDER 6 TIMMAR" }
        if balance < 86400 { return "LÅGT — UNDER 24 TIMMAR" }
        return "AKTIV"
    }

    private var fraction: Double { min(1.0, balance / 86400) }

    var body: some View {
        VStack(spacing: 14) {

            // Statuslinje — bioluminescerande arm-linje
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(urgencyGlow)
                        .frame(width: 5, height: 5)
                        .shadow(color: urgencyGlow, radius: 4)
                    Text(statusLabel)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(urgencyGlow.opacity(0.9))
                    Spacer()
                    Text("IN TIME")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.12))
                        .tracking(3)
                }

                // Bioluminescent linje
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 5)
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [urgencyGlow.opacity(0.5), urgencyGlow, urgencyGlow.opacity(0.7)]),
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(0, CGFloat(fraction)) * UIScreen.main.bounds.width - 64, height: 5)
                        .shadow(color: urgencyGlow.opacity(0.5), radius: 4)
                }
            }

            // Huvud-klocka
            Text(balance <= 0 ? "00:00:00" : TimeEngine.formatted(balance))
                .font(.system(size: balance <= 0 ? 38 : 50, weight: .bold, design: .monospaced))
                .foregroundColor(clockColor)
                .scaleEffect(pulseScale)
                .animation(
                    balance < 3600
                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                        : .default,
                    value: pulseScale
                )
                .shadow(color: urgencyGlow.opacity(balance < 3600 ? 0.6 : 0.25), radius: 12)
                .frame(maxWidth: .infinity, alignment: .center)

            // Sekundärt — dagar/total
            if balance >= 86400 {
                let days = Int(balance) / 86400
                let hours = (Int(balance) % 86400) / 3600
                Text("\(days) dag\(days == 1 ? "" : "ar") \(hours) tim kvar")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(urgencyGlow.opacity(balance < 3600 ? 0.55 : 0.12), lineWidth: 1)
        )
        .shadow(color: urgencyGlow.opacity(balance < 3600 ? 0.15 : 0), radius: 20)
    }
}

// MARK: - Stat Pill

// Enkel FlowLayout för aktiva effekter — wraps items i rader
struct FlowLayout<Item: Identifiable, Content: View>: View {
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                content(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

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

    @State private var pressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            .scaleEffect(pressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2), value: pressed)
        }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }
        )
    }
}

// Marknad-knapp med badge för aktiva effekter
struct ShopShortcutButton: View {
    @ObservedObject private var shop = ShopManager.shared
    let action: () -> Void
    @State private var pressed = false

    private var activeCount: Int {
        shop.activeEffects.filter { !$0.isExpired }.count
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Marknad")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(activeCount > 0 ? Color.green.opacity(0.12) : Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(activeCount > 0 ? Color.green.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                )

                if activeCount > 0 {
                    Text("\(activeCount)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                        .padding(4)
                        .background(Color.green)
                        .clipShape(Circle())
                        .offset(x: -6, y: 4)
                }
            }
            .scaleEffect(pressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2), value: pressed)
        }
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in pressed = true }
            .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - Zone Status Card — Dashboard zonkort

struct ZoneStatusCard: View {
    let zone: ZoneProfile
    let nextZone: ZoneProfile?
    let inflation: InflationManager
    let canMigrate: Bool
    let onMigrate: () -> Void
    let onViewMap: () -> Void

    @State private var borderPhase: CGFloat = 0
    @State private var glowPulse = false
    @State private var showMigrateAlert = false
    @State private var migrateMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // ── Topp: nuvarande zon ──
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    // Zon-ikon med pulsande ring
                    ZStack {
                        Circle()
                            .stroke(zone.color.opacity(glowPulse ? 0.7 : 0.2), lineWidth: 1.5)
                            .frame(width: 44, height: 44)
                            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowPulse)
                        Circle()
                            .fill(zone.color.opacity(0.15))
                            .frame(width: 38, height: 38)
                        Image(systemName: zone.zoneIcon)
                            .font(.system(size: 17))
                            .foregroundColor(zone.color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("DIN ZON")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                            Text(zone.name.uppercased())
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(zone.color)
                        }
                        Text(zone.description)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: onViewMap) {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 10))
                            Text("Karta")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(zone.color.opacity(0.85))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(zone.color.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                // Stats row
                HStack(spacing: 0) {
                    ZoneQuickStat(label: "SKATT", value: "\(Int(zone.taxRate * 100))%", color: .yellow)
                    Divider().background(Color.white.opacity(0.08)).frame(height: 30)
                    ZoneQuickStat(label: "JOBB", value: "x\(String(format: "%.1f", zone.workMultiplier))", color: .green)
                    Divider().background(Color.white.opacity(0.08)).frame(height: 30)
                    ZoneQuickStat(label: "KASINO", value: zone.casinoAccess ? "Ja" : "Nej", color: zone.casinoAccess ? .cyan : .gray)
                    Divider().background(Color.white.opacity(0.08)).frame(height: 30)
                    ZoneQuickStat(label: "BOOSTS", value: "\(zone.maxActiveBoosts)", color: .purple)
                }
                .background(Color.black.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Inflation indicator
                HStack(spacing: 6) {
                    Image(systemName: inflation.severity.icon)
                        .font(.system(size: 11))
                        .foregroundColor(inflation.severity.color)
                    Text("Inflation \(inflation.percentLabel)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(inflation.severity.color)
                    Text("•")
                        .foregroundColor(.white.opacity(0.2))
                    Text("\(inflation.daysLabel) i zonen")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(inflation.severity.label)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(inflation.severity.color)
                        .clipShape(Capsule())
                }
            }
            .padding(14)

            // ── Nästa zon ──
            if let next = nextZone {
                Divider().background(zone.color.opacity(0.15))

                HStack(spacing: 10) {
                    Image(systemName: next.zoneIcon)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.35))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text("NÄSTA:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                            Text(next.name)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Text("x\(String(format: "%.1f", next.workMultiplier)) jobb • \(Int(next.taxRate * 100))% skatt")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.3))
                    }

                    Spacer()

                    if canMigrate {
                        Button(action: {
                            let result = ZoneManager.shared.migrateToNextZone()
                            migrateMessage = result.message
                            showMigrateAlert = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 12))
                                Text("Flytta — \(TimeEngine.shortFormatted(next.entryCostSeconds))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(next.color)
                            .clipShape(Capsule())
                        }
                    } else {
                        Text("\(TimeEngine.shortFormatted(next.entryCostSeconds)) krävs")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(
            ZStack {
                Color.white.opacity(0.04)
                LinearGradient(
                    gradient: Gradient(colors: [zone.color.opacity(0.08), Color.clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            zone.color.opacity(0.7),
                            zone.color.opacity(0.15),
                            zone.color.opacity(0.5),
                            zone.color.opacity(0.1),
                            zone.color.opacity(0.7)
                        ]),
                        center: .center,
                        angle: .degrees(borderPhase)
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: zone.color.opacity(0.15), radius: 12, y: 4)
        .onAppear {
            glowPulse = true
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                borderPhase = 360
            }
        }
        .alert("Zonmigration", isPresented: $showMigrateAlert) {
            Button("OK") {}
        } message: { Text(migrateMessage) }
    }
}

struct ZoneQuickStat: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
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
