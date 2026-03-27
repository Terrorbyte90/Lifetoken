import SwiftUI
import AVKit

// MARK: - ZoneChatMessage

struct ZoneChatMessage: Identifiable, Codable {
    let id: String
    let username: String
    let text: String
    let timestamp: Date
    let zone: String
}

// MARK: - ZoneChatManager

class ZoneChatManager: ObservableObject {
    static let shared = ZoneChatManager()
    @Published var messages: [ZoneChatMessage] = []
    private let key = "zone_chat_v1"
    private var refreshTimer: Timer?

    private init() { loadMessages(); startRefresh() }

    func loadMessages() {
        let zone = GameState.shared.currentZone.name
        guard let data = UserDefaults.standard.data(forKey: key),
              let all = try? JSONDecoder().decode([ZoneChatMessage].self, from: data)
        else { messages = []; return }
        messages = Array(all.filter { $0.zone == zone }.suffix(50).reversed())
    }

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let zone = GameState.shared.currentZone.name
        let msg = ZoneChatMessage(
            id: UUID().uuidString,
            username: UserDefaults.standard.string(forKey: "username") ?? "Spelare",
            text: trimmed, timestamp: Date(), zone: zone
        )
        var all: [ZoneChatMessage] = []
        if let data = UserDefaults.standard.data(forKey: key),
           let existing = try? JSONDecoder().decode([ZoneChatMessage].self, from: data) {
            all = existing
        }
        all.append(msg)
        if all.count > 200 { all = Array(all.suffix(200)) }
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
        loadMessages()
    }

    private func startRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.loadMessages()
        }
    }
}

// MARK: - DashboardView

struct DashboardView: View {
    @ObservedObject private var engine        = TimeEngine.shared
    @ObservedObject private var gameState     = GameState.shared
    @ObservedObject private var incomeManager = IncomeManager.shared
    @ObservedObject private var inflation     = InflationManager.shared
    @ObservedObject private var server        = ServerSync.shared
    @ObservedObject private var board         = BoardManager.shared
    @ObservedObject private var socialManager = SocialManager.shared

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
    @State private var showGazette     = false
    @State private var showSettings    = false
    @State private var pulseAnim: Bool = false

    // Zonchatt
    @State private var chatInput = ""

