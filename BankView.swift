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
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var bankManager = BankManager.shared
    @ObservedObject private var investMgr = InvestmentManager.shared
    @ObservedObject private var social = SocialManager.shared

    @State private var selectedTab: BankTab = .tidskonto
    @State private var loanAmount: TimeInterval = 3600
    @State private var investAmount: TimeInterval = 3600
    @State private var maturityDays: Int = 7
    @State private var showLoanConfirm = false
    @State private var showInvestConfirm = false
    @State private var transactionHistory: [(label: String, amount: TimeInterval, date: Date)] = []

    enum BankTab: String, CaseIterable {
        case tidslaan     = "Tidslån"
        case tidskonto    = "Tidskonto"
        case npcUtlaning  = "NPC-utlåning"
        case historik     = "Historik"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.03, green: 0.04, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.7))
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("TIDBANKEN")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text(TimeEngine.shortFormatted(engine.balance))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                .padding()
                .padding(.top, 20)

                // Tab bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(BankTab.allCases, id: \.self) { tab in
                            Button { selectedTab = tab } label: {
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(selectedTab == tab ? .black : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selectedTab == tab ? Color.green : Color.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .tidslaan:     tidslaanSection
                        case .tidskonto:    tidskontoSection
                        case .npcUtlaning:  npcUtlaningSection
                        case .historik:     historikSection
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
                _ = investMgr.invest(amount: investAmount, maturityDays: maturityDays, zone: gameState.currentZone)
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Investera \(TimeEngine.shortFormatted(investAmount)) i \(maturityDays) dagar?\nPengarna låses under löptiden.")
        }
        .alert("Marknadskrasch!", isPresented: $investMgr.showCrashAlert) {
            Button("OK") {}
        } message: { Text(investMgr.crashMessage) }
        .alert("Transaktion", isPresented: $social.showAlert) {
            Button("OK") {}
        } message: { Text(social.alertMessage) }
    }

    // MARK: - Tidslån Section
    private var tidslaanSection: some View {
        VStack(spacing: 16) {
            let zone = gameState.currentZone
            let maxLoan = BankManager.maxLoan(for: zone)
            let rate = BankManager.dailyRate(for: zone) * 100

            // Loan info card
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundColor(.cyan)
                    Text("LÅNEVILLKOR")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                }
                bankInfoRow(label: "Maxbelopp", value: TimeEngine.shortFormatted(maxLoan), color: .yellow)
                bankInfoRow(label: "Daglig ränta", value: String(format: "%.2f%%", rate), color: .orange)
                bankInfoRow(label: "Löptid", value: "30 dagar", color: .white)
                bankInfoRow(label: "Din zon", value: "\(zone.name) (nivå \(zone.index))", color: zone.color)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Active loan display
            if let loan = bankManager.activeLoan {
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("AKTIVT LÅN")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                        Spacer()
                        if loan.isPastDue {
                            Text("FÖRFALLET!")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.red)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    bankInfoRow(label: "Lånebelopp", value: TimeEngine.shortFormatted(loan.principal), color: .white)
                    bankInfoRow(label: "Upplupen ränta", value: TimeEngine.shortFormatted(loan.interest), color: .orange)
                    bankInfoRow(label: "Totalt att betala", value: TimeEngine.shortFormatted(loan.totalDue), color: .red)
                    bankInfoRow(label: "Dagar kvar", value: "\(Swift.max(0, loan.dueDays - Int(loan.daysElapsed))) dagar", color: .white.opacity(0.6))

                    Button {
                        bankManager.repayLoan()
                    } label: {
                        Text("BETALA TILLBAKA  (\(TimeEngine.shortFormatted(loan.totalDue)))")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(engine.balance >= loan.totalDue ? Color.green : Color.gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(engine.balance < loan.totalDue)
                }
                .padding(16)
                .background(Color.yellow.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.3), lineWidth: 1))

            } else {
                // New loan form
                VStack(spacing: 12) {
                    Text("NY ANSÖKAN")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 4) {
                        HStack {
                            Text("Belopp: \(TimeEngine.shortFormatted(loanAmount))")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        Slider(value: $loanAmount, in: 3600...Swift.max(3601, maxLoan), step: 3600)
                            .accentColor(.cyan)
                    }

                    bankInfoRow(
                        label: "Total kostnad (30 dagar)",
                        value: TimeEngine.shortFormatted(loanAmount * (1 + rate / 100 * 30)),
                        color: .orange
                    )

                    Button { showLoanConfirm = true } label: {
                        Text("ANSÖK OM LÅN")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Tidskonto Section
    private var tidskontoSection: some View {
        VStack(spacing: 16) {
            // Rate display
            VStack(spacing: 6) {
                Text("DAGLIG RÄNTA")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Text(String(format: "%.1f%%", InvestmentManager.dailyRate(for: gameState.currentZone) * 100))
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                Text("Marknaden kan krascha (5% chans/vecka)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.red.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // New investment form
            VStack(spacing: 12) {
                Text("NY INVESTERING")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 4) {
                    HStack {
                        Text("Belopp: \(TimeEngine.shortFormatted(investAmount))")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.yellow)
                        Spacer()
                    }
                    Slider(value: $investAmount, in: 3600...max(3601, min(engine.balance * 0.8, 86400 * 365)), step: 3600)
                        .accentColor(.green)
                }

                HStack(spacing: 8) {
                    ForEach([1, 7, 14, 30, 90], id: \.self) { days in
                        Button { maturityDays = days } label: {
                            Text("\(days)d")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(maturityDays == days ? .black : .white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(maturityDays == days ? Color.green : Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                let projected = investAmount * pow(1 + InvestmentManager.dailyRate(for: gameState.currentZone), Double(maturityDays))
                bankInfoRow(label: "Prognos efter \(maturityDays)d", value: TimeEngine.shortFormatted(projected), color: .green)

                Button { showInvestConfirm = true } label: {
                    Text("INVESTERA \(TimeEngine.shortFormatted(investAmount))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(investAmount <= engine.balance ? Color.green : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(investAmount > engine.balance)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Active investments
            if !investMgr.investments.isEmpty {
                VStack(spacing: 10) {
                    Text("AKTIVA INVESTERINGAR")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)

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
        VStack(spacing: 14) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.cyan)
                Text("Lån till NPC:er ger ränteintäkter. Risk: NPC betalar inte tillbaka.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(12)
            .background(Color.cyan.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !social.activeLoans.isEmpty {
                Text("AKTIVA LÅN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(social.activeLoans.filter { $0.lentToNPC }) { loan in
                    let npc = NPCPlayer.all.first(where: { $0.name == loan.npcName })
                    LoanCard(loan: loan) {
                        if let n = npc { social.collectFromNPC(loan, npc: n) }
                    }
                }
            }

            Text("TILLGÄNGLIGA NPC:ER")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(NPCPlayer.all.filter { $0.zone == gameState.currentZone.name }) { npc in
                npcLendCard(npc: npc)
            }

            if NPCPlayer.all.filter({ $0.zone == gameState.currentZone.name }).isEmpty {
                Text("Inga NPC:er i din zon (\(gameState.currentZone.name))")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    private func npcLendCard(npc: NPCPlayer) -> some View {
        HStack(spacing: 12) {
            Text(npc.avatar).font(.system(size: 26))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(npc.name)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.0f%%/mån", npc.loanInterestRate * 100))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                Text(npc.bio)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
                Text(String(format: "Pålitlighet: %.0f%%", npc.reliability * 100))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(npc.reliability > 0.8 ? .green : .orange)
            }

            Button("LÅN") {
                _ = social.lendToNPC(npc, amount: 3600, days: 7)
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Historik Section
    private var historikSection: some View {
        VStack(spacing: 10) {
            if transactionHistory.isEmpty {
                Text("Ingen transaktionshistorik ännu.")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
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
                        Text(tx.amount >= 0 ? "+\(TimeEngine.shortFormatted(tx.amount))" : "-\(TimeEngine.shortFormatted(abs(tx.amount)))")
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
    private func bankInfoRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
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
