import SwiftUI
import Foundation

// MARK: - Investment Manager

struct Investment: Codable, Identifiable {
    let id: UUID
    let amount: TimeInterval
    let startDate: Date
    let dailyRate: Double
    let maturityDays: Int

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

    static func dailyRate(for zone: ZoneProfile) -> Double {
        switch zone.name {
        case "Halvmörkret":   return 0.003
        case "Gränslandet":   return 0.005
        case "Stigarnas Dal": return 0.008
        case "Uppgången":     return 0.012
        case "Tröskeln":      return 0.018
        case "Vakttornet":    return 0.025
        case "Evigheten":     return 0.035
        default:              return 0.003
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
        TransactionLedger.shared.record(label: "Investering (\(maturityDays)d)", amount: -amount)
        return true
    }

    func withdraw(_ investment: Investment) {
        guard let idx = investments.firstIndex(where: { $0.id == investment.id }) else { return }
        let value = investment.currentValue
        let taxed = value * (1 - GameState.shared.currentZone.taxRate)
        TimeEngine.shared.addTime(taxed)
        GameState.shared.recordEarning(taxed - investment.amount)
        TransactionLedger.shared.record(
            label: investment.isMatured ? "Investering uttagen (matured)" : "Tidig investering uttagen",
            amount: taxed
        )
        investments.remove(at: idx)
        saveInvestments()
    }

    private func startCrashMonitor() {
        crashTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            let dailyCrashChance = 0.05 / 7.0
            if Double.random(in: 0...1) < dailyCrashChance / 24.0 {
                self?.triggerCrash()
            }
        }
    }

