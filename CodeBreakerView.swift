import SwiftUI

// MARK: - Kodknäckaren (Mastermind)

struct CodeBreakerView: View {
    let difficulty: Int
    @Environment(\.dismiss) var dismiss

    // Config [Enkel, Medel, Svår, Expert, Legende]
    private let codeLengths: [Int] = [4, 4, 5, 6, 6]
    private let symbolCounts: [Int] = [6, 8, 9, 9, 12]  // symbols available (1-N + letters)
    private let maxAttempts: [Int] = [5, 4, 4, 4, 3]
    private let timeLimits: [Int] = [90, 90, 90, 60, 40]
    private let rewards = [
        (on2: 9, on34: 6, on5: 3),
        (on2: 15, on34: 10, on5: 5),
        (on2: 25, on34: 16, on5: 8),
        (on2: 40, on34: 26, on5: 13),
        (on2: 80, on34: 52, on5: 26),
    ]
    private let difficultyLabels = ["ENKEL", "MEDEL", "SVÅR", "EXPERT", "LEGENDE"]

    private var difficultyIndex: Int {
        min(max(difficulty, 0), timeLimits.count - 1)
    }

    private var codeLen: Int { codeLengths[difficultyIndex] }
    private var symCount: Int { symbolCounts[difficultyIndex] }
    private var maxAttempt: Int { maxAttempts[difficultyIndex] }
    private var timeLimit: Int { timeLimits[difficultyIndex] }
    private var reward: (on2: Int, on34: Int, on5: Int) { rewards[difficultyIndex] }
    private var difficultyLabel: String { difficultyLabels[difficultyIndex] }

    private var symbols: [String] {
        let digits = (1...9).map { "\($0)" }
        let letters = ["A","B","C","D","E","F"]
        let pool = digits + letters
        return Array(pool.prefix(symCount))
    }

    struct GuessRow: Identifiable {
        let id = UUID()
        let guess: [String]
        let blacks: Int  // right symbol, right place
        let whites: Int  // right symbol, wrong place
    }

    enum Phase { case ready, playing, result(won: Bool, attempts: Int, earned: TimeInterval) }

    @State private var phase:        Phase    = .ready
    @State private var secretCode:   [String] = []
    @State private var currentGuess: [String] = []
    @State private var rows:         [GuessRow] = []
    @State private var timeLeft:     Int      = 90
    @State private var cursorBlink:  Bool     = false
    @State private var shakeCursor:  CGFloat  = 0
    @State private var selectedPos:  Int      = 0

