import SwiftUI
import Foundation

// MARK: - PlayerLoan

struct PlayerLoan: Codable {
    let id: UUID
    let principal: TimeInterval
    let dailyRate: Double
    let startDate: Date
    let dueDays: Int

    var daysElapsed: Double { Date().timeIntervalSince(startDate) / 86400 }
    var interest: TimeInterval { principal * dailyRate * daysElapsed }
    var totalDue: TimeInterval { principal + interest }
    var isPastDue: Bool { daysElapsed > Double(dueDays) }
}

// MARK: - BankManager

class BankManager: ObservableObject {
    static let shared = BankManager()

    @Published var activeLoan: PlayerLoan? = nil
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    static func maxLoan(for zone: ZoneProfile) -> TimeInterval {
        switch zone.index {
        case 0...3: return 43200
        case 4...7: return 86400
        case 8...11: return 259200
        default: return 604800
        }
    }

    static func dailyRate(for zone: ZoneProfile) -> Double {
        switch zone.index {
        case 0...3: return 0.25 / 30
        case 4...7: return 0.18 / 30
        case 8...11: return 0.12 / 30
        default: return 0.08 / 30
        }
    }

    func takeLoan(amount: TimeInterval) -> Bool {
        guard activeLoan == nil else {
            alertMessage = "Du har redan ett aktivt lån."
            showAlert = true
            return false
        }
        let zone = GameState.shared.currentZone
        guard amount <= BankManager.maxLoan(for: zone) else {
            alertMessage = "Lånebelopp överstiger maxgränsen för din zon."
            showAlert = true
            return false
        }
        TimeEngine.shared.addTime(amount)
        activeLoan = PlayerLoan(
            id: UUID(),
            principal: amount,
            dailyRate: BankManager.dailyRate(for: zone),
            startDate: Date(),
            dueDays: 30
        )
        save()
        return true
    }

    func repayLoan() {
        guard let loan = activeLoan else { return }
        let total = loan.totalDue
        guard TimeEngine.shared.deductTime(total) else {
            alertMessage = "Otillräcklig tid för att betala tillbaka lånet. Du behöver \(TimeEngine.shortFormatted(total))."
            showAlert = true
            return
        }
        activeLoan = nil
        save()
    }

    private let loanKey = "player_loan"

    init() {
        if let d = UserDefaults.standard.data(forKey: loanKey),
           let l = try? JSONDecoder().decode(PlayerLoan.self, from: d) {
            activeLoan = l
        }
    }

    private func save() {
        if let l = activeLoan, let d = try? JSONEncoder().encode(l) {
            UserDefaults.standard.set(d, forKey: loanKey)
        } else {
            UserDefaults.standard.removeObject(forKey: loanKey)
        }
    }
}

// MARK: - BankView

