import SwiftUI
import Foundation

// MARK: - Transaction Ledger (persistent transaktionshistorik)

struct BankTransaction: Codable, Identifiable {
    let id: String
    let label: String
    let amount: TimeInterval
    let date: Date

    init(label: String, amount: TimeInterval) {
        self.id = UUID().uuidString
        self.label = label
        self.amount = amount
        self.date = Date()
    }
}

class TransactionLedger {
    static let shared = TransactionLedger()
    private let storageKey = "bankTransactions"

    private(set) var transactions: [BankTransaction] = []

    private init() { load() }

    func record(label: String, amount: TimeInterval) {
        let tx = BankTransaction(label: label, amount: amount)
        transactions.insert(tx, at: 0)
        if transactions.count > 100 { transactions = Array(transactions.prefix(100)) }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BankTransaction].self, from: data) else { return }
        transactions = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

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

@MainActor
class BankManager: ObservableObject {
    static let shared = BankManager()

    @Published var activeLoan: PlayerLoan? = nil
    @Published var savingsBalance: TimeInterval = 0
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

    private let savingsKey = "player_savings_balance_v1"
    private let savingsDateKey = "player_savings_interest_date_v1"
    private let savingsDailyRate: Double = 0.004

    func effectiveLoanRate(for zone: ZoneProfile) -> Double {
        let repFactor = ZoneReputationManager.shared.priceMultiplier(for: zone.name)
        let ruleFactor = GovernanceManager.shared.loanRateMultiplier()
        return BankManager.dailyRate(for: zone) * repFactor * ruleFactor
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
            dailyRate: effectiveLoanRate(for: zone),
            startDate: Date(),
            dueDays: 30
        )
        save()
        TransactionLedger.shared.record(label: "Tidslån beviljat", amount: amount)
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
        TransactionLedger.shared.record(label: "Lån återbetalt (inkl. ränta)", amount: -total)
        ZoneReputationManager.shared.adjustForLoanRepayment(onTime: !loan.isPastDue)
        activeLoan = nil
        save()
    }

    // MARK: - Privatlån: godkännandelogik

    /// Kontrollerar om ansökan kan beviljas baserat på hälsoinkomst och pålitlighetsroll.
    func canApplyForLoan(
        amount: TimeInterval,
        reliability: Double,
        maxMultiplier: Double
    ) -> (approved: Bool, reason: String) {
        let dailyIncome = IncomeManager.shared.projectedDailyIncome
        let maxAmount = dailyIncome * maxMultiplier
        guard amount <= maxAmount else {
            return (false, "Du har inte tjänat tillräckligt för att låna så mycket.")
        }
        let roll = Double.random(in: 0...1)
        if roll > reliability {
            return (false, "Avslaget.")
        }
        return (true, "Godkänt.")
    }

    /// Beviljar ett privatlån med angiven ränta (daglig) om spelaren inte redan har ett lån.
    func takePrivateLoan(amount: TimeInterval, dailyRate: Double, lenderName: String) -> Bool {
        guard activeLoan == nil else {
            alertMessage = "Du har redan ett aktivt lån."
            showAlert = true
            return false
        }
        TimeEngine.shared.addTime(amount)
        let repFactor = ZoneReputationManager.shared.priceMultiplier(for: GameState.shared.currentZone.name)
        let ruleFactor = GovernanceManager.shared.loanRateMultiplier()
        activeLoan = PlayerLoan(
            id: UUID(),
            principal: amount,
            dailyRate: dailyRate * repFactor * ruleFactor,
            startDate: Date(),
            dueDays: 30
        )
        save()
        TransactionLedger.shared.record(label: "Privatlån från \(lenderName)", amount: amount)
        return true
    }

    private let loanKey = "player_loan"

    init() {
        if let d = UserDefaults.standard.data(forKey: loanKey),
           let l = try? JSONDecoder().decode(PlayerLoan.self, from: d) {
            activeLoan = l
        }
        savingsBalance = UserDefaults.standard.double(forKey: savingsKey)
        applySavingsInterestIfNeeded()
    }

    func depositToSavings(_ amount: TimeInterval) -> Bool {
        guard amount > 0 else { return false }
        applySavingsInterestIfNeeded()
        guard TimeEngine.shared.deductTime(amount) else {
            alertMessage = "Otillräcklig tid för insättning."
            showAlert = true
            return false
        }
        savingsBalance += amount
        saveSavings()
        TransactionLedger.shared.record(label: "Bankkonto — insättning", amount: -amount)
        return true
    }

    func withdrawFromSavings(_ amount: TimeInterval) -> Bool {
        guard amount > 0 else { return false }
        applySavingsInterestIfNeeded()
        guard savingsBalance >= amount else {
            alertMessage = "Du har inte tillräckligt på bankkontot."
            showAlert = true
            return false
        }
        savingsBalance -= amount
        TimeEngine.shared.addTime(amount)
        saveSavings()
        TransactionLedger.shared.record(label: "Bankkonto — uttag", amount: amount)
        return true
    }

    private func applySavingsInterestIfNeeded() {
        let now = Date()
        let last = UserDefaults.standard.object(forKey: savingsDateKey) as? Date ?? now
        let elapsedDays = max(0, now.timeIntervalSince(last) / 86400)
        guard savingsBalance > 0, elapsedDays > 0 else {
            UserDefaults.standard.set(now, forKey: savingsDateKey)
            return
        }
        let growth = savingsBalance * (pow(1 + savingsDailyRate, elapsedDays) - 1)
        if growth > 0 {
            savingsBalance += growth
            TransactionLedger.shared.record(label: "Bankkonto — ränta", amount: growth)
        }
        UserDefaults.standard.set(now, forKey: savingsDateKey)
        saveSavings()
    }

    private func save() {
        if let l = activeLoan, let d = try? JSONEncoder().encode(l) {
            UserDefaults.standard.set(d, forKey: loanKey)
        } else {
            UserDefaults.standard.removeObject(forKey: loanKey)
        }
        saveSavings()
    }

    private func saveSavings() {
        UserDefaults.standard.set(savingsBalance, forKey: savingsKey)
        UserDefaults.standard.set(Date(), forKey: savingsDateKey)
    }
}

