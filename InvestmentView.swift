import SwiftUI
import Foundation

// MARK: - Investment Manager

struct Investment: Codable, Identifiable {
    let id: UUID
    let amount: TimeInterval
    let startDate: Date
    let dailyRate: Double    // e.g. 0.005 = 0.5% per day
    let maturityDays: Int    // locked for this many days

    var ageInDays: Double { Date().timeIntervalSince(startDate) / 86400 }
    var isMatured: Bool { ageInDays >= Double(maturityDays) }
    var currentValue: TimeInterval { amount * pow(1 + dailyRate, ageInDays) }
    var projectedValue: TimeInterval { amount * pow(1 + dailyRate, Double(maturityDays)) }
    var profit: TimeInterval { currentValue - amount }
}

class InvestmentManager: ObservableObject {
    static let shared = InvestmentManager()

    @Published var investments: [Investment] = []
    @Published var showCrashAlert: Bool = false
    @Published var crashMessage: String = ""

    private let investmentsKey = "active_investments"
    private var crashTimer: Timer?

    // Interest rates per zone
    static func dailyRate(for zone: ZoneProfile) -> Double {
        switch zone.name {
        case "Duskline":    return 0.003   // 0.3%/day
        case "Midgrey":     return 0.005   // 0.5%/day
        case "Risefield":   return 0.008   // 0.8%/day
        case "Aetherpoint": return 0.012   // 1.2%/day
        case "Novalux":     return 0.018   // 1.8%/day
        case "Vaultum":     return 0.025   // 2.5%/day
        case "Solara":      return 0.035   // 3.5%/day
        default:            return 0.003
        }
    }

    private init() {
        loadInvestments()
        startCrashMonitor()
    }

    func invest(amount: TimeInterval, maturityDays: Int, zone: ZoneProfile) -> Bool {
        guard TimeEngine.shared.deductTime(amount) else { return false }
        let inv = Investment(
            id: UUID(),
            amount: amount,
            startDate: Date(),
            dailyRate: InvestmentManager.dailyRate(for: zone),
            maturityDays: maturityDays
        )
        investments.append(inv)
        saveInvestments()
        return true
    }

    func withdraw(_ investment: Investment) {
        guard let idx = investments.firstIndex(where: { $0.id == investment.id }) else { return }
        let value = investment.currentValue
        let taxed = value * (1 - GameState.shared.currentZone.taxRate)
        TimeEngine.shared.addTime(taxed)
        GameState.shared.recordEarning(taxed - investment.amount)
        investments.remove(at: idx)
        saveInvestments()
    }

    private func startCrashMonitor() {
        // 5% chance of market crash per week — checked every hour
        crashTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            let dailyCrashChance = 0.05 / 7.0
            if Double.random(in: 0...1) < dailyCrashChance / 24.0 {
                self?.triggerCrash()
            }
        }
    }

    private func triggerCrash() {
        guard !investments.isEmpty else { return }
        // Crash loses 30-60% of all investments
        let lossFactor = Double.random(in: 0.3...0.6)
        var newInvestments: [Investment] = []
        for inv in investments {
            let reduced = inv.amount * (1 - lossFactor)
            newInvestments.append(Investment(id: inv.id, amount: reduced,
                                             startDate: inv.startDate,
                                             dailyRate: inv.dailyRate,
                                             maturityDays: inv.maturityDays))
        }
        investments = newInvestments
        saveInvestments()
        crashMessage = "Marknadskrasch! Dina investeringar forlorade \(Int(lossFactor * 100))% av sitt varde."
        showCrashAlert = true
    }

    private func saveInvestments() {
        if let data = try? JSONEncoder().encode(investments) {
            UserDefaults.standard.set(data, forKey: investmentsKey)
        }
    }

    private func loadInvestments() {
        guard let data = UserDefaults.standard.data(forKey: investmentsKey),
              let loaded = try? JSONDecoder().decode([Investment].self, from: data) else { return }
        investments = loaded
    }
}

