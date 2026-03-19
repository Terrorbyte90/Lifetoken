import SwiftUI

// MARK: - Lottery Manager

class LotteryManager: ObservableObject {
    static let shared = LotteryManager()

    @Published var jackpot: TimeInterval = 31_536_000
    @Published var ticketsBought: Int = 0
    @Published var lastDrawDate: Date? = nil
    @Published var lastWinner: String? = nil

    private let ticketCost: TimeInterval = 3_600

    private let jackpotKey  = "lottery_jackpot"
    private let lastDrawKey = "lottery_lastDraw"
    private let ticketsKey  = "lottery_tickets"

    private init() {
        let saved = UserDefaults.standard.double(forKey: jackpotKey)
        jackpot       = saved < 3_600 ? 31_536_000 : saved
        ticketsBought = UserDefaults.standard.integer(forKey: ticketsKey)
        lastDrawDate  = UserDefaults.standard.object(forKey: lastDrawKey) as? Date
    }

    func buyTickets(_ count: Int) -> Bool {
        let cost = ticketCost * Double(count)
        guard TimeEngine.shared.deductTime(cost) else { return false }
        ticketsBought += count
        jackpot       += cost * 0.70
        persist()
        return true
    }

    func conductDraw() -> (won: Bool, prize: TimeInterval) {
        let odds      = 500_000
        let winChance = Double(max(ticketsBought, 1)) / Double(odds)
        let won       = Double.random(in: 0...1) < winChance

        if won {
            let prize    = jackpot
            let taxRate  = GameState.shared.currentZone.taxRate
            let netPrize = prize * (1.0 - taxRate)
            TimeEngine.shared.addTime(netPrize)
            GameState.shared.recordEarning(netPrize)
            TransactionLedger.shared.record(label: "Tidslotteri — JACKPOT!", amount: netPrize)
            jackpot       = 31_536_000
            ticketsBought = 0
            UserDefaults.standard.set(Date(), forKey: lastDrawKey)
            lastDrawDate  = Date()
            persist()
            return (true, prize)
        } else {
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

    var nextDrawDate: Date {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.weekday = 1
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

    @State private var ticketCount: Int = 1
    @State private var isDrawing: Bool = false
    @State private var drawPhase: DrawPhase = .idle
    @State private var drawResult: DrawResult? = nil
    @State private var ballsAnimating: Bool = false
    @State private var pulseJackpot: Bool = false
    @State private var showConfetti: Bool = false

    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotif  = UINotificationFeedbackGenerator()

    enum DrawPhase { case idle, drawing, revealed }
    struct DrawResult { let won: Bool; let prize: TimeInterval; let newJackpot: TimeInterval }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.01, blue: 0.08), Color(red: 0.08, green: 0.02, blue: 0.12), Color.black],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            RadialGradient(
                colors: [Color.purple.opacity(0.15), .clear],
                center: .top, startRadius: 0, endRadius: 400
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: LTSpacing.xxl) {
                    lotteryHeader
                    jackpotDisplay
                    drawTimerCard
                    ticketPurchaseSection
                    drawSection
                    Spacer(minLength: LTSpacing.scrollBottom)
                }
            }

            if drawPhase == .revealed, let result = drawResult {
                drawResultOverlay(result)
            }

