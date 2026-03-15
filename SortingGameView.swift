import SwiftUI

// MARK: - Sorteringsverket

struct SortingGameView: View {
    let difficulty: Int
    @Environment(\.dismiss) var dismiss

    // Config [Enkel, Medel, Svår, Expert]
    private let categoryCounts: [Int]    = [3, 4, 5, 5]
    private let timeLimits:     [Int]    = [60, 60, 45, 40]
    private let fallingSpeed:   [Double] = [8.0, 6.0, 4.5, 3.5]  // seconds to fall across screen
    private let spawnInterval:  [Double] = [1.4, 1.1, 0.85, 0.7]
    private let rewards = [
        (perfect:15, good:8, worse:2),
        (perfect:25, good:14, worse:4),
        (perfect:42, good:23, worse:7),
        (perfect:70, good:38, worse:11),
    ]
    private var catCount:  Int    { categoryCounts[difficulty] }
    private var timeLimit: Int    { timeLimits[difficulty] }
    private var fallSpeed: Double { fallingSpeed[difficulty] }
    private var spawn:     Double { spawnInterval[difficulty] }
    private var reward:    (perfect:Int,good:Int,worse:Int) { rewards[difficulty] }

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
            // Factory background
            Color(red:0.06,green:0.05,blue:0.04).ignoresSafeArea()
            factoryBg.ignoresSafeArea()

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

    // MARK: - Factory Background

    private var factoryBg: some View {
        Canvas { ctx, size in
            // Conveyor belt pattern at bottom
            let beltY = size.height * 0.75
            for x in stride(from: 0.0, to: size.width, by: 24) {
                var p = Path()
                p.move(to: CGPoint(x: x, y: beltY))
                p.addLine(to: CGPoint(x: x + 12, y: beltY + 8))
                ctx.stroke(p, with: .color(Color(white:0.12)), lineWidth: 2)
            }
            // Metal grating lines
            for y in stride(from: 0.0, to: beltY, by: 60) {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(Color(white:0.06)), lineWidth: 1)
            }
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
                Text(["ENKEL","MEDEL","SVÅR","EXPERT"][difficulty])
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white:0.35))
                    .tracking(4)
            }

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
                HStack {
                    Text("✓ \(score)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(Color(red:0.2,green:0.9,blue:0.2))
                    Text("✗ \(mistakes)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(.red)
                    Spacer()
                    if combo > 1 {
                        Text("x\(combo) KOMBO")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text("\(timeLeft)s")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(timeLeft < 10 ? .red : .white)
                }
                .padding(.horizontal, 16)
                .padding(.top, 54)
                .zIndex(10)

                // ── Falling objects ──────────────────
                ForEach(objects.filter { !$0.isDone }) { obj in
                    let x = obj.xFraction * w
                    let y = obj.yOffset * (h - binH)
                    let col = categories[obj.categoryIndex].color

                    ZStack {
                        Circle()
                            .fill(col.opacity(0.2))
                            .frame(width: 52, height: 52)
                        Circle()
                            .stroke(col.opacity(0.6), lineWidth: 2)
                            .frame(width: 52, height: 52)
                        Text(obj.symbol)
                            .font(.system(size: 26))
                    }
                    .shadow(color: col.opacity(0.4), radius: 8)
                    .position(x: x, y: y)
                    .animation(.linear(duration: 1/30.0), value: obj.yOffset)
                }

                // ── Combo label ──────────────────────
                if showCombo {
                    Text(comboLabel)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 8)
                        .transition(.opacity.combined(with: .scale))
                        .position(x: w/2, y: h * 0.4)
                        .zIndex(20)
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
        return Button(action: { sortObject(into: index) }) {
            VStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.system(size: 18))
                    .foregroundColor(cat.color)
                Text(cat.name)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(cat.color.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: w, height: h)
            .background(cat.color.opacity(0.1))
            .overlay(
                Rectangle().stroke(cat.color.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Result Screen

    private func resultScreen(earned: TimeInterval) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundColor(Color(red:0.9,green:0.55,blue:0.1))

            VStack(spacing: 8) {
                Text("SKIFT AVSLUTAT")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
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

            if earned > 0 {
                Text("+\(TimeEngine.shortFormatted(earned))")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red:0.9,green:0.55,blue:0.1))
            } else {
                Text("För många fel. Minimal utbetalning.")
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
            awardMiniJobEarnings(minutes: minutes)
            let zone = GameState.shared.currentZone
            net = TimeInterval(minutes * 60) * zone.workMultiplier * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
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
