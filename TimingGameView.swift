import SwiftUI

// MARK: - Tidskalibratorn

struct TimingGameView: View {
    let difficulty: Int
    @Environment(\.dismiss) var dismiss

    // Config per difficulty: [Enkel, Medel, Svår, Expert]
    private let zoneDegrees:  [Double] = [60, 35, 18, 8]
    private let speedRPS:     [Double] = [0.6, 1.0, 1.6, 2.4]  // rotations/sec
    private let roundCounts:  [Int]    = [3, 3, 4, 5]
    private let timeLimits:   [Int]    = [90, 90, 90, 90]
    private let rewards = [
        (best:8,  normal:5,  worse:2),
        (best:14, normal:9,  worse:4),
        (best:22, normal:14, worse:7),
        (best:37, normal:24, worse:12),
    ]

    private var zoneWidth:   Double { zoneDegrees[difficulty] }
    private var speed:       Double { speedRPS[difficulty] }
    private var totalRounds: Int    { roundCounts[difficulty] }
    private var reward:      (best:Int,normal:Int,worse:Int) { rewards[difficulty] }

    // Game state
    enum Phase { case ready, playing, result(earned: TimeInterval) }
    @State private var phase:        Phase = .ready
    @State private var gameStart:    Date  = .init()
    @State private var needleAngle:  Double = 0
    @State private var currentRound: Int   = 0
    @State private var deviations:   [Double] = []
    @State private var lastLabel:    String = ""
    @State private var lastColor:    Color  = .white
    @State private var showLabel:    Bool   = false
    @State private var flashRing:    Bool   = false
    @State private var flashSuccess: Bool   = false
    @State private var timeLeft:     Int    = 90
    @State private var speedVariation: Double = 0

    // Timers
    @State private var renderTimer   = Timer.publish(every: 1/60.0, on: .main, in: .common).autoconnect()
    @State private var countdown     = Timer.publish(every: 1,      on: .main, in: .common).autoconnect()

