import SwiftUI
import Foundation

// MARK: - PvP Rånet
// Utmana en spelare i din zon på ett reaktionstest.
// Vinner du → stjäl en del av deras tid. Förlorar du → de tar din insats.
// Backfire → du förlorar insatsen PLUS 10% av din nuvarande balans.
// Cooldown 4 timmar per offer.

// MARK: - Raid-scenarions

enum RaidOutcome {
    case success    // anfallaren stjäl tid från försvararen
    case failure    // anfallaren förlorar sin insats
    case backfire   // anfallaren rånas — förlorar MER än insatsen
}

struct RaidScenario: Identifiable, Equatable {
    let id = UUID()
    let outcome: RaidOutcome
    let title: String
    let story: String
}

// 5 framgångsscenarier
private let successScenarios: [RaidScenario] = [
    .init(outcome: .success, title: "Snabbt och obarmhärtigt",
          story: "Du smög upp bakifrån. Innan de hann reagera var det klart. Deras tid är nu din."),
    .init(outcome: .success, title: "Perfekt timing",
          story: "Du väntade tills de var distraherade. Tre sekunder. Mer behövde du inte."),
    .init(outcome: .success, title: "Välplanerat anfall",
          story: "Du hade studerat deras mönster i dagar. I natt betalade det sig."),
    .init(outcome: .success, title: "Övermäktig styrka",
          story: "De försökte springa. Det hjälpte inte. Du är snabbare."),
    .init(outcome: .success, title: "I mörkret",
          story: "Nattmarknaden var tom. Bara du och dem. Och nu bara du.")
]

// 5 misslyckandescenarier
private let failureScenarios: [RaidScenario] = [
    .init(outcome: .failure, title: "De såg dig komma",
          story: "Din approach var för uppenbar. De var förberedda och du sprang därifrån tomhänt."),
    .init(outcome: .failure, title: "Vittnen i skuggorna",
          story: "Någon annan bevittnade rånet och larmar. Du tvingas avbryta och fly."),
    .init(outcome: .failure, title: "Fel mål",
          story: "Du valde fel person. De visade sig vara beväpnade. Du drog dig tillbaka snabbt."),
    .init(outcome: .failure, title: "Teknisk fördel",
          story: "De hade ett system som varnade dem i förväg. Du kom tomhänt."),
    .init(outcome: .failure, title: "Panikade i sista sekunden",
          story: "Allt var planerat. Men när det väl kom till kritan, svek dig nerverna.")
]

// 5 backfire-scenarier
private let backfireScenarios: [RaidScenario] = [
    .init(outcome: .backfire, title: "Fällan",
          story: "Det var en fälla från början. De väntade på dig. Nu ligger du nere och de tar din tid."),
    .init(outcome: .backfire, title: "Motattack",
          story: "Du attackerade. De slog tillbaka hårdare. Du vaknar utan vad du kom med, och lite till."),
    .init(outcome: .backfire, title: "Övermannad",
          story: "De var inte ensamma. Tre mot en. Du hade ingen chans. Ditt insats är deras nu."),
    .init(outcome: .backfire, title: "Spelade svagt",
          story: "De låtsades vara svaga. Det var de inte. Nu betalar du priset för din arrogans."),
    .init(outcome: .backfire, title: "Drog fel kort",
          story: "Slumpen var inte på din sida. De var snabbare, starkare och mer hänsynslösa.")
]

// MARK: - Modeller

enum RaidStatus: String, Codable {
    case pending   = "pending"
    case active    = "active"
    case won       = "won"
    case lost      = "lost"
    case backfired = "backfired"
    case declined  = "declined"
}

struct RaidRecord: Identifiable, Codable {
    let id: String
    let attackerName: String
    let defenderId: String?
    let defenderName: String
    let stake: TimeInterval
    var status: RaidStatus
    let timestamp: Date

    var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "Europe/Stockholm")
        return fmt.string(from: timestamp)
    }
}

// MARK: - PvP Manager