// MARK: - Privatlångivare

struct PrivateLender: Identifiable {
    let id: UUID
    let name: String
    let tagline: String
    let reliability: Double         // 0–1
    let dailyRate: Double           // t.ex. 0.08 = 8%/dag
    let maxMultiplier: Double       // max = dagsinkomst * multiplier
    let accentColor: Color
    let icon: String

    var maxLoanAmount: TimeInterval {
        IncomeManager.shared.projectedDailyIncome * maxMultiplier
    }
}

extension PrivateLender {
    // Tre fasta långivare tillgängliga i alla zoner
    static let all: [PrivateLender] = [
        PrivateLender(
            id: UUID(),
            name: "Sebastian R.",
            tagline: "Rik kille. Hög ränta, hög garanti.",
            reliability: 0.95,
            dailyRate: 0.08,
            maxMultiplier: 30,
            accentColor: Color(red: 1.0, green: 0.82, blue: 0.18),
            icon: "crown.fill"
        ),
        PrivateLender(
            id: UUID(),
            name: "Marcus T.",
            tagline: "Vanlig kille. Normala villkor.",
            reliability: 0.65,
            dailyRate: 0.05,
            maxMultiplier: 15,
            accentColor: Color(red: 0.25, green: 0.55, blue: 1.0),
            icon: "person.fill"
        ),
        PrivateLender(
            id: UUID(),
            name: "K-G",
            tagline: "Skum typ. Ingen ränta. Stor risk.",
            reliability: 0.15,
            dailyRate: 0.02,
            maxMultiplier: 5,
            accentColor: Color(red: 0.68, green: 0.22, blue: 0.95),
            icon: "eye.slash.fill"
        )
    ]
}

// MARK: - BankView

