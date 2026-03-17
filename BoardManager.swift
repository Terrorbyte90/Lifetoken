import Foundation
import SwiftUI

// MARK: - Styrelsen — De Tre Mäktiga
// NPCs som driver systemet. Deras balans syns alltid på dashboarden.
// Om en spelare klättrar förbi dem tar spelaren deras makt.

struct BoardMember: Identifiable {
    let id: String
    var displayName: String       // NPC-namn eller spelarnamn
    var isNPC: Bool               // false om en spelare tagit rollen
    let role: PowerRole
    var balance: TimeInterval     // live-balans i sekunder
    var weeklyIncome: TimeInterval // inkomst denna vecka från maktpositionen
    var balanceHistory: [TimeInterval] // för sparkline

    var title: String { role.title }
    var color: Color { role.color }
}

enum PowerRole: String, CaseIterable {
    case rank1 = "rank1"
    case rank2 = "rank2"
    case rank3 = "rank3"

    var title: String {
        switch self {
        case .rank1: return "GREGOR SKATT"
        case .rank2: return "ARVID TOLL"
        case .rank3: return "LEON PRENT"
        }
    }

    var subtitle: String {
        switch self {
        case .rank1: return "Skattemagnaten — uppbär skatten"
        case .rank2: return "Tidstjuven — snor din balans"
        case .rank3: return "Inflationsherren — tjänar på priser"
        }
    }

    var description: String {
        switch self {
        case .rank1: return "Uppbär en del av all skatteintäkt som flödar genom systemet. Varje gång en spelare betalar skatt får Skattemagnaten sin andel."
        case .rank2: return "Drar 3–12% av alla spelares balans varje vecka som en osynlig systemavgift. Du märker det knappt — men det summerar sig."
        case .rank3: return "Utlöser inflationsspiken en gång per vecka. Varje gång priserna stiger tjänar han på att din sparade tid förlorar köpkraft."
        }
    }

    var color: Color {
        switch self {
        case .rank1: return Color(red: 0.9, green: 0.3, blue: 0.1)
        case .rank2: return Color(red: 0.8, green: 0.6, blue: 0.1)
        case .rank3: return Color(red: 0.5, green: 0.3, blue: 0.9)
        }
    }

    var icon: String {
        switch self {
        case .rank1: return "dollarsign.circle.fill"
        case .rank2: return "clock.fill"
        case .rank3: return "printer.fill"
        }
    }

    // Startbalanser enligt spec (i sekunder)
    var startingBalance: TimeInterval {
        switch self {
        case .rank1: return 87 * 365.25 * 86400   // 87 år
        case .rank2: return 100 * 365.25 * 86400  // 100 år
        case .rank3: return 95 * 365.25 * 86400   // 95 år
        }
    }
}

// MARK: - Board Manager

class BoardManager: ObservableObject {
    static let shared = BoardManager()

    @Published var members: [BoardMember] = []
    @Published var pendingSystemFee: Double = 0      // Arvids veckoavgift (3–12%)
    @Published var pendingInflationSpike: Bool = false
    @Published var lastSpikeHour: String = ""

    // Lokalt ackumulerad skatt sedan sist (adderas till Gregors balans)
    private var accumulatedTax: TimeInterval = 0

    private var weeklyTimer: Timer?
    private var drainTimer: Timer?

    private let storageKey = "boardMembers"

    private init() {
        loadOrInit()
        startDrainTimer()
        scheduleWeeklyEvents()
    }

    // MARK: - Init / Load

    private func loadOrInit() {
        // Ladda sparade balanser
        let savedBalances = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Double] ?? [:]
        let savedWeekly   = UserDefaults.standard.dictionary(forKey: "boardWeekly") as? [String: Double] ?? [:]
        let savedNames    = UserDefaults.standard.dictionary(forKey: "boardNames") as? [String: String] ?? [:]
        let savedIsNPC    = UserDefaults.standard.dictionary(forKey: "boardIsNPC") as? [String: Bool] ?? [:]