class PvPRaidManager: ObservableObject {
    static let shared = PvPRaidManager()

    @Published var activeRaid: RaidRecord? = nil
    @Published var history: [RaidRecord] = []
    @Published var cooldowns: [String: Date] = [:]

    @Published var raidPhase: RaidPhase = .idle
    @Published var reactionTarget: Bool = false
    @Published var playerReactionMs: Int? = nil
    @Published var opponentReactionMs: Int? = nil
    @Published var resolvedScenario: RaidScenario? = nil
    @Published var resolvedTimeDelta: TimeInterval = 0

    private var targetAppearTime: Date? = nil
    private var raidTimer: Timer? = nil

    private let cooldownDuration: TimeInterval = 4 * 3600
    private let storageKey = "pvpHistory"

    enum RaidPhase {
        case idle, waiting, target, done
    }

    private init() {
        loadHistory()
        loadCooldowns()
    }

    private func cooldownKey(id: String) -> String {
        "id:\(id)"
    }

    private func cooldownKey(username: String) -> String {
        "name:\(normalizeZoneID(username))"
    }

    private func cooldownDate(for target: ServerUser) -> Date? {
        if let byID = cooldowns[cooldownKey(id: target.id)] { return byID }
        if let byName = cooldowns[cooldownKey(username: target.username)] { return byName }
        return cooldowns[target.username] // legacy storage key
    }

    func isOnCooldown(_ target: ServerUser) -> Bool {
        guard let lastRaid = cooldownDate(for: target) else { return false }
        return Date() < lastRaid.addingTimeInterval(cooldownDuration)
    }

    func cooldownRemaining(for target: ServerUser) -> TimeInterval {
        guard let lastRaid = cooldownDate(for: target) else { return 0 }
        return max(0, lastRaid.addingTimeInterval(cooldownDuration).timeIntervalSinceNow)
    }

    private func maxStake(for zone: ZoneProfile) -> TimeInterval {
        switch zone.index {
        case 0:     return 1800          // Askan: 30 min
        case 1...3: return 3600          // Spillrorna–Dimman: 1h
        case 4...6: return 7200          // Halvmörkret–Stigarnas Dal: 2h
        default:    return 21600         // senare zoner: max 6h för rån
        }
    }

    func initiateRaid(target: ServerUser, stake: TimeInterval, completion: @escaping (Bool, String) -> Void) {
        let playerName = GameState.shared.username
        guard !playerName.isEmpty else { completion(false, "Inget spelarnamn."); return }
        guard stake > 0 else { completion(false, "Ogiltig insats."); return }
        guard TimeEngine.shared.balance >= stake else { completion(false, "Otillräcklig balans."); return }
        let zoneMaxStake = maxStake(for: GameState.shared.currentZone)
        guard stake <= zoneMaxStake else {
            completion(false, "Insatsen är för hög i din nuvarande zon. Max: \(TimeEngine.shortFormatted(zoneMaxStake)).")
            return
        }

        if isOnCooldown(target) {
            let remaining = cooldownRemaining(for: target)
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            completion(false, "\(target.username) kan inte raidadas igen än. Cooldown: \(h)h \(m)m kvar.")
            return
        }

        guard TimeEngine.shared.deductTime(stake) else {
            completion(false, "Kunde inte låsa insatsen. Försök igen.")
            return
        }

        let record = RaidRecord(
            id: UUID().uuidString,
            attackerName: playerName,
            defenderId: target.id,
            defenderName: target.username,
            stake: stake,
            status: .active,
            timestamp: Date()
        )
        activeRaid = record
        resolvedScenario = nil
        resolvedTimeDelta = 0

        raidPhase = .waiting
        startReactionTest()
        completion(true, "Rånet påbörjat!")
    }

