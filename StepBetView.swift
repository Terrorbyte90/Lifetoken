import SwiftUI
import Foundation

// MARK: - StepBet — Arbetsduell
// Två spelare satsar tid mot varandra. Flest steg vinner vid deadline.

// MARK: - Modeller

enum BetDeadline: String, CaseIterable {
    case evening  = "Kl 21:00"
    case midnight = "Midnatt"

    var hour: Int { self == .evening ? 21 : 0 }
}

enum BetStatus: String, Codable {
    case pending    = "pending"
    case active     = "active"
    case settled    = "settled"
    case declined   = "declined"
}

struct StepBet: Identifiable, Codable {
    let id: String
    let challengerName: String
    let opponentName: String
    var challengerSteps: Int
    var opponentSteps: Int
    let stake: TimeInterval          // insats i sekunder
    let deadline: Date
    var status: BetStatus
    let createdAt: Date

    var isExpired: Bool { Date() > deadline }
    var winnerName: String? {
        guard status == .settled else { return nil }
        return challengerSteps > opponentSteps ? challengerName : opponentName
    }

    var formattedDeadline: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "Europe/Stockholm")
        return fmt.string(from: deadline)
    }
}

// MARK: - StepBet Manager

class StepBetManager: ObservableObject {
    static let shared = StepBetManager()

    @Published var activeBets: [StepBet] = []
    @Published var pendingBets: [StepBet] = []
    @Published var history: [StepBet] = []

    private let storageKey = "stepBets"
    private var syncTimer: Timer?

    private init() {
        load()
        startSyncTimer()
    }

    // MARK: - Skapa duell

    func createChallenge(
        opponentName: String,
        stake: TimeInterval,
        deadline: BetDeadline,
        completion: @escaping (Bool, String) -> Void
    ) {
        let playerName = GameState.shared.username
        guard !playerName.isEmpty else { completion(false, "Inget spelarnamn."); return }
        guard TimeEngine.shared.balance >= stake else {
            completion(false, "Otillräcklig balans."); return
        }
        guard stake <= maxStake(for: GameState.shared.currentZone) else {
            completion(false, "Insatsen överstiger zonens gräns."); return
        }

        // Lås insatsen från utmanaren
        TimeEngine.shared.deductTime(stake)

        let deadlineDate = nextDeadlineDate(hour: deadline.hour)
        let bet = StepBet(
            id: UUID().uuidString,
            challengerName: playerName,
            opponentName: opponentName,
            challengerSteps: IncomeManager.shared.dailySteps,
            opponentSteps: 0,
            stake: stake,
            deadline: deadlineDate,
            status: .pending,
            createdAt: Date()
        )

        pendingBets.insert(bet, at: 0)
        save()

        // Skicka till server
        Task {
            await ServerSync.shared.createStepBet(bet: bet)
        }

        completion(true, "Duell skickad till \(opponentName).")
    }

    // Motståndaren accepterar
    func acceptBet(betId: String, completion: @escaping (Bool) -> Void) {
        guard let idx = pendingBets.firstIndex(where: { $0.id == betId }) else {
            completion(false); return
        }
        let stake = pendingBets[idx].stake
        guard TimeEngine.shared.balance >= stake else { completion(false); return }

        TimeEngine.shared.deductTime(stake)
        pendingBets[idx].status = .active
        activeBets.insert(pendingBets[idx], at: 0)
        pendingBets.remove(at: idx)
        save()
        Task { await ServerSync.shared.acceptStepBet(betId: betId) }
        completion(true)
    }

    func declineBet(betId: String) {
        if let idx = pendingBets.firstIndex(where: { $0.id == betId }) {
            // Återbetala utmanarens insats
            TimeEngine.shared.addTime(pendingBets[idx].stake)
            pendingBets[idx].status = .declined
            pendingBets.remove(at: idx)
            save()
        }
    }