    private func triggerCrash() {
        guard !investments.isEmpty else { return }
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
        crashMessage = "Marknadskrasch! Dina investeringar förlorade \(Int(lossFactor * 100))% av sitt värde."
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
    @ObservedObject private var engine    = TimeEngine.shared

    @State private var investAmount: TimeInterval = 3600
    @State private var maturityDays: Int = 7
    @State private var showConfirm: Bool = false

    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotif  = UINotificationFeedbackGenerator()

    let maturityOptions = [1, 3, 7, 14, 30, 90]

    var body: some View {
        ZStack {
            // Premium dark background
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.06, blue: 0.04),
                    Color(red: 0.01, green: 0.02, blue: 0.02),
                    Color.black
                ],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: LTSpacing.xl) {

                    // Title
                    VStack(spacing: LTSpacing.xs) {
                        Text("TIME BANK")
                            .font(LTFont.displayTitle(22))
                            .foregroundColor(.white)
                            .tracking(4)
                            .padding(.top, LTSpacing.xxxl + LTSpacing.sm)
                        Text("TIDSINVESTERING")
                            .font(LTFont.label(9))
                            .foregroundColor(.white.opacity(0.3))
                            .tracking(4)
                    }

                    // Rate display
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: LTSpacing.xs) {
                            Text("DAGLIG RÄNTA")
                                .font(LTFont.label(9))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(2)
                            Text(String(format: "%.1f%%", InvestmentManager.dailyRate(for: gameState.currentZone) * 100))
                                .font(LTFont.value(36))
                                .foregroundColor(.green)
                                .neonGlow(.green, intensity: 0.4)
                                .contentTransition(.numericText())
                            Text("Marknaden kan krascha (5% chans/vecka)")
                                .font(LTFont.body(10))
                                .foregroundColor(.red.opacity(0.7))
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 64, height: 64)
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 26))
                                .foregroundColor(.green)
                        }
                        .accessibilityHidden(true)
                    }
                    .padding(LTSpacing.lg)
                    .ltAccentCard(color: .green)
                    .padding(.horizontal, LTSpacing.horizontal)

                    LTInfoCallout(
                        title: "Investeringsrisk",
                        message: "Högre avkastning kräver längre bindningstid. Behåll en buffert för oväntade utgifter och lån.",
                        icon: "chart.bar.doc.horizontal.fill",
                        tint: .green
                    )
                    .padding(.horizontal, LTSpacing.horizontal)

                    // New investment form
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("NY INVESTERING")
                                .font(LTFont.heading(12))
                                .foregroundColor(.white)
                                .tracking(2)
                            Spacer()
                        }
                        .padding(LTSpacing.md)

                        Divider().background(Color.white.opacity(0.06))

                        VStack(spacing: LTSpacing.md) {
                            // Amount slider
                            VStack(spacing: LTSpacing.xs + 2) {
                                HStack {
                                    Text("Belopp")
                                        .font(LTFont.body(11))
                                        .foregroundColor(.white.opacity(0.5))
                                    Spacer()
                                    Text(TimeEngine.shortFormatted(investAmount))
                                        .font(LTFont.value(15))
                                        .foregroundColor(.yellow)
                                        .contentTransition(.numericText())
                                        .animation(LTAnimation.springFast, value: investAmount)
                                }
                                Slider(
                                    value: $investAmount,
                                    in: 3600...max(7200, min(engine.balance * 0.8, 86400 * 365)),
                                    step: 3600
                                )
                                .tint(.green)
                                .accessibilityLabel("Investeringsbelopp")
                                .accessibilityValue(TimeEngine.shortFormatted(investAmount))
                            }

                            // Duration picker
                            VStack(alignment: .leading, spacing: LTSpacing.xs + 2) {
                                Text("Löptid")
                                    .font(LTFont.body(11))
                                    .foregroundColor(.white.opacity(0.5))
                                HStack(spacing: LTSpacing.xs + 2) {
                                    ForEach(maturityOptions, id: \.self) { days in
                                        Button {
                                            hapticLight.impactOccurred()
                                            withAnimation(LTAnimation.springFast) { maturityDays = days }
                                        } label: {
                                            Text("\(days)d")
                                                .font(LTFont.label(11))
                                                .foregroundColor(maturityDays == days ? .black : .white)
                                                .padding(.horizontal, LTSpacing.sm + 2)
                                                .padding(.vertical, LTSpacing.xs + 2)
                                                .background(maturityDays == days ? Color.green : Color.white.opacity(0.1))
                                                .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                                        }
                                        .buttonStyle(LTPressEffect())
                                        .accessibilityLabel("\(days) dagar")
                                        .accessibilityAddTraits(maturityDays == days ? .isSelected : [])
                                    }
                                }
                            }

                            // Projection
                            let projected = investAmount * pow(1 + InvestmentManager.dailyRate(for: gameState.currentZone), Double(maturityDays))
                            let profit = projected - investAmount
                            let taxedProfit = profit * (1 - gameState.currentZone.taxRate)

                            VStack(spacing: LTSpacing.xs) {
                                HStack {
                                    Text("Prognos efter \(maturityDays) dagar")
                                        .font(LTFont.body(11))
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    Text(TimeEngine.shortFormatted(projected))
                                        .font(LTFont.heading(13))
                                        .foregroundColor(.white)
                                        .contentTransition(.numericText())
                                        .animation(LTAnimation.springFast, value: projected)
                                }
                                HStack {
                                    Text("Vinst efter skatt")
                                        .font(LTFont.body(11))
                                        .foregroundColor(.white.opacity(0.4))
                                    Spacer()
                                    Text("+\(TimeEngine.shortFormatted(taxedProfit))")
                                        .font(LTFont.heading(13))
                                        .foregroundColor(.green)
                                        .contentTransition(.numericText())
                                        .animation(LTAnimation.springFast, value: taxedProfit)
                                }
                            }

                            Button {
                                hapticMedium.impactOccurred()
                                showConfirm = true
                            } label: {
                                Text("INVESTERA \(TimeEngine.shortFormatted(investAmount))")
                                    .font(LTFont.heading(14))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, LTSpacing.md)
                                    .background(investAmount <= engine.balance ? Color.green : Color.gray)
                                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                            }
                            .disabled(investAmount > engine.balance)
                            .buttonStyle(LTPressEffect())
                            .accessibilityLabel("Investera \(TimeEngine.shortFormatted(investAmount))")
                            .accessibilityHint(investAmount > engine.balance ? "Otillräcklig balans" : "Låser beloppet under \(maturityDays) dagar")
                        }
                        .padding(LTSpacing.md)
                    }
                    .ltCard(radius: LTRadius.md)
                    .padding(.horizontal, LTSpacing.horizontal)

                    // Active investments
                    if !investMgr.investments.isEmpty {
                        VStack(spacing: LTSpacing.sm) {
                            HStack {
                                Text("AKTIVA INVESTERINGAR")
                                    .font(LTFont.label(11))
                                    .foregroundColor(.white.opacity(0.4))
                                    .tracking(2)
                                Spacer()
                                Text("\(investMgr.investments.count) aktiva")
                                    .font(LTFont.body(10))
                                    .foregroundColor(.green.opacity(0.7))
                            }
                            .padding(.horizontal, LTSpacing.horizontal)

                            ForEach(investMgr.investments) { inv in
                                InvestmentCard(investment: inv) {
                                    hapticNotif.notificationOccurred(inv.isMatured ? .success : .warning)
                                    investMgr.withdraw(inv)
                                }
                                .padding(.horizontal, LTSpacing.horizontal)
                            }
                        }
                    } else {
                        LTEmptyStateCard(
                            icon: "chart.line.downtrend.xyaxis",
                            title: "Inga aktiva investeringar",
                            message: "Starta en investering ovan för att börja bygga passiv tillväxt.",
                            tint: .green
                        )
                        .padding(.horizontal, LTSpacing.horizontal)
                    }

                    Spacer(minLength: LTSpacing.scrollBottom)
                }
            }
        }
        .alert("Bekräfta Investering", isPresented: $showConfirm) {
            Button("Investera") {
                hapticNotif.notificationOccurred(.success)
                _ = investMgr.invest(amount: investAmount, maturityDays: maturityDays, zone: gameState.currentZone)
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Investera \(TimeEngine.shortFormatted(investAmount)) i \(maturityDays) dagar?\nPengarna är låsta under löptiden.")
        }
        .alert("Marknadskrasch!", isPresented: $investMgr.showCrashAlert) {
            Button("OK") {}
        } message: { Text(investMgr.crashMessage) }
    }
}