    private func startReactionTest() {
        let delay = Double.random(in: 1.0...4.0)
        raidTimer?.invalidate()
        raidTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.raidPhase = .target
                self?.reactionTarget = true
                self?.targetAppearTime = Date()

                self?.raidTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    DispatchQueue.main.async {
                        if self?.playerReactionMs == nil {
                            self?.playerTapped(success: false)
                        }
                    }
                }
            }
        }
    }

    func playerTapped(success: Bool) {
        guard raidPhase == .target, let appearTime = targetAppearTime else { return }
        raidTimer?.invalidate()

        let ms = Int(Date().timeIntervalSince(appearTime) * 1000)
        playerReactionMs = ms
        reactionTarget = false

        let opponentMs = Int.random(in: 180...600)
        opponentReactionMs = opponentMs

        // Utfall baserat på differens i reaktionstid
        let outcome: RaidOutcome
        if !success {
            // Timeout/feltryck ska inte ge backfire direkt.
            outcome = .failure
        } else {
            let diff = opponentMs - ms  // positivt = spelaren är snabbare
            if diff > 100 {
                outcome = .success
            } else if diff < -200 {
                outcome = .backfire
            } else {
                outcome = .failure
            }
        }

        resolveRaid(outcome: outcome)
    }

    private func resolveRaid(outcome: RaidOutcome) {
        guard var record = activeRaid else { return }
        raidPhase = .done

        // Välj slumpmässigt scenario baserat på utfall
        let scenario: RaidScenario
        switch outcome {
        case .success:
            scenario = successScenarios.randomElement()!
            let grossPayout = record.stake * 2
            let houseFee = grossPayout * 0.05
            let netPayout = grossPayout - houseFee
            TimeEngine.shared.addTime(netPayout)
            BoardManager.shared.collectTax(amount: houseFee)
            record.status = .won
            resolvedTimeDelta = netPayout - record.stake
            TransactionLedger.shared.record(label: "Rån — vinst", amount: resolvedTimeDelta)
            MissionsManager.incrementProgress("pvp_raids_won")
        case .failure:
            scenario = failureScenarios.randomElement()!
            record.status = .lost
            resolvedTimeDelta = -record.stake
            TransactionLedger.shared.record(label: "Rån — förlust", amount: resolvedTimeDelta)
        case .backfire:
            scenario = backfireScenarios.randomElement()!
            // Förlorar insatsen PLUS 10% av balansen (upp till stakebeloppet)
            let extraPenalty = min(TimeEngine.shared.balance * 0.10, record.stake)
            if extraPenalty > 0 {
                _ = TimeEngine.shared.deductTime(extraPenalty)
            }
            record.status = .backfired
            resolvedTimeDelta = -(record.stake + extraPenalty)
            TransactionLedger.shared.record(label: "Rån — backfire", amount: resolvedTimeDelta)
        }

        resolvedScenario = scenario
        MissionsManager.incrementProgress("pvp_raids_done")

        let now = Date()
        if let defenderId = record.defenderId, !defenderId.isEmpty {
            cooldowns[cooldownKey(id: defenderId)] = now
        }
        cooldowns[cooldownKey(username: record.defenderName)] = now
        cooldowns[record.defenderName] = now // legacy compatibility
        saveCooldowns()

        history.insert(record, at: 0)
        let won = outcome == .success
        NotificationManager.shared.sendRaidNotification(
            target: record.defenderName,
            amount: TimeEngine.shortFormatted(abs(resolvedTimeDelta)),
            won: won,
            backfired: outcome == .backfire
        )
        activeRaid = nil
        saveHistory()
    }

    func resetRaid() {
        raidPhase = .idle
        reactionTarget = false
        playerReactionMs = nil
        opponentReactionMs = nil
        activeRaid = nil
        resolvedScenario = nil
        resolvedTimeDelta = 0
        raidTimer?.invalidate()
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([RaidRecord].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(Array(history.prefix(50))) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadCooldowns() {
        if let data = UserDefaults.standard.data(forKey: "pvpCooldowns"),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            cooldowns = decoded
        }
    }

    private func saveCooldowns() {
        if let data = try? JSONEncoder().encode(cooldowns) {
            UserDefaults.standard.set(data, forKey: "pvpCooldowns")
        }
    }
}