    // Topplista
    @State private var topListIndex = 0
    @State private var liveTopPlayers: [ServerUser] = []

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
                    ZoneVideoInfoCard(
                        zone: gameState.currentZone,
                        memberCount: server.zoneMembers.count,
                        onTap: { showZoneMap = true }
                    )
                    .padding(.horizontal)
                    salaryCard
                    pvpSection
                    zoneChatCard
                    missionsCard
                    toplistaSection
                    NewsFeedWidget(maxItems: 3).padding(.horizontal)
                    microTextBar
                    Spacer(minLength: LTSpacing.scrollBottom)
                }
                .padding(.top, 4)
            }
        }
        .onAppear {
            gameState.updateZone()
            inflation.update()
            Task { await loadLiveTopPlayers() }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(showOnboarding: $showOnboarding)
        }
        .sheet(isPresented: $showTimeMarket)          { TimeMarketView() }
        .fullScreenCover(isPresented: $showZoneMap)     { NavigationStack { ZoneVisual() } }
        .sheet(isPresented: $showMissions)              { MissionsView() }
        .fullScreenCover(isPresented: $showBank)        { BankView() }
        .sheet(isPresented: $showStepBet)              { StepBetView() }
        .fullScreenCover(isPresented: $showNightMarket) { NightMarketView() }
        .sheet(isPresented: $showPvPRaid)              { PvPRaidView() }
        .sheet(isPresented: $showNewsFeed)             { NavigationStack { NewsFeedView() } }
        .sheet(isPresented: $showBoard)                { NavigationStack { BoardDetailView() } }
        .sheet(isPresented: $showMiniJobs)             { NavigationStack { MiniJobsView() } }
        .sheet(isPresented: $showGazette)              { NavigationStack { GazetteView() } }
        .sheet(isPresented: $showSettings)             { AccountSettingsView() }
        .alert("Streak Bonus!", isPresented: $gameState.showStreakBonus) {
            Button("Tack!", role: .cancel) {}
        } message: { Text(gameState.streakBonusMessage) }
        // Anti-cheat handled silently by server
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

            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))
            }
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

    // MARK: - Salary Card

    private var salaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LÖN")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(3)
                    Text("Din hälsa ger dig lön, bättre hälsa, mer lön")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .italic()
                }
                Spacer()
            }
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label("HÄLSOINKOMST", systemImage: "heart.fill")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.green.opacity(0.6))
                    Text(TimeEngine.formatted(incomeManager.projectedDailyIncome))
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                    Label("\(incomeManager.dailySteps.formatted()) steg", systemImage: "figure.walk")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.green.opacity(0.5))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("NÄSTA UTBETALNING")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Text(countdownToMidnight())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.03, green: 0.10, blue: 0.03))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Topplista

    private let topListCycleTexts = [
        "Tre mäktigaste spelarna kontrollerar lifetokens ekonomi",
        "Mäktigaste spelarna lever på din och alla andras tid",
        "Klättra förbi dem och ta deras plats om du kan"
    ]

    private var toplistaSection: some View {
        let displayPlayers: [(name: String, advantage: String)] = liveTopPlayers.isEmpty
            ? [
                ("Viktor_H",  "+15% av allas inkomst"),
                ("Malin_88",  "+8% av allas inkomst"),
                ("ZeroKing",  "+4% av allas inkomst")
            ]
            : liveTopPlayers.prefix(3).map { user in
                let balance = TimeEngine.shortFormatted(user.timeBalance ?? 0)
                return (user.username, "~\(balance)")
            }

        return VStack(alignment: .leading, spacing: 10) {
            Text(topListCycleTexts[topListIndex])
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(.easeInOut(duration: 0.4), value: topListIndex)

            HStack {
                Text("TOPPLISTA")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(3)
                Spacer()
            }

            ForEach(Array(displayPlayers.enumerated()), id: \.offset) { i, player in
                HStack(spacing: 10) {
                    Text("#\(i + 1)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(i == 0 ? .yellow : i == 1 ? Color(white: 0.75) : Color(red: 0.8, green: 0.5, blue: 0.2))
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(player.name)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text(player.advantage)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.green.opacity(0.65))
                    }
                    Spacer()
                    Text("??:??:??")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.025))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            withAnimation { topListIndex = (topListIndex + 1) % topListCycleTexts.count }
        }
        .task(id: gameState.currentZone.name) {
            await loadLiveTopPlayers()
        }
    }

    // MARK: - Zone Chat Card

    private var zoneChatCard: some View {
        let zoneMessages = socialManager.currentZoneMessages
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(.cyan.opacity(0.55))
                    .font(.system(size: 12))
                Text("ZONCHATT — \(gameState.currentZone.name.uppercased())")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
            }

            if zoneMessages.isEmpty {
                Text("Ingen har skrivit ännu. Var den första.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
                    .italic()
                    .padding(.vertical, 4)
            } else {
                ForEach(zoneMessages.suffix(5)) { msg in
                    HStack(alignment: .top, spacing: 5) {
                        Text(msg.senderName + ":")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.75))
                            .lineLimit(1)
                        Text(msg.text)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(2)
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Skriv...", text: $chatInput)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit { sendZoneMessage() }
                Button("→") { sendZoneMessage() }
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(Color(red: 0.02, green: 0.07, blue: 0.10))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Missions Card

    private var missionsCard: some View {
        Button { showMissions = true } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.purple.opacity(0.15)).frame(width: 44, height: 44)
                    Image(systemName: "checklist")
                        .font(.system(size: 20))
                        .foregroundColor(.purple.opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("UPPDRAG")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                        .tracking(2)
                    Text("Tryck för att visa aktiva uppdrag")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(14)
            .background(Color.purple.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.18), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - PvP Section

    private var pvpSection: some View {
        VStack(spacing: 10) {
            Text("Livet är orättvist i Lifetoken, var orättvis tillbaks..")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 10) {
                Button { showStepBet = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("STEG-DUELL")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                            Text("Utmana en spelare")
                                .font(.system(size: 9, design: .monospaced))
                                .opacity(0.7)
                        }
                        Spacer()
                    }
                    .foregroundColor(.orange)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.22), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button { showPvPRaid = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RÅN")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                            Text("Råna en spelare")
                                .font(.system(size: 9, design: .monospaced))
                                .opacity(0.7)
                        }
                        Spacer()
                    }
                    .foregroundColor(.red)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.22), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
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

    private func sendZoneMessage() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        socialManager.sendMessage(text)
        chatInput = ""
    }

    private func loadLiveTopPlayers() async {
        do {
            let users = try await server.fetchZoneLeaderboard(zone: gameState.currentZone.name, limit: 3)
            await MainActor.run {
                liveTopPlayers = users.sorted(by: { ($0.timeBalance ?? 0) > ($1.timeBalance ?? 0) })
            }
        } catch {
            await MainActor.run {
                liveTopPlayers = []
            }
        }
    }
}