struct BankView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var bankManager = BankManager.shared
    @ObservedObject private var investMgr = InvestmentManager.shared
    @ObservedObject private var social    = SocialManager.shared

    @State private var selectedTab: BankTab = .tidskonto
    @State private var loanAmount:   TimeInterval = 3600
    @State private var investAmount: TimeInterval = 3600
    @State private var maturityDays: Int = 7
    @State private var showLoanConfirm    = false
    @State private var showInvestConfirm  = false
    @State private var transactionHistory: [(label: String, amount: TimeInterval, date: Date)] = []

    enum BankTab: String, CaseIterable {
        case tidslaan    = "Tidslån"
        case tidskonto   = "Tidskonto"
        case npcUtlaning = "NPC-utlåning"
        case historik    = "Historik"
    }

    // Safe upper bound for invest slider — always a multiple of 3600 and at least 7200
    // (range needs width ≥ step to avoid "max stride must be positive" fatal error)
    private var investUpperBound: TimeInterval {
        let raw = min(engine.balance * 0.8, TimeInterval(86400 * 365))
        let floored = (raw / 3600).rounded(.down) * 3600   // snap to step grid
        return max(7200.0, floored)                         // at minimum 2 steps
    }
    private var investAmountClamped: TimeInterval {
        min(investAmount, investUpperBound)
    }

    var body: some View {
        ZStack {
            // Rich dark gradient
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.09),
                    Color(red: 0.01, green: 0.02, blue: 0.04),
                    Color.black
                ],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Subtle grid lines
            Canvas { ctx, size in
                for y in stride(from: 0.0, to: size.height, by: 48) {
                    var p = Path(); p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y))
                    ctx.stroke(p, with: .color(Color.blue.opacity(0.03)), lineWidth: 1)
                }
            }.ignoresSafeArea()

            VStack(spacing: 0) {
                bankHeader
                tabBar
                    .padding(.bottom, 6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case .tidslaan:    tidslaanSection
                        case .tidskonto:   tidskontoSection
                        case .npcUtlaning: npcUtlaningSection
                        case .historik:    historikSection
                        }
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .alert("Tidbanken", isPresented: $bankManager.showAlert) {
            Button("OK") {}
        } message: { Text(bankManager.alertMessage) }
        .alert("Bekräfta Lån", isPresented: $showLoanConfirm) {
            Button("Ta Lån") { _ = bankManager.takeLoan(amount: loanAmount) }
            Button("Avbryt", role: .cancel) {}
        } message: {
            let zone = gameState.currentZone
            let rate = BankManager.dailyRate(for: zone) * 100
            Text("Låna \(TimeEngine.shortFormatted(loanAmount))?\nDaglig ränta: \(String(format: "%.2f", rate))%\nFörfaller om 30 dagar.")
        }
        .alert("Bekräfta Investering", isPresented: $showInvestConfirm) {
            Button("Investera") {
                _ = investMgr.invest(amount: investAmountClamped, maturityDays: maturityDays, zone: gameState.currentZone)
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Investera \(TimeEngine.shortFormatted(investAmountClamped)) i \(maturityDays) dagar?\nPengarna låses under löptiden.")
        }
        .alert("Marknadskrasch!", isPresented: $investMgr.showCrashAlert) {
            Button("OK") {}
        } message: { Text(investMgr.crashMessage) }
        .alert("Transaktion", isPresented: $social.showAlert) {
            Button("OK") {}
        } message: { Text(social.alertMessage) }
        .onChange(of: engine.balance) { _, _ in
            // Clamp invest slider value when balance drops
            if investAmount > investUpperBound {
                investAmount = max(3600, (investUpperBound / 3600).rounded(.down) * 3600)
            }
        }
    }

    // MARK: - Header

    private var bankHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(9)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("TIDBANKEN")
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(3)
                    Text(gameState.currentZone.name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(gameState.currentZone.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeEngine.shortFormatted(engine.balance))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text("saldo")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 58)
            .padding(.bottom, 14)

            Divider().background(Color.white.opacity(0.06))
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(BankTab.allCases, id: \.self) { tab in
                    Button { withAnimation(.spring(response: 0.3)) { selectedTab = tab } } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(selectedTab == tab ? .black : .white.opacity(0.6))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedTab == tab
                                ? tabColor(tab)
                                : Color.white.opacity(0.07))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(tabColor(tab).opacity(selectedTab == tab ? 0 : 0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func tabColor(_ tab: BankTab) -> Color {
        switch tab {
        case .tidslaan:    return .cyan
        case .tidskonto:   return .green
        case .npcUtlaning: return .orange
        case .historik:    return .purple
        }
    }

    // MARK: - Tidslån Section

    private var tidslaanSection: some View {
        VStack(spacing: 14) {
            let zone    = gameState.currentZone
            let maxLoan = BankManager.maxLoan(for: zone)
            let rate    = BankManager.dailyRate(for: zone) * 100

            // Loan terms card
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 14))
                    Text("LÅNEVILLKOR")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                    Spacer()
                    Text("30 DAGAR")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color.cyan.opacity(0.7))
                }
                .padding(14)

                Divider().background(Color.cyan.opacity(0.1))

                VStack(spacing: 8) {
                    bankRow("Maxbelopp", TimeEngine.shortFormatted(maxLoan), .yellow)
                    bankRow("Daglig ränta", String(format: "%.2f%%", rate), .orange)
                    bankRow("Din zon", "\(zone.name) (niv. \(zone.index))", zone.color)
                }
                .padding(14)
            }
            .background(
                LinearGradient(colors: [Color.cyan.opacity(0.07), Color.clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.2), lineWidth: 1))

            // Active loan or new loan form
            if let loan = bankManager.activeLoan {
                activeLoanCard(loan: loan)
            } else {
                newLoanForm(maxLoan: maxLoan, rate: rate)
            }
        }
    }

    private func activeLoanCard(loan: PlayerLoan) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(loan.isPastDue ? Color.red : Color.yellow)
                        .frame(width: 6, height: 6)
                    Text(loan.isPastDue ? "FÖRFALLET LÅN" : "AKTIVT LÅN")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(loan.isPastDue ? .red : .yellow)
                        .tracking(2)
                }
                Spacer()
                Text("\(max(0, loan.dueDays - Int(loan.daysElapsed)))d kvar")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(14)

            Divider().background(Color.yellow.opacity(0.1))

            VStack(spacing: 8) {
                bankRow("Lånebelopp",       TimeEngine.shortFormatted(loan.principal), .white)
                bankRow("Upplupen ränta",   TimeEngine.shortFormatted(loan.interest), .orange)
                bankRow("Totalt att betala",TimeEngine.shortFormatted(loan.totalDue), .red)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)

            Button {
                bankManager.repayLoan()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                    Text("BETALA TILLBAKA — \(TimeEngine.shortFormatted(loan.totalDue))")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(engine.balance >= loan.totalDue ? Color.green : Color.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(engine.balance < loan.totalDue)
            .padding(14)
        }
        .background(
            LinearGradient(colors: [Color.yellow.opacity(0.08), Color.clear],
                           startPoint: .top, endPoint: .bottom)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
    }

    private func newLoanForm(maxLoan: TimeInterval, rate: Double) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 13))
                Text("NY ANSÖKAN")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(2)
                Spacer()
            }
            .padding(14)

            Divider().background(Color.white.opacity(0.06))

            VStack(spacing: 12) {
                HStack {
                    Text("Belopp")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(TimeEngine.shortFormatted(loanAmount))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                Slider(value: $loanAmount, in: 3600...Swift.max(3601, maxLoan), step: 3600)
                    .tint(.cyan)

                bankRow(
                    "Total kostnad (30d)",
                    TimeEngine.shortFormatted(loanAmount * (1 + rate / 100 * 30)),
                    .orange
                )

                Button { showLoanConfirm = true } label: {
                    Text("ANSÖK OM LÅN")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(14)
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    // MARK: - Tidskonto Section

    private var tidskontoSection: some View {
        VStack(spacing: 14) {
            let rate = InvestmentManager.dailyRate(for: gameState.currentZone)

            // Rate banner
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAGLIG RÄNTA")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                    Text(String(format: "%.2f%%", rate * 100))
                        .font(.system(size: 34, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                    Text("Marknaden kan krascha (5% risk/vecka)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.red.opacity(0.7))
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 22))
                        .foregroundColor(.green)
                }
            }
            .padding(16)
            .background(
                LinearGradient(colors: [Color.green.opacity(0.1), Color.clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.25), lineWidth: 1))

            // New investment form
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 13))
                    Text("NY INVESTERING")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)
                    Spacer()
                    Text("LÖPTID")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.06))

                VStack(spacing: 14) {
                    // Amount slider — clamped binding prevents crash
                    VStack(spacing: 6) {
                        HStack {
                            Text("Belopp")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text(TimeEngine.shortFormatted(investAmountClamped))
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                        Slider(
                            value: Binding(
                                get: { investAmountClamped },
                                set: { investAmount = $0 }
                            ),
                            in: 3600...investUpperBound,
                            step: 3600
                        )
                        .tint(.green)
                    }

                    // Duration picker
                    HStack(spacing: 6) {
                        ForEach([1, 7, 14, 30, 90], id: \.self) { days in
                            Button { maturityDays = days } label: {
                                Text("\(days)d")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(maturityDays == days ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(maturityDays == days ? Color.green : Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                        }
                    }

                    let projected = investAmountClamped * pow(1 + rate, Double(maturityDays))
                    bankRow("Prognos efter \(maturityDays)d", TimeEngine.shortFormatted(projected), .green)
                    bankRow("Vinst", "+" + TimeEngine.shortFormatted(projected - investAmountClamped), .cyan)

                    Button { showInvestConfirm = true } label: {
                        Text("INVESTERA \(TimeEngine.shortFormatted(investAmountClamped))")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(investAmountClamped <= engine.balance ? Color.green : Color.gray.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(investAmountClamped > engine.balance)
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))

            // Active investments
            if !investMgr.investments.isEmpty {
                VStack(spacing: 8) {
                    HStack {
                        Text("AKTIVA INVESTERINGAR")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                            .tracking(2)
                        Spacer()
                        Text("\(investMgr.investments.count) aktiva")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))
                    }

                    ForEach(investMgr.investments) { inv in
                        InvestmentCard(investment: inv) {
                            investMgr.withdraw(inv)
                        }
                    }
                }
            }
        }
    }

    // MARK: - NPC-utlåning Section

    private var npcUtlaningSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 13))
                Text("Lån till NPC:er ger ränteintäkter. Risk: NPC betalar inte tillbaka.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(12)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.2), lineWidth: 1))

            if !social.activeLoans.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DINA AKTIVA LÅN")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .tracking(2)

                    ForEach(social.activeLoans.filter { $0.lentToNPC }) { loan in
                        let npc = NPCPlayer.all.first(where: { $0.name == loan.npcName })
                        LoanCard(loan: loan) {
                            if let n = npc { social.collectFromNPC(loan, npc: n) }
                        }
                    }
                }
            }

            Text("TILLGÄNGLIGA NPC:ER")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            let zoneNPCs = NPCPlayer.all.filter { $0.zone == gameState.currentZone.name }
            if zoneNPCs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.slash.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.2))
                    Text("Inga NPC:er i \(gameState.currentZone.name)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(zoneNPCs) { npc in
                    npcLendCard(npc: npc)
                }
            }
        }
    }

    private func npcLendCard(npc: NPCPlayer) -> some View {
        HStack(spacing: 12) {
            Text(npc.avatar)
                .font(.system(size: 28))
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.05))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(npc.name)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f%%/mån", npc.loanInterestRate * 100))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                Text(npc.bio)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Circle().fill(npc.reliability > 0.8 ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(String(format: "Pålitlighet: %.0f%%", npc.reliability * 100))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(npc.reliability > 0.8 ? .green : .orange)
                }
            }

            Button("LÅN") {
                _ = social.lendToNPC(npc, amount: 3600, days: 7)
            }
            .font(.system(size: 11, weight: .black, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Historik Section

    private var historikSection: some View {
        VStack(spacing: 8) {
            if transactionHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.15))
                    Text("Ingen transaktionshistorik ännu.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(transactionHistory.indices, id: \.self) { i in
                    let tx = transactionHistory[i]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.label)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white)
                            Text(tx.date.formatted(.dateTime.day().month().hour().minute()))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                        Text(tx.amount >= 0 ? "+\(TimeEngine.shortFormatted(tx.amount))" : "−\(TimeEngine.shortFormatted(abs(tx.amount)))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(tx.amount >= 0 ? .green : .red)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: Helper

    private func bankRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

#Preview {
    BankView()
        .preferredColorScheme(.dark)
}