    // MARK: - Sync steg var 5:e minut

    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.syncStepsAndSettle()
        }
    }

    func syncStepsAndSettle() {
        let mySteps = IncomeManager.shared.dailySteps
        let playerName = GameState.shared.username

        for i in activeBets.indices {
            let bet = activeBets[i]

            // Uppdatera mina steg
            if bet.challengerName == playerName {
                activeBets[i].challengerSteps = mySteps
            } else if bet.opponentName == playerName {
                activeBets[i].opponentSteps = mySteps
            }

            // Kontrollera om deadline passerat
            if activeBets[i].isExpired {
                settleBet(betId: bet.id)
            }
        }
        save()
    }

    private func settleBet(betId: String) {
        guard let idx = activeBets.firstIndex(where: { $0.id == betId }) else { return }
        var bet = activeBets[idx]
        bet.status = .settled

        let playerName = GameState.shared.username
        let iChallenger = bet.challengerName == playerName
        let iWon = (iChallenger && bet.challengerSteps > bet.opponentSteps) ||
                   (!iChallenger && bet.opponentSteps > bet.challengerSteps)

        if iWon {
            // Vinnaren får dubbla insatsen minus 5% husavgift
            let grossPayout = bet.stake * 2
            let houseFee = grossPayout * 0.05
            let netPayout = grossPayout - houseFee
            TimeEngine.shared.addTime(netPayout)
            BoardManager.shared.collectTax(amount: houseFee)
            TransactionLedger.shared.record(label: "Stegduell — vinst", amount: netPayout - bet.stake)
            NewsManager.shared.addStepBetEvent(
                winner: iChallenger ? bet.challengerName : bet.opponentName,
                loser:  iChallenger ? bet.opponentName : bet.challengerName,
                amount: netPayout
            )
        } else {
            TransactionLedger.shared.record(label: "Stegduell — förlust", amount: -bet.stake)
        }

        history.insert(bet, at: 0)
        activeBets.remove(at: idx)
        save()
    }

    // MARK: - Zonbegränsning

    func maxStake(for zone: ZoneProfile) -> TimeInterval {
        switch zone.index {
        case 0:     return 1800          // Askan: 30 min
        case 1...3: return 3600          // Spillrorna–Dimman: 1h
        case 4...6: return 7200          // Halvmörkret–Stigarnas Dal: 2h
        default:    return .infinity     // Uppgången+: obegränsat
        }
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: [StepBet]].self, from: data) {
            activeBets  = decoded["active"] ?? []
            pendingBets = decoded["pending"] ?? []
            history     = decoded["history"] ?? []
        }
    }

    private func save() {
        let payload: [String: [StepBet]] = [
            "active":  activeBets,
            "pending": pendingBets,
            "history": Array(history.prefix(50))
        ]
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func nextDeadlineDate(hour: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        let now = Date()
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = 0
        comps.second = 0
        var d = cal.date(from: comps) ?? now
        if d <= now { d = cal.date(byAdding: .day, value: 1, to: d) ?? d }
        return d
    }
}

// MARK: - StepBet View