struct BankView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine      = TimeEngine.shared
    @ObservedObject private var gameState   = GameState.shared
    @ObservedObject private var bankManager = BankManager.shared
    @ObservedObject private var investMgr   = InvestmentManager.shared
    @ObservedObject private var social      = SocialManager.shared
    @ObservedObject private var incomeMgr   = IncomeManager.shared

    @State private var selectedTab: BankTab = .tidskonto
    @State private var loanAmount:   TimeInterval = 3600
    @State private var investAmount: TimeInterval = 3600
    @State private var maturityDays: Int = 7
    @State private var showLoanConfirm       = false
    @State private var showInvestConfirm     = false
    @State private var transactionHistory: [BankTransaction] = []

    // Privatlån-state
    @State private var selectedLender: PrivateLender? = nil
    @State private var privateLoanAmount: TimeInterval = 3600
    @State private var showPrivateLoanSheet  = false
    @State private var privateLoanResult     = ""
    @State private var showPrivateLoanResult = false

    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotif  = UINotificationFeedbackGenerator()

    enum BankTab: String, CaseIterable {
        case tidslaan    = "Tidslån"
        case tidskonto   = "Tidskonto"
        case privatlan   = "Privatlån"
        case historik    = "Historik"
    }

    private var investUpperBound: TimeInterval {
        let raw = min(engine.balance * 0.8, TimeInterval(86400 * 365))
        let floored = (raw / 3600).rounded(.down) * 3600
        return max(7200.0, floored)
    }
    private var investAmountClamped: TimeInterval {
        min(investAmount, investUpperBound)
    }

    var body: some View {
        ZStack {
            // Premiumdark bakgrund
            Color(red: 0.04, green: 0.04, blue: 0.08).ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.12),
                    Color(red: 0.02, green: 0.02, blue: 0.06),
                    Color.black
                ],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Rutnätsöverlagring
            Canvas { ctx, size in
                for y in stride(from: 0.0, to: size.height, by: 48) {
                    var p = Path()
                    p.move(to: .init(x: 0, y: y))
                    p.addLine(to: .init(x: size.width, y: y))
                    ctx.stroke(p, with: .color(Color.blue.opacity(0.03)), lineWidth: 1)
                }
            }.ignoresSafeArea()

            VStack(spacing: 0) {
                bankHeader
                tabBar
                    .padding(.bottom, LTSpacing.xs + 2)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: LTSpacing.lg) {
                        switch selectedTab {
                        case .tidslaan:    tidslaanSection
                        case .tidskonto:   tidskontoSection
                        case .privatlan:   privatlanSection
                        case .historik:    historikSection
                        }
                        Spacer(minLength: LTSpacing.scrollBottom)
                    }
                    .padding(.horizontal, LTSpacing.horizontal)
                }
            }
        }
        .alert("Tidsbanken", isPresented: $bankManager.showAlert) {
            Button("OK") {}
        } message: { Text(bankManager.alertMessage) }
        .alert("Bekräfta Lån", isPresented: $showLoanConfirm) {
            Button("Ta Lån") {
                hapticNotif.notificationOccurred(.success)
                _ = bankManager.takeLoan(amount: loanAmount)
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            let zone = gameState.currentZone
            let rate = bankManager.effectiveLoanRate(for: zone) * 100
            Text("Låna \(TimeEngine.shortFormatted(loanAmount))?\nDaglig ränta: \(String(format: "%.2f", rate))%\nFörfaller om 30 dagar.")
        }
        .alert("Bekräfta Investering", isPresented: $showInvestConfirm) {
            Button("Investera") {
                hapticNotif.notificationOccurred(.success)
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
        .alert("Privatlåneansökan", isPresented: $showPrivateLoanResult) {
            Button("OK") {}
        } message: { Text(privateLoanResult) }
        .sheet(isPresented: $showPrivateLoanSheet) {
            if let lender = selectedLender {
                privateLoanSheet(lender: lender)
            }
        }
        .onChange(of: engine.balance) { _, _ in
            if investAmount > investUpperBound {
                investAmount = max(3600, (investUpperBound / 3600).rounded(.down) * 3600)
            }
        }
        .onAppear {
            transactionHistory = TransactionLedger.shared.transactions
        }
        .onChange(of: selectedTab) { _, tab in
            hapticLight.impactOccurred()
            if tab == .historik {
                transactionHistory = TransactionLedger.shared.transactions
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
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Stäng banken")

                Spacer()
                VStack(spacing: 2) {
                    Text("TIDSBANKEN")
                        .font(LTFont.heading(17))
                        .foregroundColor(.white)
                        .tracking(3)
                    Text(gameState.currentZone.name)
                        .font(LTFont.body(10))
                        .foregroundColor(gameState.currentZone.color)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeEngine.shortFormatted(engine.balance))
                        .font(LTFont.heading(13))
                        .foregroundColor(.yellow)
                        .contentTransition(.numericText())
                        .animation(LTAnimation.springFast, value: engine.balance)
                    Text("saldo")
                        .font(LTFont.body(9))
                        .foregroundColor(.white.opacity(0.3))
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Saldo: \(TimeEngine.shortFormatted(engine.balance))")
            }
            .padding(.horizontal, LTSpacing.horizontal)
            .padding(.top, 58)
            .padding(.bottom, LTSpacing.md)

            Divider().background(Color.white.opacity(0.06))
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LTSpacing.xs + 2) {
                ForEach(BankTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(LTAnimation.springFast) { selectedTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(LTFont.label(11))
                            .foregroundColor(selectedTab == tab ? .black : .white.opacity(0.6))
                            .padding(.horizontal, LTSpacing.md)
                            .padding(.vertical, 7)
                            .background(selectedTab == tab
                                ? tabColor(tab)
                                : Color.white.opacity(0.07))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(tabColor(tab).opacity(selectedTab == tab ? 0 : 0.3), lineWidth: 1))
                    }
                    .buttonStyle(LTPressEffect())
                    .accessibilityLabel(tab.rawValue)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, LTSpacing.horizontal)
            .padding(.vertical, LTSpacing.sm)
        }
    }

    private func tabColor(_ tab: BankTab) -> Color {
        switch tab {
        case .tidslaan:    return .cyan
        case .tidskonto:   return .green
        case .privatlan:   return Color(red: 1.0, green: 0.82, blue: 0.18)
        case .historik:    return .purple
        }
    }

    // MARK: - Tidslån Section

    private var tidslaanSection: some View {
        VStack(spacing: LTSpacing.md) {
            let zone    = gameState.currentZone
            let maxLoan = BankManager.maxLoan(for: zone)
            let rate    = bankManager.effectiveLoanRate(for: zone) * 100

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundColor(.cyan)
                        .font(.system(size: 14))
                    Text("LÅNEVILLKOR")
                        .font(LTFont.heading(11))
                        .foregroundColor(.white)
                        .tracking(2)
                    Spacer()
                    Text("30 DAGAR")
                        .font(LTFont.body(9))
                        .foregroundColor(Color.cyan.opacity(0.7))
                }
                .padding(LTSpacing.md)

                Divider().background(Color.cyan.opacity(0.1))

                VStack(spacing: LTSpacing.sm) {
                    bankRow("Maxbelopp", TimeEngine.shortFormatted(maxLoan), .yellow)
                    bankRow("Daglig ränta", String(format: "%.2f%%", rate), .orange)
                    bankRow("Din zon", "\(zone.name) (niv. \(zone.index))", zone.color)
                }
                .padding(LTSpacing.md)
            }
            .ltAccentCard(color: .cyan)

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
                HStack(spacing: LTSpacing.xs + 2) {
                    Circle().fill(loan.isPastDue ? Color.red : Color.yellow)
                        .frame(width: 6, height: 6)
                    Text(loan.isPastDue ? "FÖRFALLET LÅN" : "AKTIVT LÅN")
                        .font(LTFont.heading(11))
                        .foregroundColor(loan.isPastDue ? .red : .yellow)
                        .tracking(2)
                }
                Spacer()
                Text("\(max(0, loan.dueDays - Int(loan.daysElapsed)))d kvar")
                    .font(LTFont.body(10))
                    .foregroundColor(.white.opacity(0.4))
                    .contentTransition(.numericText())
            }
            .padding(LTSpacing.md)

            Divider().background(Color.yellow.opacity(0.1))

            VStack(spacing: LTSpacing.sm) {
                bankRow("Lånebelopp",        TimeEngine.shortFormatted(loan.principal), .white)
                bankRow("Upplupen ränta",    TimeEngine.shortFormatted(loan.interest), .orange)
                bankRow("Totalt att betala", TimeEngine.shortFormatted(loan.totalDue), .red)
            }
            .padding(.horizontal, LTSpacing.md)
            .padding(.top, LTSpacing.md)

            Button {
                hapticMedium.impactOccurred()
                bankManager.repayLoan()
            } label: {
                HStack(spacing: LTSpacing.xs + 2) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13))
                    Text("BETALA TILLBAKA — \(TimeEngine.shortFormatted(loan.totalDue))")
                        .font(LTFont.heading(12))
                        .tracking(1)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(engine.balance >= loan.totalDue ? Color.green : Color.gray.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            }
            .disabled(engine.balance < loan.totalDue)
            .buttonStyle(LTPressEffect())
            .padding(LTSpacing.md)
            .accessibilityLabel("Betala tillbaka lånet: \(TimeEngine.shortFormatted(loan.totalDue))")
            .accessibilityHint(engine.balance >= loan.totalDue ? "Tryck för att betala" : "Otillräcklig balans")
        }
        .ltAccentCard(color: .yellow)
    }

    private func newLoanForm(maxLoan: TimeInterval, rate: Double) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.cyan)
                    .font(.system(size: 13))
                Text("NY ANSÖKAN")
                    .font(LTFont.heading(11))
                    .foregroundColor(.white)
                    .tracking(2)
                Spacer()
            }
            .padding(LTSpacing.md)

            Divider().background(Color.white.opacity(0.06))

            VStack(spacing: LTSpacing.md) {
                HStack {
                    Text("Belopp")
                        .font(LTFont.body(11))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(TimeEngine.shortFormatted(loanAmount))
                        .font(LTFont.value(15))
                        .foregroundColor(.cyan)
                        .contentTransition(.numericText())
                        .animation(LTAnimation.springFast, value: loanAmount)
                }

                Slider(value: $loanAmount, in: 3600...Swift.max(3601, maxLoan), step: 3600)
                    .tint(.cyan)
                    .accessibilityLabel("Lånebelopp")
                    .accessibilityValue(TimeEngine.shortFormatted(loanAmount))

                bankRow(
                    "Total kostnad (30d)",
                    TimeEngine.shortFormatted(loanAmount * (1 + rate / 100 * 30)),
                    .orange
                )

                Button {
                    hapticMedium.impactOccurred()
                    showLoanConfirm = true
                } label: {
                    Text("ANSÖK OM LÅN")
                        .font(LTFont.heading(13))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.cyan)
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                }
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Ansök om lån på \(TimeEngine.shortFormatted(loanAmount))")
            }
            .padding(LTSpacing.md)
        }
        .ltCard(radius: LTRadius.md)
    }

    // MARK: - Tidskonto Section

    private var tidskontoSection: some View {
        VStack(spacing: LTSpacing.md) {
            let rate = InvestmentManager.dailyRate(for: gameState.currentZone)

            savingsAccountCard

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: LTSpacing.xs) {
                    Text("DAGLIG RÄNTA")
                        .font(LTFont.label(9))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                    Text(String(format: "%.2f%%", rate * 100))
                        .font(LTFont.value(34))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                    Text("Marknaden kan krascha (5% risk/vecka)")
                        .font(LTFont.body(9))
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
                .accessibilityHidden(true)
            }
            .padding(LTSpacing.lg)
            .ltAccentCard(color: .green)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 13))
                    Text("NY INVESTERING")
                        .font(LTFont.heading(11))
                        .foregroundColor(.white)
                        .tracking(2)
                    Spacer()
                    Text("LÖPTID")
                        .font(LTFont.body(9))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(LTSpacing.md)

                Divider().background(Color.white.opacity(0.06))

                VStack(spacing: LTSpacing.md) {
                    VStack(spacing: LTSpacing.xs + 2) {
                        HStack {
                            Text("Belopp")
                                .font(LTFont.body(11))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text(TimeEngine.shortFormatted(investAmountClamped))
                                .font(LTFont.value(15))
                                .foregroundColor(.yellow)
                                .contentTransition(.numericText())
                                .animation(LTAnimation.springFast, value: investAmountClamped)
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
                        .accessibilityLabel("Investeringsbelopp")
                        .accessibilityValue(TimeEngine.shortFormatted(investAmountClamped))
                    }

                    HStack(spacing: LTSpacing.xs + 2) {
                        ForEach([1, 7, 14, 30, 90], id: \.self) { days in
                            Button {
                                hapticLight.impactOccurred()
                                withAnimation(LTAnimation.springFast) { maturityDays = days }
                            } label: {
                                Text("\(days)d")
                                    .font(LTFont.label(11))
                                    .foregroundColor(maturityDays == days ? .black : .white.opacity(0.7))
                                    .padding(.horizontal, LTSpacing.sm + 2)
                                    .padding(.vertical, LTSpacing.xs + 2)
                                    .background(maturityDays == days ? Color.green : Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(LTPressEffect())
                            .accessibilityLabel("\(days) dagar")
                            .accessibilityAddTraits(maturityDays == days ? .isSelected : [])
                        }
                    }

                    let projected = investAmountClamped * pow(1 + rate, Double(maturityDays))
                    bankRow("Prognos efter \(maturityDays)d", TimeEngine.shortFormatted(projected), .green)
                    bankRow("Vinst", "+" + TimeEngine.shortFormatted(projected - investAmountClamped), .cyan)

                    Button {
                        hapticMedium.impactOccurred()
                        showInvestConfirm = true
                    } label: {
                        Text("INVESTERA \(TimeEngine.shortFormatted(investAmountClamped))")
                            .font(LTFont.heading(13))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(investAmountClamped <= engine.balance ? Color.green : Color.gray.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                    }
                    .disabled(investAmountClamped > engine.balance)
                    .buttonStyle(LTPressEffect())
                    .accessibilityLabel("Investera \(TimeEngine.shortFormatted(investAmountClamped))")
                    .accessibilityHint(investAmountClamped > engine.balance ? "Otillräcklig balans" : "Låser beloppet under \(maturityDays) dagar")
                }
                .padding(LTSpacing.md)
            }
            .ltCard(radius: LTRadius.md)

            if !investMgr.investments.isEmpty {
                VStack(spacing: LTSpacing.sm) {
                    HStack {
                        Text("AKTIVA INVESTERINGAR")
                            .font(LTFont.label(10))
                            .foregroundColor(.white.opacity(0.35))
                            .tracking(2)
                        Spacer()
                        Text("\(investMgr.investments.count) aktiva")
                            .font(LTFont.body(10))
                            .foregroundColor(.green.opacity(0.7))
                    }

                    ForEach(investMgr.investments) { inv in
                        InvestmentCard(investment: inv) {
                            hapticNotif.notificationOccurred(inv.isMatured ? .success : .warning)
                            investMgr.withdraw(inv)
                        }
                    }
                }
            }
        }
    }

    private var savingsAccountCard: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PERSONLIGT KONTO")
                        .font(LTFont.label(9))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                    Text(TimeEngine.shortFormatted(bankManager.savingsBalance))
                        .font(LTFont.value(24))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                }
                Spacer()
                Text("Ränta ~0.40%/dag")
                    .font(LTFont.caption(9))
                    .foregroundColor(.white.opacity(0.5))
            }

            HStack(spacing: 8) {
                Button {
                    let amount = min(engine.balance * 0.25, 7200)
                    _ = bankManager.depositToSavings(max(600, amount))
                } label: {
                    Text("Sätt in")
                        .font(LTFont.body(11))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    let amount = min(bankManager.savingsBalance, 7200)
                    _ = bankManager.withdrawFromSavings(max(600, amount))
                } label: {
                    Text("Ta ut")
                        .font(LTFont.body(11))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .ltAccentCard(color: .green)
    }

    // MARK: - Privatlån Section

    private var privatlanSection: some View {
        VStack(spacing: LTSpacing.md) {
            // Inkomstinfo — visar basen för maxlåneberäkning
            HStack(spacing: LTSpacing.sm) {
                Image(systemName: "heart.fill")
                    .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.35))
                    .font(.system(size: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("HÄLSOINKOMST IDAG")
                        .font(LTFont.label(9))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(2)
                    Text(TimeEngine.shortFormatted(incomeMgr.projectedDailyIncome))
                        .font(LTFont.value(18))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(LTAnimation.springFast, value: incomeMgr.projectedDailyIncome)
                }
                Spacer()
                Text("Max lånebelopp\nbaseras på detta")
                    .font(LTFont.body(9))
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.trailing)
            }
            .padding(LTSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: LTRadius.sm)
                    .fill(Color(red: 0.10, green: 0.06, blue: 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: LTRadius.sm)
                            .stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.25), lineWidth: 1)
                    )
            )

            // Aktivt lån visas längst upp om det finns ett
            if let loan = bankManager.activeLoan {
                activeLoanCard(loan: loan)
            }

            Text("PRIVATLÅNGIVARE")
                .font(LTFont.label(10))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(PrivateLender.all) { lender in
                privatLenderCard(lender: lender)
            }
        }
    }

    private func privatLenderCard(lender: PrivateLender) -> some View {
        let dailyIncome = incomeMgr.projectedDailyIncome
        let maxAmount   = dailyIncome * lender.maxMultiplier
        let reliPct     = Int(lender.reliability * 100)
        let ratePct     = lender.dailyRate * 100

        return VStack(spacing: 0) {
            // Kortets övre del — personinfo och badges
            HStack(spacing: LTSpacing.md) {
                ZStack {
                    Circle()
                        .fill(lender.accentColor.opacity(0.14))
                        .frame(width: 52, height: 52)
                        .blur(radius: 6)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [lender.accentColor.opacity(0.18), Color.black.opacity(0.6)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(Circle().stroke(lender.accentColor.opacity(0.4), lineWidth: 1))
                    Image(systemName: lender.icon)
                        .font(.system(size: 20))
                        .foregroundColor(lender.accentColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lender.name)
                        .font(LTFont.heading(15))
                        .foregroundColor(.white)

                    Text(lender.tagline)
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)

                    // Pålitlighetsbadge
                    HStack(spacing: 5) {
                        Text("PÅLITLIGHET: \(reliPct)%")
                            .font(LTFont.label(9))
                            .foregroundColor(reliabilityColor(lender.reliability))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(reliabilityColor(lender.reliability).opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(reliabilityColor(lender.reliability).opacity(0.35), lineWidth: 1))
                    }
                }

                Spacer()
            }
            .padding(LTSpacing.lg)

            // Låndetaljer
            VStack(spacing: LTSpacing.sm) {
                Divider().background(lender.accentColor.opacity(0.12))

                HStack(spacing: 0) {
                    lenderStatCell(
                        label: "RÄNTA/DAG",
                        value: String(format: "%.0f%%", ratePct),
                        color: lender.accentColor
                    )
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                    lenderStatCell(
                        label: "MAX BELOPP",
                        value: maxAmount > 0 ? TimeEngine.shortFormatted(maxAmount) : "—",
                        color: .white
                    )
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                    lenderStatCell(
                        label: "MULTIPLIKATOR",
                        value: "\(Int(lender.maxMultiplier))x lön",
                        color: .white.opacity(0.6)
                    )
                }
                .padding(.bottom, LTSpacing.sm)
            }

            // Ansökningsknapp
            Button {
                hapticMedium.impactOccurred()
                selectedLender = lender
                privateLoanAmount = min(3600, maxAmount)
                showPrivateLoanSheet = true
            } label: {
                HStack(spacing: LTSpacing.xs + 2) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11))
                    Text(bankManager.activeLoan != nil ? "LÅN AKTIVT" : "ANSÖK OM LÅN")
                        .font(LTFont.heading(12))
                        .tracking(1)
                }
                .foregroundColor(bankManager.activeLoan != nil ? .white.opacity(0.3) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    bankManager.activeLoan != nil
                        ? Color.white.opacity(0.07)
                        : lender.accentColor
                )
            }
            .disabled(bankManager.activeLoan != nil)
            .buttonStyle(LTPressEffect())
            .accessibilityLabel("Ansök om lån från \(lender.name)")
            .accessibilityHint(bankManager.activeLoan != nil ? "Du har redan ett aktivt lån" : "Öppnar låneformulär")
        }
        .background(
            RoundedRectangle(cornerRadius: LTRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            lender.accentColor.opacity(0.06),
                            Color(red: 0.04, green: 0.04, blue: 0.08)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.lg)
                .stroke(
                    LinearGradient(
                        colors: [lender.accentColor.opacity(0.45), lender.accentColor.opacity(0.10)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: lender.accentColor.opacity(0.10), radius: 14, x: 0, y: 6)
    }

    private func lenderStatCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(LTFont.caption(8))
                .foregroundColor(.white.opacity(0.35))
                .tracking(1)
            Text(value)
                .font(LTFont.heading(12))
                .foregroundColor(color)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LTSpacing.sm)
    }

    /// Returnerar färg baserat på pålitlighetsnivå
    private func reliabilityColor(_ reliability: Double) -> Color {
        if reliability >= 0.8 { return Color(red: 0.2, green: 0.85, blue: 0.4) }
        if reliability >= 0.5 { return Color(red: 1.0, green: 0.75, blue: 0.15) }
        return Color(red: 0.9, green: 0.25, blue: 0.25)
    }

    // MARK: - Privatlån Sheet

    private func privateLoanSheet(lender: PrivateLender) -> some View {
        let dailyIncome = incomeMgr.projectedDailyIncome
        let maxAmount   = dailyIncome * lender.maxMultiplier
        let sliderMax   = max(3601, maxAmount)

        return NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.08).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: LTSpacing.lg) {
                        // Säljarinformation
                        HStack(spacing: LTSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(lender.accentColor.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: lender.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(lender.accentColor)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lender.name)
                                    .font(LTFont.heading(18))
                                    .foregroundColor(.white)
                                Text(lender.tagline)
                                    .font(LTFont.body(11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            Spacer()
                        }
                        .padding(LTSpacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: LTRadius.md)
                                .fill(lender.accentColor.opacity(0.07))
                                .overlay(
                                    RoundedRectangle(cornerRadius: LTRadius.md)
                                        .stroke(lender.accentColor.opacity(0.25), lineWidth: 1)
                                )
                        )

                        // Lånebeloppsväljare
                        VStack(spacing: LTSpacing.sm) {
                            HStack {
                                Text("Lånebelopp")
                                    .font(LTFont.body(12))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                                Text(TimeEngine.shortFormatted(privateLoanAmount))
                                    .font(LTFont.value(20))
                                    .foregroundColor(lender.accentColor)
                                    .contentTransition(.numericText())
                                    .animation(LTAnimation.springFast, value: privateLoanAmount)
                            }

                            Slider(
                                value: $privateLoanAmount,
                                in: 3600...sliderMax,
                                step: 3600
                            )
                            .tint(lender.accentColor)
                        }
                        .padding(LTSpacing.lg)
                        .ltCard(radius: LTRadius.md)

                        // Villkorsöversikt
                        VStack(spacing: LTSpacing.sm) {
                            bankRow("Ränta per dag",
                                    String(format: "%.0f%%", lender.dailyRate * 100),
                                    lender.accentColor)
                            bankRow("Total kostnad (30d)",
                                    TimeEngine.shortFormatted(privateLoanAmount * (1 + lender.dailyRate * 30)),
                                    .orange)
                            bankRow("Pålitlighet",
                                    String(format: "%.0f%%", lender.reliability * 100),
                                    reliabilityColor(lender.reliability))
                            bankRow("Max tillåtet",
                                    maxAmount > 0 ? TimeEngine.shortFormatted(maxAmount) : "Inget",
                                    .white.opacity(0.6))
                        }
                        .padding(LTSpacing.lg)
                        .ltCard(radius: LTRadius.md)

                        // Ansökningsknapp
                        Button {
                            hapticNotif.notificationOccurred(.success)
                            let result = bankManager.canApplyForLoan(
                                amount: privateLoanAmount,
                                reliability: lender.reliability,
                                maxMultiplier: lender.maxMultiplier
                            )
                            if result.approved {
                                _ = bankManager.takePrivateLoan(
                                    amount: privateLoanAmount,
                                    dailyRate: lender.dailyRate,
                                    lenderName: lender.name
                                )
                                privateLoanResult = "\(lender.name) godkände din ansökan.\n+\(TimeEngine.shortFormatted(privateLoanAmount)) har krediterats."
                            } else {
                                privateLoanResult = "\(lender.name): \(result.reason)"
                            }
                            showPrivateLoanSheet = false
                            showPrivateLoanResult = true
                        } label: {
                            Text("SKICKA ANSÖKAN")
                                .font(LTFont.heading(14))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(lender.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                        }
                        .buttonStyle(LTPressEffect())
                        .accessibilityLabel("Skicka låneansökan till \(lender.name)")
                    }
                    .padding(.horizontal, LTSpacing.horizontal)
                    .padding(.top, LTSpacing.lg)
                    .padding(.bottom, LTSpacing.scrollBottom)
                }
            }
            .navigationTitle("Låneansökan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Avbryt") { showPrivateLoanSheet = false }
                        .font(LTFont.body(14))
                        .foregroundColor(lender.accentColor)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Historik Section

    private var historikSection: some View {
        VStack(spacing: LTSpacing.sm) {
            if transactionHistory.isEmpty {
                VStack(spacing: LTSpacing.md) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.15))
                    Text("Ingen transaktionshistorik ännu.")
                        .font(LTFont.body(12))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, LTSpacing.xxxl + LTSpacing.sm)
            } else {
                ForEach(transactionHistory) { tx in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.label)
                                .font(LTFont.body(12))
                                .foregroundColor(.white)
                            Text(tx.date.formatted(.dateTime.day().month().hour().minute()))
                                .font(LTFont.body(9))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        Spacer()
                        Text(tx.amount >= 0 ? "+\(TimeEngine.shortFormatted(tx.amount))" : "−\(TimeEngine.shortFormatted(abs(tx.amount)))")
                            .font(LTFont.heading(12))
                            .foregroundColor(tx.amount >= 0 ? .green : .red)
                            .contentTransition(.numericText())
                    }
                    .padding(LTSpacing.sm + 2)
                    .ltCard(radius: LTRadius.sm)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(tx.label): \(tx.amount >= 0 ? "plus" : "minus") \(TimeEngine.shortFormatted(abs(tx.amount)))")
                }
            }
        }
    }

    // MARK: Helper

    private func bankRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(LTFont.body(11))
                .foregroundColor(.white.opacity(0.45))
            Spacer()
            Text(value)
                .font(LTFont.heading(12))
                .foregroundColor(color)
        }
    }
}

#Preview {
    BankView()
        .preferredColorScheme(.dark)
}
