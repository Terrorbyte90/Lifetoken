import SwiftUI

// MARK: - Crash Game

struct CrashView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    // Betting state
    @State private var betAmount: TimeInterval = 1800
    @State private var phase: CrashPhase = .waiting

    // Game state
    @State private var multiplier: Double = 1.0
    @State private var crashPoint: Double = 1.0
    @State private var hasCashedOut: Bool = false
    @State private var cashedOutMultiplier: Double = 0
    @State private var history: [Double] = []

    // Animation
    @State private var gameTimer: Timer? = nil
    @State private var elapsed: Double = 0
    @State private var pathPoints: [(x: Double, y: Double)] = [(0, 0)]

    // Result
    @State private var resultMessage: String = ""
    @State private var showResult: Bool = false

    enum CrashPhase { case waiting, countdown, running, crashed }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.02, blue: 0.06), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                historyRow
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer()

                // Graph + multiplier display
                ZStack {
                    crashGraph
                        .padding(.horizontal, 16)

                    VStack {
                        if phase == .crashed && !hasCashedOut {
                            Text("KRASCH!")
                                .font(.system(size: 36, weight: .black, design: .monospaced))
                                .foregroundColor(.red)
                                .shadow(color: .red.opacity(0.6), radius: 12)
                        } else {
                            Text(String(format: "%.2fx", multiplier))
                                .font(.system(size: 48, weight: .black, design: .monospaced))
                                .foregroundColor(multiplierColor)
                                .shadow(color: multiplierColor.opacity(0.5), radius: 8)
                                .monospacedDigit()
                        }
                    }
                }

                Spacer()

                // Controls
                controlSection
                    .padding(.horizontal)
                    .padding(.bottom, 30)
            }
        }
        .alert("Resultat", isPresented: $showResult) {
            Button("OK") { resetGame() }
        } message: { Text(resultMessage) }
        .onDisappear { stopTimer() }
    }

    // MARK: Header
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
            Text("CRASH")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.yellow)
        }
        .padding()
        .padding(.top, 20)
    }

    // MARK: History Row
    private var historyRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("Historia:")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                ForEach(history.suffix(10).reversed(), id: \.self) { pt in
                    Text(String(format: "%.2fx", pt))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(pt < 1.5 ? .red : (pt < 3.0 ? .yellow : .green))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(height: 28)
    }

    // MARK: Crash Graph
    private var crashGraph: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                // Background grid
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    for i in 0...4 {
                        let y = h - (h * Double(i) / 4)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 1)

                // Crash line
                if pathPoints.count > 1 {
                    Path { path in
                        let w = geo.size.width
                        let h = geo.size.height
                        let maxX = max(elapsed, 1)
                        let maxY = max(multiplier, 2)

                        let firstPt = pathPoints[0]
                        path.move(to: CGPoint(
                            x: firstPt.x / maxX * w,
                            y: h - firstPt.y / maxY * h
                        ))
                        for pt in pathPoints.dropFirst() {
                            path.addLine(to: CGPoint(
                                x: pt.x / maxX * w,
                                y: h - pt.y / maxY * h
                            ))
                        }
                    }
                    .stroke(
                        phase == .crashed ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                }

                // Cash out line (horizontal)
                if hasCashedOut {
                    let h = geo.size.height
                    let w = geo.size.width
                    let maxY = max(multiplier, 2)
                    let y = h - cashedOutMultiplier / maxY * h
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(Color.yellow.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))

                    Text(String(format: "%.2fx", cashedOutMultiplier))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.yellow)
                        .position(x: 30, y: y - 10)
                }
            }
        }
        .frame(height: 180)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Controls
    private var controlSection: some View {
        VStack(spacing: 14) {
            switch phase {
            case .waiting, .crashed:
                waitingControls
            case .countdown:
                Text("Startar...")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            case .running:
                cashOutButton
            }
        }
    }

    private var waitingControls: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Insats: \(TimeEngine.shortFormatted(betAmount))")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.yellow)
                Spacer()
            }

            Slider(value: $betAmount, in: 60...max(60, min(engine.balance, 86400 * 7)), step: 60)
                .accentColor(.green)

            HStack(spacing: 8) {
                ForEach([600.0, 1800.0, 3600.0, 21600.0, 86400.0], id: \.self) { v in
                    Button { betAmount = min(v, engine.balance) } label: {
                        Text(TimeEngine.shortFormatted(v))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
                    }
                }
            }

            Button { startRound() } label: {
                Text("STARTA  (\(TimeEngine.shortFormatted(betAmount)))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(betAmount <= engine.balance ? Color.green : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(betAmount > engine.balance)
        }
    }

    private var cashOutButton: some View {
        VStack(spacing: 8) {
            if hasCashedOut {
                VStack(spacing: 4) {
                    Text("CASHAD UT!")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                    Text("@ \(String(format: "%.2fx", cashedOutMultiplier))")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(16)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Button { cashOut() } label: {
                    VStack(spacing: 4) {
                        Text("CASH OUT")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                        Text("+\(TimeEngine.shortFormatted(betAmount * multiplier))")
                            .font(.system(size: 13, design: .monospaced))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    // MARK: Computed color
    var multiplierColor: Color {
        if phase == .crashed { return .red }
        if multiplier < 2.0 { return .green }
        if multiplier < 5.0 { return .yellow }
        return Color(red: 1, green: 0.5, blue: 0)
    }

    // MARK: - Game Logic

    func startRound() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        multiplier = 1.0
        elapsed = 0
        hasCashedOut = false
        cashedOutMultiplier = 0
        pathPoints = [(0, 1)]
        crashPoint = generateCrashPoint()
        phase = .countdown

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .running
            startTimer()
        }
    }

    func generateCrashPoint() -> Double {
        // Exponential distribution with house edge ~5%
        // P(crash > x) = 0.95/x for x >= 1
        let r = Double.random(in: 0..<1)
        if r < 0.05 { return 1.0 }
        return max(1.0, 0.95 / r)
    }

    func startTimer() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            DispatchQueue.main.async {
                elapsed += 0.1
                // Multiplier grows exponentially
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

        let gross = betAmount * cashedOutMultiplier
        let taxRate = gameState.currentZone.taxRate
        let net = gross * (1 - taxRate)
        TimeEngine.shared.addTime(net)
        GameState.shared.recordEarning(net - betAmount)
    }

    func triggerCrash() {
        stopTimer()
        phase = .crashed
        history.append(crashPoint)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if hasCashedOut {
                let gross = betAmount * cashedOutMultiplier
                let taxRate = gameState.currentZone.taxRate
                let net = gross * (1 - taxRate)
                resultMessage = "Cash out @ \(String(format: "%.2fx", cashedOutMultiplier))\n+\(TimeEngine.shortFormatted(net - betAmount)) vinst (efter skatt)\nKraschpunkt: \(String(format: "%.2fx", crashPoint))"
            } else {
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
    }

    var statusMessage: String {
        switch phase {
        case .waiting: return ""
        case .countdown: return "Väntar..."
        case .running: return hasCashedOut ? "Cashad ut — väntar på krasch" : "Kör..."
        case .crashed: return "Krasch!"
        }
    }
}

#Preview {
    CrashView()
        .preferredColorScheme(.dark)
}
