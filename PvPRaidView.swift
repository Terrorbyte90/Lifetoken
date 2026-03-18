import SwiftUI
import Foundation

// MARK: - PvP Rånet
// Utmana en spelare i din zon på ett reaktionstest.
// Vinner du → stjäl en del av deras tid. Förlorar du → de tar din insats.
// Cooldown 4 timmar per offer.

// MARK: - Modeller

enum RaidStatus: String, Codable {
    case pending   = "pending"
    case active    = "active"
    case won       = "won"
    case lost      = "lost"
    case declined  = "declined"
}

struct RaidRecord: Identifiable, Codable {
    let id: String
    let attackerName: String
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

    func initiateRaid(target: ServerUser, stake: TimeInterval, completion: @escaping (Bool, String) -> Void) {
        let playerName = GameState.shared.username
        guard !playerName.isEmpty else { completion(false, "Inget spelarnamn."); return }
        guard TimeEngine.shared.balance >= stake else { completion(false, "Otillräcklig balans."); return }

        if let lastRaid = cooldowns[target.username], Date() < lastRaid.addingTimeInterval(cooldownDuration) {
            let remaining = lastRaid.addingTimeInterval(cooldownDuration).timeIntervalSinceNow
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            completion(false, "\(target.username) kan inte raidadas igen än. Cooldown: \(h)h \(m)m kvar.")
            return
        }

        TimeEngine.shared.deductTime(stake)

        let record = RaidRecord(
            id: UUID().uuidString,
            attackerName: playerName,
            defenderName: target.username,
            stake: stake,
            status: .active,
            timestamp: Date()
        )
        activeRaid = record

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

        let iWon = success && ms < opponentMs
        resolveRaid(playerWon: iWon)
    }

    private func resolveRaid(playerWon: Bool) {
        guard var record = activeRaid else { return }
        raidPhase = .done

        if playerWon {
            let stolen = record.stake
            TimeEngine.shared.addTime(record.stake + stolen)
            record.status = .won
            MissionsManager.incrementProgress("pvp_raids_won")
        } else {
            record.status = .lost
        }

        MissionsManager.incrementProgress("pvp_raids_done")

        cooldowns[record.defenderName] = Date()
        saveCooldowns()

        history.insert(record, at: 0)
        NotificationManager.shared.sendRaidNotification(from: record.attackerName, amount: TimeEngine.shortFormatted(record.stake), won: playerWon)
        activeRaid = nil
        saveHistory()
    }

    func resetRaid() {
        raidPhase = .idle
        reactionTarget = false
        playerReactionMs = nil
        opponentReactionMs = nil
        activeRaid = nil
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

    private let hapticImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let hapticNotif  = UINotificationFeedbackGenerator()
    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)

