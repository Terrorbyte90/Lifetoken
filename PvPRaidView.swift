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
    @Published var cooldowns: [String: Date] = [:]  // username → kan raidads igen

    // Reaktionstest-state
    @Published var raidPhase: RaidPhase = .idle
    @Published var reactionTarget: Bool = false
    @Published var playerReactionMs: Int? = nil
    @Published var opponentReactionMs: Int? = nil

    private var targetAppearTime: Date? = nil
    private var raidTimer: Timer? = nil

    private let cooldownDuration: TimeInterval = 4 * 3600  // 4h
    private let storageKey = "pvpHistory"

    enum RaidPhase {
        case idle, waiting, target, done
    }

    private init() {
        loadHistory()
        loadCooldowns()
    }

    // MARK: - Starta raid

    func initiateRaid(target: ServerUser, stake: TimeInterval, completion: @escaping (Bool, String) -> Void) {
        let playerName = GameState.shared.username
        guard !playerName.isEmpty else { completion(false, "Inget spelarnamn."); return }
        guard TimeEngine.shared.balance >= stake else { completion(false, "Otillräcklig balans."); return }

        // Kontrollera cooldown
        if let lastRaid = cooldowns[target.username], Date() < lastRaid.addingTimeInterval(cooldownDuration) {
            let remaining = lastRaid.addingTimeInterval(cooldownDuration).timeIntervalSinceNow
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            completion(false, "\(target.username) kan inte raidadas igen än. Cooldown: \(h)h \(m)m kvar.")
            return
        }

        // Lås insatsen
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

        // Starta reaktionstestet
        raidPhase = .waiting
        startReactionTest()
        completion(true, "Rånet påbörjat!")
    }

    // MARK: - Reaktionstest

    private func startReactionTest() {
        // Slumpmässig fördröjning 1–4 sekunder innan målet visas
        let delay = Double.random(in: 1.0...4.0)
        raidTimer?.invalidate()
        raidTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.raidPhase = .target
                self?.reactionTarget = true
                self?.targetAppearTime = Date()

                // Om spelaren inte trycker inom 3 sekunder → automatisk förlust
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

        // Simulera motståndarens reaktion (AI med lite slump)
        let opponentMs = Int.random(in: 180...600)
        opponentReactionMs = opponentMs

        let iWon = success && ms < opponentMs
        resolveRaid(playerWon: iWon)
    }

    // MARK: - Avgör utfall

    private func resolveRaid(playerWon: Bool) {
        guard var record = activeRaid else { return }
        raidPhase = .done

        if playerWon {
            // Spelaren vinner — får tillbaka insatsen + stjäl lika mycket från motståndaren
            let stolen = record.stake
            TimeEngine.shared.addTime(record.stake + stolen)
            record.status = .won
        } else {
            // Spelaren förlorar — insatsen är redan dragen
            record.status = .lost
        }

        // Sätt cooldown på offret
        cooldowns[record.defenderName] = Date()
        saveCooldowns()

        history.insert(record, at: 0)
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

    // MARK: - Persistence

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
    @ObservedObject private var manager = PvPRaidManager.shared
    @ObservedObject private var server  = ServerSync.shared
    @ObservedObject private var engine  = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedTarget: ServerUser? = nil
    @State private var stakeMinutes: Double = 30
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var phase: ViewPhase = .selection

    enum ViewPhase { case selection, reaction, result }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

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
                    Button("Stäng") { dismiss() }.foregroundColor(.white).font(.system(size: 13, design: .monospaced))
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
        ScrollView {
            VStack(spacing: 20) {
                // Varningsbanner
                warningBanner

                // Välj offer
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("VÄLJ OFFER")
                    if server.zoneMembers.isEmpty {
                        emptyState("Inga spelare i din zon.")
                    } else {
                        ForEach(server.zoneMembers.filter { $0.username != gameState.username }) { member in
                            targetRow(member)
                        }
                    }
                }

                // Insats
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("INSATS: \(TimeEngine.shortFormatted(stakeMinutes * 60))")
                    Slider(value: $stakeMinutes, in: 15...120, step: 15)
                        .tint(Color(red: 0.9, green: 0.3, blue: 0.1))
                    HStack {
                        Text("15 min").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                        Spacer()
                        Text("2h").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                    }
                }

                // Historik
                historySection

                // Raid-knapp
                Button {
                    guard let target = selectedTarget else { return }
                    manager.initiateRaid(target: target, stake: stakeMinutes * 60) { success, msg in
                        if success {
                            phase = .reaction
                        } else {
                            errorMessage = msg
                            showError = true
                        }
                    }
                } label: {
                    Text("STARTA RÅNET")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedTarget != nil
                                    ? Color(red: 0.9, green: 0.3, blue: 0.1)
                                    : Color(red: 0.3, green: 0.3, blue: 0.35))
                }
                .disabled(selectedTarget == nil)

                Spacer(minLength: 40)
            }
            .padding(16)
        }
    }

    // MARK: - Reaktionstest

    private var reactionView: some View {
        VStack(spacing: 0) {
            Spacer()

            if manager.raidPhase == .waiting {
                VStack(spacing: 16) {
                    Text("VÄNTA...")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.1))
                    Text("Tryck NÄR du ser målet.")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
                }
            } else if manager.raidPhase == .target {
                VStack(spacing: 20) {
                    Circle()
                        .fill(Color(red: 0.9, green: 0.2, blue: 0.1))
                        .frame(width: 140, height: 140)
                        .overlay(
                            Text("TRYCK!")
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        )
                        .shadow(color: Color(red: 0.9, green: 0.2, blue: 0.1).opacity(0.6), radius: 20)
                        .onTapGesture {
                            manager.playerTapped(success: true)
                            phase = .result
                        }
                    Text("TAP NOW!")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.1))
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture {
            if manager.raidPhase == .target {
                manager.playerTapped(success: true)
                phase = .result
            }
        }
        .onChange(of: manager.raidPhase) { _, newPhase in
            if newPhase == .done { phase = .result }
        }
    }

    // MARK: - Resultat

    private var resultView: some View {
        let won = manager.history.first?.status == .won
        let playerMs = manager.playerReactionMs ?? 0
        let oppMs    = manager.opponentReactionMs ?? 0

        return VStack(spacing: 24) {
            Spacer()

            Text(won ? "RÅNET LYCKADES" : "RÅNET MISSLYCKADES")
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundColor(won ? Color(red: 0.1, green: 0.9, blue: 0.5) : Color(red: 0.9, green: 0.2, blue: 0.1))
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                reactionRow(label: "Du", ms: playerMs, best: playerMs < oppMs)
                reactionRow(label: "Motståndare", ms: oppMs, best: oppMs <= playerMs)
            }
            .padding()
            .background(Color(red: 0.06, green: 0.06, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if won {
                Text("Du stal \(TimeEngine.shortFormatted(manager.history.first?.stake ?? 0)) från offret.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.9, blue: 0.5))
            } else {
                Text("Din insats förlorades.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
            }

            Button {
                manager.resetRaid()
                phase = .selection
            } label: {
                Text("TILLBAKA")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Spacer()
        }
        .padding(24)
    }

    private func reactionRow(label: String, ms: Int, best: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text("\(ms) ms")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(best ? Color(red: 0.1, green: 0.9, blue: 0.5) : Color(red: 0.9, green: 0.3, blue: 0.1))
        }
    }

    // MARK: - Sub-views

    private var warningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill").foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.1))
            VStack(alignment: .leading, spacing: 2) {
                Text("Din tid eller ditt liv.")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("Reagera snabbare än motståndaren. Vinner du → stjäl deras insats. Förlorar du → de tar din.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
                    .lineSpacing(2)
            }
        }
        .padding(12)
        .background(Color(red: 0.1, green: 0.04, blue: 0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(red: 0.5, green: 0.15, blue: 0.1), lineWidth: 1))
    }

    private func targetRow(_ member: ServerUser) -> some View {
        let selected = selectedTarget?.id == member.id
        let onCooldown: Bool = {
            if let cd = manager.cooldowns[member.username] {
                return Date() < cd.addingTimeInterval(4 * 3600)
            }
            return false
        }()

        return Button { if !onCooldown { selectedTarget = member } } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.username)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(onCooldown ? Color(red: 0.4, green: 0.4, blue: 0.45) : .white)
                    if onCooldown {
                        Text("Immunitet aktiv")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                    }
                }
                Spacer()
                if selected {
                    Image(systemName: "target")
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.1))
                }
                if onCooldown {
                    Image(systemName: "shield.fill")
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                        .font(.system(size: 14))
                }
            }
            .padding(12)
            .background(selected ? Color(red: 0.12, green: 0.04, blue: 0.04) : Color(red: 0.06, green: 0.06, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color(red: 0.6, green: 0.15, blue: 0.1) : Color(red: 0.2, green: 0.2, blue: 0.28), lineWidth: 1))
        }
        .disabled(onCooldown)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("HISTORIK")
            if manager.history.isEmpty {
                Text("Inga råd ännu.").font(.system(size: 11, design: .monospaced)).foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.4))
            } else {
                ForEach(manager.history.prefix(5)) { r in
                    HStack {
                        Text(r.attackerName == gameState.username ? "vs \(r.defenderName)" : "\(r.attackerName) vs dig")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text(r.status == .won ? "VANN" : "FÖRLORADE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(r.status == .won ? Color(red: 0.1, green: 0.9, blue: 0.5) : Color(red: 0.9, green: 0.3, blue: 0.1))
                    }
                    .padding(10)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.09))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
            .tracking(2)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
    }
}
