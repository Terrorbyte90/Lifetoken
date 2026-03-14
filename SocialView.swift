import SwiftUI
import Foundation

// MARK: - NPC Player

struct NPCPlayer: Identifiable {
    let id: UUID
    let name: String
    let zone: String
    let avatar: String
    let bio: String
    var balance: TimeInterval
    var loanInterestRate: Double    // daily interest they charge
    var reliability: Double         // 0-1, chance they repay on time
    var lastSeen: String

    static let all: [NPCPlayer] = [
        NPCPlayer(id: UUID(), name: "Viktor R.", zone: "Duskline", avatar: "😐",
                  bio: "Fabriksarbetare. Alltid lite knapp pa tid. Pålitlig nog.",
                  balance: 3600 * 8, loanInterestRate: 0.15, reliability: 0.80, lastSeen: "2h sedan"),
        NPCPlayer(id: UUID(), name: "Mara D.", zone: "Midgrey", avatar: "🧐",
                  bio: "Revisor. Noggrant bokford. Betalar alltid tillbaka.",
                  balance: 86400 * 3, loanInterestRate: 0.08, reliability: 0.95, lastSeen: "1h sedan"),
        NPCPlayer(id: UUID(), name: "ARIA-7", zone: "Aetherpoint", avatar: "🤖",
                  bio: "AI-analytiker. Aldrig sen med betalning. Lag ranta.",
                  balance: 86400 * 60, loanInterestRate: 0.05, reliability: 0.99, lastSeen: "15m sedan"),
        NPCPlayer(id: UUID(), name: "Kai Dusk", zone: "Novalux", avatar: "😎",
                  bio: "Tidshandlare. Hog risk, hog beloning. Lite otillforitlig.",
                  balance: 86400 * 400, loanInterestRate: 0.25, reliability: 0.60, lastSeen: "3h sedan"),
        NPCPlayer(id: UUID(), name: "Echo", zone: "Novalux", avatar: "🎭",
                  bio: "Mystisk spelare. Ingen vet var hen kommer ifran. Hog ranta.",
                  balance: 86400 * 300, loanInterestRate: 0.30, reliability: 0.50, lastSeen: "Just nu"),
        NPCPlayer(id: UUID(), name: "Syndra Wei", zone: "Solara", avatar: "👑",
                  bio: "Tidsmiljonar. Erbjuder lan till hogt pris. Alltid palitlig.",
                  balance: 86400 * 365 * 5, loanInterestRate: 0.50, reliability: 1.0, lastSeen: "5m sedan"),
    ]
}

// MARK: - Loan Record

struct LoanRecord: Codable, Identifiable {
    let id: UUID
    let npcName: String
    let principal: TimeInterval
    let dailyRate: Double
    let startDate: Date
    let dueDays: Int
    let lentToNPC: Bool   // true = you lent to NPC, false = you borrowed from NPC

    var daysElapsed: Double { Date().timeIntervalSince(startDate) / 86400 }
    var interest: TimeInterval { principal * dailyRate * daysElapsed }
    var totalDue: TimeInterval { principal + interest }
    var isPastDue: Bool { daysElapsed > Double(dueDays) }
}

// MARK: - Social Manager

class SocialManager: ObservableObject {
    static let shared = SocialManager()

    @Published var activeLoans: [LoanRecord] = []
    @Published var transferHistory: [(String, TimeInterval, Date)] = []
    @Published var showAlert: Bool = false
    @Published var alertMessage: String = ""

    private let loansKey = "social_loans"

    private init() { loadLoans() }

    /// Lend time to an NPC player
    func lendToNPC(_ npc: NPCPlayer, amount: TimeInterval, days: Int) -> Bool {
        guard TimeEngine.shared.deductTime(amount) else {
            alertMessage = "Otillräcklig tid for overforing."
            showAlert = true
            return false
        }
        let loan = LoanRecord(id: UUID(), npcName: npc.name, principal: amount,
                              dailyRate: npc.loanInterestRate / 30,  // monthly rate -> daily
                              startDate: Date(), dueDays: days, lentToNPC: true)
        activeLoans.append(loan)
        saveLoans()
        transferHistory.append((npc.name, -amount, Date()))
        return true
    }

    /// Collect repayment from NPC
    func collectFromNPC(_ loan: LoanRecord, npc: NPCPlayer) {
        guard let idx = activeLoans.firstIndex(where: { $0.id == loan.id }) else { return }

        // Check if NPC repays (based on reliability)
        let repays = Double.random(in: 0...1) < npc.reliability
        if repays {
            let repayment = loan.totalDue
            let taxed = repayment * (1 - GameState.shared.currentZone.taxRate)
            TimeEngine.shared.addTime(taxed)
            GameState.shared.recordEarning(taxed - loan.principal)
            alertMessage = "\(npc.name) betalade tillbaka!\n+\(TimeEngine.shortFormatted(taxed)) (efter skatt)\nRänta: +\(TimeEngine.shortFormatted(loan.interest))"
            transferHistory.append((npc.name, taxed, Date()))
        } else {
            // NPC defaults — lose principal
            alertMessage = "\(npc.name) betalade INTE tillbaka.\nDu förlorade \(TimeEngine.shortFormatted(loan.principal))."
        }
        activeLoans.remove(at: idx)
        saveLoans()
        showAlert = true
    }