        members = PowerRole.allCases.map { role in
            BoardMember(
                id: role.rawValue,
                displayName: savedNames[role.rawValue] ?? role.title,
                isNPC: savedIsNPC[role.rawValue] ?? true,
                role: role,
                balance: savedBalances[role.rawValue] ?? role.startingBalance,
                weeklyIncome: savedWeekly[role.rawValue] ?? 0,
                balanceHistory: []
            )
        }
    }

    private func save() {
        var balances: [String: Double] = [:]
        var weekly: [String: Double] = [:]
        var names: [String: String] = [:]
        var isNPC: [String: Bool] = [:]
        for m in members {
            balances[m.id]   = m.balance
            weekly[m.id]     = m.weeklyIncome
            names[m.id]      = m.displayName
            isNPC[m.id]      = m.isNPC
        }
        UserDefaults.standard.set(balances, forKey: storageKey)
        UserDefaults.standard.set(weekly, forKey: "boardWeekly")
        UserDefaults.standard.set(names, forKey: "boardNames")
        UserDefaults.standard.set(isNPC, forKey: "boardIsNPC")
    }

    // MARK: - Drain — alla tickar ner som vanliga spelare

    private func startDrainTimer() {
        drainTimer?.invalidate()
        drainTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.tickDrain()
        }
    }

    private func tickDrain() {
        DispatchQueue.main.async {
            for i in self.members.indices {
                // Drain 1 sekund per sekund (60s per minut)
                self.members[i].balance = max(0, self.members[i].balance - 60)
                // Lägg till i historik (max 7 datapunkter)
                self.members[i].balanceHistory.append(self.members[i].balance)
                if self.members[i].balanceHistory.count > 7 {
                    self.members[i].balanceHistory.removeFirst()
                }
            }
            self.save()
            self.checkRankChanges()
        }
    }

    // MARK: - Gregor — samlar all skatt

    /// Anropas varje gång en spelare betalar skatt (från TimeEngine/IncomeManager)
    func collectTax(amount: TimeInterval) {
        accumulatedTax += amount
        DispatchQueue.main.async {
            if let idx = self.members.firstIndex(where: { $0.role == .rank1 }) {
                self.members[idx].balance += amount
                self.members[idx].weeklyIncome += amount
            }
        }
    }

    // MARK: - Arvid — veckoavgift 3–12%

    private func scheduleWeeklyEvents() {
        weeklyTimer?.invalidate()
        // Kör varje vecka (7 dagar i sekunder)
        // I produktion: använd faktisk kalender för exakt timing
        let weekSeconds: TimeInterval = 7 * 24 * 3600
        weeklyTimer = Timer.scheduledTimer(withTimeInterval: weekSeconds, repeats: true) { [weak self] _ in
            self?.executeWeeklySystemFee()
            self?.executeWeeklyInflationSpike()
        }
    }

    func executeWeeklySystemFee() {
        let feePercent = Double.random(in: 0.03...0.12)
        let playerBalance = TimeEngine.shared.balance
        let fee = playerBalance * feePercent

        // Dra från spelaren via safe deductTime
        TimeEngine.shared.deductTime(min(fee, playerBalance))

        // Ge till Arvid
        DispatchQueue.main.async {
            if let idx = self.members.firstIndex(where: { $0.role == .rank2 }) {
                self.members[idx].balance += fee
                self.members[idx].weeklyIncome += fee
            }
            self.pendingSystemFee = feePercent

            // Nyhet
            let pct = String(format: "%.0f", feePercent * 100)
            NewsManager.shared.addSystemFeeEvent(percent: feePercent, totalStolen: fee)
        }
    }

    func executeWeeklyInflationSpike() {
        // Leon utlöser en spike — inflationsskillnaden adderas till hans balans
        let baseInflation = InflationManager.shared.currentMultiplier
        let spikeExtra = 0.003 * baseInflation // 0.3% extra per dag × 7 dagar
        let spikeIncome = TimeEngine.shared.balance * spikeExtra

        DispatchQueue.main.async {
            if let idx = self.members.firstIndex(where: { $0.role == .rank3 }) {
                self.members[idx].balance += spikeIncome
                self.members[idx].weeklyIncome += spikeIncome
            }
            let hour = Calendar.current.component(.hour, from: Date())
            self.lastSpikeHour = String(format: "%02d:00", hour)
            self.pendingInflationSpike = true

            // Nyhet
            NewsManager.shared.addInflationSpikeEvent(hour: self.lastSpikeHour)
        }
    }

    // MARK: - Rankbyte — spelaren tar makten

    private func checkRankChanges() {
        let playerBalance = TimeEngine.shared.balance
        let playerName    = GameState.shared.username
        guard !playerName.isEmpty else { return }

        for i in members.indices {
            let member = members[i]
            if playerBalance > member.balance {
                if member.isNPC || member.displayName != playerName {
                    // Spelaren tar makten!
                    members[i].displayName = playerName
                    members[i].isNPC = false
                    save()
                    NewsManager.shared.addRankChangeEvent(playerName: playerName, role: member.role)
                }
            } else if !member.isNPC && member.displayName == playerName {
                // Spelaren föll — återgå till NPC-namn
                members[i].displayName = member.role.title
                members[i].isNPC = true
                save()
            }
        }
    }

    // MARK: - Total stulet för Styrelsevy

    var totalTaxCollected: TimeInterval {
        UserDefaults.standard.double(forKey: "totalTaxCollected")
    }

    func recordTaxCollection(_ amount: TimeInterval) {
        let prev = UserDefaults.standard.double(forKey: "totalTaxCollected")
        UserDefaults.standard.set(prev + amount, forKey: "totalTaxCollected")
    }

    // MARK: - Konveniensåtkomst

    var rank1: BoardMember? { members.first(where: { $0.role == .rank1 }) }
    var rank2: BoardMember? { members.first(where: { $0.role == .rank2 }) }
    var rank3: BoardMember? { members.first(where: { $0.role == .rank3 }) }
}