struct StepBetView: View {
    @ObservedObject private var manager = StepBetManager.shared
    @ObservedObject private var server  = ServerSync.shared
    @ObservedObject private var engine  = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: Int = 0
    @State private var showChallenge: Bool = false
    @State private var challengeResult: String = ""
    @State private var showResult: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Tab bar
                    HStack(spacing: 0) {
                        tabBtn("Aktiva", tag: 0)
                        tabBtn("Utmaningar", tag: 1)
                        tabBtn("Historik", tag: 2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Divider().background(Color(red: 0.15, green: 0.15, blue: 0.2)).padding(.top, 6)

                    ScrollView {
                        VStack(spacing: 14) {
                            if selectedTab == 0 { activeBetsTab }
                            else if selectedTab == 1 { pendingBetsTab }
                            else { historyTab }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("STEGDUELLEN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") { dismiss() }.foregroundColor(.white).font(.system(size: 13, design: .monospaced))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showChallenge = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.5))
                    }
                }
            }
        }
        .sheet(isPresented: $showChallenge) {
            CreateChallengeSheet(result: $challengeResult, showResult: $showResult)
        }
        .alert("Duell", isPresented: $showResult) {
            Button("OK", role: .cancel) {}
        } message: { Text(challengeResult) }
        .preferredColorScheme(.dark)
    }

    // MARK: - Aktiva bets

    private var activeBetsTab: some View {
        Group {
            if manager.activeBets.isEmpty {
                emptyState(text: "Inga aktiva dueller.\nUtmana någon i din zon.")
            } else {
                ForEach(manager.activeBets) { bet in
                    activeBetCard(bet)
                }
            }
        }
    }

    private func activeBetCard(_ bet: StepBet) -> some View {
        let myName = gameState.username
        let mySteps = bet.challengerName == myName ? bet.challengerSteps : bet.opponentSteps
        let theirSteps = bet.challengerName == myName ? bet.opponentSteps : bet.challengerSteps
        let opponent = bet.challengerName == myName ? bet.opponentName : bet.challengerName
        let leading = mySteps >= theirSteps

        return VStack(spacing: 12) {
            HStack {
                Text("VS \(opponent.uppercased())")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                Text("INSATS: \(TimeEngine.shortFormatted(bet.stake))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.1))
            }

            // Progress-bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                        .frame(height: 8)
                    let total = max(Double(mySteps + theirSteps), 1)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(leading ? Color(red: 0.1, green: 0.9, blue: 0.5) : Color(red: 0.9, green: 0.3, blue: 0.1))
                        .frame(width: geo.size.width * CGFloat(mySteps) / CGFloat(total), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                stepPill(steps: mySteps, label: "Du", leading: leading)
                Spacer()
                Text("Deadline \(bet.formattedDeadline)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                Spacer()
                stepPill(steps: theirSteps, label: opponent, leading: !leading)
            }
        }
        .padding(14)
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(leading ? Color(red: 0.1, green: 0.5, blue: 0.2) : Color(red: 0.5, green: 0.15, blue: 0.1), lineWidth: 1))
    }

    private func stepPill(steps: Int, label: String, leading: Bool) -> some View {
        VStack(spacing: 2) {
            Text("\(steps)")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(leading ? Color(red: 0.1, green: 0.9, blue: 0.5) : Color(red: 0.9, green: 0.3, blue: 0.1))
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
        }
    }

    // MARK: - Pending bets

    private var pendingBetsTab: some View {
        Group {
            if manager.pendingBets.isEmpty {
                emptyState(text: "Inga väntande utmaningar.")
            } else {
                ForEach(manager.pendingBets) { bet in
                    pendingBetCard(bet)
                }
            }
        }
    }

    private func pendingBetCard(_ bet: StepBet) -> some View {
        let isChallenger = bet.challengerName == gameState.username
        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isChallenger ? "Du utmanade \(bet.opponentName)" : "\(bet.challengerName) utmanar dig")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Insats: \(TimeEngine.shortFormatted(bet.stake)) • \(bet.formattedDeadline)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                }
                Spacer()
            }
            if !isChallenger {
                HStack(spacing: 10) {
                    Button {
                        manager.acceptBet(betId: bet.id) { _ in }
                    } label: {
                        Text("ACCEPTERA")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color(red: 0.1, green: 0.9, blue: 0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Button {
                        manager.declineBet(betId: bet.id)
                    } label: {
                        Text("AVBÖJ")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red: 0.3, green: 0.3, blue: 0.4), lineWidth: 1))
    }

    // MARK: - History

    private var historyTab: some View {
        Group {
            if manager.history.isEmpty {
                emptyState(text: "Ingen historik ännu.")
            } else {
                ForEach(manager.history) { bet in
                    historyCard(bet)
                }
            }
        }
    }

    private func historyCard(_ bet: StepBet) -> some View {
        let won = bet.winnerName == gameState.username
        return HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("VS \(bet.challengerName == gameState.username ? bet.opponentName : bet.challengerName)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("\(bet.challengerSteps) vs \(bet.opponentSteps) steg")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
            }
            Spacer()
            Text(won ? "VANN" : "FÖRLORADE")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(won ? Color(red: 0.1, green: 0.9, blue: 0.5) : Color(red: 0.9, green: 0.3, blue: 0.1))
        }
        .padding(12)
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tabBtn(_ title: String, tag: Int) -> some View {
        Button { selectedTab = tag } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(selectedTab == tag ? .white : Color(red: 0.45, green: 0.45, blue: 0.5))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(selectedTab == tag ? Color(red: 0.1, green: 0.9, blue: 0.5) : .clear),
                    alignment: .bottom
                )
        }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
    }
}

