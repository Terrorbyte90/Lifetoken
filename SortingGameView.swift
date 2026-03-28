import SwiftUI

// MARK: - Sorteringsverket

struct SortingGameView: View {
    let difficulty: Int
    @Environment(\.dismiss) var dismiss

    // Config [Enkel, Medel, Svår, Expert, Legende]
    private let categoryCounts: [Int] = [3, 4, 5, 5, 5]
    private let timeLimits: [Int] = [60, 60, 45, 40, 25]
    private let fallingSpeed: [Double] = [8.0, 6.0, 4.5, 3.5, 2.7]  // seconds to fall across screen
    private let spawnInterval: [Double] = [1.4, 1.1, 0.85, 0.7, 0.55]
    private let rewards = [
        (perfect: 7, good: 4, worse: 1),
        (perfect: 12, good: 7, worse: 2),
        (perfect: 21, good: 11, worse: 3),
        (perfect: 35, good: 19, worse: 5),
        (perfect: 70, good: 38, worse: 10),
    ]
    private let difficultyLabels = ["ENKEL", "MEDEL", "SVÅR", "EXPERT", "LEGENDE"]

    private var difficultyIndex: Int {
        min(max(difficulty, 0), timeLimits.count - 1)
    }

    private var catCount: Int { categoryCounts[difficultyIndex] }
    private var timeLimit: Int { timeLimits[difficultyIndex] }
    private var fallSpeed: Double { fallingSpeed[difficultyIndex] }
    private var spawn: Double { spawnInterval[difficultyIndex] }
    private var reward: (perfect: Int, good: Int, worse: Int) { rewards[difficultyIndex] }
    private var difficultyLabel: String { difficultyLabels[difficultyIndex] }

    // Categories (name, icon, color)
    private let allCategories: [(name:String,icon:String,color:Color)] = [
        ("METALL",    "wrench.fill",      Color(red:0.6,green:0.6,blue:0.7)),
        ("ORGANISKT", "leaf.fill",        Color(red:0.2,green:0.8,blue:0.3)),
        ("ENERGI",    "bolt.fill",        Color(red:0.95,green:0.85,blue:0.1)),
        ("KEMISKT",   "flask.fill",       Color(red:0.9,green:0.3,blue:0.8)),
        ("RADIOAKTIVT","atom",            Color(red:0.3,green:0.9,blue:0.9)),
    ]
    private var categories: [(name:String,icon:String,color:Color)] { Array(allCategories.prefix(catCount)) }

    struct FallingObject: Identifiable {
        let id = UUID()
        let categoryIndex: Int
        var xFraction: CGFloat      // 0–1 horizontal position
        var yOffset:   CGFloat      // current y position (0 = top, 1 = bottom)
        let symbol:    String
        var isDone:    Bool = false
    }

    enum Phase { case ready, playing, result(earned: TimeInterval) }

    @State private var phase:      Phase  = .ready
    @State private var objects:    [FallingObject] = []
    @State private var score:      Int    = 0
    @State private var mistakes:   Int    = 0
    @State private var combo:      Int    = 0
    @State private var maxCombo:   Int    = 0
    @State private var timeLeft:   Int    = 60
    @State private var showCombo:  Bool   = false
    @State private var comboLabel: String = ""
    @State private var lastSpawn:   Date = .init()
    @State private var countdown    = Timer.publish(every: 1,      on: .main, in: .common).autoconnect()
    @State private var physicsTimer = Timer.publish(every: 1/30.0, on: .main, in: .common).autoconnect()

    // Object symbols per category
    private let objectSymbols: [[String]] = [
        ["⚙","🔩","🔧","⛓"],
        ["🌿","🌱","🍃","🌾"],
        ["⚡","🔋","💡","🔌"],
        ["⚗","🧪","💊","🧬"],
        ["☢","⚛","🔬","☣"],
    ]