// MARK: - ZoneVideoInfoCard

struct ZoneVideoInfoCard: View {
    let zone: ZoneProfile
    let memberCount: Int
    let onTap: () -> Void

    @State private var player: AVPlayer? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let p = player {
                    LoopingVideoPlayer(player: p)
                } else {
                    zone.color.opacity(0.15)
                }
            }
            .frame(height: 160)

            LinearGradient(
                colors: [.clear, .black.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: zone.zoneIcon)
                        .foregroundColor(zone.color)
                        .font(.system(size: 12))
                    Text(zone.name.uppercased())
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(zone.color)
                        .tracking(2)
                    Spacer()
                    Text("VISA ZONER →")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                HStack(spacing: 16) {
                    Label("\(memberCount) spelare", systemImage: "person.2.fill")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                    Label("\(Int(zone.taxRate * 100))% skatt", systemImage: "percent")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.orange.opacity(0.85))
                    Label(String(format: "%.1f%% infl/dag", zone.inflationRatePerDay * 100), systemImage: "arrow.up.right")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.red.opacity(0.85))
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(zone.color.opacity(0.35), lineWidth: 1))
        .onTapGesture { onTap() }
        .onAppear { setupPlayer() }
        .onDisappear { player?.pause() }
    }

    private func setupPlayer() {
        let num = zone.index + 1
        let name = "zon\(num)"
        let url = Bundle.main.url(forResource: name, withExtension: "mp4")
               ?? Bundle.main.url(forResource: name, withExtension: "mov")
        guard let url else { return }
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: p.currentItem, queue: .main
        ) { _ in p.seek(to: .zero); p.play() }
        p.play()
        player = p
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
    @ObservedObject private var engine = TimeEngine.shared

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
            ZoneOperationsView()
                .tabItem { Label("Zoncentral", systemImage: "building.2.crop.circle.fill") }
                .tag(3)
            SocialView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }
                .tag(4)
        }
        .tint(LTPalette.neonGreen)
        .preferredColorScheme(.dark)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .overlay {
            if engine.cryoSleepActive {
                CryoSleepOverlay()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: engine.cryoSleepActive)
        .modifier(ZoneUpgradeFlash())
        // Dödsläge — visas som fullskärmstäckning när spelaren är borta
        .fullScreenCover(isPresented: Binding(
            get: { engine.isDead },
            set: { _ in }
        )) {
            DeathView()
        }
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