// MARK: - PvP Raid View

struct PvPRaidView: View {
    @ObservedObject private var manager   = PvPRaidManager.shared
    @ObservedObject private var server    = ServerSync.shared
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedTarget: ServerUser? = nil
    @State private var stakeMinutes: Double = 30
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var phase: ViewPhase = .selection
    @State private var targetScale: CGFloat = 0.6
    @State private var resultAppeared: Bool = false
    @State private var targetPulse: Bool = false
    @State private var raidScenario: RaidScenario? = nil

    private let hapticImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let hapticNotif  = UINotificationFeedbackGenerator()
    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)

    enum ViewPhase { case selection, reaction, result }

    private func raidStakeLimit(for zone: ZoneProfile) -> TimeInterval {
        switch zone.index {
        case 0:     return 1800
        case 1...3: return 3600
        case 4...6: return 7200
        default:    return 21600
        }
    }

    private var maxStakeMinutes: Double {
        max(15, raidStakeLimit(for: gameState.currentZone) / 60)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Mörk röd-svart bakgrund
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.01, blue: 0.01),
                        Color(red: 0.04, green: 0.01, blue: 0.01),
                        Color.black
                    ],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()

                switch phase {
                case .selection: selectionView
                case .reaction:  reactionView
                case .result:    resultView
                }
            }
            .navigationTitle("RÅNET")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.09, green: 0.01, blue: 0.01), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                        .font(LTFont.body(13))
                        .accessibilityLabel("Stäng rånet")
                }
            }
        }
        .alert("Fel", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage) }
        .preferredColorScheme(.dark)
        // Visa resultatscenario som ett sheet när det sätts
        .sheet(item: $raidScenario) { scenario in
            scenarioResultSheet(scenario)
        }
        .onChange(of: manager.resolvedScenario) { _, newScenario in
            if let s = newScenario {
                raidScenario = s
            }
        }
    }

    // MARK: - Val av mål

    private var selectionView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: LTSpacing.xl) {
                warningBanner

                VStack(alignment: .leading, spacing: LTSpacing.sm) {
                    sectionHeader("VÄLJ OFFER")
                    if server.zoneMembers.isEmpty {
                        emptyState("Inga spelare i din zon.")
                    } else {
                        ForEach(server.zoneMembers.filter { $0.username != gameState.username }) { member in
                            targetRow(member)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: LTSpacing.sm) {
                    sectionHeader("INSATS: \(TimeEngine.shortFormatted(stakeMinutes * 60))")
                    Slider(value: $stakeMinutes, in: 15...maxStakeMinutes, step: 15)
                        .tint(LTPalette.danger)
                        .accessibilityLabel("Insats i minuter")
                        .accessibilityValue(TimeEngine.shortFormatted(stakeMinutes * 60))
                    HStack {
                        Text("15 min").font(LTFont.body(9)).foregroundColor(.gray)
                        Spacer()
                        Text("Max \(TimeEngine.shortFormatted(maxStakeMinutes * 60))")
                            .font(LTFont.body(9))
                            .foregroundColor(.gray)
                    }
                }

                historySection

                Button {
                    guard let target = selectedTarget else { return }
                    hapticImpact.impactOccurred()
                    manager.initiateRaid(target: target, stake: stakeMinutes * 60) { success, msg in
                        if success {
                            withAnimation(LTAnimation.springFast) { phase = .reaction }
                        } else {
                            errorMessage = msg
                            showError = true
                            hapticNotif.notificationOccurred(.error)
                        }
                    }
                } label: {
                    HStack(spacing: LTSpacing.sm) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14))
                        Text("STARTA RÅNET")
                            .font(LTFont.heading(14))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LTSpacing.lg)
                    .background(
                        selectedTarget != nil
                            ? LTPalette.danger
                            : Color(red: 0.3, green: 0.3, blue: 0.35)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                    .shadow(color: selectedTarget != nil ? LTPalette.danger.opacity(0.4) : .clear, radius: 12)
                }
                .disabled(selectedTarget == nil)
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Starta rånet")
                .accessibilityHint(selectedTarget == nil ? "Välj ett offer först" : "Startar reaktionstestet mot \(selectedTarget?.username ?? "")")

                Spacer(minLength: LTSpacing.xxxl + LTSpacing.lg)
            }
            .padding(LTSpacing.lg)
        }
    }

    // MARK: - Reaktionstest

    private var reactionView: some View {
        VStack(spacing: 0) {
            Spacer()

            if manager.raidPhase == .waiting {
                VStack(spacing: LTSpacing.xl) {
                    // Nedräkningspuls-ikon
                    ZStack {
                        Circle()
                            .stroke(LTPalette.danger.opacity(0.2), lineWidth: 2)
                            .frame(width: 120, height: 120)
                        Circle()
                            .stroke(LTPalette.danger.opacity(targetPulse ? 0.6 : 0.1), lineWidth: 1)
                            .frame(width: 160, height: 160)
                            .animation(LTAnimation.ambientPulse, value: targetPulse)
                        Image(systemName: "eye.fill")
                            .font(.system(size: 32))
                            .foregroundColor(LTPalette.danger.opacity(0.7))
                    }
                    .onAppear { targetPulse = true }

                    Text("VÄNTA...")
                        .font(LTFont.value(32))
                        .foregroundColor(LTPalette.gold)
                        .accessibilityLabel("Vänta på målet")

                    Text("Tryck NÄR du ser målet.")
                        .font(LTFont.body(14))
                        .foregroundColor(.white.opacity(0.45))

                    if let targetName = manager.history.first?.defenderName ?? selectedTarget?.username {
                        Text("Offer: \(targetName.uppercased())")
                            .font(LTFont.label(11))
                            .foregroundColor(LTPalette.danger.opacity(0.7))
                            .tracking(2)
                    }
                }
                .transition(.opacity)
            } else if manager.raidPhase == .target {
                VStack(spacing: LTSpacing.xl) {
                    ZStack {
                        // Yttre glödring
                        Circle()
                            .fill(LTPalette.danger.opacity(0.15))
                            .frame(width: 200, height: 200)
                            .blur(radius: 30)

                        // Mittcirkel
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [LTPalette.danger, Color(red: 0.8, green: 0.0, blue: 0.0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 160, height: 160)
                            .shadow(color: LTPalette.danger.opacity(0.8), radius: 30)
                            .neonGlow(LTPalette.danger, intensity: 1.5)

                        // Träffmarkör
                        Image(systemName: "target")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .scaleEffect(targetScale)
                    .onAppear {
                        hapticImpact.impactOccurred()
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.50)) {
                            targetScale = 1.0
                        }
                    }
                    .onTapGesture {
                        hapticNotif.notificationOccurred(.success)
                        manager.playerTapped(success: true)
                        withAnimation(LTAnimation.springFast) { phase = .result }
                    }
                    .accessibilityLabel("Tryck nu!")
                    .accessibilityAddTraits(.isButton)

                    Text("TAP NOW!")
                        .font(LTFont.value(22))
                        .foregroundColor(LTPalette.danger)
                        .neonGlow(LTPalette.danger, intensity: 0.7)
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            if manager.raidPhase == .target {
                hapticNotif.notificationOccurred(.success)
                manager.playerTapped(success: true)
                withAnimation(LTAnimation.springFast) { phase = .result }
            }
        }
        .onChange(of: manager.raidPhase) { _, newPhase in
            if newPhase == .done {
                withAnimation(LTAnimation.springSmooth) { phase = .result }
            }
        }
    }

    // MARK: - Resultat

    private var resultView: some View {
        let lastRecord = manager.history.first
        let status = lastRecord?.status ?? .lost
        let won = status == .won
        let backfired = status == .backfired
        let playerMs = manager.playerReactionMs ?? 0
        let oppMs    = manager.opponentReactionMs ?? 0
        let timeDelta = manager.resolvedTimeDelta

        return VStack(spacing: LTSpacing.xxl) {
            Spacer()

            // Statusikon med dramatisk animation
            ZStack {
                Circle()
                    .fill(resultIconColor(won: won, backfired: backfired).opacity(0.15))
                    .frame(width: 110, height: 110)
                    .blur(radius: 25)
                Image(systemName: resultIconName(won: won, backfired: backfired))
                    .font(.system(size: 52))
                    .foregroundColor(resultIconColor(won: won, backfired: backfired))
                    .neonGlow(resultIconColor(won: won, backfired: backfired), intensity: 1.0)
            }
            .scaleEffect(resultAppeared ? 1.0 : 0.3)
            .opacity(resultAppeared ? 1.0 : 0.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.55), value: resultAppeared)
            .onAppear {
                hapticNotif.notificationOccurred(won ? .success : .error)
                withAnimation { resultAppeared = true }
            }

            // Rubrik
            Text(resultHeadline(won: won, backfired: backfired))
                .font(LTFont.value(22))
                .foregroundColor(resultIconColor(won: won, backfired: backfired))
                .multilineTextAlignment(.center)
                .accessibilityLabel(resultHeadline(won: won, backfired: backfired))

            // Reaktionsjämförelse
            VStack(spacing: LTSpacing.sm) {
                reactionRow(label: "Du", ms: playerMs, best: playerMs < oppMs)
                reactionRow(label: "Motståndare", ms: oppMs, best: oppMs <= playerMs)
            }
            .padding(LTSpacing.lg)
            .ltCard(radius: LTRadius.sm)

            // Tidskonsekvens
            HStack(spacing: LTSpacing.xs) {
                Image(systemName: timeDelta >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundColor(timeDelta >= 0 ? LTPalette.neonGreen : LTPalette.danger)
                Text(timeDeltaLabel(delta: timeDelta))
                    .font(LTFont.heading(14))
                    .foregroundColor(timeDelta >= 0 ? LTPalette.neonGreen : LTPalette.danger)
            }

            // Scenario-knapp (öppnar sheet med narrativ)
            if manager.resolvedScenario != nil {
                Button {
                    raidScenario = manager.resolvedScenario
                } label: {
                    HStack(spacing: LTSpacing.xs) {
                        Image(systemName: "text.book.closed.fill")
                            .font(.system(size: 13))
                        Text("VIS RAPPORT")
                            .font(LTFont.heading(12))
                    }
                    .foregroundColor(LTPalette.gold)
                    .padding(.horizontal, LTSpacing.lg)
                    .padding(.vertical, LTSpacing.sm)
                    .background(LTPalette.gold.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                    .overlay(RoundedRectangle(cornerRadius: LTRadius.xs).stroke(LTPalette.gold.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(LTPressEffect())
            }

            Button {
                hapticLight.impactOccurred()
                manager.resetRaid()
                resultAppeared = false
                withAnimation(LTAnimation.springSmooth) { phase = .selection }
            } label: {
                Text("TILLBAKA")
                    .font(LTFont.heading(14))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LTSpacing.md)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            }
            .buttonStyle(LTPressEffect())
            .accessibilityLabel("Tillbaka till spelarval")

            Spacer()
        }
        .padding(LTSpacing.xxl)
    }

    // MARK: - Scenario-resultatsheet

    @ViewBuilder
    private func scenarioResultSheet(_ scenario: RaidScenario) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.01, blue: 0.01),
                    Color.black
                ],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: LTSpacing.xxl) {
                Spacer()

                // Outcome-badge
                Text(outcomeBadgeText(scenario.outcome))
                    .font(LTFont.label(10))
                    .foregroundColor(outcomeColor(scenario.outcome))
                    .tracking(3)
                    .padding(.horizontal, LTSpacing.lg)
                    .padding(.vertical, LTSpacing.xs)
                    .background(outcomeColor(scenario.outcome).opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(outcomeColor(scenario.outcome).opacity(0.4), lineWidth: 1))

                // Rubrik
                Text(scenario.title.uppercased())
                    .font(LTFont.value(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, LTSpacing.lg)

                // Narrativ text
                Text(scenario.story)
                    .font(LTFont.body(15))
                    .foregroundColor(Color(red: 0.75, green: 0.72, blue: 0.70))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, LTSpacing.xxl)

                Divider()
                    .background(outcomeColor(scenario.outcome).opacity(0.3))
                    .padding(.horizontal, LTSpacing.xxxl)

                // Tidsresultat
                let delta = manager.resolvedTimeDelta
                VStack(spacing: LTSpacing.xs) {
                    Text(delta >= 0 ? "VINST" : "FÖRLUST")
                        .font(LTFont.label(10))
                        .foregroundColor(delta >= 0 ? LTPalette.neonGreen : LTPalette.danger)
                        .tracking(3)
                    Text(timeDeltaLabel(delta: delta))
                        .font(LTFont.value(32))
                        .foregroundColor(delta >= 0 ? LTPalette.neonGreen : LTPalette.danger)
                        .contentTransition(.numericText())
                }

                Spacer()

                // Stäng-knapp
                Button {
                    raidScenario = nil
                } label: {
                    Text("STÄNG")
                        .font(LTFont.heading(14))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LTSpacing.md)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                }
                .buttonStyle(LTPressEffect())
                .padding(.horizontal, LTSpacing.xl)
                .padding(.bottom, LTSpacing.xxxl)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hjälpfunktioner

    private func resultIconName(won: Bool, backfired: Bool) -> String {
        if won { return "checkmark.seal.fill" }
        if backfired { return "exclamationmark.triangle.fill" }
        return "xmark.seal.fill"
    }

    private func resultIconColor(won: Bool, backfired: Bool) -> Color {
        if won { return LTPalette.neonGreen }
        if backfired { return LTPalette.warning }
        return LTPalette.danger
    }

    private func resultHeadline(won: Bool, backfired: Bool) -> String {
        if won { return "RÅNET LYCKADES" }
        if backfired { return "DU RÅNADES TILLBAKA" }
        return "RÅNET MISSLYCKADES"
    }

    private func outcomeBadgeText(_ outcome: RaidOutcome) -> String {
        switch outcome {
        case .success:  return "FRAMGÅNG"
        case .failure:  return "MISSLYCKADE"
        case .backfire: return "BACKFIRE"
        }
    }

    private func outcomeColor(_ outcome: RaidOutcome) -> Color {
        switch outcome {
        case .success:  return LTPalette.neonGreen
        case .failure:  return LTPalette.danger
        case .backfire: return LTPalette.warning
        }
    }

    private func timeDeltaLabel(delta: TimeInterval) -> String {
        let abs = Swift.abs(delta)
        let prefix = delta >= 0 ? "+" : "-"
        return "\(prefix)\(TimeEngine.shortFormatted(abs))"
    }

    private func reactionRow(label: String, ms: Int, best: Bool) -> some View {
        HStack {
            Text(label)
                .font(LTFont.heading(12))
                .foregroundColor(.white)
            Spacer()
            Text("\(ms) ms")
                .font(LTFont.value(14))
                .foregroundColor(best ? LTPalette.neonGreen : LTPalette.danger)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Sub-vyer

    private var warningBanner: some View {
        HStack(spacing: LTSpacing.sm) {
            Image(systemName: "bolt.fill")
                .foregroundColor(LTPalette.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Din tid eller ditt liv.")
                    .font(LTFont.heading(12))
                    .foregroundColor(.white)
                Text("Reagera snabbare än motståndaren. Vinner du → stjäl deras tid. Förlorar du → de tar din insats. Backfire → du förlorar mer.")
                    .font(LTFont.body(10))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
                    .lineSpacing(2)
            }
        }
        .padding(LTSpacing.md)
        .ltAccentCard(color: LTPalette.danger, radius: LTRadius.sm)
    }

    private func targetRow(_ member: ServerUser) -> some View {
        let selected = selectedTarget?.id == member.id
        let onCooldown = manager.isOnCooldown(member)

        return Button {
            if !onCooldown {
                hapticLight.impactOccurred()
                withAnimation(LTAnimation.springFast) { selectedTarget = member }
            }
        } label: {
            HStack(spacing: LTSpacing.md) {
                // Spelarikon
                ZStack {
                    Circle()
                        .fill(onCooldown
                              ? Color(red: 0.15, green: 0.15, blue: 0.2)
                              : (selected ? LTPalette.danger.opacity(0.25) : Color(red: 0.12, green: 0.04, blue: 0.06)))
                        .frame(width: 36, height: 36)
                    Image(systemName: onCooldown ? "shield.fill" : "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(onCooldown
                                         ? Color(red: 0.4, green: 0.4, blue: 0.5)
                                         : (selected ? LTPalette.danger : .white.opacity(0.7)))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(member.username)
                        .font(LTFont.heading(13))
                        .foregroundColor(onCooldown ? Color(red: 0.4, green: 0.4, blue: 0.45) : .white)
                    if onCooldown {
                        Text("Immunitet aktiv")
                            .font(LTFont.body(9))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                    } else {
                        Text("Tillgänglig")
                            .font(LTFont.body(9))
                            .foregroundColor(LTPalette.neonGreenDim.opacity(0.6))
                    }
                }

                Spacer()

                if selected && !onCooldown {
                    Image(systemName: "target")
                        .foregroundColor(LTPalette.danger)
                        .font(.system(size: 18))
                        .neonGlow(LTPalette.danger, intensity: 0.6)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(LTSpacing.md)
            .background(
                selected
                    ? Color(red: 0.14, green: 0.03, blue: 0.03)
                    : Color(red: 0.06, green: 0.06, blue: 0.09)
            )
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: LTRadius.sm)
                    .stroke(
                        selected ? LTPalette.danger.opacity(0.7) : Color(red: 0.18, green: 0.18, blue: 0.26),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .shadow(color: selected ? LTPalette.danger.opacity(0.25) : .clear, radius: 8)
            .animation(LTAnimation.springFast, value: selected)
        }
        .disabled(onCooldown)
        .buttonStyle(LTPressEffect())
        .accessibilityLabel(member.username)
        .accessibilityHint(onCooldown ? "Immunitet aktiv — kan inte raidadas just nu" : (selected ? "Vald som offer" : "Tryck för att välja som offer"))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            sectionHeader("HISTORIK")
            if manager.history.isEmpty {
                Text("Inga råd ännu.")
                    .font(LTFont.body(11))
                    .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.4))
            } else {
                ForEach(manager.history.prefix(5)) { r in
                    HStack {
                        Text(r.attackerName == gameState.username ? "vs \(r.defenderName)" : "\(r.attackerName) vs dig")
                            .font(LTFont.heading(11))
                            .foregroundColor(.white)
                        Spacer()
                        Text(historyStatusLabel(r.status))
                            .font(LTFont.label(10))
                            .foregroundColor(historyStatusColor(r.status))
                    }
                    .padding(LTSpacing.sm + 2)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(r.attackerName == gameState.username ? "Mot \(r.defenderName)" : "\(r.attackerName) mot dig"): \(historyStatusLabel(r.status))"
                    )
                }
            }
        }
    }

    private func historyStatusLabel(_ status: RaidStatus) -> String {
        switch status {
        case .won:       return "VANN"
        case .lost:      return "FÖRLORADE"
        case .backfired: return "BACKFIRE"
        default:         return status.rawValue.uppercased()
        }
    }

    private func historyStatusColor(_ status: RaidStatus) -> Color {
        switch status {
        case .won:       return LTPalette.neonGreen
        case .backfired: return LTPalette.warning
        default:         return LTPalette.danger
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(LTFont.label(9))
            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
            .tracking(2)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(LTFont.body(11))
            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
    }
}