    var body: some View {
        ZStack {
            // Premium svart bakgrund
            Color.black.ignoresSafeArea()
            premiumBg.ignoresSafeArea()

            switch phase {
            case .ready:                    readyScreen
            case .playing:                  playingScreen
            case .result(let e):            resultScreen(earned: e)
            }
        }
        .onReceive(countdown) { _ in
            guard case .playing = phase else { return }
            if timeLeft > 0 { timeLeft -= 1 } else { finishGame() }
        }
        .onReceive(physicsTimer) { _ in
            guard case .playing = phase else { return }
            updatePhysics()
        }
    }

    // MARK: - Premium Background

    private var premiumBg: some View {
        Canvas { ctx, size in
            // Subtilt rutnät — premium dark grid
            let gridStep: CGFloat = 36
            for x in stride(from: 0.0, to: size.width, by: gridStep) {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(Color.white.opacity(0.028)), lineWidth: 1)
            }
            for y in stride(from: 0.0, to: size.height, by: gridStep) {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(Color.white.opacity(0.028)), lineWidth: 1)
            }
            // Golvrand vid behållarna
            let floorY = size.height * 0.86
            ctx.fill(Path(CGRect(x: 0, y: floorY, width: size.width, height: 2)),
                     with: .color(Color.white.opacity(0.06)))
        }
    }

    // MARK: - Ready Screen

    private var readyScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.square.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(red:0.9,green:0.55,blue:0.1))
                Text("SORTERINGSVERKET")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(3)
                Text(difficultyLabel)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white:0.35))
                    .tracking(4)
            }

            LTInfoCallout(
                title: "Mål",
                message: "Sortera objektet som ligger lägst på skärmen till rätt behållare. Långa kombokedjor höjer tempot och förbättrar slutlönen.",
                icon: "tray.full.fill",
                tint: Color(red:0.9,green:0.55,blue:0.1)
            )
            .padding(.horizontal, 24)

            // Category preview
            VStack(spacing: 8) {
                Text("BEHÅLLARE:")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(white:0.35))
                    .tracking(3)
                HStack(spacing: 8) {
                    ForEach(0..<catCount, id: \.self) { i in
                        VStack(spacing: 4) {
                            Image(systemName: categories[i].icon)
                                .font(.system(size: 18))
                                .foregroundColor(categories[i].color)
                            Text(categories[i].name)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(categories[i].color.opacity(0.8))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(categories[i].color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(categories[i].color.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            VStack(spacing: 8) {
                infoRow("Tid",      "\(timeLimit)s",   .white)
                infoRow("Perfekt lön", "\(reward.perfect) min", Color(red:0.9,green:0.55,blue:0.1))
                infoRow("Kombo bonus", "+multiplikator", .yellow)
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            Button(action: startGame) {
                Text("STARTA LÖPANDEBAND")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red:0.9,green:0.55,blue:0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)

            Button("Avbryt") { dismiss() }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white:0.3))

            Spacer()
        }
    }

    // MARK: - Playing Screen

    private var playingScreen: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let binH: CGFloat = 80

            ZStack(alignment: .top) {
                // ── Stats bar ──────────────────────────
                HStack(spacing: 12) {
                    // Poäng
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                        Text("\(score)")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.green)
                            .shadow(color: .green.opacity(0.5), radius: 4)
                    }
                    // Fel
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                        Text("\(mistakes)")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundColor(.red)
                    }
                    Spacer()
                    // Kombo-badge
                    if combo > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text("×\(combo)")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                        .shadow(color: .yellow.opacity(0.3), radius: 4)
                    }
                    Spacer()
                    // Timer
                    Text("\(timeLeft)s")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(timeLeft < 10 ? .red : Color(white: 0.85))
                        .shadow(color: timeLeft < 10 ? .red.opacity(0.5) : .clear, radius: 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 54)
                .zIndex(10)

                LTInfoCallout(
                    title: "Kontroll",
                    message: "Tryck på behållaren som matchar objektets ikon/färg. Missar eller sena objekt bryter din kombo.",
                    icon: "hand.tap.fill",
                    tint: Color(red:0.9,green:0.55,blue:0.1)
                )
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .zIndex(10)

                // ── Fallande objekt — glödande kapslar ──────────────────
                ForEach(objects.filter { !$0.isDone }) { obj in
                    let x = obj.xFraction * w
                    let y = obj.yOffset * (h - binH)
                    let col = categories[obj.categoryIndex].color

                    ZStack {
                        // Yttre glöd
                        Capsule()
                            .fill(col.opacity(0.12))
                            .frame(width: 58, height: 44)
                            .shadow(color: col.opacity(0.6), radius: 8)
                        // Kapselform
                        Capsule()
                            .fill(LinearGradient(
                                colors: [col.opacity(0.35), col.opacity(0.15)],
                                startPoint: .top, endPoint: .bottom
                            ))
                            .frame(width: 54, height: 40)
                        Capsule()
                            .stroke(col.opacity(0.7), lineWidth: 1.5)
                            .frame(width: 54, height: 40)
                        // Symbol
                        Text(obj.symbol)
                            .font(.system(size: 22))
                    }
                    .shadow(color: col.opacity(0.5), radius: 6)
                    .position(x: x, y: y)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: obj.yOffset)
                }

                // ── Kombo-label med snap-animation ──────────────────────
                if showCombo {
                    Text(comboLabel)
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.7), radius: 10)
                        .shadow(color: .orange.opacity(0.4), radius: 18)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 1.4).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        ))
                        .position(x: w/2, y: h * 0.38)
                        .zIndex(20)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showCombo)
                }

                // ── Bins ───────────────────────────
                HStack(spacing: 0) {
                    ForEach(0..<catCount, id: \.self) { i in
                        binView(index: i, w: w / CGFloat(catCount), h: binH)
                    }
                }
                .frame(width: w, height: binH)
                .position(x: w/2, y: h - binH/2)
                .zIndex(5)
            }
            .clipped()
        }
    }

    private func binView(index: Int, w: CGFloat, h: CGFloat) -> some View {
        let cat = categories[index]
        return Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            sortObject(into: index)
        }) {
            VStack(spacing: 5) {
                Image(systemName: cat.icon)
                    .font(.system(size: 20))
                    .foregroundColor(cat.color)
                    .shadow(color: cat.color.opacity(0.6), radius: 4)
                Text(cat.name)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(cat.color.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .tracking(1)
            }
            .frame(width: w, height: h)
            .background(
                LinearGradient(
                    colors: [cat.color.opacity(0.18), cat.color.opacity(0.08)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                Rectangle()
                    .stroke(cat.color.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: cat.color.opacity(0.2), radius: 6)
        }
    }

    // MARK: - Result Screen

    private func resultScreen(earned: TimeInterval) -> some View {
        let won = earned > 0
        let penalized = earned < 0
        return VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill((won ? Color(red:0.9,green:0.55,blue:0.1) : Color.red).opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: won ? "checkmark.seal.fill" : (penalized ? "exclamationmark.octagon.fill" : "minus.circle.fill"))
                    .font(.system(size: 52))
                    .foregroundColor(won ? Color(red:0.9,green:0.55,blue:0.1) : (penalized ? .red : Color(white:0.4)))
            }

            VStack(spacing: 8) {
                Text(won ? "SKIFT AVSLUTAT" : (penalized ? "FELSORTERING — BÖTER" : "SKIFT AVSLUTAT"))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(won ? .white : (penalized ? .red : Color(white:0.5)))
                    .tracking(3)
                Text("Rätt sorterade: \(score) | Fel: \(mistakes)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(white:0.45))
                if maxCombo > 1 {
                    Text("Bästa kombo: x\(maxCombo)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.yellow)
                }
            }

            LTInfoCallout(
                title: "Skiftanalys",
                message: won ? "Stabil precision genom hela passet gav full eller delvis ersättning." : "För hög felprocent gav böter. Fokusera på säkra träffar före tempo.",
                icon: won ? "chart.bar.fill" : "exclamationmark.bubble.fill",
                tint: won ? Color(red:0.9,green:0.55,blue:0.1) : .red
            )
            .padding(.horizontal, 24)

            if earned > 0 {
                Text("+\(TimeEngine.shortFormatted(earned))")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red:0.9,green:0.55,blue:0.1))
            } else if earned < 0 {
                VStack(spacing: 4) {
                    Text("−\(TimeEngine.shortFormatted(abs(earned)))")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                    Text("Avgift för felaktig källsortering.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white:0.35))
                }
            } else {
                Text("Ingen sortering gjord.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(white:0.35))
            }

            Button("Stäng") { dismiss() }
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color(red:0.9,green:0.55,blue:0.1))
                .clipShape(Capsule())

            Spacer()
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        objects   = []
        score     = 0
        mistakes  = 0
        combo     = 0
        maxCombo  = 0
        timeLeft  = timeLimit
        lastSpawn = Date()
        phase     = .playing
        spawnObject()
    }

    private func spawnObject() {
        guard case .playing = phase else { return }
        let catIdx = Int.random(in: 0..<catCount)
        let syms   = objectSymbols[catIdx]
        let obj    = FallingObject(
            categoryIndex: catIdx,
            xFraction: CGFloat.random(in: 0.12...0.88),
            yOffset: 0.05,
            symbol: syms.randomElement() ?? "?"
        )
        objects.append(obj)
    }

    private func updatePhysics() {
        let dt = CGFloat(1.0 / 30.0)
        let step = dt / CGFloat(fallSpeed)

        // Difficulty-based spawning
        if -lastSpawn.timeIntervalSinceNow >= spawn {
            lastSpawn = Date()
            spawnObject()
        }

        for i in objects.indices {
            guard !objects[i].isDone else { continue }
            objects[i].yOffset += step
            if objects[i].yOffset >= 0.95 {
                // Object reached bottom without being sorted → mistake
                objects[i].isDone = true
                registerMiss()
            }
        }
        // Clean up old objects
        objects = objects.filter { $0.yOffset < 1.1 }
    }

    private func sortObject(into binIndex: Int) {
        // Find the lowest (highest yOffset) unsorted object
        guard let idx = objects.indices
            .filter({ !objects[$0].isDone })
            .sorted(by: { objects[$0].yOffset > objects[$1].yOffset })
            .first else { return }

        let obj = objects[idx]
        objects[idx].isDone = true

        if obj.categoryIndex == binIndex {
            score += 1
            combo += 1
            maxCombo = max(maxCombo, combo)
            if combo >= 3 {
                let label = combo >= 7 ? "MEGA x\(combo)!" : combo >= 5 ? "SUPER x\(combo)" : "KOMBO x\(combo)"
                showComboLabel(label)
            }
        } else {
            mistakes += 1
            combo = 0
        }
    }

    private func registerMiss() {
        mistakes += 1
        combo = 0
    }

    private func showComboLabel(_ text: String) {
        comboLabel = text
        withAnimation(.spring()) { showCombo = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showCombo = false }
        }
    }

    private func finishGame() {
        guard case .playing = phase else { return }
        let minutes = calcEarnings()
        var net: TimeInterval = 0
        if minutes > 0 {
            awardMiniJobEarnings(minutes: minutes, jobName: "Sorteringsverket")
            let zone = GameState.shared.currentZone
            net = TimeInterval(minutes * 60) * zone.workMultiplier * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
            NewsManager.shared.addMiniJobCompletedEvent(jobName: "Sorteringsverket", earned: net, won: true)
        } else {
            // 30% penalty of the perfect reward at current difficulty
            let penaltyMin = max(1, Int(Double(reward.perfect) * 0.30))
            penalizeMiniJob(minutes: penaltyMin, jobName: "Sorteringsverket")
            net = -TimeInterval(penaltyMin * 60)
            NewsManager.shared.addMiniJobCompletedEvent(jobName: "Sorteringsverket", earned: 0, won: false)
        }
        phase = .result(earned: net)
    }

    private func calcEarnings() -> Int {
        guard score > 0 else { return 0 }
        let errorRate = Double(mistakes) / max(Double(score + mistakes), 1)
        if errorRate < 0.05 { return reward.perfect }
        if errorRate < 0.20 { return reward.good }
        if errorRate < 0.40 { return reward.worse }
        return 0
    }

    private func infoRow(_ label: String, _ value: String, _ col: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white:0.45))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(col)
        }
    }
}
