import SwiftUI

// MARK: - Sprängämnesexperten

struct BombDefuseView: View {
    let difficulty: Int
    @Environment(\.dismiss) var dismiss

    // Config [Enkel, Medel, Svår, Expert]
    private let wireCountCfg:  [Int]    = [3, 4, 5, 6]
    private let timeLimits:    [Int]    = [20, 15, 12, 8]
    private let clueShowTime:  [Double] = [5, 5, 5, 5]
    private let rewards = [
        (early:10, normal:6,  penalty:5),
        (early:17, normal:10, penalty:10),
        (early:30, normal:17, penalty:20),
        (early:50, normal:30, penalty:40),
    ]

    private var wireCount: Int { wireCountCfg[difficulty] }
    private var timeLimit: Int { timeLimits[difficulty] }
    private var reward:    (early:Int,normal:Int,penalty:Int) { rewards[difficulty] }

    // Wire colors
    private let wireColors: [Color] = [
        Color(red:0.9,green:0.2,blue:0.2),  // röd
        Color(red:0.2,green:0.4,blue:1.0),  // blå
        Color(red:0.2,green:0.85,blue:0.2), // grön
        Color(red:0.95,green:0.85,blue:0.1),// gul
        Color(red:0.9,green:0.5,blue:0.1),  // orange
        Color(red:0.7,green:0.2,blue:0.9),  // lila
    ]
    private let wireNames = ["röda","blåa","gröna","gula","orangea","lila"]

    enum Phase { case ready, clueShowing, playing, result(won: Bool, early: Bool, earned: TimeInterval) }

    @State private var phase:       Phase  = .ready
    @State private var correctWire: Int    = 0
    @State private var cutWire:     Int?   = nil
    @State private var timeLeft:    Int    = 20
    @State private var clueLeft:    Double = 5
    @State private var clue:        String = ""
    @State private var wiresCut:    Set<Int> = []
    @State private var clueFade:    Double = 1
    @State private var sparkPos:       CGPoint = .zero
    @State private var showSpark:      Bool    = false
    @State private var bombShake:      CGFloat = 0
    @State private var cutFlashWire:   Int?    = nil   // wire index showing flash
    @State private var sparkParticles: [(id: UUID, angle: Double, dist: CGFloat, opacity: Double)] = []
    @State private var wireDropOffset: [Int: CGFloat] = [:]  // extra y-drop per wire half

    @State private var timer     = Timer.publish(every: 1,    on: .main, in: .common).autoconnect()
    @State private var clueTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Dark circuit board background
            Color(red: 0.03, green: 0.04, blue: 0.03).ignoresSafeArea()
            circuitPattern.ignoresSafeArea()