            if showConfetti {
                CasinoParticleView()
                    .environmentObject(ThemeEngine.shared)
            }
        }
    }

    // MARK: - Header

    private var lotteryHeader: some View {
        HStack {
            Button {
                hapticLight.impactOccurred()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(LTPressEffect())
            .accessibilityLabel("Stäng lotteriet")

            Spacer()
            VStack(spacing: 2) {
                Text("TIDSLOTERIET")
                    .font(LTFont.heading(16))
                    .foregroundColor(.white)
                    .tracking(4)
                Text(TimeEngine.shortFormatted(engine.balance))
                    .font(LTFont.body(10))
                    .foregroundColor(LTPalette.gold)
                    .contentTransition(.numericText())
                    .animation(LTAnimation.springFast, value: engine.balance)
            }
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
        .padding(.horizontal, LTSpacing.xl)
        .padding(.top, 54)
    }

    // MARK: - Jackpot

    private var jackpotDisplay: some View {
        VStack(spacing: LTSpacing.sm) {
            Text("JACKPOTT")
                .font(LTFont.label(9))
                .foregroundColor(.purple.opacity(0.7))
                .tracking(6)

            Text(TimeEngine.formatted(lottery.jackpot))
                .font(LTFont.value(30))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .shadow(color: Color.purple.opacity(pulseJackpot ? 0.5 : 0.2), radius: pulseJackpot ? 16 : 8)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseJackpot)
                .contentTransition(.numericText())
                .accessibilityLabel("Jackpott: \(TimeEngine.formatted(lottery.jackpot))")

            Text("≈ \(String(format: "%.1f", lottery.jackpot / 31_536_000)) år")
                .font(LTFont.heading(13))
                .foregroundColor(LTPalette.gold.opacity(0.8))

            HStack(spacing: LTSpacing.sm) {
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
                                .font(LTFont.caption(8))
                                .foregroundColor(.white)
                        )
                        .shadow(color: [Color.purple, Color.blue, Color.red, Color.orange, Color.green, Color.pink][i].opacity(0.4), radius: 6)
                        .scaleEffect(ballsAnimating ? 1.0 : 0.7)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(Double(i) * 0.06), value: ballsAnimating)
                }
            }
            .padding(.top, LTSpacing.xs)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LTSpacing.xxl)
        .padding(.horizontal, LTSpacing.xl)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.04, blue: 0.18), Color(red: 0.06, green: 0.02, blue: 0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.xl))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.xl).stroke(Color.purple.opacity(0.3), lineWidth: 1))
        .shadow(color: .purple.opacity(0.15), radius: 16, y: 6)
        .padding(.horizontal, LTSpacing.horizontal)
        .onAppear { pulseJackpot = true; ballsAnimating = true }
    }

    // MARK: - Draw timer

    private var drawTimerCard: some View {
        HStack(spacing: LTSpacing.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text("NÄSTA DRAGNING")
                    .font(LTFont.label(8))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
                Text("Söndag 20:00")
                    .font(LTFont.heading(13))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("OM")
                    .font(LTFont.label(8))
                    .foregroundColor(.white.opacity(0.35))
                    .tracking(2)
                Text(lottery.timeUntilDraw)
                    .font(LTFont.value(16))
                    .foregroundColor(.green)
                    .contentTransition(.numericText())
            }
        }
        .padding(LTSpacing.lg)
        .ltCard(radius: LTRadius.sm)
        .padding(.horizontal, LTSpacing.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nästa dragning söndag klockan 20:00, om \(lottery.timeUntilDraw)")
    }

    // MARK: - Ticket purchase

    private var ticketPurchaseSection: some View {
        VStack(alignment: .leading, spacing: LTSpacing.lg) {
            Text("KÖP LOTTER")
                .font(LTFont.label(9))
                .foregroundColor(.white.opacity(0.35))
                .tracking(3)
                .padding(.horizontal, LTSpacing.xs)

            HStack {
                Image(systemName: "ticket.fill")
                    .foregroundColor(lottery.ticketsBought > 0 ? .purple : .white.opacity(0.2))
                    .accessibilityHidden(true)
                Text("Dina lotter: \(lottery.ticketsBought)")
                    .font(LTFont.heading(14))
                    .foregroundColor(lottery.ticketsBought > 0 ? .purple : .white.opacity(0.4))
                    .contentTransition(.numericText())
                    .animation(LTAnimation.springFast, value: lottery.ticketsBought)
                Spacer()
                Text(String(format: "Odds: %.4f%%", Double(lottery.ticketsBought) / 5000.0))
                    .font(LTFont.body(10))
                    .foregroundColor(.white.opacity(0.3))
                    .contentTransition(.numericText())
                    .animation(LTAnimation.springFast, value: lottery.ticketsBought)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Du har \(lottery.ticketsBought) lotter. Odds: \(String(format: "%.4f", Double(lottery.ticketsBought) / 5000.0)) procent")

            // Quantity stepper
            HStack(spacing: 0) {
                Button {
                    if ticketCount > 1 {
                        hapticLight.impactOccurred()
                        withAnimation(LTAnimation.springFast) { ticketCount -= 1 }
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.06))
                }
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Minska antal lotter")

                Spacer()
                VStack(spacing: 2) {
                    Text("\(ticketCount)")
                        .font(LTFont.value(36))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(LTAnimation.springFast, value: ticketCount)
                    Text("lotter  ·  \(TimeEngine.shortFormatted(3600.0 * Double(ticketCount)))")
                        .font(LTFont.body(10))
                        .foregroundColor(LTPalette.gold.opacity(0.8))
                        .contentTransition(.numericText())
                        .animation(LTAnimation.springFast, value: ticketCount)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(ticketCount) lotter, kostnad \(TimeEngine.shortFormatted(3600.0 * Double(ticketCount)))")
                Spacer()

                Button {
                    if ticketCount < 100 {
                        hapticLight.impactOccurred()
                        withAnimation(LTAnimation.springFast) { ticketCount += 1 }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.06))
                }
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Öka antal lotter")
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))

            // Quick-pick
            HStack(spacing: LTSpacing.sm) {
                ForEach([1, 5, 10, 25, 50], id: \.self) { n in
                    Button {
                        hapticLight.impactOccurred()
                        withAnimation(LTAnimation.springFast) { ticketCount = n }
                    } label: {
                        Text("\(n)")
                            .font(LTFont.label(11))
                            .foregroundColor(ticketCount == n ? .black : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LTSpacing.sm)
                            .background(ticketCount == n ? Color.purple : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                    }
                    .buttonStyle(LTPressEffect())
                    .accessibilityLabel("\(n) lotter")
                    .accessibilityAddTraits(ticketCount == n ? .isSelected : [])
                }
            }

            let cost      = 3600.0 * Double(ticketCount)
            let canAfford = cost <= engine.balance

            buyButton(ticketCount: ticketCount, canAfford: canAfford)
        }
        .padding(LTSpacing.lg + 2)
        .ltCard(radius: LTRadius.md)
        .padding(.horizontal, LTSpacing.horizontal)
    }

    @ViewBuilder
    private func buyButton(ticketCount: Int, canAfford: Bool) -> some View {
        Button {
            if canAfford {
                hapticMedium.impactOccurred()
                if lottery.buyTickets(ticketCount) {
                    withAnimation(.spring()) { ballsAnimating = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring()) { ballsAnimating = true }
                    }
                }
            }
        } label: {
            HStack(spacing: LTSpacing.sm) {
                Image(systemName: "ticket.fill")
                    .accessibilityHidden(true)
                Text("KÖP \(ticketCount) LOTTER")
                    .font(LTFont.heading(14))
            }
            .foregroundColor(canAfford ? .white : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, LTSpacing.lg)
            .background(buyButtonGradient(canAfford: canAfford))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            .shadow(color: canAfford ? Color.purple.opacity(0.4) : .clear, radius: 12, y: 4)
        }
        .disabled(!canAfford)
        .buttonStyle(LTPressEffect())
        .accessibilityLabel("Köp \(ticketCount) lotter för \(TimeEngine.shortFormatted(3600.0 * Double(ticketCount)))")
        .accessibilityHint(canAfford ? "" : "Otillräcklig balans")
    }

    private func buyButtonGradient(canAfford: Bool) -> LinearGradient {
        if canAfford {
            return LinearGradient(
                colors: [Color.purple, Color(red: 0.5, green: 0.1, blue: 0.8)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: - Draw section

    private var drawSection: some View {
        VStack(spacing: LTSpacing.md) {
            Text("DRAGNING")
                .font(LTFont.label(9))
                .foregroundColor(.white.opacity(0.25))
                .tracking(3)

            Button {
                hapticMedium.impactOccurred()
                conductDrawAnimation()
            } label: {
                HStack(spacing: LTSpacing.sm) {
                    if isDrawing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    Text(isDrawing ? "Drar lotter..." : "Simulera veckodragning")
                        .font(LTFont.body(12))
                }
                .foregroundColor(.white.opacity(isDrawing ? 0.5 : 0.4))
            }
            .disabled(isDrawing || drawPhase != .idle)
            .buttonStyle(LTPressEffect())
            .accessibilityLabel(isDrawing ? "Dragning pågår" : "Simulera veckodragning")

            Text("Odds: 1 av 500 000 per lott  ·  70% av biljettintäkter till jackpott")
                .font(LTFont.caption(9))
                .foregroundColor(.white.opacity(0.2))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, LTSpacing.horizontal)
    }

    // MARK: - Draw result overlay

    private func drawResultOverlay(_ result: DrawResult) -> some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(LTAnimation.fade) { drawPhase = .idle }
                }

            VStack(spacing: LTSpacing.xxl) {
                if result.won {
                    Image(systemName: "star.fill")
                        .font(.system(size: 52))
                        .foregroundColor(LTPalette.gold)
                        .neonGlow(LTPalette.gold, intensity: 1.2)
                        .accessibilityHidden(true)
                    Text("DU VANN JACKPOTTEN!")
                        .font(LTFont.heading(20))
                        .foregroundColor(LTPalette.gold)
                        .shadow(color: .yellow.opacity(0.6), radius: 16)
                        .multilineTextAlignment(.center)
                    Text(TimeEngine.formatted(result.prize))
                        .font(LTFont.value(28))
                        .foregroundColor(.white)
                    Text("har krediterats ditt konto")
                        .font(LTFont.body(12))
                        .foregroundColor(.white.opacity(0.5))
                } else {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.purple.opacity(0.5))
                        .accessibilityHidden(true)
                    Text("Ingen vinst denna vecka")
                        .font(LTFont.heading(18))
                        .foregroundColor(.white)
                    Text("Jackpotten rullas över")
                        .font(LTFont.body(12))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Ny jackpott: \(TimeEngine.shortFormatted(result.newJackpot))")
                        .font(LTFont.heading(14))
                        .foregroundColor(.purple)
                        .contentTransition(.numericText())
                }

                Button("Stäng") {
                    hapticLight.impactOccurred()
                    withAnimation(LTAnimation.fade) { drawPhase = .idle }
                }
                .font(LTFont.heading(13))
                .foregroundColor(.black)
                .padding(.horizontal, LTSpacing.xxxl + LTSpacing.sm)
                .padding(.vertical, LTSpacing.md)
                .background(result.won ? LTPalette.gold : Color.purple)
                .clipShape(Capsule())
                .buttonStyle(LTPressEffect())
                .accessibilityLabel("Stäng resultat")
            }
            .padding(LTSpacing.xxxl)
            .background(Color(red: 0.05, green: 0.03, blue: 0.10))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xl))
            .overlay(RoundedRectangle(cornerRadius: LTRadius.xl).stroke(Color.purple.opacity(0.4), lineWidth: 1))
            .shadow(color: .purple.opacity(0.3), radius: 30)
            .padding(.horizontal, LTSpacing.xxl)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(result.won ? "Du vann jackpotten! \(TimeEngine.formatted(result.prize))" : "Ingen vinst denna vecka. Ny jackpott: \(TimeEngine.shortFormatted(result.newJackpot))")
        }
    }

    // MARK: - Logic

    private func conductDrawAnimation() {
        guard drawPhase == .idle else { return }
        isDrawing = true
        drawPhase = .drawing

        withAnimation(.spring()) { ballsAnimating = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring()) { ballsAnimating = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let (won, prize) = lottery.conductDraw()
            isDrawing = false
            hapticNotif.notificationOccurred(won ? .success : .warning)
            let result = DrawResult(won: won, prize: prize, newJackpot: lottery.jackpot)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                drawResult = result
                drawPhase = .revealed
            }
            if won {
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showConfetti = false }
            }
        }
    }
}

#Preview {
    LotteryView()
        .preferredColorScheme(.dark)
}
