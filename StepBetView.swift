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
        guard challengerSteps != opponentSteps else { return nil }
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
    @Published var duelWinStreak: Int = 0

    private let storageKey = "stepBets"
    private let streakKey = "stepDuelWinStreak"
    private var syncTimer: Timer?

    private init() {
        load()
        duelWinStreak = UserDefaults.standard.integer(forKey: streakKey)
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
        guard TimeEngine.shared.deductTime(stake) else {
            completion(false, "Kunde inte låsa insatsen. Försök igen.")
            return
        }

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

        NotificationManager.shared.sendStepDuelChallenge(
            from: playerName,
            to: opponentName,
            stake: TimeEngine.shortFormatted(stake),
            deadline: bet.formattedDeadline
        )
        completion(true, "Duell skickad till \(opponentName).")
    }

    // Motståndaren accepterar
    func acceptBet(betId: String, completion: @escaping (Bool) -> Void) {
        guard let idx = pendingBets.firstIndex(where: { $0.id == betId }) else {
            completion(false); return
        }
        let stake = pendingBets[idx].stake
        guard TimeEngine.shared.balance >= stake else { completion(false); return }

        guard TimeEngine.shared.deductTime(stake) else {
            completion(false)
            return
        }
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

    // MARK: - Sync steg var minut

    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.syncStepsAndSettle()
        }
    }

    func syncStepsAndSettle() {
        let mySteps = IncomeManager.shared.dailySteps
        let playerName = GameState.shared.username
        let betIDs = activeBets.map(\.id)

        for betID in betIDs {
            guard let i = activeBets.firstIndex(where: { $0.id == betID }) else { continue }
            let bet = activeBets[i]

            if bet.challengerName == playerName {
                activeBets[i].challengerSteps = mySteps
                Task { await ServerSync.shared.syncStepBet(betId: bet.id, steps: mySteps) }
            } else if bet.opponentName == playerName {
                activeBets[i].opponentSteps = mySteps
                Task { await ServerSync.shared.syncStepBet(betId: bet.id, steps: mySteps) }
            }

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
        let challengerWon = bet.challengerSteps > bet.opponentSteps
        let opponentWon = bet.opponentSteps > bet.challengerSteps
        let isDraw = !challengerWon && !opponentWon
        let winnerName = challengerWon ? bet.challengerName : (opponentWon ? bet.opponentName : "DRAW")
        let isParticipant = bet.challengerName == playerName || bet.opponentName == playerName
        let iWon = winnerName == playerName

        Task { await ServerSync.shared.settleBet(betId: bet.id, winnerName: winnerName) }

        if isDraw {
            // Oavgjort i 1v1: återbetala lokal spelares låsta insats.
            if isParticipant {
                TimeEngine.shared.addTime(bet.stake)
                TransactionLedger.shared.record(label: "Stegduell — oavgjort", amount: 0)
            }
            duelWinStreak = 0
        } else if iWon {
            // Vinnaren får dubbla insatsen minus 5% husavgift
            let grossPayout = bet.stake * 2
            let houseFee = grossPayout * 0.05
            let netPayout = grossPayout - houseFee
            TimeEngine.shared.addTime(netPayout)
            BoardManager.shared.collectTax(amount: houseFee)
            TransactionLedger.shared.record(label: "Stegduell — vinst", amount: netPayout - bet.stake)
            NewsManager.shared.addStepBetEvent(
                winner: winnerName,
                loser:  winnerName == bet.challengerName ? bet.opponentName : bet.challengerName,
                amount: netPayout
            )
            duelWinStreak += 1
        } else {
            TransactionLedger.shared.record(label: "Stegduell — förlust", amount: -bet.stake)
            duelWinStreak = 0
        }
        UserDefaults.standard.set(duelWinStreak, forKey: streakKey)

        history.insert(bet, at: 0)
        activeBets.remove(at: idx)
        save()
    }

    func rematch(from bet: StepBet, stake: TimeInterval, completion: @escaping (Bool, String) -> Void) {
        let myName = GameState.shared.username
        let opponent = bet.challengerName == myName ? bet.opponentName : bet.challengerName
        createChallenge(opponentName: opponent, stake: stake, deadline: .midnight, completion: completion)
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
    @ObservedObject private var manager   = StepBetManager.shared
    @ObservedObject private var gameState = GameState.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: Int = 0
    @State private var showChallenge: Bool = false
    @State private var challengeResult: String = ""
    @State private var showResult: Bool = false
    @State private var now: Date = Date()

    // Timer för live-nedräkning
    private let countdownTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Text("Win-streak: \(manager.duelWinStreak)")
                            .font(LTFont.caption(10))
                            .foregroundColor(manager.duelWinStreak > 0 ? LTPalette.neonGreen : Color(red: 0.5, green: 0.5, blue: 0.55))
                        Spacer()
                    }
                    .padding(.horizontal, LTSpacing.lg)
                    .padding(.top, LTSpacing.sm)

                    // Flik-bar
                    HStack(spacing: 0) {
                        tabBtn("AKTIVA",     tag: 0, count: manager.activeBets.count)
                        tabBtn("VÄNTAR",     tag: 1, count: manager.pendingBets.count)
                        tabBtn("HISTORIK",   tag: 2, count: nil)
                    }
                    .padding(.horizontal, LTSpacing.lg)
                    .padding(.top, LTSpacing.sm)

                    Divider()
                        .background(Color(red: 0.15, green: 0.15, blue: 0.2))
                        .padding(.top, 6)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: LTSpacing.md) {
                            switch selectedTab {
                            case 0: activeBetsTab
                            case 1: pendingBetsTab
                            default: historyTab
                            }
                        }
                        .padding(LTSpacing.lg)
                        .padding(.bottom, LTSpacing.scrollBottom)
                    }
                }
            }
            .navigationTitle("STEGDUELLEN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Stäng") { dismiss() }
                        .foregroundColor(.white)
                        .font(LTFont.body(13))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showChallenge = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(LTPalette.neonGreen)
                            .font(.system(size: 20))
                    }
                    .accessibilityLabel("Ny duell")
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
        .onAppear {
            manager.syncStepsAndSettle()
        }
        .onReceive(countdownTimer) { t in now = t }
    }

    // MARK: - Aktiva bets

    private var activeBetsTab: some View {
        Group {
            if manager.activeBets.isEmpty {
                emptyState(text: "Inga aktiva dueller.\nUtmana en spelare.")
            } else {
                ForEach(manager.activeBets) { bet in
                    activeBetCard(bet)
                }
            }
        }
    }

    private func activeBetCard(_ bet: StepBet) -> some View {
        let myName      = gameState.username
        let mySteps     = bet.challengerName == myName ? bet.challengerSteps : bet.opponentSteps
        let theirSteps  = bet.challengerName == myName ? bet.opponentSteps : bet.challengerSteps
        let myLabel     = myName
        let opponentName = bet.challengerName == myName ? bet.opponentName : bet.challengerName
        let leading     = mySteps >= theirSteps
        let countdown   = countdownString(to: bet.deadline, from: now)

        return VStack(spacing: LTSpacing.md) {
            // Rubrik-rad
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: LTSpacing.xs) {
                        Text(myLabel.uppercased())
                            .font(LTFont.heading(13))
                            .foregroundColor(.white)
                        Text("VS")
                            .font(LTFont.label(10))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                        Text(opponentName.uppercased())
                            .font(LTFont.heading(13))
                            .foregroundColor(.white)
                    }
                    Text("Insats: \(TimeEngine.shortFormatted(bet.stake))")
                        .font(LTFont.body(10))
                        .foregroundColor(LTPalette.gold)
                }
                Spacer()
                // Statusbadge
                statusBadge(.active)
            }

            // Steg-display — stora siffror
            HStack(alignment: .bottom) {
                // Mina steg
                VStack(spacing: 2) {
                    Text("\(mySteps)")
                        .font(LTFont.value(34))
                        .foregroundColor(leading ? LTPalette.neonGreen : LTPalette.danger)
                        .contentTransition(.numericText())
                    Text(myLabel)
                        .font(LTFont.caption(9))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                // VS-separator
                VStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                    Text("STEG")
                        .font(LTFont.caption(8))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.5))
                }

                // Motståndarens steg
                VStack(spacing: 2) {
                    Text("\(theirSteps)")
                        .font(LTFont.value(34))
                        .foregroundColor(leading ? LTPalette.danger : LTPalette.neonGreen)
                        .contentTransition(.numericText())
                    Text(opponentName)
                        .font(LTFont.caption(9))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            // Progress-bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.18))
                        .frame(height: 6)
                    let total = max(Double(mySteps + theirSteps), 1)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: leading
                                    ? [LTPalette.neonGreen, LTPalette.neonGreenDim]
                                    : [LTPalette.danger, Color(red: 0.7, green: 0.1, blue: 0.1)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(mySteps) / CGFloat(total), height: 6)
                        .animation(LTAnimation.springSmooth, value: mySteps)
                }
            }
            .frame(height: 6)

            // Nedräkning
            HStack {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                Text(countdown)
                    .font(LTFont.body(11))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.6))
                Spacer()
                Text(leading ? "DU LEDER" : "DU FÖRLORAR")
                    .font(LTFont.label(10))
                    .foregroundColor(leading ? LTPalette.neonGreen : LTPalette.danger)
                    .tracking(1)
            }
        }
        .padding(LTSpacing.lg)
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.sm)
                .stroke(
                    leading
                        ? LTPalette.neonGreen.opacity(0.25)
                        : LTPalette.danger.opacity(0.25),
                    lineWidth: 1
                )
        )
        .shadow(color: leading ? LTPalette.neonGreen.opacity(0.08) : LTPalette.danger.opacity(0.08), radius: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Duell mot \(opponentName): \(mySteps) vs \(theirSteps) steg. \(countdown) kvar.")
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
        return VStack(spacing: LTSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: LTSpacing.xs) {
                        Text(bet.challengerName.uppercased())
                            .font(LTFont.heading(13))
                            .foregroundColor(isChallenger ? LTPalette.neonGreen : .white)
                        Text("VS")
                            .font(LTFont.label(10))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                        Text(bet.opponentName.uppercased())
                            .font(LTFont.heading(13))
                            .foregroundColor(!isChallenger ? LTPalette.neonGreen : .white)
                    }
                    Text("Insats: \(TimeEngine.shortFormatted(bet.stake))  •  Deadline: \(bet.formattedDeadline)")
                        .font(LTFont.body(10))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                }
                Spacer()
                statusBadge(.pending)
            }

            if !isChallenger {
                HStack(spacing: LTSpacing.sm) {
                    Button {
                        manager.acceptBet(betId: bet.id) { _ in }
                    } label: {
                        Text("ACCEPTERA")
                            .font(LTFont.heading(12))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LTSpacing.sm + 2)
                            .background(LTPalette.neonGreen)
                            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                    }
                    .buttonStyle(LTPressEffect())

                    Button {
                        manager.declineBet(betId: bet.id)
                    } label: {
                        Text("AVBÖJ")
                            .font(LTFont.heading(12))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LTSpacing.sm + 2)
                            .background(Color(red: 0.15, green: 0.15, blue: 0.2))
                            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                    }
                    .buttonStyle(LTPressEffect())
                }
            } else {
                Text("Väntar på att \(bet.opponentName) accepterar...")
                    .font(LTFont.body(11))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(LTSpacing.lg)
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.sm)
                .stroke(Color(red: 0.25, green: 0.25, blue: 0.35), lineWidth: 1)
        )
    }

    // MARK: - History

    private var historyTab: some View {
        Group {
            if manager.history.isEmpty {
                emptyState(text: "Ingen historik ännu.")
            } else {
                ForEach(manager.history) { bet in
                    VStack(spacing: 8) {
                        historyCard(bet)
                        rematchButton(for: bet)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func rematchButton(for bet: StepBet) -> some View {
        let amount = min(bet.stake, manager.maxStake(for: gameState.currentZone))
        Button {
            manager.rematch(from: bet, stake: amount) { success, msg in
                challengeResult = msg
                showResult = true
                if success { selectedTab = 1 }
            }
        } label: {
            Text("REMATCH (\(TimeEngine.shortFormatted(amount)))")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func historyCard(_ bet: StepBet) -> some View {
        let myName  = gameState.username
        let isDraw  = bet.status == .settled && bet.winnerName == nil
        let won     = bet.winnerName == myName
        let oppName = bet.challengerName == myName ? bet.opponentName : bet.challengerName
        let mySteps = bet.challengerName == myName ? bet.challengerSteps : bet.opponentSteps
        let opSteps = bet.challengerName == myName ? bet.opponentSteps : bet.challengerSteps
        let accent: Color = isDraw ? LTPalette.gold : (won ? LTPalette.neonGreen : LTPalette.danger)
        let statusText = isDraw ? "OAVGJORT" : (won ? "VANN" : "FÖRLORADE")
        let statusLabel = isDraw ? "Oavgjort" : (won ? "Vann" : "Förlorade")

        return HStack(spacing: LTSpacing.md) {
            // Resultatsymbol
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: isDraw ? "equal.circle.fill" : (won ? "trophy.fill" : "xmark"))
                    .font(.system(size: 16))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("VS \(oppName.uppercased())")
                    .font(LTFont.heading(12))
                    .foregroundColor(.white)
                Text("\(mySteps) vs \(opSteps) steg")
                    .font(LTFont.body(10))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(statusText)
                    .font(LTFont.label(11))
                    .foregroundColor(accent)
                Text(TimeEngine.shortFormatted(bet.stake))
                    .font(LTFont.body(10))
                    .foregroundColor(LTPalette.gold.opacity(0.8))
            }
        }
        .padding(LTSpacing.md)
        .background(Color(red: 0.06, green: 0.06, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.sm)
                .stroke(
                    accent.opacity(0.15),
                    lineWidth: 1
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mot \(oppName): \(mySteps) mot \(opSteps) steg. \(statusLabel).")
    }

    // MARK: - Hjälpkomponenter

    private func tabBtn(_ title: String, tag: Int, count: Int?) -> some View {
        Button { selectedTab = tag } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(LTFont.label(11))
                        .foregroundColor(selectedTab == tag ? .white : Color(red: 0.45, green: 0.45, blue: 0.5))
                    if let n = count, n > 0 {
                        Text("\(n)")
                            .font(LTFont.caption(8))
                            .foregroundColor(selectedTab == tag ? .black : .white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(selectedTab == tag ? LTPalette.neonGreen : Color(red: 0.3, green: 0.3, blue: 0.4))
                            .clipShape(Capsule())
                    }
                }
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(selectedTab == tag ? LTPalette.neonGreen : .clear)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func statusBadge(_ status: BetStatus) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case .pending:  return ("VÄNTAR",  LTPalette.warning)
            case .active:   return ("AKTIV",   LTPalette.neonGreen)
            case .settled:  return ("AVGJORD", Color(red: 0.5, green: 0.5, blue: 0.6))
            case .declined: return ("AVBÖJD",  LTPalette.danger)
            }
        }()

        Text(label)
            .font(LTFont.caption(8))
            .foregroundColor(color)
            .tracking(1)
            .padding(.horizontal, LTSpacing.sm)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }

    private func countdownString(to deadline: Date, from now: Date) -> String {
        let remaining = deadline.timeIntervalSince(now)
        guard remaining > 0 else { return "Utgången" }
        let days    = Int(remaining) / 86400
        let hours   = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m kvar"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m kvar"
        } else {
            return "\(minutes)m kvar"
        }
    }

    private func emptyState(text: String) -> some View {
        VStack(spacing: LTSpacing.md) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 36))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4))
            Text(text)
                .font(LTFont.body(13))
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Skapa Utmaning Sheet

struct CreateChallengeSheet: View {
    @Binding var result: String
    @Binding var showResult: Bool
    @ObservedObject private var server    = ServerSync.shared
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedOpponent: ServerUser? = nil
    @State private var stakeHours: Double = 0.5
    @State private var selectedDeadline: BetDeadline = .evening
    @State private var sending: Bool = false

    private var maxStakeHours: Double {
        let secs = StepBetManager.shared.maxStake(for: gameState.currentZone)
        let hours = secs == .infinity ? 24.0 : secs / 3600
        return max(0.5, hours)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: LTSpacing.xl) {

                        // Välj motståndare
                        VStack(alignment: .leading, spacing: LTSpacing.sm) {
                            sectionHeader("VÄLJ MOTSTÅNDARE")
                            if server.zoneMembers.isEmpty {
                                Text("Inga spelare i din zon just nu.")
                                    .font(LTFont.body(12))
                                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.45))
                            } else {
                                ForEach(server.zoneMembers.filter { $0.username != gameState.username }) { member in
                                    opponentRow(member)
                                }
                            }
                        }

                        // Insats
                        VStack(alignment: .leading, spacing: LTSpacing.sm) {
                            sectionHeader("INSATS: \(TimeEngine.shortFormatted(stakeHours * 3600))")
                            Slider(value: $stakeHours, in: 0.25...maxStakeHours, step: 0.25)
                                .tint(LTPalette.neonGreen)
                            HStack {
                                Text("15 min")
                                    .font(LTFont.caption(9))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("Max \(TimeEngine.shortFormatted(maxStakeHours * 3600))")
                                    .font(LTFont.caption(9))
                                    .foregroundColor(.gray)
                            }
                        }

                        // Deadline — varaktighet 1-7 dagar
                        VStack(alignment: .leading, spacing: LTSpacing.sm) {
                            sectionHeader("DEADLINE")
                            HStack(spacing: LTSpacing.sm) {
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
                            HStack(spacing: LTSpacing.xs) {
                                if sending {
                                    ProgressView()
                                        .tint(.black)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "figure.walk")
                                }
                                Text(sending ? "SKICKAR..." : "SKICKA UTMANING")
                                    .font(LTFont.heading(14))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LTSpacing.lg)
                            .background(
                                selectedOpponent != nil && stakeHours * 3600 <= engine.balance
                                    ? LTPalette.neonGreen
                                    : Color(red: 0.3, green: 0.3, blue: 0.35)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                        }
                        .disabled(selectedOpponent == nil || stakeHours * 3600 > engine.balance || sending)
                        .buttonStyle(LTPressEffect())

                        Spacer(minLength: LTSpacing.xxxl)
                    }
                    .padding(LTSpacing.lg)
                }
            }
            .navigationTitle("NY DUELL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }
                        .foregroundColor(.white)
                        .font(LTFont.body(13))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func opponentRow(_ member: ServerUser) -> some View {
        let selected = selectedOpponent?.id == member.id
        return Button { selectedOpponent = member } label: {
            HStack(spacing: LTSpacing.md) {
                ZStack {
                    Circle()
                        .fill(selected
                              ? LTPalette.neonGreen.opacity(0.2)
                              : Color(red: 0.1, green: 0.1, blue: 0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(selected ? LTPalette.neonGreen : .white.opacity(0.6))
                }
                Text(member.username)
                    .font(LTFont.heading(13))
                    .foregroundColor(.white)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(LTPalette.neonGreen)
                        .font(.system(size: 18))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(LTSpacing.md)
            .background(selected ? Color(red: 0.04, green: 0.12, blue: 0.07) : Color(red: 0.06, green: 0.06, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: LTRadius.sm)
                    .stroke(
                        selected ? LTPalette.neonGreen.opacity(0.5) : Color(red: 0.2, green: 0.2, blue: 0.28),
                        lineWidth: selected ? 1.5 : 1
                    )
            )
            .animation(LTAnimation.springFast, value: selected)
        }
        .buttonStyle(LTPressEffect())
        .accessibilityLabel(member.username)
        .accessibilityHint(selected ? "Vald motståndare" : "Välj som motståndare")
    }

    private func deadlineBtn(_ d: BetDeadline) -> some View {
        let sel = selectedDeadline == d
        return Button { selectedDeadline = d } label: {
            Text(d.rawValue)
                .font(LTFont.heading(12))
                .foregroundColor(sel ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LTSpacing.sm + 2)
                .background(sel ? LTPalette.neonGreen : Color(red: 0.1, green: 0.1, blue: 0.15))
                .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
        }
        .buttonStyle(LTPressEffect())
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(LTFont.label(9))
            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.55))
            .tracking(2)
    }

    private func warningRow(_ text: String) -> some View {
        HStack(spacing: LTSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(LTPalette.danger)
            Text(text)
                .font(LTFont.body(11))
                .foregroundColor(LTPalette.danger)
        }
        .padding(LTSpacing.md)
        .background(LTPalette.danger.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.xs).stroke(LTPalette.danger.opacity(0.3), lineWidth: 1))
    }
}