    @State private var timer     = Timer.publish(every: 1,    on: .main, in: .common).autoconnect()
    @State private var blinkTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    @State private var crtFlicker: Double = 1.0
    @State private var flickerTimer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Terminal background — deep green-black
            LinearGradient(
                colors: [Color(red:0.01,green:0.06,blue:0.01), Color(red:0.02,green:0.03,blue:0.02)],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            // Phosphor grid dots
            GeometryReader { g in
                Canvas { ctx, sz in
                    let step: CGFloat = 3
                    for x in stride(from: 0.0, to: sz.width, by: step) {
                        for y in stride(from: 0.0, to: sz.height, by: step) {
                            let dot = CGRect(x: x, y: y, width: 1, height: 1)
                            ctx.fill(Path(dot), with: .color(Color(red:0,green:0.3,blue:0).opacity(0.08)))
                        }
                    }
                    // Horizontal scanlines
                    for y in stride(from: 0.0, to: sz.height, by: 4) {
                        ctx.fill(Path(CGRect(x:0, y:y, width:sz.width, height:1.5)),
                                 with: .color(Color.black.opacity(0.18)))
                    }
                    // Vignette (dark corners)
                    let r = min(sz.width, sz.height) * 1.2
                    let cx = sz.width / 2, cy = sz.height / 2
                    for i in stride(from: 0.0, to: 1.0, by: 0.05) {
                        let fr = r * CGFloat(i)
                        let vig = CGRect(x: cx - fr, y: cy - fr, width: fr*2, height: fr*2)
                        ctx.fill(Path(ellipseIn: vig),
                                 with: .color(Color.black.opacity(max(0, (i - 0.6) * 0.6))))
                    }
                }.ignoresSafeArea()
            }
            .opacity(crtFlicker)

            // Corner bracket decorations
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                Canvas { ctx, sz in
                    let bLen: CGFloat = 18, bW: CGFloat = 2
                    let pad: CGFloat  = 20
                    let gc: GraphicsContext.Shading = .color(Color(red:0.1,green:0.6,blue:0.1).opacity(0.5))
                    // Top-left
                    var p = Path(); p.move(to: CGPoint(x: pad, y: pad + bLen)); p.addLine(to: CGPoint(x: pad, y: pad)); p.addLine(to: CGPoint(x: pad + bLen, y: pad))
                    ctx.stroke(p, with: gc, lineWidth: bW)
                    // Top-right
                    var p2 = Path(); p2.move(to: CGPoint(x: w-pad-bLen, y: pad)); p2.addLine(to: CGPoint(x: w-pad, y: pad)); p2.addLine(to: CGPoint(x: w-pad, y: pad+bLen))
                    ctx.stroke(p2, with: gc, lineWidth: bW)
                    // Bottom-left
                    var p3 = Path(); p3.move(to: CGPoint(x: pad, y: h-pad-bLen)); p3.addLine(to: CGPoint(x: pad, y: h-pad)); p3.addLine(to: CGPoint(x: pad+bLen, y: h-pad))
                    ctx.stroke(p3, with: gc, lineWidth: bW)
                    // Bottom-right
                    var p4 = Path(); p4.move(to: CGPoint(x: w-pad-bLen, y: h-pad)); p4.addLine(to: CGPoint(x: w-pad, y: h-pad)); p4.addLine(to: CGPoint(x: w-pad, y: h-pad-bLen))
                    ctx.stroke(p4, with: gc, lineWidth: bW)
                }
            }.ignoresSafeArea()

