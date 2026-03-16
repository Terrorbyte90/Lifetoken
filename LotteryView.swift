import SwiftUI

// MARK: - Lottery Manager

class LotteryManager: ObservableObject {
    static let shared = LotteryManager()

    @Published var jackpot: TimeInterval = 31_536_000   // Start: 1 year
    @Published var ticketsBought: Int = 0
    @Published var lastDrawDate: Date? = nil
    @Published var lastWinner: String? = nil

    private let ticketCost: TimeInterval = 3_600        // 1 hour per ticket

    private let jackpotKey  = "lottery_jackpot"
    private let lastDrawKey = "lottery_lastDraw"
    private let ticketsKey  = "lottery_tickets"

    private init() {
        let saved = UserDefaults.standard.double(forKey: jackpotKey)
        jackpot      = saved < 3_600 ? 31_536_000 : saved
        ticketsBought = UserDefaults.standard.integer(forKey: ticketsKey)
        lastDrawDate  = UserDefaults.standard.object(forKey: lastDrawKey) as? Date
    }

    // MARK: Buy tickets

    /// Returns `true` on success, `false` if insufficient balance.
    func buyTickets(_ count: Int) -> Bool {
        let cost = ticketCost * Double(count)
        guard TimeEngine.shared.deductTime(cost) else { return false }
        ticketsBought += count
        jackpot       += cost * 0.70    // 70% of ticket sales go to jackpot
        persist()
        return true
    }

    // MARK: Draw

    /// Simulates a weekly draw. Returns (won, prize).
    func conductDraw() -> (won: Bool, prize: TimeInterval) {
        let odds       = 500_000
        let winChance  = Double(max(ticketsBought, 1)) / Double(odds)
        let won        = Double.random(in: 0...1) < winChance

        if won {
            let prize    = jackpot
            let taxRate  = GameState.shared.currentZone.taxRate
            let netPrize = prize * (1.0 - taxRate)
            TimeEngine.shared.addTime(netPrize)
            GameState.shared.recordEarning(netPrize)
            jackpot       = 31_536_000
            ticketsBought = 0
            UserDefaults.standard.set(Date(), forKey: lastDrawKey)
            lastDrawDate  = Date()
            persist()
            return (true, prize)
        } else {
            // 30% chance of a rollover bonus; otherwise plain rollover
            if Double.random(in: 0...1) < 0.30 {
                jackpot = 31_536_000 + jackpot * 0.10
            }
            ticketsBought = 0
            UserDefaults.standard.set(Date(), forKey: lastDrawKey)
            lastDrawDate  = Date()
            persist()
            return (false, 0)
        }
    }

    // MARK: Timing

    var nextDrawDate: Date {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.weekday = 1   // Sunday
        comps.hour    = 20
        comps.minute  = 0
        return cal.nextDate(after: Date(),
                            matching: comps,
                            matchingPolicy: .nextTime)
               ?? Date().addingTimeInterval(604_800)
    }

    var timeUntilDraw: String {
        let secs = Int(nextDrawDate.timeIntervalSince(Date()))
        guard secs > 0 else { return "Nu!" }
        let d = secs / 86_400
        let h = (secs % 86_400) / 3_600
        let m = (secs % 3_600) / 60
        if d > 0 { return "\(d)d \(h)h" }
        return "\(h)h \(m)m"
    }

    // MARK: Persistence

    private func persist() {
        UserDefaults.standard.set(jackpot,       forKey: jackpotKey)
        UserDefaults.standard.set(ticketsBought, forKey: ticketsKey)
    }
}

// MARK: - Lottery View

struct LotteryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine  = TimeEngine.shared
    @ObservedObject private var lottery = LotteryManager.shared

    @State private var ticketCount:    Int = 1
    @State private var showResult:     Bool = false
    @State private var resultMessage:  String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    headerBar
                    jackpotCard
                    drawInfoBlock
                    ticketSection
                    divider
                    simulateButton
                    Spacer(minLength: 80)
                }
            }
        }
        .alert("Lotteri", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: Sub-views

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.7))
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            Spacer()
            Text("TIME LOTTERY")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.yellow)
        }
        .padding()
        .padding(.top, 20)
    }

    private var jackpotCard: some View {
        VStack(spacing: 8) {
            Text("JACKPOTT")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
            Text(TimeEngine.formatted(lottery.jackpot))
                .font(.system(size: 34, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("≈ \(String(format: "%.1f", lottery.jackpot / 31_536_000)) år")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.yellow.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.yellow.opacity(0.07))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var drawInfoBlock: some View {
        VStack(spacing: 6) {
            Text("Nästa dragning: Söndag 20:00")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundColor(.green)
                Text("Om \(lottery.timeUntilDraw)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Text("Odds: 1 av 500 000 per lott")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.red.opacity(0.7))
            Text("70% av biljettintäkter går till jackpotten")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
        }
    }

    private var ticketSection: some View {
        VStack(spacing: 16) {
            // Your tickets
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(lottery.ticketsBought > 0 ? .green : .white.opacity(0.3))
                Text("DINA LOTTER: \(lottery.ticketsBought)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(lottery.ticketsBought > 0 ? .green : .white.opacity(0.5))
            }

            // Stepper
            HStack {
                Button {
                    if ticketCount > 1 { ticketCount -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
                VStack(spacing: 2) {
                    Text("\(ticketCount)")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("lotter")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()

                Button {
                    if ticketCount < 100 { ticketCount += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 40)

            // Quick-pick row
            HStack(spacing: 10) {
                ForEach([1, 5, 10, 25, 50], id: \.self) { n in
                    Button { ticketCount = n } label: {
                        Text("\(n)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(ticketCount == n ? .black : .white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ticketCount == n ? Color.yellow : Color.white.opacity(0.08))
                            .cornerRadius(8)
                    }
                }
            }

            // Cost summary
            let cost = 3_600.0 * Double(ticketCount)
            VStack(spacing: 3) {
                Text("Kostnad: \(TimeEngine.shortFormatted(cost))")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.yellow)
                Text("Vinstchans: \(String(format: "%.4f", Double(ticketCount) / 5000.0))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }

            // Buy button
            Button {
                if lottery.buyTickets(ticketCount) {
                    resultMessage = "Köpte \(ticketCount) lotter för \(TimeEngine.shortFormatted(cost)).\nTotalt: \(lottery.ticketsBought) lotter."
                } else {
                    resultMessage = "Otillräcklig tid. Du behöver \(TimeEngine.shortFormatted(cost))."
                }
                showResult = true
            } label: {
                Text("KÖP \(ticketCount) LOTTER")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(cost > engine.balance ? Color.gray : Color.yellow)
                    .cornerRadius(12)
            }
            .disabled(cost > engine.balance)
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal)
    }

    private var simulateButton: some View {
        VStack(spacing: 6) {
            Text("TESTA DRAGNING")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))

            Button {
                let (won, prize) = lottery.conductDraw()
                if won {
                    resultMessage = "DU VANN JACKPOTTEN!\n\(TimeEngine.formatted(prize)) har krediterats ditt konto."
                } else {
                    resultMessage = "Ingen vinst denna vecka.\nJackpotten rullas över.\nNy jackpott: \(TimeEngine.formatted(lottery.jackpot))"
                }
                showResult = true
            } label: {
                Text("Simulera veckodragning")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .underline()
            }
        }
    }
}

#Preview {
    LotteryView()
        .preferredColorScheme(.dark)
}