    private func saveLoans() {
        if let data = try? JSONEncoder().encode(activeLoans) {
            UserDefaults.standard.set(data, forKey: loansKey)
        }
    }

    private func loadLoans() {
        guard let data = UserDefaults.standard.data(forKey: loansKey),
              let loaded = try? JSONDecoder().decode([LoanRecord].self, from: data) else { return }
        activeLoans = loaded
    }
}

// MARK: - Social View

struct SocialView: View {
    @ObservedObject private var social = SocialManager.shared
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    @State private var selectedNPC: NPCPlayer? = nil
    @State private var showLendSheet: Bool = false
    @State private var lendAmount: TimeInterval = 3600
    @State private var lendDays: Int = 7

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("SOCIAL EKONOMI")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.top, 60)
                        Text("Lend tid. Tjäna ränta. Riskera allt.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Info banner
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.cyan)
                        Text("Alla transfers kostar 10% nätverksskatt utöver zonens skatt.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding()
                    .background(Color.cyan.opacity(0.07))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Active loans
                    if !social.activeLoans.isEmpty {
                        VStack(spacing: 10) {
                            Text("AKTIVA LÅN")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(social.activeLoans) { loan in
                                let npc = NPCPlayer.all.first(where: { $0.name == loan.npcName })
                                LoanCard(loan: loan) {
                                    if let n = npc { social.collectFromNPC(loan, npc: n) }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // NPC players
                    VStack(spacing: 12) {
                        Text("SPELARE ONLINE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(NPCPlayer.all) { npc in
                            NPCCard(npc: npc) {
                                selectedNPC = npc
                                showLendSheet = true
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
            }
        }
        .sheet(isPresented: $showLendSheet) {
            if let npc = selectedNPC {
                LendSheetView(npc: npc, lendAmount: $lendAmount, lendDays: $lendDays) {
                    _ = social.lendToNPC(npc, amount: lendAmount, days: lendDays)
                    showLendSheet = false
                }
            }
        }
        .alert("Transaktion", isPresented: $social.showAlert) {
            Button("OK") {}
        } message: { Text(social.alertMessage) }
    }
}

struct NPCCard: View {
    let npc: NPCPlayer
    let onLend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(npc.avatar).font(.system(size: 28))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(npc.name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text(npc.zone)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                }
                Text(npc.bio)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(2)
                HStack(spacing: 16) {
                    Label(String(format: "Ränta: %.0f%%/man", npc.loanInterestRate * 100),
                          systemImage: "percent")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.yellow)
                    Label(String(format: "Pålitlighet: %.0f%%", npc.reliability * 100),
                          systemImage: "checkmark.shield")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(npc.reliability > 0.8 ? .green : .orange)
                }
            }

            Button("LAN", action: onLend)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.green)
                .cornerRadius(8)
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .cornerRadius(12)
    }
}

struct LoanCard: View {
    let loan: LoanRecord
    let onCollect: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(loan.npcName)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text("Utlånat: \(TimeEngine.shortFormatted(loan.principal))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Text("Förfaller om \(max(0, loan.dueDays - Int(loan.daysElapsed)))d | Total: \(TimeEngine.shortFormatted(loan.totalDue))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.yellow)
            }
            Spacer()
            if loan.isPastDue {
                Button("KRAV", action: onCollect)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(loan.isPastDue ? Color.orange.opacity(0.1) : Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(loan.isPastDue ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1))
    }
}

struct LendSheetView: View {
    let npc: NPCPlayer
    @Binding var lendAmount: TimeInterval
    @Binding var lendDays: Int
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine = TimeEngine.shared
    let onConfirm: () -> Void

    var projectedReturn: TimeInterval {
        lendAmount * (1 + (npc.loanInterestRate / 30) * Double(lendDays))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark").foregroundColor(.white)
                    }
                    Spacer()
                    Text("LÅN TILL \(npc.name.uppercased())")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 24)
                }
                .padding()

                Text(npc.avatar).font(.system(size: 60))

                VStack(spacing: 8) {
                    Text("Månatlig ränta: \(Int(npc.loanInterestRate * 100))%")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text(String(format: "Pålitlighet: %.0f%%", npc.reliability * 100))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(npc.reliability > 0.8 ? .green : .orange)
                    if npc.reliability < 0.7 {
                        Text("Hög risk för utebliven återbetalning!")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }

                VStack(spacing: 10) {
                    Text("Belopp: \(TimeEngine.shortFormatted(lendAmount))")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(.white)
                    Slider(value: $lendAmount,
                           in: 3600...max(3601, min(engine.balance * 0.9, 86400 * 365)),
                           step: 3600)
                        .accentColor(.green)

                    HStack {
                        ForEach([3, 7, 14, 30, 60], id: \.self) { d in
                            Button("\(d)d") { lendDays = d }
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(lendDays == d ? .black : .white)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(lendDays == d ? Color.green : Color.white.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }

                    Text("Förväntad återbetalning: \(TimeEngine.shortFormatted(projectedReturn))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                    Text("(+\(TimeEngine.shortFormatted(projectedReturn - lendAmount)) i ränta)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green.opacity(0.6))
                }
                .padding(.horizontal)

                Button(action: onConfirm) {
                    Text("BEKRÄFTA LÅN")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()
            }
        }
    }
}