            switch phase {
            case .ready:                        readyScreen
            case .playing:                      playScreen
            case .result(let w, let a, let e):  resultScreen(won: w, attempts: a, earned: e)
            }
        }
        .onReceive(timer) { _ in
            guard case .playing = phase else { return }
            if timeLeft > 0 { timeLeft -= 1 } else { finishGame(won: false) }
        }
        .onReceive(blinkTimer) { _ in
            cursorBlink.toggle()
        }
        .onReceive(flickerTimer) { _ in
            // Occasional CRT flicker
            withAnimation(.easeInOut(duration: 0.05)) { crtFlicker = 0.85 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeInOut(duration: 0.05)) { crtFlicker = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeInOut(duration: 0.04)) { crtFlicker = 0.92 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                        withAnimation(.easeInOut(duration: 0.06)) { crtFlicker = 1.0 }
                    }
                }
            }
        }
    }

    // MARK: - Ready Screen

    private var readyScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            terminalHeader

            VStack(alignment: .leading, spacing: 12) {
                termLine("> SÄKERHETSNIVÅ: \(difficultyLabel)", .green)
                termLine("> KOD: \(codeLen) TECKEN (1-\(symCount)\(difficulty == 3 ? "+A-F" : ""))", .green)
                termLine("> FÖRSÖK: \(maxAttempt)", .green)
                termLine("> TID: \(timeLimit)s", .green)
                termLine("> GRÖN = rätt plats | GUL = fel plats", Color(red:0.5,green:0.9,blue:0.5))
                Divider().background(Color(red:0.1,green:0.4,blue:0.1))
                termLine("MAXLÖN 2 FÖRSÖK: \(reward.on2)m", .white)
                termLine("MAXLÖN 3-4 FÖRSÖK: \(reward.on34)m", .white)
                termLine("MAXLÖN 5 FÖRSÖK: \(reward.on5)m", .white)
            }
            .padding(20)
            .background(Color(red:0.02,green:0.08,blue:0.02))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(red:0.1,green:0.45,blue:0.1), lineWidth: 1))
            .padding(.horizontal, 24)

            Button(action: startGame) {
                HStack {
                    Image(systemName: "play.fill").font(.system(size: 13))
                    Text("INITIERA INTRÅNG")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .tracking(2)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red:0.1,green:0.9,blue:0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Button("Avbryt") { dismiss() }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white:0.3))

            Spacer()
        }
    }

    // MARK: - Play Screen

    private var playScreen: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                terminalHeader
                Spacer()
                Text("\(timeLeft)s")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(timeLeft < 15 ? .red : Color(red:0.2,green:0.9,blue:0.2))
            }
            .padding(.horizontal, 20)
            .padding(.top, 54)
            .padding(.bottom, 16)

            // Divider
            Rectangle()
                .fill(Color(red:0.1,green:0.35,blue:0.1))
                .frame(height: 1)
                .padding(.horizontal, 20)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Past guesses
                        ForEach(rows) { row in
                            guessRow(row)
                                .id(row.id)
                        }

                        // Current input row
                        if rows.count < maxAttempt {
                            currentInputRow
                                .id("input")
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: rows.count) { _, _ in
                    withAnimation { proxy.scrollTo("input", anchor: .bottom) }
                }
            }

            // Symbol picker
            symbolPicker

            // Submit button
            Button(action: submitGuess) {
                Text("SKICKA ▶")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(currentGuess.count == codeLen ? Color(red:0.1,green:0.9,blue:0.2) : Color(white:0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(currentGuess.count < codeLen)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .offset(x: shakeCursor)
    }

    // MARK: - Guess row (submitted)

    private func guessRow(_ row: GuessRow) -> some View {
        let lineNum = (rows.firstIndex(where: { $0.id == row.id }) ?? 0) + 1
        let isPerfect = row.blacks == codeLen
        return HStack(spacing: 0) {
            // Line number
            Text(String(format: "%02d", lineNum))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(red:0.1,green:0.5,blue:0.1))
                .frame(width: 28)

            // Symbols
            HStack(spacing: 5) {
                ForEach(Array(row.guess.enumerated()), id: \.offset) { i, sym in
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(symbolBg(sym, pos: i, in: row))
                            .frame(width: 30, height: 30)
                        // Glow for correct position
                        if secretCode.indices.contains(i) && secretCode[i] == sym {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(red:0.1,green:0.9,blue:0.2).opacity(0.6), lineWidth: 1.5)
                                .frame(width: 30, height: 30)
                        }
                        Text(sym)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(symbolColor(sym, pos: i, in: row))
                    }
                }
            }

            Spacer()

            // Feedback pegs in 2x grid
            VStack(alignment: .trailing, spacing: 3) {
                HStack(spacing: 3) {
                    ForEach(0..<min(row.blacks, (codeLen + 1) / 2), id: \.self) { _ in
                        Circle()
                            .fill(Color(red:0.1,green:0.9,blue:0.2))
                            .frame(width: 8, height: 8)
                            .shadow(color: Color(red:0.1,green:0.9,blue:0.2).opacity(0.8), radius: 3)
                    }
                    ForEach(0..<min(row.whites, (codeLen + 1) / 2), id: \.self) { _ in
                        Circle()
                            .fill(Color(red:0.95,green:0.85,blue:0.1))
                            .frame(width: 8, height: 8)
                    }
                }
                HStack(spacing: 3) {
                    ForEach(0..<max(0, row.blacks - (codeLen + 1) / 2), id: \.self) { _ in
                        Circle()
                            .fill(Color(red:0.1,green:0.9,blue:0.2))
                            .frame(width: 8, height: 8)
                            .shadow(color: Color(red:0.1,green:0.9,blue:0.2).opacity(0.8), radius: 3)
                    }
                    ForEach(0..<max(0, row.whites - (codeLen + 1) / 2), id: \.self) { _ in
                        Circle()
                            .fill(Color(red:0.95,green:0.85,blue:0.1))
                            .frame(width: 8, height: 8)
                    }
                    let emptyCount = codeLen - row.blacks - row.whites
                    ForEach(0..<max(0, emptyCount), id: \.self) { _ in
                        Circle()
                            .stroke(Color(white:0.2), lineWidth: 1)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .frame(width: 56)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(isPerfect
            ? Color(red:0.02,green:0.12,blue:0.02)
            : Color(red:0.02,green:0.07,blue:0.02))
        .overlay {
            if isPerfect {
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color(red:0.1,green:0.7,blue:0.1).opacity(0.4), lineWidth: 1)
            }
        }
    }

    private func symbolColor(_ sym: String, pos: Int, in row: GuessRow) -> Color {
        if secretCode.indices.contains(pos) && secretCode[pos] == sym { return .black }
        if secretCode.contains(sym) { return Color(red:0.1,green:0.1,blue:0.1) }
        return Color(white:0.5)
    }

    private func symbolBg(_ sym: String, pos: Int, in row: GuessRow) -> Color {
        if secretCode.indices.contains(pos) && secretCode[pos] == sym {
            return Color(red:0.1,green:0.9,blue:0.2)
        }
        if secretCode.contains(sym) {
            return Color(red:0.9,green:0.8,blue:0.0)
        }
        return Color(white:0.1)
    }

    // MARK: - Current input row

    private var currentInputRow: some View {
        HStack(spacing: 0) {
            Text("\(rows.count + 1).")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(white:0.25))
                .frame(width: 24)

            HStack(spacing: 6) {
                ForEach(0..<codeLen, id: \.self) { i in
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(i < currentGuess.count ? Color(white:0.15) : Color.clear)
                            .frame(width: 28, height: 28)
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(i == currentGuess.count && cursorBlink
                                    ? Color(red:0.2,green:0.9,blue:0.2)
                                    : Color(white: i < currentGuess.count ? 0.3 : 0.12),
                                    lineWidth: i == currentGuess.count ? 2 : 1)
                            .frame(width: 28, height: 28)

                        if i < currentGuess.count {
                            Text(currentGuess[i])
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red:0.2,green:0.9,blue:0.2))
                        } else if i == currentGuess.count {
                            // Cursor
                            Rectangle()
                                .fill(Color(red:0.2,green:0.9,blue:0.2).opacity(cursorBlink ? 0.9 : 0.2))
                                .frame(width: 3, height: 16)
                        }
                    }
                    .onTapGesture {
                        if i < currentGuess.count {
                            currentGuess = Array(currentGuess.prefix(i))
                            selectedPos = i
                        }
                    }
                }
            }

            Spacer()

            // Backspace
            Button(action: {
                if !currentGuess.isEmpty { currentGuess.removeLast() }
            }) {
                Image(systemName: "delete.left")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white:0.4))
                    .frame(width: 32, height: 32)
                    .background(Color(white:0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(red:0.02,green:0.1,blue:0.02))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(red:0.1,green:0.5,blue:0.1).opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Symbol Picker

    private var symbolPicker: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color(red:0.08,green:0.25,blue:0.08))
                .frame(height: 1)
                .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(symCount, 9)), spacing: 8) {
                ForEach(symbols, id: \.self) { sym in
                    Button(action: { appendSymbol(sym) }) {
                        Text(sym)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red:0.2,green:0.9,blue:0.2))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(Color(red:0.04,green:0.1,blue:0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red:0.1,green:0.4,blue:0.1), lineWidth: 1))
                    }
                    .disabled(currentGuess.count >= codeLen)
                    .opacity(currentGuess.count >= codeLen ? 0.35 : 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(Color(red:0.02,green:0.06,blue:0.02))
    }

    // MARK: - Result Screen

    private func resultScreen(won: Bool, attempts: Int, earned: TimeInterval) -> some View {
        VStack(spacing: 24) {
            Spacer()
            terminalHeader

            VStack(spacing: 8) {
                Text(won ? "SYSTEM BRUTET" : "INTRÅNG MISSLYCKAT")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(won ? Color(red:0.1,green:0.9,blue:0.2) : .red)
                    .tracking(2)

                if won {
                    Text("Koden knäckt på \(attempts) försök.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white:0.45))
                } else {
                    Text("Koden: \(secretCode.joined())")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.8))
                }
            }

            if earned > 0 {
                Text("+\(TimeEngine.shortFormatted(earned))")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red:0.1,green:0.9,blue:0.2))
            } else {
                Text("Noll lön. Systemet vann.")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color(white:0.35))
            }

            Button("Stäng") { dismiss() }
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(won ? Color(red:0.1,green:0.9,blue:0.2) : Color.red)
                .clipShape(Capsule())

            Spacer()
        }
    }

    // MARK: - Logic

    private func startGame() {
        secretCode   = (0..<codeLen).map { _ in symbols.randomElement() ?? "1" }
        currentGuess = []
        rows         = []
        timeLeft     = timeLimit
        phase        = .playing
    }

    private func appendSymbol(_ sym: String) {
        guard currentGuess.count < codeLen else { return }
        currentGuess.append(sym)
    }

    private func submitGuess() {
        guard currentGuess.count == codeLen else { return }

        let (b, w) = evaluate(guess: currentGuess, code: secretCode)
        let row = GuessRow(guess: currentGuess, blacks: b, whites: w)
        rows.append(row)
        currentGuess = []

        if b == codeLen {
            finishGame(won: true)
        } else if rows.count >= maxAttempt {
            finishGame(won: false)
        } else {
            // Wrong — shake
            withAnimation(.default.repeatCount(3, autoreverses: true)) { shakeCursor = 5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shakeCursor = 0 }
        }
    }

    private func evaluate(guess: [String], code: [String]) -> (blacks: Int, whites: Int) {
        var blacks = 0
        var whites = 0
        var codeCopy  = code
        var guessCopy = guess

        // Blacks first
        for i in 0..<codeLen {
            if guess[i] == code[i] {
                blacks += 1
                codeCopy[i]  = ""
                guessCopy[i] = ""
            }
        }
        // Whites
        for i in 0..<codeLen {
            guard !guessCopy[i].isEmpty else { continue }
            if let j = codeCopy.firstIndex(of: guessCopy[i]) {
                whites += 1
                codeCopy[j] = ""
            }
        }
        return (blacks, whites)
    }

    private func finishGame(won: Bool) {
        guard case .playing = phase else { return }
        let att = rows.count
        var minutes = 0
        if won {
            if att <= 2      { minutes = reward.on2 }
            else if att <= 4 { minutes = reward.on34 }
            else             { minutes = reward.on5 }
        }
        var net: TimeInterval = 0
        if minutes > 0 {
            awardMiniJobEarnings(minutes: minutes, jobName: "Kodknäckaren")
            let zone = GameState.shared.currentZone
            net = TimeInterval(minutes * 60) * zone.workMultiplier * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
            NewsManager.shared.addMiniJobCompletedEvent(jobName: "Kodknäckaren", earned: net, won: won)
        } else {
            NewsManager.shared.addMiniJobCompletedEvent(jobName: "Kodknäckaren", earned: 0, won: false)
        }
        phase = .result(won: won, attempts: att, earned: net)
    }

    // MARK: - Helpers

    private var terminalHeader: some View {
        HStack(spacing: 8) {
            // Status dot
            Circle()
                .fill(Color(red:0.1,green:0.9,blue:0.2))
                .frame(width: 6, height: 6)
                .shadow(color: Color(red:0.1,green:0.9,blue:0.2), radius: 4)
            Image(systemName: "terminal.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(red:0.1,green:0.9,blue:0.2))
            Text("KODKNÄCKAREN")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(Color(red:0.1,green:0.9,blue:0.2))
                .tracking(3)
                .shadow(color: Color(red:0.1,green:0.9,blue:0.2).opacity(0.6), radius: 4)
            Text("v\(difficulty + 1).\(codeLen)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(red:0.1,green:0.5,blue:0.1))
        }
    }

    private func termLine(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(color)
            Spacer()
        }
    }
}