    // Target at 12 o'clock. targetDeg = visual degrees CW from 12 o'clock.
    // Arc center in trim coords: (targetDeg/360 + 0.75) % 1 (no rotationEffect needed).
    // Hit detection uses (needleAngle - 90) % 360 to get visual angle.
    private let targetDeg: Double = 0  // 0 = 12 o'clock

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Subtle scanlines
            GeometryReader { g in
                Canvas { ctx, sz in
                    for y in stride(from: 0.0, to: sz.height, by: 3) {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: sz.width, height: 1)),
                                 with: .color(Color.cyan.opacity(0.018)))
                    }
                }.ignoresSafeArea()
            }

            switch phase {
            case .ready:   readyScreen
            case .playing: playingScreen
            case .result(let e): resultScreen(earned: e)
            }
        }
        .onReceive(renderTimer) { _ in
            guard case .playing = phase else { return }
            updateNeedle()
        }
        .onReceive(countdown) { _ in
            guard case .playing = phase else { return }
            timeLeft = max(0, timeLeft - 1)
            if timeLeft == 0 { finishGame() }
        }
    }

    // MARK: - Ready Screen

    private var readyScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Text("TIDSKALIBRATORN")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .tracking(5)
                Text(["ENKEL","MEDEL","SVÅR","EXPERT"][difficulty])
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .tracking(4)
            }

            // Preview dial
            dialView(size: 220, interactive: false)

            // Info
            VStack(spacing: 10) {
                infoRow("Träffzon", "\(Int(zoneWidth))°", .cyan)
                infoRow("Rundor", "\(totalRounds)", .white)
                infoRow("Max lön", "\(reward.best) min", .cyan)
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cyan.opacity(0.15), lineWidth: 1))
            .padding(.horizontal, 40)

            Button(action: startGame) {
                Text("STARTA KALIBRERING")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            Button("Avbryt") { dismiss() }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white: 0.3))

            Spacer()
        }
    }

    // MARK: - Playing Screen

    private var playingScreen: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RUNDA \(currentRound + 1) / \(totalRounds)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                    Text("TRYCKT PÅ RÄTT ÖGONBLICK")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Color(white: 0.25))
                        .tracking(2)
                }
                Spacer()
                Text("\(timeLeft)s")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(timeLeft < 10 ? .red : .yellow)
            }
            .padding(.horizontal, 28)
            .padding(.top, 60)
            .padding(.bottom, 20)

            // Label
            ZStack {
                Text(showLabel ? lastLabel : " ")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(lastColor)
                    .opacity(showLabel ? 1 : 0)
                    .scaleEffect(showLabel ? 1 : 0.8)
                    .animation(.spring(response: 0.25), value: showLabel)
            }
            .frame(height: 36)
            .padding(.bottom, 16)

            // Dial
            GeometryReader { g in
                dialView(size: min(g.size.width - 48, g.size.height - 40), interactive: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Round pips
            HStack(spacing: 10) {
                ForEach(0..<totalRounds, id: \.self) { i in
                    Circle()
                        .fill(pipColor(for: i))
                        .frame(width: 9, height: 9)
                        .scaleEffect(i == currentRound ? 1.3 : 1)
                        .animation(.spring(), value: currentRound)
                }
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func dialView(size: CGFloat, interactive: Bool) -> some View {
        ZStack {
            // ── Outer glow ring
            Circle()
                .stroke(Color.cyan.opacity(0.06), lineWidth: 24)
                .frame(width: size, height: size)

            // ── Outer ring
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 2)
                .frame(width: size, height: size)

            // ── Tick marks
            ForEach(0..<60, id: \.self) { i in
                let isMajor = i % 5 == 0
                Rectangle()
                    .fill(Color.white.opacity(isMajor ? 0.3 : 0.1))
                    .frame(width: isMajor ? 2 : 1, height: isMajor ? 14 : 7)
                    .offset(y: -(size/2 - (isMajor ? 10 : 7)))
                    .rotationEffect(.degrees(Double(i) * 6))
            }

            // ── Target zone arc (glowing cyan)
            // Trim center: (targetDeg/360 + 0.75) % 1.0 maps 0° → 0.75 (12 o'clock, no rotation)
            let center = ((targetDeg / 360.0) + 0.75).truncatingRemainder(dividingBy: 1.0)
            let halfW  = zoneWidth / 2.0 / 360.0
            let startA = center - halfW
            let endA   = center + halfW

            // Glow
            Circle()
                .trim(from: startA, to: endA)
                .stroke(Color.cyan.opacity(0.15), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .frame(width: size - 8, height: size - 8)

            // Solid arc
            Circle()
                .trim(from: startA, to: endA)
                .stroke(
                    LinearGradient(colors: [.cyan.opacity(0.4), .cyan, .cyan.opacity(0.4)],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: size - 8, height: size - 8)

            // ── Flash ring on tap
            if flashRing {
                Circle()
                    .stroke(flashSuccess ? Color.cyan : Color.red, lineWidth: 3)
                    .frame(width: size - 4, height: size - 4)
                    .opacity(flashRing ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: flashRing)
            }

            // ── Needle
            ZStack {
                // Shadow
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 8, height: size * 0.44)
                    .offset(y: -(size * 0.22))

                // Main needle
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white, Color.white.opacity(0.6)],
                        startPoint: .bottom, endPoint: .top)
                    )
                    .frame(width: 3, height: size * 0.42)
                    .offset(y: -(size * 0.21))

                // Needle tip glow
                Circle()
                    .fill(Color.white)
                    .frame(width: 5, height: 5)
                    .offset(y: -(size * 0.42))

                // Center hub
                Circle()
                    .fill(Color.black)
                    .frame(width: 16, height: 16)
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: 16, height: 16)
            }
            .rotationEffect(.degrees(needleAngle - 90))
            .animation(interactive ? nil : .linear(duration: 0.016), value: needleAngle)
        }
        .frame(width: size, height: size)
        .if(interactive) { v in
            v.onTapGesture { handleTap() }
        }
    }

    // MARK: - Result Screen

    private func resultScreen(earned: TimeInterval) -> some View {
        let avgDev = deviations.isEmpty ? 999.0 : deviations.reduce(0,+) / Double(deviations.count)
        return VStack(spacing: 24) {
            Spacer()

            Text("KALIBRERING AVSLUTAD")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .tracking(3)

            // Round results
            VStack(spacing: 8) {
                ForEach(Array(deviations.enumerated()), id: \.offset) { i, dev in
                    HStack {
                        Text("Runda \(i+1):")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(white: 0.45))
                        Spacer()
                        Text(dev < 0.002 ? "PERFEKT" : "±\(Int(dev * 1000))ms")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(devColor(dev))
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1))
            .padding(.horizontal, 32)

            // Average
            Text("Snitt: ±\(Int(avgDev * 1000))ms")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(white: 0.45))

            // Payout
            if earned > 0 {
                VStack(spacing: 4) {
                    Text("+\(TimeEngine.shortFormatted(earned))")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                    Text("tillagd på ditt konto (efter skatt)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                }
            } else if earned < 0 {
                VStack(spacing: 4) {
                    Text("−\(TimeEngine.shortFormatted(abs(earned)))")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                    Text("avdragen — precision otillräcklig")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(white: 0.35))
                }
            } else {
                Text("Precision otillräcklig. Noll lön.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(white: 0.35))
            }

            Button("Stäng") { dismiss() }
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color.cyan)
                .clipShape(Capsule())

            Spacer()
        }
    }

    // MARK: - Logic

    private func startGame() {
        timeLeft  = timeLimits[difficulty]
        gameStart = Date()
        currentRound = 0
        deviations = []
        showLabel = false
        needleAngle = Double.random(in: 0...360)
        phase = .playing
    }

    private func updateNeedle() {
        let elapsed = Date().timeIntervalSince(gameStart)
        let deg = elapsed * speed * 360
        // Add sinusoidal variation for harder levels
        let variation = difficulty >= 2 ? sin(elapsed * 1.3) * Double(difficulty) * 8 : 0
        needleAngle = (deg + variation).truncatingRemainder(dividingBy: 360)
        if needleAngle < 0 { needleAngle += 360 }
    }

    private func handleTap() {
        guard case .playing = phase, currentRound < totalRounds else { return }

        // Convert needleAngle to visual clock position (degrees CW from 12 o'clock)
        // Needle is drawn with rotationEffect(needleAngle - 90), so visual = needleAngle - 90
        var a = (needleAngle - 90).truncatingRemainder(dividingBy: 360)
        if a < 0 { a += 360 }

        // Deviation from target (degrees CW from 12 o'clock)
        var dev = abs(a - targetDeg)
        if dev > 180 { dev = 360 - dev }

        // Convert to time (seconds)
        let devTime = dev / 360.0 * (1.0 / speed)
        deviations.append(devTime)

        let isHit = dev <= zoneWidth / 2
        let label: String
        let col:   Color
        if dev <= zoneWidth * 0.2 {
            label = "PERFEKT"; col = .cyan
        } else if isHit {
            label = "BRA"; col = .green
        } else if dev <= zoneWidth * 1.5 {
            label = "NÄRA"; col = .yellow
        } else {
            label = "MISS"; col = .red
        }
        lastLabel = label; lastColor = col
        flashSuccess = isHit
        withAnimation { showLabel = true; flashRing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { showLabel = false; flashRing = false }
        }

        currentRound += 1
        if currentRound >= totalRounds {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { finishGame() }
        }
    }

    private func finishGame() {
        guard case .playing = phase else { return }
        let earned = calcEarnings()
        let zone   = GameState.shared.currentZone
        var net: TimeInterval
        if earned > 0 {
            awardMiniJobEarnings(minutes: earned)
            net = TimeInterval(earned * 60) * zone.workMultiplier * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
        } else {
            // 30% penalty of best reward for bad calibration
            let penaltyMin = max(1, Int(Double(reward.best) * 0.30))
            penalizeMiniJob(minutes: penaltyMin)
            net = -TimeInterval(penaltyMin * 60)  // negative = penalty for display
        }
        phase = .result(earned: net)
    }

    private func calcEarnings() -> Int {
        guard !deviations.isEmpty else { return 0 }
        let avgDev = deviations.reduce(0,+) / Double(deviations.count)
        let period = 1.0 / speed
        let perfect = period * (zoneWidth * 0.2) / 360
        let good    = period * (zoneWidth * 0.6) / 360
        let ok      = period * zoneWidth / 360
        if avgDev <= perfect { return reward.best }
        if avgDev <= good    { return reward.normal }
        if avgDev <= ok      { return reward.worse }
        return 0
    }

    private func devColor(_ dev: Double) -> Color {
        let period = 1.0 / speed
        let zone   = period * zoneWidth / 360
        if dev <= zone * 0.2 { return .cyan }
        if dev <= zone * 0.6 { return .green }
        if dev <= zone       { return .yellow }
        return .red
    }

    private func pipColor(for index: Int) -> Color {
        if index >= deviations.count { return index == currentRound ? .white : Color(white:0.2) }
        return devColor(deviations[index])
    }

    private func infoRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white: 0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

// MARK: - View extension helper
private extension View {
    @ViewBuilder func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}
