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

// MARK: - Lottery View — Omdesignad

struct LotteryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine  = TimeEngine.shared
    @ObservedObject private var lottery = LotteryManager.shared

    @State private var ticketCount: Int = 1
    @State private var isDrawing: Bool = false
    @State private var drawPhase: DrawPhase = .idle
    @State private var drawResult: DrawResult? = nil
    @State private var ballsAnimating: Bool = false
    @State private var pulseJackpot: Bool = false

    enum DrawPhase { case idle, drawing, revealed }
    struct DrawResult { let won: Bool; let prize: TimeInterval; let newJackpot: TimeInterval }

    var body: some View {
        ZStack {
            // Deep lottery background
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.01, blue: 0.08), Color(red: 0.08, green: 0.02, blue: 0.12), Color.black],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Purple atmospheric glow
            RadialGradient(
                colors: [Color.purple.opacity(0.15), .clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    lotteryHeader
                    jackpotDisplay
                    drawTimerCard
                    ticketPurchaseSection
                    drawSection
                    Spacer(minLength: 80)
                }
            }

            // Draw result overlay (no popup)
            if drawPhase == .revealed, let result = drawResult {
                drawResultOverlay(result)
            }
        }
    }

    // MARK: - Header

    private var lotteryHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("TIDSLOTERIET")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)
                Text(TimeEngine.shortFormatted(engine.balance))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.3))
            }
            Spacer()
            // Balance placeholder for symmetry
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, 20)
        .padding(.top, 54)
    }

    // MARK: - Jackpot

    private var jackpotDisplay: some View {
        VStack(spacing: 10) {
            Text("JACKPOTT")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.purple.opacity(0.7))
                .tracking(6)

            Text(TimeEngine.formatted(lottery.jackpot))
                .font(.system(size: 30, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .shadow(color: Color.purple.opacity(pulseJackpot ? 0.5 : 0.2), radius: pulseJackpot ? 16 : 8)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseJackpot)

            Text("≈ \(String(format: "%.1f", lottery.jackpot / 31_536_000)) år")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.8))

            // Lottery balls decoration
            HStack(spacing: 10) {
                ForEach(0..<6) { i in
                    Circle()
                        .fill(
                            LinearGradient(colors: [
                                [Color.purple, Color.blue, Color.red, Color.orange, Color.green, Color.pink][i],
                                [Color.purple, Color.blue, Color.red, Color.orange, Color.green, Color.pink][i].opacity(0.5)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 26, height: 26)
                        .overlay(
                            Text("\(Int.random(in: 1...49))")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundColor(.white)
                        )
                        .shadow(color: [Color.purple, Color.blue, Color.red, Color.orange, Color.green, Color.pink][i].opacity(0.4), radius: 6)
                        .scaleEffect(ballsAnimating ? 1.0 : 0.7)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.06), value: ballsAnimating)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            LinearGradient(colors: [Color(red: 0.12, green: 0.04, blue: 0.18), Color(red: 0.06, green: 0.02, blue: 0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.purple.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
        .onAppear { pulseJackpot = true; ballsAnimating = true }
    }

    // MARK: - Draw timer

    private var drawTimerCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("NÄSTA DRAGNING")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
                Text("Söndag 20:00")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("OM")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
                Text(lottery.timeUntilDraw)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    // MARK: - Ticket purchase

    private var ticketPurchaseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KÖP LOTTER")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .tracking(3)
                .padding(.horizontal, 4)

            // Current tickets
            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(lottery.ticketsBought > 0 ? .purple : .white.opacity(0.2))
                Text("Dina lotter: \(lottery.ticketsBought)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(lottery.ticketsBought > 0 ? .purple : .white.opacity(0.4))
                Spacer()
                Text("Odds: \(String(format: "%.4f", Double(lottery.ticketsBought) / 5000.0))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }

            // Quantity picker
            HStack(spacing: 0) {
                Button {
                    if ticketCount > 1 { ticketCount -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.06))
                }

                Spacer()
                VStack(spacing: 2) {
                    Text("\(ticketCount)")
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    Text("lotter  ·  \(TimeEngine.shortFormatted(3600.0 * Double(ticketCount)))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.8))
                }
                Spacer()

                Button {
                    if ticketCount < 100 { ticketCount += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.06))
                }
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Quick-pick
            HStack(spacing: 8) {
                ForEach([1, 5, 10, 25, 50], id: \.self) { n in
                    Button { ticketCount = n } label: {
                        Text("\(n)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(ticketCount == n ? .black : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(ticketCount == n ? Color.purple : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            let cost = 3600.0 * Double(ticketCount)
            let canAfford = cost <= engine.balance

            // Buy button
            buyButton(ticketCount: ticketCount, canAfford: canAfford)
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func buyButton(ticketCount: Int, canAfford: Bool) -> some View {
        Button {
            if lottery.buyTickets(ticketCount) {
                withAnimation(.spring()) { ballsAnimating = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring()) { ballsAnimating = true }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "ticket.fill")
                Text("KÖP \(ticketCount) LOTTER")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
            }
            .foregroundColor(canAfford ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(buyButtonGradient(canAfford: canAfford))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: canAfford ? Color.purple.opacity(0.4) : .clear, radius: 12, y: 4)
        }
        .disabled(!canAfford)
    }

    private func buyButtonGradient(canAfford: Bool) -> LinearGradient {
        if canAfford {
            return LinearGradient(colors: [Color.purple, Color(red: 0.5, green: 0.1, blue: 0.8)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            return LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                                  startPoint: .top, endPoint: .bottom)
        }
    }

    // MARK: - Draw section

    private var drawSection: some View {
        VStack(spacing: 12) {
            Text("DRAGNING")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .tracking(3)

            Button {
                conductDrawAnimation()
            } label: {
                HStack(spacing: 8) {
                    if isDrawing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    Text(isDrawing ? "Drar lotter..." : "Simulera veckodragning")
                        .font(.system(size: 12, design: .monospaced))
                }
                .foregroundColor(.white.opacity(isDrawing ? 0.5 : 0.4))
            }
            .disabled(isDrawing || drawPhase != .idle)

            Text("Odds: 1 av 500 000 per lott  ·  70% av biljettintäkter till jackpott")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Draw result overlay (no popup)

    private func drawResultOverlay(_ result: DrawResult) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.3)) { drawPhase = .idle }
                }

            VStack(spacing: 24) {
                if result.won {
                    Text("🎉")
                        .font(.system(size: 60))
                    Text("DU VANN JACKPOTTEN!")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.3))
                        .shadow(color: .yellow.opacity(0.6), radius: 16)
                        .multilineTextAlignment(.center)
                    Text(TimeEngine.formatted(result.prize))
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                    Text("har krediterats ditt konto")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Text("😔")
                        .font(.system(size: 48))
                    Text("Ingen vinst denna vecka")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Jackpotten rullas över")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Ny jackpott: \(TimeEngine.shortFormatted(result.newJackpot))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple)
                }

                Button("Stäng") {
                    withAnimation(.easeOut(duration: 0.3)) { drawPhase = .idle }
                }
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(result.won ? Color(red: 1.0, green: 0.85, blue: 0.3) : Color.purple)
                .clipShape(Capsule())
            }
            .padding(32)
            .background(Color(red: 0.05, green: 0.03, blue: 0.10))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.purple.opacity(0.4), lineWidth: 1))
            .shadow(color: .purple.opacity(0.3), radius: 30)
            .padding(.horizontal, 24)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
    }

    // MARK: - Logic

    private func conductDrawAnimation() {
        guard drawPhase == .idle else { return }
        isDrawing = true
        drawPhase = .drawing

        // Animate balls
        withAnimation(.spring()) { ballsAnimating = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring()) { ballsAnimating = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let (won, prize) = lottery.conductDraw()
            isDrawing = false
            let result = DrawResult(won: won, prize: prize, newJackpot: lottery.jackpot)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                drawResult = result
                drawPhase = .revealed
            }
        }
    }
}

#Preview {
    LotteryView()
        .preferredColorScheme(.dark)
}