    enum ViewPhase { case selection, reaction, result }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.02, blue: 0.02),
                        Color(red: 0.03, green: 0.01, blue: 0.01),
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
                    Slider(value: $stakeMinutes, in: 15...120, step: 15)
                        .tint(LTPalette.danger)
                        .accessibilityLabel("Insats i minuter")
                        .accessibilityValue(TimeEngine.shortFormatted(stakeMinutes * 60))
                    HStack {
                        Text("15 min").font(LTFont.body(9)).foregroundColor(.gray)
                        Spacer()
                        Text("2h").font(LTFont.body(9)).foregroundColor(.gray)
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
                    Text("STARTA RÅNET")
                        .font(LTFont.heading(14))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LTSpacing.lg)
                        .background(
                            selectedTarget != nil
                                ? LTPalette.danger
                                : Color(red: 0.3, green: 0.3, blue: 0.35)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
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
                VStack(spacing: LTSpacing.lg) {
                    Text("VÄNTA...")
                        .font(LTFont.value(32))
                        .foregroundColor(LTPalette.gold)
                        .accessibilityLabel("Vänta på målet")
                    Text("Tryck NÄR du ser målet.")
                        .font(LTFont.body(14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .transition(.opacity)
            } else if manager.raidPhase == .target {
                VStack(spacing: LTSpacing.xl) {
                    Circle()
                        .fill(LTPalette.danger)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Text("TRYCK!")
                                .font(LTFont.heading(22))
                                .foregroundColor(.white)
                        )
                        .shadow(color: LTPalette.danger.opacity(0.7), radius: 24)
                        .neonGlow(LTPalette.danger, intensity: 1.2)
                        .scaleEffect(targetScale)
                        .onAppear {
                            hapticImpact.impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
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
                        .font(LTFont.label(14))
                        .foregroundColor(LTPalette.danger)
                        .neonGlow(LTPalette.danger, intensity: 0.5)
                }
                .transition(.scale(scale: 0.5).combined(with: .opacity))
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
        let won = manager.history.first?.status == .won
        let playerMs = manager.playerReactionMs ?? 0
        let oppMs    = manager.opponentReactionMs ?? 0

        return VStack(spacing: LTSpacing.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill((won ? LTPalette.neonGreen : LTPalette.danger).opacity(0.12))
                    .frame(width: 90, height: 90)
                    .blur(radius: 20)
                Image(systemName: won ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundColor(won ? LTPalette.neonGreen : LTPalette.danger)
                    .neonGlow(won ? LTPalette.neonGreen : LTPalette.danger, intensity: 0.8)
            }
            .scaleEffect(resultAppeared ? 1.0 : 0.4)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: resultAppeared)
            .onAppear {
                hapticNotif.notificationOccurred(won ? .success : .error)
                withAnimation { resultAppeared = true }
            }

            Text(won ? "RÅNET LYCKADES" : "RÅNET MISSLYCKADES")
                .font(LTFont.value(24))
                .foregroundColor(won ? LTPalette.neonGreen : LTPalette.danger)
                .multilineTextAlignment(.center)
                .accessibilityLabel(won ? "Rånet lyckades" : "Rånet misslyckades")

            VStack(spacing: LTSpacing.sm) {
                reactionRow(label: "Du", ms: playerMs, best: playerMs < oppMs)
                reactionRow(label: "Motståndare", ms: oppMs, best: oppMs <= playerMs)
            }
            .padding(LTSpacing.lg)
            .ltCard(radius: LTRadius.sm)

            if won {
                Text("Du stal \(TimeEngine.shortFormatted(manager.history.first?.stake ?? 0)) från offret.")
                    .font(LTFont.body(13))
                    .foregroundColor(LTPalette.neonGreenDim)
            } else {
                Text("Din insats förlorades.")
                    .font(LTFont.body(13))
                    .foregroundColor(LTPalette.danger.opacity(0.8))
            }

            Button {
                hapticLight.impactOccurred()
                manager.resetRaid()
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

    // MARK: - Sub-views

    private var warningBanner: some View {
        HStack(spacing: LTSpacing.sm) {
            Image(systemName: "bolt.fill")
                .foregroundColor(LTPalette.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Din tid eller ditt liv.")
                    .font(LTFont.heading(12))
                    .foregroundColor(.white)
                Text("Reagera snabbare än motståndaren. Vinner du → stjäl deras insats. Förlorar du → de tar din.")
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
        let onCooldown: Bool = {
            if let cd = manager.cooldowns[member.username] {
                return Date() < cd.addingTimeInterval(4 * 3600)
            }
            return false
        }()

        return Button {
            if !onCooldown {
                hapticLight.impactOccurred()
                withAnimation(LTAnimation.springFast) { selectedTarget = member }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.username)
                        .font(LTFont.heading(13))
                        .foregroundColor(onCooldown ? Color(red: 0.4, green: 0.4, blue: 0.45) : .white)
                    if onCooldown {
                        Text("Immunitet aktiv")
                            .font(LTFont.body(9))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "target")
                        .foregroundColor(LTPalette.danger)
                        .neonGlow(LTPalette.danger, intensity: 0.5)
                        .transition(.scale.combined(with: .opacity))
                }
                if onCooldown {
                    Image(systemName: "shield.fill")
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                        .font(.system(size: 14))
                }
            }
            .padding(LTSpacing.md)
            .background(selected ? Color(red: 0.12, green: 0.04, blue: 0.04) : Color(red: 0.06, green: 0.06, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: LTRadius.sm)
                .stroke(selected ? LTPalette.danger.opacity(0.6) : Color(red: 0.2, green: 0.2, blue: 0.28), lineWidth: 1))
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
                        Text(r.status == .won ? "VANN" : "FÖRLORADE")
                            .font(LTFont.label(10))
                            .foregroundColor(r.status == .won ? LTPalette.neonGreen : LTPalette.danger)
                    }
                    .padding(LTSpacing.sm + 2)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(r.attackerName == gameState.username ? "Mot \(r.defenderName)" : "\(r.attackerName) mot dig"): \(r.status == .won ? "Vann" : "Förlorade")")
                }
            }
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