            switch phase {
            case .ready:                      readyScreen
            case .clueShowing:                clueScreen
            case .playing:                    playScreen
            case .result(let w, let e, let earned): resultScreen(won: w, early: e, earned: earned)
            }
        }
        .onReceive(timer) { _ in
            switch phase {
            case .playing:
                if timeLeft > 0 { timeLeft -= 1 }
                else { handleTimeout() }
            default: break
            }
        }
        .onReceive(clueTimer) { _ in
            if case .clueShowing = phase {
                clueLeft = max(0, clueLeft - 0.05)
                if clueLeft <= 1.5 {
                    withAnimation(.easeIn(duration: 1.5)) { clueFade = 0 }
                }
                if clueLeft <= 0 {
                    withAnimation { phase = .playing }
                }
            }
        }
        .offset(x: bombShake)
    }

    // MARK: - Circuit board background

    private var circuitPattern: some View {
        Canvas { ctx, size in
            let s = stride(from: 0.0, to: max(size.width, size.height), by: 48)
            for x in s {
                for y in s {
                    let r = CGRect(x: x, y: y, width: 2, height: 2)
                    ctx.fill(Path(r), with: .color(Color(red:0.1,green:0.25,blue:0.1).opacity(0.4)))
                    // Random traces
                    if Int(x + y) % 3 == 0 {
                        var p = Path()
                        p.move(to: CGPoint(x: x + 2, y: y + 1))
                        p.addLine(to: CGPoint(x: x + 48, y: y + 1))
                        ctx.stroke(p, with: .color(Color(red:0.1,green:0.3,blue:0.1).opacity(0.25)), lineWidth: 1)
                    }
                    if Int(x + y) % 5 == 0 {
                        var p = Path()
                        p.move(to: CGPoint(x: x + 1, y: y + 2))
                        p.addLine(to: CGPoint(x: x + 1, y: y + 48))
                        ctx.stroke(p, with: .color(Color(red:0.1,green:0.3,blue:0.1).opacity(0.2)), lineWidth: 1)
                    }
                }
            }
        }
    }

    // MARK: - Ready Screen

    private var readyScreen: some View {
        VStack(spacing: 28) {
            Spacer()
            // Bomb icon
            ZStack {
                Circle()
                    .fill(Color(red:0.15,green:0.05,blue:0.05))
                    .frame(width: 100, height: 100)
                Circle()
                    .stroke(Color.red.opacity(0.4), lineWidth: 2)
                    .frame(width: 100, height: 100)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }

            VStack(spacing: 8) {
                Text("SPRÄNGÄMNESEXPERTEN")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .tracking(2)
                Text(["ENKEL","MEDEL","SVÅR","EXPERT"][difficulty])
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white:0.35))
                    .tracking(4)
            }

            VStack(alignment: .leading, spacing: 10) {
                warnRow("Ledtråden visas \(Int(clueShowTime[difficulty]))s sedan försvinner den.")
                warnRow("Du har en chans. Klipper du fel — straff.")
                warnRow("Fel tråd kostar dig \(reward.penalty) min.")
                warnRow("\(wireCount) trådar. Tänk snabbt.")
            }
            .padding(16)
            .background(Color.red.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 32)

            // Pay preview
            HStack(spacing: 20) {
                payBadge("+\(reward.early)m", "med 3s kvar", Color(red:0.2,green:0.9,blue:0.2))
                payBadge("+\(reward.normal)m", "precis i tid", .yellow)
                payBadge("−\(reward.penalty)m", "fel tråd", .red)
            }

            Button(action: beginGame) {
                Text("JAG ÄR REDO")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .tracking(3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red:0.9,green:0.2,blue:0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)

            Button("Avbryt") { dismiss() }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white:0.3))

            Spacer()
        }
    }

    // MARK: - Clue Screen

    private var clueScreen: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("LÄSTEKNIKER AKTIV")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red:0.2,green:0.9,blue:0.2))
                .tracking(4)

            // Clue box
            VStack(spacing: 12) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color(red:0.2,green:0.9,blue:0.2))
                Text(clue)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(Color(red:0.05,green:0.12,blue:0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red:0.2,green:0.9,blue:0.2).opacity(0.4), lineWidth: 1))
            .opacity(clueFade)
            .padding(.horizontal, 32)

            // Timer bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red:0.2,green:0.9,blue:0.2))
                        .frame(width: g.size.width * CGFloat(clueLeft / clueShowTime[difficulty]), height: 4)
                        .animation(.linear(duration: 0.05), value: clueLeft)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 40)

            Text("Ledtråden försvinner om \(String(format:"%.1f",clueLeft))s")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white:0.35))

            Spacer()
        }
    }

    // MARK: - Play Screen

    private var playScreen: some View {
        VStack(spacing: 0) {
            // Countdown
            HStack {
                Spacer()
                ZStack {
                    Circle().stroke(Color.red.opacity(0.2), lineWidth: 4).frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: CGFloat(timeLeft) / CGFloat(timeLimit))
                        .stroke(timeLeft < 5 ? Color.red : Color.yellow,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timeLeft)
                    Text("\(timeLeft)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(timeLeft < 5 ? .red : .white)
                }
                Spacer()
            }
            .padding(.top, 60)
            .padding(.bottom, 16)

            Text("KLIPP EN TRÅD")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white:0.35))
                .tracking(4)
                .padding(.bottom, 32)

            // Wires
            GeometryReader { g in
                VStack(spacing: 0) {
                    Spacer()
                    ForEach(0..<wireCount, id: \.self) { i in
                        wireView(index: i, width: g.size.width)
                            .padding(.vertical, 8)
                    }
                    Spacer()
                }
            }

            // Spark effect
            if showSpark {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private func wireView(index: Int, width: CGFloat) -> some View {
        let isSelected = wiresCut.contains(index)
        let isFlashing = cutFlashWire == index
        let col        = wireColors[index % wireColors.count]
        let dropExtra  = wireDropOffset[index] ?? 0

        ZStack {
            // Wire track background
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white:0.08))
                .frame(height: 14)
                .padding(.horizontal, 32)

            if !isSelected {
                // Full wire with undulation
                WireShape(index: index)
                    .stroke(col, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .frame(height: 50)
                    .padding(.horizontal, 24)
                    .shadow(color: col.opacity(isFlashing ? 1.0 : 0.5), radius: isFlashing ? 16 : 6)

                // Inner highlight
                WireShape(index: index)
                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(height: 50)
                    .padding(.horizontal, 24)

                // Flash overlay when being cut
                if isFlashing {
                    WireShape(index: index)
                        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(height: 50)
                        .padding(.horizontal, 24)
                        .transition(.opacity)
                }

                // End connectors
                HStack {
                    Circle().fill(Color(white:0.3)).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(white:0.5), lineWidth: 2))
                    Spacer()
                    Circle().fill(Color(white:0.3)).frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(white:0.5), lineWidth: 2))
                }
                .padding(.horizontal, 18)

            } else {
                // Cut wire — two drooping halves with spark particles
                ZStack {
                    HStack(spacing: 0) {
                        WireHalf(col: col, isLeft: true, extraDrop: dropExtra)
                        // Cut gap with sparks
                        ZStack {
                            ForEach(sparkParticles.prefix(isSelected ? sparkParticles.count : 0), id: \.id) { p in
                                Circle()
                                    .fill(col.opacity(p.opacity))
                                    .frame(width: 4, height: 4)
                                    .offset(
                                        x: CGFloat(cos(p.angle)) * p.dist,
                                        y: CGFloat(sin(p.angle)) * p.dist
                                    )
                            }
                            // Char marks at cut point
                            VStack(spacing: 1) {
                                Rectangle()
                                    .fill(Color(white:0.6))
                                    .frame(width: 2, height: 8)
                                Circle()
                                    .fill(col.opacity(0.7))
                                    .frame(width: 5, height: 5)
                                Rectangle()
                                    .fill(Color(white:0.4))
                                    .frame(width: 2, height: 8)
                            }
                        }
                        .frame(width: 24)
                        WireHalf(col: col, isLeft: false, extraDrop: dropExtra)
                    }
                    .padding(.horizontal, 24)
                    .opacity(0.65)
                }
            }
        }
        .frame(height: 60)
        .contentShape(Rectangle())
        .onTapGesture { if !isSelected { cutWire(at: index) } }
        .scaleEffect(isSelected ? 0.97 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isFlashing)
    }

    // MARK: - Result Screen

    private func resultScreen(won: Bool, early: Bool, earned: TimeInterval) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(won ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: won ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.system(size: 56))
                    .foregroundColor(won ? .green : .red)
            }

            VStack(spacing: 8) {
                Text(won ? (early ? "KLIPPT I TID — BONUS" : "AVVÄRJT") : "FEL TRÅD")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(won ? .green : .red)
                    .tracking(2)

                if won {
                    Text("Rätt tråd klippt\(early ? " med mer än 3 sekunder kvar" : "").")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white:0.45))
                } else {
                    Text("Bomben gick av. Betalning uteblev.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white:0.45))
                }
            }

            if won && earned > 0 {
                Text("+\(TimeEngine.shortFormatted(earned))")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
            } else if !won {
                Text("−\(reward.penalty) min")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
            }

            Button("Stäng") { dismiss() }
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(won ? Color.green : Color.red)
                .clipShape(Capsule())

            Spacer()
        }
    }

    // MARK: - Logic

    private func beginGame() {
        correctWire = Int.random(in: 0..<wireCount)
        clue        = generateClue(correct: correctWire)
        timeLeft    = timeLimit
        wiresCut    = []
        clueLeft    = clueShowTime[difficulty]
        clueFade    = 1
        phase       = .clueShowing
    }

    private func generateClue(correct: Int) -> String {
        let name  = wireNames[correct]
        let color = wireColors[correct]
        _ = color

        switch difficulty {
        case 0:
            return "Klipp den \(name) tråden."

        case 1:
            let positions = ["första","andra","tredje","fjärde"]
            let pos = positions[min(correct, positions.count-1)]
            let alt = ["Börja med den \(pos).",
                       "Räkna till \(correct+1) från vänster — klipp den.",
                       "Tråd nummer \(correct+1) är din fiende."]
            return alt.randomElement() ?? alt[0]

        case 2:
            // Logical clue
            let n = correct + 1
            if n % 2 == 0 {
                return "Klipp den tråd vars\nordningsnummer är jämnt\noch \(n == 2 ? "lägst av de jämna" : "det \(n == 4 ? "andra" : "tredje") jämna).")."
            } else {
                return "Antalet trådar du\nlåter vara rör sig från\n\(wireCount - n) (höger) till vänster."
            }

        default:
            // Caesar cipher (ROT3)
            let original = name.uppercased()
            let encoded = original.map { c -> Character in
                guard let ascii = c.asciiValue, ascii >= 65, ascii <= 90 else { return c }
                return Character(UnicodeScalar((Int(ascii) - 65 + 3) % 26 + 65)!)
            }
            return "ROT3: NOLSS GHQ\n\(String(encoded)) WUÏGHQ."
        }
    }

    private func cutWire(at index: Int) {
        // Flash the wire white briefly
        cutFlashWire = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { cutFlashWire = nil }

        // Generate spark particles
        let newSparks = (0..<12).map { _ in
            (id: UUID(),
             angle: Double.random(in: 0..<(2 * .pi)),
             dist: CGFloat.random(in: 4...16),
             opacity: Double.random(in: 0.6...1.0))
        }
        withAnimation(.easeOut(duration: 0.35)) {
            sparkParticles = newSparks
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.4)) { sparkParticles = [] }
        }

        // Animate wire halves drooping
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            wireDropOffset[index] = 10
        }

        // Mark as cut
        wiresCut.insert(index)

        // Shake bomb
        withAnimation(.default.repeatCount(4, autoreverses: true)) { bombShake = 8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { bombShake = 0 }

        let isCorrect = index == correctWire
        let isEarly   = isCorrect && timeLeft >= 3

        if isCorrect {
            let mins  = isEarly ? reward.early : reward.normal
            awardMiniJobEarnings(minutes: mins)
            let zone  = GameState.shared.currentZone
            let net   = TimeInterval(mins * 60) * zone.workMultiplier * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
            NewsManager.shared.addMiniJobCompletedEvent(jobName: "Sprängämnesexperten", earned: net, won: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                phase = .result(won: true, early: isEarly, earned: net)
            }
        } else {
            penalizeMiniJob(minutes: reward.penalty)
            NewsManager.shared.addMiniJobCompletedEvent(jobName: "Sprängämnesexperten", earned: 0, won: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                phase = .result(won: false, early: false, earned: 0)
            }
        }
    }

    private func handleTimeout() {
        penalizeMiniJob(minutes: reward.penalty)
        phase = .result(won: false, early: false, earned: 0)
    }

    // MARK: - Helpers

    private func warnRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(.red.opacity(0.7))
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white:0.55))
        }
    }

    private func payBadge(_ main: String, _ sub: String, _ col: Color) -> some View {
        VStack(spacing: 3) {
            Text(main)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundColor(col)
            Text(sub)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(white:0.35))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(col.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(col.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Wire Shapes

private struct WireShape: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mid = rect.midY
        let amp = CGFloat(index % 2 == 0 ? 6 : -6) * (1 + CGFloat(index) * 0.3)
        p.move(to: CGPoint(x: rect.minX, y: mid))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: mid),
            control1: CGPoint(x: rect.width * 0.3, y: mid + amp),
            control2: CGPoint(x: rect.width * 0.7, y: mid - amp)
        )
        return p
    }
}

private struct WireHalf: View {
    let col: Color
    let isLeft: Bool
    var extraDrop: CGFloat = 0

    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            let mid = size.height / 2
            let drop = 14 + extraDrop
            if isLeft {
                p.move(to: CGPoint(x: 0, y: mid))
                p.addCurve(
                    to: CGPoint(x: size.width, y: mid + drop),
                    control1: CGPoint(x: size.width * 0.4, y: mid + 2),
                    control2: CGPoint(x: size.width * 0.75, y: mid + drop * 0.6)
                )
            } else {
                p.move(to: CGPoint(x: size.width, y: mid))
                p.addCurve(
                    to: CGPoint(x: 0, y: mid - drop),
                    control1: CGPoint(x: size.width * 0.6, y: mid - 2),
                    control2: CGPoint(x: size.width * 0.25, y: mid - drop * 0.6)
                )
            }
            // Outer wire
            ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            // Inner highlight
            ctx.stroke(p, with: .color(Color.white.opacity(0.2)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(height: 60)
    }
}