// MARK: - Investment View

struct InvestmentView: View {
    @ObservedObject private var investMgr = InvestmentManager.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var engine = TimeEngine.shared

    @State private var investAmount: TimeInterval = 3600
    @State private var maturityDays: Int = 7
    @State private var showConfirm: Bool = false

    let maturityOptions = [1, 3, 7, 14, 30, 90]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text("TIME BANK")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    // Rate display
                    VStack(spacing: 8) {
                        Text("DAGLIG RANTA")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        Text(String(format: "%.1f%%", InvestmentManager.dailyRate(for: gameState.currentZone) * 100))
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                        Text("Marknaden kan krascha (5% chans/vecka)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .padding()
                    .background(Color.green.opacity(0.06))
                    .cornerRadius(14)
                    .padding(.horizontal)

                    // New investment form
                    VStack(spacing: 14) {
                        Text("NY INVESTERING")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 6) {
                            Text("Belopp: \(TimeEngine.shortFormatted(investAmount))")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(.yellow)
                            Slider(value: $investAmount,
                                   in: 3600...max(3601, min(engine.balance * 0.8, 86400 * 365)),
                                   step: 3600)
                                .accentColor(.green)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Loptid:")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            HStack(spacing: 8) {
                                ForEach(maturityOptions, id: \.self) { days in
                                    Button("\(days)d") {
                                        maturityDays = days
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(maturityDays == days ? .black : .white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(maturityDays == days ? Color.green : Color.white.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }

                        // Projection
                        let projected = investAmount * pow(1 + InvestmentManager.dailyRate(for: gameState.currentZone), Double(maturityDays))
                        let profit = projected - investAmount
                        let taxedProfit = profit * (1 - gameState.currentZone.taxRate)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Prognos efter \(maturityDays) dagar:")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                Text(TimeEngine.shortFormatted(projected))
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                Text("+\(TimeEngine.shortFormatted(taxedProfit)) (efter skatt)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            Spacer()
                        }

                        Button {
                            showConfirm = true
                        } label: {
                            Text("INVESTERA \(TimeEngine.shortFormatted(investAmount))")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(investAmount <= engine.balance ? Color.green : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(investAmount > engine.balance)
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(14)
                    .padding(.horizontal)

                    // Active investments
                    if !investMgr.investments.isEmpty {
                        VStack(spacing: 10) {
                            Text("AKTIVA INVESTERINGAR")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ForEach(investMgr.investments) { inv in
                                InvestmentCard(investment: inv) {
                                    investMgr.withdraw(inv)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
            }
        }
        .alert("Bekrafta Investering", isPresented: $showConfirm) {
            Button("Investera") {
                _ = investMgr.invest(amount: investAmount, maturityDays: maturityDays, zone: gameState.currentZone)
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Investera \(TimeEngine.shortFormatted(investAmount)) i \(maturityDays) dagar?\nPengarna ar lasta under loptiden.")
        }
        .alert("Marknadskrasch!", isPresented: $investMgr.showCrashAlert) {
            Button("OK") {}
        } message: { Text(investMgr.crashMessage) }
    }
}

struct InvestmentCard: View {
    let investment: Investment
    let onWithdraw: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insats: \(TimeEngine.shortFormatted(investment.amount))")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Daglig ranta: \(String(format: "%.1f", investment.dailyRate * 100))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeEngine.shortFormatted(investment.currentValue))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text("+\(TimeEngine.shortFormatted(investment.profit))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                }
            }

            HStack {
                Text("Alder: \(String(format: "%.1f", investment.ageInDays)) / \(investment.maturityDays) dagar")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if investment.isMatured {
                    Button("TA UT") { onWithdraw() }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.green)
                        .cornerRadius(8)
                } else {
                    Button("TIDIG UTTAG") { onWithdraw() }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(investment.isMatured ? Color.green.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
    }
}