// MARK: - Styrelsevy

struct BoardWidget: View {
    @ObservedObject private var board = BoardManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("STYRELSEN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                    .tracking(3)
                Spacer()
                Text("MAKT KONTROLLERAR DIG")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().background(Color(red: 0.2, green: 0.2, blue: 0.25))

            // Medlemmar
            ForEach(board.members) { member in
                boardRow(member)
                if member.id != board.members.last?.id {
                    Divider().background(Color(red: 0.12, green: 0.12, blue: 0.16))
                }
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.2, green: 0.2, blue: 0.28), lineWidth: 1))
    }

    private func boardRow(_ member: BoardMember) -> some View {
        HStack(spacing: 10) {
            // Rank badge
            Text("R\(member.role == .rank1 ? "1" : member.role == .rank2 ? "2" : "3")")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(member.color)
                .frame(width: 22)

            // Ikon
            Image(systemName: member.role.icon)
                .font(.system(size: 12))
                .foregroundColor(member.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(member.isNPC ? .white : Color(red: 0.3, green: 0.9, blue: 0.4))
                    .lineLimit(1)
                Text(member.role.subtitle)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatBalance(member.balance))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if member.weeklyIncome > 0 {
                    Text("+\(TimeEngine.shortFormatted(member.weeklyIncome))/v")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(member.color)
                }
            }

            // Sparkline
            if member.balanceHistory.count > 1 {
                SparklineView(data: member.balanceHistory, color: member.color)
                    .frame(width: 36, height: 20)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func formatBalance(_ s: TimeInterval) -> String {
        let total   = Int(max(0, s))
        let years   = total / (365 * 86400)
        let rem1    = total % (365 * 86400)
        let days    = rem1 / 86400
        let rem2    = rem1 % 86400
        let hours   = rem2 / 3600
        let minutes = (rem2 % 3600) / 60
        let secs    = rem2 % 60
        return String(format: "%02d:%03d:%02d:%02d:%02d", years, days, hours, minutes, secs)
    }
}

// MARK: - Sparkline

struct SparklineView: View {
    let data: [TimeInterval]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let minV = data.min() ?? 0
            let maxV = data.max() ?? 1
            let range = maxV - minV == 0 ? 1 : maxV - minV
            let pts = data.enumerated().map { (i, v) -> CGPoint in
                let x = geo.size.width * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                let y = geo.size.height * (1 - CGFloat((v - minV) / range))
                return CGPoint(x: x, y: y)
            }
            Path { path in
                guard let first = pts.first else { return }
                path.move(to: first)
                for pt in pts.dropFirst() { path.addLine(to: pt) }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}

// MARK: - Dedikerad Styrelsevy (full skärm)

struct BoardDetailView: View {
    @ObservedObject private var board = BoardManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("STYRELSEN")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("De tre mäktigaste")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    }
                    .padding(.top, 60)

                    // Explanation card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.0))
                                .font(.system(size: 14))
                            Text("HUR FUNGERAR DET?")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.0))
                                .tracking(2)
                        }
                        Text("Tre mäktiga figurer kontrollerar Lifetokens ekonomi. De lever på din tid — och alla andras. Klättra förbi dem i balans och ta deras plats, deras titel och deras intäktsströmmar.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(red: 0.65, green: 0.65, blue: 0.7))
                            .lineSpacing(4)

                        Divider().background(Color(red: 0.25, green: 0.25, blue: 0.3))

                        VStack(alignment: .leading, spacing: 6) {
                            bonusRow(rank: "RANG 1", icon: "dollarsign.circle.fill", color: Color(red: 0.9, green: 0.3, blue: 0.1), text: "Uppbär en del av alla skatteintäkter. Ju mer skatten flödar, desto mer tjänar han.")
                            bonusRow(rank: "RANG 2", icon: "clock.fill", color: Color(red: 0.8, green: 0.6, blue: 0.1), text: "Snor 3–12% av din balans varje vecka som en tyst avgift. Du märker det knappt tills det är för sent.")
                            bonusRow(rank: "RANG 3", icon: "printer.fill", color: Color(red: 0.5, green: 0.3, blue: 0.9), text: "Utlöser inflationsspiken varje vecka. Din sparade tid tappar köpkraft — hans balans ökar.")
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.06, green: 0.05, blue: 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.2), lineWidth: 1))

                    // Totalt stulet
                    statCard(
                        title: "TOTALT STULET",
                        value: TimeEngine.shortFormatted(board.totalTaxCollected),
                        subtitle: "Från alla spelare kombinerat",
                        color: Color(red: 0.9, green: 0.2, blue: 0.2)
                    )

                    // Varje NPC-rad
                    ForEach(board.members) { member in
                        memberCard(member)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 16)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Stäng") { dismiss() }
                    .foregroundColor(.white)
                    .font(.system(size: 13, design: .monospaced))
            }
        }
    }

    private func memberCard(_ member: BoardMember) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(member.color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.displayName)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(member.isNPC ? .white : Color(red: 0.3, green: 0.9, blue: 0.4))
                    Text(member.role.subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(formatYears(member.balance))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Intjänat: \(TimeEngine.shortFormatted(member.weeklyIncome))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(member.color)
                }
            }

            Text(member.role.description)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                .lineSpacing(3)

            if member.balanceHistory.count > 1 {
                SparklineView(data: member.balanceHistory, color: member.color)
                    .frame(height: 30)
            }
        }
        .padding(16)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(member.color.opacity(0.2), lineWidth: 1))
    }

    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                .tracking(2)
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(subtitle)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private func formatYears(_ s: TimeInterval) -> String {
        let total   = Int(max(0, s))
        let years   = total / (365 * 86400)
        let rem1    = total % (365 * 86400)
        let days    = rem1 / 86400
        let rem2    = rem1 % 86400
        let hours   = rem2 / 3600
        let minutes = (rem2 % 3600) / 60
        let secs    = rem2 % 60
        return String(format: "%02d:%03d:%02d:%02d:%02d", years, days, hours, minutes, secs)
    }

    private func bonusRow(rank: String, icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(rank)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .tracking(1)
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
                    .lineSpacing(2)
            }
        }
    }
}