// MARK: - InvestmentCard

struct InvestmentCard: View {
    let investment: Investment
    let onWithdraw: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Insats: \(TimeEngine.shortFormatted(investment.amount))")
                        .font(LTFont.heading(13))
                        .foregroundColor(.white)
                    Text(String(format: "Daglig ränta: %.1f%%", investment.dailyRate * 100))
                        .font(LTFont.body(11))
                        .foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeEngine.shortFormatted(investment.currentValue))
                        .font(LTFont.value(14))
                        .foregroundColor(.yellow)
                        .contentTransition(.numericText())
                    Text("+\(TimeEngine.shortFormatted(investment.profit))")
                        .font(LTFont.body(11))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                }
            }

            // Progress bar
            let progress = min(1.0, investment.ageInDays / Double(investment.maturityDays))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(investment.isMatured ? Color.green : Color.green.opacity(0.6))
                        .frame(width: geo.size.width * progress, height: 3)
                        .animation(LTAnimation.springSmooth, value: progress)
                }
            }
            .frame(height: 3)

            HStack {
                Text(String(format: "%.1f / %d dagar", investment.ageInDays, investment.maturityDays))
                    .font(LTFont.body(11))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if investment.isMatured {
                    Button("TA UT") { onWithdraw() }
                        .font(LTFont.heading(12))
                        .foregroundColor(.black)
                        .padding(.horizontal, LTSpacing.md)
                        .padding(.vertical, LTSpacing.xs + 2)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                        .buttonStyle(LTPressEffect())
                        .neonGlow(.green, intensity: 0.5)
                        .accessibilityLabel("Ta ut investering: \(TimeEngine.shortFormatted(investment.currentValue))")
                } else {
                    Button("TIDIG UTTAG") { onWithdraw() }
                        .font(LTFont.body(11))
                        .foregroundColor(.yellow.opacity(0.8))
                        .buttonStyle(LTPressEffect())
                        .accessibilityLabel("Tidig uttag av investering")
                        .accessibilityHint("Möjlig vinstförlust")
                }
            }
        }
        .padding(LTSpacing.md)
        .ltCard(
            color: investment.isMatured ? .green : .white,
            borderOpacity: investment.isMatured ? 0.3 : 0.08,
            shadowColor: investment.isMatured ? .green : .clear,
            shadowRadius: investment.isMatured ? 8 : 0
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Investering: \(TimeEngine.shortFormatted(investment.amount)), nuvarande värde \(TimeEngine.shortFormatted(investment.currentValue)), \(investment.isMatured ? "mogen" : "pågående")")
    }
}

#Preview {
    InvestmentView()
        .preferredColorScheme(.dark)
}
