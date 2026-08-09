import SwiftUI

// MARK: - Crash Game (Rocket Crash)

struct CrashView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    // Satsnings-tillstånd
    @State private var betAmount: TimeInterval = 1800
    @State private var phase: CrashPhase = .waiting

    // Speltillstånd
    @State private var multiplier: Double = 1.0
    @State private var crashPoint: Double = 1.0
    @State private var hasCashedOut: Bool = false
    @State private var cashedOutMultiplier: Double = 0
    @State private var history: [Double] = []

    // Animation
    @State private var gameTimer: Timer? = nil
    @State private var elapsed: Double = 0
    @State private var pathPoints: [(x: Double, y: Double)] = [(0, 0)]

    // Explosion-animation
    @State private var showExplosion: Bool = false
    @State private var explosionScale: CGFloat = 0.1
    @State private var explosionOpacity: Double = 0

    // Pulserande CASH OUT-knapp
    @State private var cashOutPulse: Bool = false

    // Resultat
    @State private var resultMessage: String = ""
    @State private var showResult: Bool = false
    @State private var showConfetti: Bool = false

    private let maxCrashMultiplier: Double = 25.0

    enum CrashPhase { case waiting, countdown, running, crashed }

    var body: some View {
        ZStack {
            // Svart rymdliknande bakgrund
            Color.black.ignoresSafeArea()

            // Subtil stjärnhimmel-effekt
            LinearGradient(
                colors: [Color(red: 0.01, green: 0.01, blue: 0.04), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                historyRow
                    .padding(.horizontal)
                    .padding(.top, 8)

                LTInfoCallout(
                    title: "Crashguide",
                    message: "Ju längre du väntar desto högre möjlig vinst, men raketen kan krascha när som helst.",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: .orange
                )
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Graf + multiplikatordisplay
                ZStack {
                    crashGraph
                        .padding(.horizontal, 16)

                    // Explosionsanimation vid krasch
                    if showExplosion {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.orange, Color.red.opacity(0.8), Color.red.opacity(0)],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .scaleEffect(explosionScale)
                            .opacity(explosionOpacity)
                    }

                    VStack {
                        if phase == .crashed && !hasCashedOut {
                            VStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.orange)
                                Text("KRASCH!")
                                    .font(.system(size: 36, weight: .black, design: .monospaced))
                                    .foregroundColor(.red)
                                    .shadow(color: .red.opacity(0.8), radius: 16)
                                Text(String(format: "@ %.2fx", crashPoint))
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        } else {
                            // Stor multiplikatordisplay
                            VStack(spacing: 2) {
                                Image(systemName: "rocket.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(multiplierDisplayColor)
                                    .opacity(phase == .running ? 1.0 : 0.4)
                                Text(String(format: "%.2fx", multiplier))
                                    .font(.system(size: 60, weight: .black, design: .monospaced))
                                    .foregroundColor(multiplierDisplayColor)
                                    .shadow(color: multiplierDisplayColor.opacity(0.7), radius: 14)
                                    .monospacedDigit()
                                    .contentTransition(.numericText(value: multiplier))
                            }
                        }
                    }
                }

                Spacer()

                // Kontroller
                controlSection
                    .padding(.horizontal)
                    .padding(.bottom, 30)
            }
        }
        .alert("Resultat", isPresented: $showResult) {
            Button("OK") { resetGame() }
        } message: { Text(resultMessage) }
        .onDisappear { stopTimer() }
        .overlay {
            if showConfetti {
                CasinoParticleView()
                    .environmentObject(ThemeEngine.shared)
            }
        }
    }

    // MARK: - Multiplier-färg

    var multiplierDisplayColor: Color {
        if phase == .crashed { return .red }
        if multiplier >= 5.0  { return Color(red: 0.2, green: 1.0, blue: 0.4) }
        if multiplier >= 2.0  { return Color(red: 0.6, green: 1.0, blue: 0.2) }
        return .yellow
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("ROCKET CRASH")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("Hus ~5%")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.6))
            }
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.yellow.opacity(0.1))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.yellow.opacity(0.25), lineWidth: 1))
        }
        .padding()
        .padding(.top, 20)
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Historikrad med smådots

    private var historyRow: some View {
        Group {
            if history.isEmpty {
                LTEmptyStateCard(
                    icon: "clock.arrow.circlepath",
                    title: "Ingen historik ännu",
                    message: "Starta en runda för att se senaste kraschpunkter här.",
                    tint: .white
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("HISTORIK")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(.white.opacity(0.25))
                            .tracking(3)
                        ForEach(Array(history.suffix(12).reversed().enumerated()), id: \.offset) { _, pt in
                            VStack(spacing: 2) {
                                // Liten dot vars färg indikerar kraschpunkten
                                Circle()
                                    .fill(historyDotColor(pt))
                                    .frame(width: 6, height: 6)
                                    .shadow(color: historyDotColor(pt).opacity(0.6), radius: 3)
                                Text(String(format: "%.2fx", pt))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(historyDotColor(pt))
                            }
                            .padding(.horizontal, 5)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .frame(height: 36)
            }
        }
    }

    private func historyDotColor(_ pt: Double) -> Color {
        if pt < 1.5 { return .red }
        if pt < 3.0 { return .yellow }
        return Color(red: 0.2, green: 1.0, blue: 0.4)
    }

    // MARK: - Kraschgraf

    private func gridPath(size: CGSize) -> Path {
        var path = Path()
        let w = size.width; let h = size.height
        for i in 0...4 {
            let y = h - (h * Double(i) / 4)
            path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: w, y: y))
        }
        for i in 0...4 {
            let x = w * Double(i) / 4
            path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: h))
        }
        return path
    }

    private func crashLinePath(size: CGSize) -> Path {
        var path = Path()
        guard pathPoints.count > 1 else { return path }
        let w = size.width; let h = size.height
        let maxX = max(elapsed, 1); let maxY = max(multiplier, 2)
        let first = pathPoints[0]
        path.move(to: CGPoint(x: first.x / maxX * w, y: h - first.y / maxY * h))
        for pt in pathPoints.dropFirst() {
            path.addLine(to: CGPoint(x: pt.x / maxX * w, y: h - pt.y / maxY * h))
        }
        return path
    }

    private func cashOutY(height: CGFloat) -> CGFloat {
        let maxY = max(multiplier, 2)
        return height - cashedOutMultiplier / maxY * height
    }

    private var crashGraph: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                gridPath(size: geo.size)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)

                if pathPoints.count > 1 {
                    let lineColor: Color = phase == .crashed ? .red : Color(red: 0.2, green: 1.0, blue: 0.4)
                    crashLinePath(size: geo.size)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .shadow(color: lineColor.opacity(0.4), radius: 6)
                }

                if hasCashedOut {
                    let y = cashOutY(height: geo.size.height)
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.yellow.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    .shadow(color: .yellow.opacity(0.4), radius: 4)

                    Text(String(format: "%.2fx", cashedOutMultiplier))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .position(x: 35, y: max(12, y - 12))
                }
            }
        }
        .frame(height: 200)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Kontroller

    private var controlSection: some View {
        VStack(spacing: 14) {
            switch phase {
            case .waiting, .crashed:
                waitingControls
            case .countdown:
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.yellow)
                    Text("STARTAR RAKETEN...")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                .padding(.vertical, 20)
            case .running:
                cashOutButton
            }
        }
    }

    private var waitingControls: some View {
        VStack(spacing: 14) {
            HStack {
                Text("INSATS:")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Text(TimeEngine.shortFormatted(betAmount))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.4), radius: 6)
                Spacer()
            }

            Slider(value: $betAmount, in: 60...max(120, min(engine.balance, 86400 * 7)), step: 60)
                .tint(Color(red: 0.2, green: 1.0, blue: 0.4))

            HStack(spacing: 8) {
                ForEach([600.0, 1800.0, 3600.0, 21600.0, 86400.0], id: \.self) { v in
                    Button { betAmount = min(v, engine.balance) } label: {
                        Text(TimeEngine.shortFormatted(v))
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                    }
                }
            }

            LTInfoCallout(
                title: "Cash out",
                message: "Tryck ut tidigt för säkrare utfall. Väntar du längre ökar vinsten men också risken för total förlust.",
                icon: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90",
                tint: .red
            )

            Button { startRound() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rocket.fill")
                        .font(.system(size: 16))
                    Text("STARTA  (\(TimeEngine.shortFormatted(betAmount)))")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                }
                .foregroundColor(betAmount <= engine.balance ? .black : .white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    betAmount <= engine.balance
                        ? LinearGradient(
                            colors: [Color(red: 0.2, green: 1.0, blue: 0.4), Color(red: 0.1, green: 0.7, blue: 0.25)],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                        : LinearGradient(colors: [Color(white: 0.2), Color(white: 0.15)], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(
                    color: betAmount <= engine.balance ? Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.4) : .clear,
                    radius: 12, y: 4
                )
            }
            .disabled(betAmount > engine.balance)
        }
    }

    // Stor, pulserande röd CASH OUT-knapp
    private var cashOutButton: some View {
        VStack(spacing: 10) {
            if hasCashedOut {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    Text("CASHAD UT!")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text("@ \(String(format: "%.2fx", cashedOutMultiplier))")
                        .font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red: 0.2, green: 1.0, blue: 0.4))
                        .shadow(color: Color(red: 0.2, green: 1.0, blue: 0.4).opacity(0.5), radius: 8)
                }
                .padding(18)
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
                .shadow(color: .green.opacity(0.2), radius: 12)
            } else {
                Button { cashOut() } label: {
                    VStack(spacing: 6) {
                        Text("CASH OUT")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                        Text("+\(TimeEngine.shortFormatted(betAmount * multiplier))")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.85, green: 0.1, blue: 0.1), Color(red: 0.6, green: 0.05, blue: 0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                    )
                    // Pulserande glöd-effekt
                    .shadow(color: .red.opacity(cashOutPulse ? 0.7 : 0.3), radius: cashOutPulse ? 20 : 10, y: 4)
                    .scaleEffect(cashOutPulse ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: cashOutPulse)
                }
                .buttonStyle(LTPressEffect(scale: 0.96))
                .onAppear { cashOutPulse = true }
                .onDisappear { cashOutPulse = false }
            }
        }
    }

    // MARK: - Spellogik

    func startRound() {
        guard phase == .waiting || phase == .crashed else { return }
        guard betAmount > 0 else { return }
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        multiplier = 1.0
        elapsed = 0
        hasCashedOut = false
        cashedOutMultiplier = 0
        pathPoints = [(0, 1)]
        crashPoint = generateCrashPoint()
        showExplosion = false
        phase = .countdown

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .running
            cashOutPulse = true
            startTimer()
        }
    }

    func generateCrashPoint() -> Double {
        // Exponentialfördelning med ~5% husfördel
        // P(crash > x) = 0.95/x för x >= 1
        let r = Double.random(in: 0..<1)
        if r < 0.05 { return 1.0 }
        return min(maxCrashMultiplier, max(1.0, 0.95 / r))
    }

    func startTimer() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                guard phase == .running else { return }
                elapsed += 0.1
                multiplier = pow(1.06, elapsed)
                pathPoints.append((elapsed, multiplier))

                if multiplier >= crashPoint {
                    triggerCrash()
                }
            }
        }
    }

    func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    func cashOut() {
        guard phase == .running, !hasCashedOut else { return }
        hasCashedOut = true
        cashedOutMultiplier = multiplier
        cashOutPulse = false

        let gross = betAmount * cashedOutMultiplier
        let taxRate = gameState.currentZone.taxRate
        let net = gross * (1 - taxRate)
        TimeEngine.shared.addTime(net)
        GameState.shared.recordEarning(net - betAmount)
        MissionsManager.incrementProgress("casino_total_wins")
        TransactionLedger.shared.record(
            label: "Crash — cash out \(String(format: "%.2fx", cashedOutMultiplier))",
            amount: net - betAmount
        )

        showConfetti = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showConfetti = false }
    }

    func triggerCrash() {
        stopTimer()
        cashOutPulse = false
        phase = .crashed
        history.append(crashPoint)

        // Explosionsanimation — skalar upp och tonar ut
        if !hasCashedOut {
            showExplosion = true
            withAnimation(.easeOut(duration: 0.4)) {
                explosionScale = 1.8
                explosionOpacity = 0.9
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.4)) {
                explosionOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showExplosion = false
                explosionScale = 0.1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if hasCashedOut {
                let gross = betAmount * cashedOutMultiplier
                let taxRate = gameState.currentZone.taxRate
                let net = gross * (1 - taxRate)
                resultMessage = "Cash out @ \(String(format: "%.2fx", cashedOutMultiplier))\n+\(TimeEngine.shortFormatted(net - betAmount)) vinst (efter skatt)\nKraschpunkt: \(String(format: "%.2fx", crashPoint))"
            } else {
                TransactionLedger.shared.record(label: "Crash — förlust", amount: -betAmount)
                resultMessage = "KRASCH @ \(String(format: "%.2fx", crashPoint))\nFörlorade \(TimeEngine.shortFormatted(betAmount))."
            }
            showResult = true
        }
    }

    func resetGame() {
        phase = .waiting
        multiplier = 1.0
        elapsed = 0
        hasCashedOut = false
        pathPoints = [(0, 1)]
        showExplosion = false
        explosionScale = 0.1
        explosionOpacity = 0
        cashOutPulse = false
    }

    var statusMessage: String {
        switch phase {
        case .waiting:   return ""
        case .countdown: return "Väntar..."
        case .running:   return hasCashedOut ? "Cashad ut — väntar på krasch" : "Kör..."
        case .crashed:   return "Krasch!"
        }
    }
}

#Preview {
    CrashView()
        .preferredColorScheme(.dark)
}