// MARK: - Skapa Utmaning Sheet

struct CreateChallengeSheet: View {
    @Binding var result: String
    @Binding var showResult: Bool
    @ObservedObject private var server  = ServerSync.shared
    @ObservedObject private var engine  = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedOpponent: ServerUser? = nil
    @State private var stakeHours: Double = 0.5
    @State private var selectedDeadline: BetDeadline = .evening
    @State private var sending: Bool = false

    private var maxStakeHours: Double {
        let secs = StepBetManager.shared.maxStake(for: gameState.currentZone)
        let hours = secs == .infinity ? 24.0 : secs / 3600
        return max(0.5, hours)   // must be >= lower(0.25) + step(0.25) to avoid stride crash
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        // Välj motståndare
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("VÄLJ MOTSTÅNDARE")
                            if server.zoneMembers.isEmpty {
                                Text("Inga spelare i din zon just nu.")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                            } else {
                                ForEach(server.zoneMembers.filter { $0.username != gameState.username }) { member in
                                    opponentRow(member)
                                }
                            }
                        }

                        // Insats
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("INSATS: \(TimeEngine.shortFormatted(stakeHours * 3600))")
                            Slider(value: $stakeHours, in: 0.25...maxStakeHours, step: 0.25)
                                .tint(Color(red: 0.1, green: 0.9, blue: 0.5))
                            HStack {
                                Text("15 min").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                                Spacer()
                                Text("Max \(TimeEngine.shortFormatted(maxStakeHours * 3600))")
                                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                            }
                        }

                        // Deadline
                        VStack(alignment: .leading, spacing: 8) {
                            sectionHeader("DEADLINE")
                            HStack(spacing: 10) {
                                ForEach(BetDeadline.allCases, id: \.self) { d in
                                    deadlineBtn(d)
                                }
                            }
                        }

                        // Balansvarning
                        let stake = stakeHours * 3600
                        if stake > engine.balance {
                            warningRow("Otillräcklig balans.")
                        }

                        // Skicka
                        Button {
                            guard let opp = selectedOpponent else { return }
                            sending = true
                            StepBetManager.shared.createChallenge(
                                opponentName: opp.username,
                                stake: stakeHours * 3600,
                                deadline: selectedDeadline
                            ) { success, msg in
                                DispatchQueue.main.async {
                                    sending = false
                                    result = msg
                                    showResult = true
                                    if success { dismiss() }
                                }
                            }
                        } label: {
                            Text(sending ? "SKICKAR..." : "SKICKA UTMANING")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedOpponent != nil && stakeHours * 3600 <= engine.balance
                                            ? Color(red: 0.1, green: 0.9, blue: 0.5)
                                            : Color(red: 0.3, green: 0.3, blue: 0.35))
                        }
                        .disabled(selectedOpponent == nil || stakeHours * 3600 > engine.balance || sending)

                        Spacer(minLength: 40)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("NY DUELL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }.foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func opponentRow(_ member: ServerUser) -> some View {
        let selected = selectedOpponent?.id == member.id
        return Button { selectedOpponent = member } label: {
            HStack {
                Text(member.username)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.5))
                }
            }
            .padding(12)
            .background(selected ? Color(red: 0.05, green: 0.15, blue: 0.08) : Color(red: 0.06, green: 0.06, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color(red: 0.1, green: 0.6, blue: 0.2) : Color(red: 0.2, green: 0.2, blue: 0.28), lineWidth: 1))
        }
    }

    private func deadlineBtn(_ d: BetDeadline) -> some View {
        let sel = selectedDeadline == d
        return Button { selectedDeadline = d } label: {
            Text(d.rawValue)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(sel ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(sel ? Color(red: 0.1, green: 0.9, blue: 0.5) : Color(red: 0.1, green: 0.1, blue: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
            .tracking(2)
    }

    private func warningRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
            Text(text).font(.system(size: 11, design: .monospaced)).foregroundColor(.red)
        }
        .padding(10)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
