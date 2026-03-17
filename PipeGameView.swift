import SwiftUI

// MARK: - Pipe Puzzle — Rörmockaren

// ── Direction ─────────────────────────────────────────────────────────────────

enum PDir: Int, CaseIterable {
    case top = 0, right = 1, bottom = 2, left = 3

    func rotated(by n: Int) -> PDir { PDir(rawValue: (rawValue + n + 4) % 4)! }
    var opposite: PDir { PDir(rawValue: (rawValue + 2) % 4)! }
    var delta: (r: Int, c: Int) {
        switch self {
        case .top:    return (-1, 0)
        case .right:  return (0,  1)
        case .bottom: return (1,  0)
        case .left:   return (0, -1)
        }
    }
}

// ── Pipe type with base openings ──────────────────────────────────────────────

enum PType: CaseIterable {
    case cap, straight, corner, tee, cross

    var base: Set<PDir> {
        switch self {
        case .cap:      return [.top]
        case .straight: return [.top, .bottom]
        case .corner:   return [.top, .right]
        case .tee:      return [.top, .right, .bottom]
        case .cross:    return [.top, .right, .bottom, .left]
        }
    }
}

// ── Pipe cell ─────────────────────────────────────────────────────────────────

struct PCell {
    var type:     PType
    var rotation: Int     // 0–3
    var isWet:    Bool = false
    var isSource: Bool = false
    var isDrain:  Bool = false

    var openings: Set<PDir> {
        Set(type.base.map { $0.rotated(by: rotation) })
    }

    mutating func rotate() { rotation = (rotation + 1) % 4 }

    // Find (type, rotation) whose openings match required set
    static func make(openings required: Set<PDir>) -> PCell {
        for t in PType.allCases {
            for r in 0..<4 {
                let c = PCell(type: t, rotation: r)
                if c.openings == required { return c }
            }
        }
        return PCell(type: .cross, rotation: 0)
    }
}

// MARK: - Puzzle Generator

struct PipeGrid {
    let size: Int
    var cells: [[PCell]]

    static func generate(size: Int, maxScramble: Int = 3) -> PipeGrid {
        var cells = Array(repeating: Array(repeating: PCell(type: .straight, rotation: 0), count: size), count: size)

        // 1. DFS path from (0,0) to (size-1, size-1)
        var path: [(r:Int,c:Int)] = [(0,0)]
        var visited = Set<String>()
        visited.insert("0_0")

        func dfs(_ r: Int, _ c: Int) -> Bool {
            if r == size-1 && c == size-1 { return true }
            let dirs: [(Int,Int)] = [(0,1),(1,0),(0,-1),(-1,0)].shuffled()
            for (dr,dc) in dirs {
                let nr = r+dr, nc = c+dc
                let key = "\(nr)_\(nc)"
                if nr>=0 && nr<size && nc>=0 && nc<size && !visited.contains(key) {
                    visited.insert(key)
                    path.append((nr,nc))
                    if dfs(nr,nc) { return true }
                    path.removeLast()
                    visited.remove(key)
                }
            }
            return false
        }
        _ = dfs(0,0)

        let pathSet = Set(path.map { "\($0.r)_\($0.c)" })

        // 2. Assign pipe types to path cells
        for i in 0..<path.count {
            let (r,c) = (path[i].r, path[i].c)
            var conns = Set<PDir>()
            if i > 0 {
                let (pr,pc) = (path[i-1].r, path[i-1].c)
                conns.insert(dirBetween(from:(r,c), to:(pr,pc)))
            }
            if i < path.count-1 {
                let (nr,nc) = (path[i+1].r, path[i+1].c)
                conns.insert(dirBetween(from:(r,c), to:(nr,nc)))
            }
            // Inlet/outlet
            if i == 0           { conns.insert(.left) }
            if i == path.count-1 { conns.insert(.right) }

            var cell = PCell.make(openings: conns)
            cell.isSource = i == 0
            cell.isDrain  = i == path.count-1
            // Don't scramble source or drain — only scramble middle path cells
            if i > 0 && i < path.count - 1 {
                let scramble = Int.random(in: 1...maxScramble)
                cell.rotation = (cell.rotation + scramble) % 4
            }
            cells[r][c] = cell
        }

        // 3. Fill non-path cells with random (non-cross) pipes
        for r in 0..<size {
            for c in 0..<size {
                if !pathSet.contains("\(r)_\(c)") {
                    let t = [PType.cap, .straight, .corner, .tee].randomElement() ?? .straight
                    cells[r][c] = PCell(type: t, rotation: Int.random(in: 0..<4))
                }
            }
        }

        return PipeGrid(size: size, cells: cells)
    }

    private static func dirBetween(from: (Int,Int), to: (Int,Int)) -> PDir {
        let dr = to.0 - from.0
        let dc = to.1 - from.1
        if dr == -1 { return .top }
        if dr ==  1 { return .bottom }
        if dc ==  1 { return .right }
        return .left
    }

    // BFS flood fill from inlet
    mutating func floodFill() -> Bool {
        for r in 0..<size { for c in 0..<size { cells[r][c].isWet = false } }

        guard cells[0][0].openings.contains(.left) else { return false }
        var queue  = [(0,0)]
        var wet    = Set<String>()
        wet.insert("0_0")
        cells[0][0].isWet = true

        while !queue.isEmpty {
            let (r,c) = queue.removeFirst()
            for dir in cells[r][c].openings {
                let nr = r + dir.delta.r
                let nc = c + dir.delta.c
                let key = "\(nr)_\(nc)"
                guard nr>=0 && nr<size && nc>=0 && nc<size && !wet.contains(key) else { continue }
                if cells[nr][nc].openings.contains(dir.opposite) {
                    wet.insert(key)
                    cells[nr][nc].isWet = true
                    queue.append((nr,nc))
                }
            }
        }
        return cells[size-1][size-1].isWet && cells[size-1][size-1].openings.contains(.right)
    }
}

// MARK: - Main View

struct PipeGameView: View {
    let difficulty: Int
    @Environment(\.dismiss) var dismiss

    private let gridSizes:  [Int]    = [4, 5, 6, 7]
    private let timeLimits: [Int]    = [45, 35, 25, 20]
    private let rewards:    [Int]    = [6, 11, 19, 32]

    private var gridSize:  Int { gridSizes[difficulty] }
    private var timeLimit: Int { timeLimits[difficulty] }
    private var reward:    Int { rewards[difficulty] }

    enum Phase { case ready, playing, waterFlowing(won: Bool), result(won: Bool, earned: TimeInterval) }

    @State private var phase:      Phase   = .ready
    @State private var grid:       PipeGrid = PipeGrid(size: 4, cells: [])
    @State private var timeLeft:   Int     = 30
    @State private var waterAnim:  Double  = 0
    @State private var tapFlash:   String? = nil  // cell key that flashed

    @State private var countdown   = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var waterTimer  = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color(red:0.05,green:0.06,blue:0.08).ignoresSafeArea()
            metalGrating.ignoresSafeArea()

            switch phase {
            case .ready:                   readyScreen
            case .playing:                 playingScreen
            case .waterFlowing(let won):   waterFlowScreen(won: won)
            case .result(let w, let e):    resultScreen(won: w, earned: e)
            }
        }
        .onReceive(countdown) { _ in
            guard case .playing = phase else { return }
            if timeLeft > 0 { timeLeft -= 1 } else { triggerWaterFlow() }
        }
        .onReceive(waterTimer) { _ in
            if case .waterFlowing = phase {
                waterAnim = min(1, waterAnim + 0.04)
            }
        }
    }

    // MARK: - Metal grating background

    private var metalGrating: some View {
        Canvas { ctx, size in
            for y in stride(from: 0.0, to: size.height, by: 8) {
                ctx.fill(Path(CGRect(x:0, y:y, width:size.width, height:1)),
                         with: .color(Color(white:0.05)))
            }
            for x in stride(from: 0.0, to: size.width, by: 80) {
                ctx.fill(Path(CGRect(x:x, y:0, width:2, height:size.height)),
                         with: .color(Color(white:0.04)))
            }
        }
    }

    // MARK: - Ready Screen

    private var readyScreen: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated drop icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.05, green: 0.2, blue: 0.15))
                    .frame(width: 100, height: 100)
                    .overlay(Circle().stroke(Color(red: 0.1, green: 0.8, blue: 0.5).opacity(0.4), lineWidth: 2))
                    .shadow(color: Color(red: 0.1, green: 0.8, blue: 0.5).opacity(0.3), radius: 16)
                Image(systemName: "pipe.and.drop.fill")
                    .font(.system(size: 42))
                    .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.6))
            }

            VStack(spacing: 6) {
                Text("RÖRMOCKAREN")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)
                Text(["ENKEL","MEDEL","SVÅR","EXPERT"][difficulty])
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.5).opacity(0.7))
                    .tracking(6)
            }

            // Info grid
            VStack(spacing: 0) {
                infoRow("Rutnät", "\(gridSize)×\(gridSize)", icon: "grid")
                Divider().background(Color.white.opacity(0.06))
                infoRow("Tidsgräns", "\(timeLimit)s", icon: "timer")
                Divider().background(Color.white.opacity(0.06))
                infoRow("Belöning vid vinst", "+\(reward) min", icon: "plus.circle", valueColor: Color(red: 0.1, green: 0.9, blue: 0.6))
                Divider().background(Color.white.opacity(0.06))
                infoRow("Straff vid läcka", "−\(max(1, reward/3)) min", icon: "minus.circle", valueColor: .red)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.09))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07), lineWidth: 1))
            .padding(.horizontal, 28)

            VStack(spacing: 10) {
                Button(action: startGame) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                        Text("KOPPLA RÖREN")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .tracking(2)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [Color(red: 0.1, green: 0.9, blue: 0.6), Color(red: 0.05, green: 0.7, blue: 0.4)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Color(red: 0.1, green: 0.8, blue: 0.5).opacity(0.35), radius: 12, y: 4)
                }
                .padding(.horizontal, 28)

                Button("Avbryt") { dismiss() }
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(white: 0.3))
            }

            Spacer()
        }
    }

    private func infoRow(_ label: String, _ value: String, icon: String, valueColor: Color = .white) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Playing Screen

    private var playingScreen: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.6))
                    Text("RÖRMOCKAREN")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                // Dramatic timer
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                        .frame(width: 48, height: 48)
                    Circle()
                        .trim(from: 0, to: CGFloat(timeLeft) / CGFloat(timeLimit))
                        .stroke(
                            timeLeft < 10 ? Color.red : Color(red: 0.1, green: 0.9, blue: 0.6),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timeLeft)
                    Text("\(timeLeft)")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(timeLeft < 10 ? .red : .white)
                        .scaleEffect(timeLeft < 10 ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: timeLeft < 10)
                }
                Button(action: triggerWaterFlow) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9))
                        Text("STARTA FLÖDE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.1, green: 0.9, blue: 0.6).opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(red: 0.1, green: 0.9, blue: 0.6).opacity(0.25), lineWidth: 1))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 54)
            .padding(.bottom, 12)

            // Inlet/outlet labels
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right").font(.system(size: 10))
                    Text("INLOPP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                }
                .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.6))
                Spacer()
                HStack(spacing: 4) {
                    Text("UTLOPP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    Image(systemName: "arrow.right").font(.system(size: 10))
                }
                .foregroundColor(Color(red: 0.1, green: 0.8, blue: 1.0))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)

            // Grid
            GeometryReader { geo in
                let padding: CGFloat = 16
                let available = min(geo.size.width, geo.size.height) - padding * 2
                let cellSize  = available / CGFloat(gridSize)

                ZStack {
                    // Grid lines
                    Canvas { ctx, sz in
                        for i in 0...gridSize {
                            let x = padding + cellSize * CGFloat(i)
                            var p = Path(); p.move(to: CGPoint(x:x,y:padding)); p.addLine(to: CGPoint(x:x,y:padding+available))
                            ctx.stroke(p, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
                            let y = padding + cellSize * CGFloat(i)
                            var q = Path(); q.move(to: CGPoint(x:padding,y:y)); q.addLine(to: CGPoint(x:padding+available,y:y))
                            ctx.stroke(q, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
                        }
                    }

                    // Cells
                    ForEach(0..<gridSize, id:\.self) { r in
                        ForEach(0..<gridSize, id:\.self) { c in
                            let cell  = grid.cells[r][c]
                            let flash = tapFlash == "\(r)_\(c)"
                            let ox    = padding + cellSize * CGFloat(c)
                            let oy    = padding + cellSize * CGFloat(r)

                            PipeCellView(cell: cell, size: cellSize, isFlashing: flash)
                                .position(x: ox + cellSize/2, y: oy + cellSize/2)
                                .onTapGesture {
                                    rotatePipe(r: r, c: c)
                                }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Water flow screen

    private func waterFlowScreen(won: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(won ? "FLÖDET HÅLLER" : "LÄCKA DETEKTERAD")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(won ? Color(red:0.2,green:0.8,blue:0.5) : .orange)
                    .tracking(2)
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 54).padding(.bottom, 12)

            GeometryReader { geo in
                let padding:  CGFloat = 16
                let available = min(geo.size.width, geo.size.height) - padding * 2
                let cellSize  = available / CGFloat(gridSize)

                ZStack {
                    Canvas { ctx, sz in
                        for i in 0...gridSize {
                            let x = padding + cellSize * CGFloat(i)
                            var p = Path(); p.move(to: CGPoint(x:x,y:padding)); p.addLine(to: CGPoint(x:x,y:padding+available))
                            ctx.stroke(p, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
                            let y = padding + cellSize * CGFloat(i)
                            var q = Path(); q.move(to: CGPoint(x:padding,y:y)); q.addLine(to: CGPoint(x:padding+available,y:y))
                            ctx.stroke(q, with: .color(Color.white.opacity(0.05)), lineWidth: 1)
                        }
                    }

                    ForEach(0..<gridSize, id:\.self) { r in
                        ForEach(0..<gridSize, id:\.self) { c in
                            let cell = grid.cells[r][c]
                            let ox   = padding + cellSize * CGFloat(c)
                            let oy   = padding + cellSize * CGFloat(r)

                            PipeCellView(cell: cell, size: cellSize, isFlashing: false)
                                .position(x: ox + cellSize/2, y: oy + cellSize/2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 16)
        }
        .onChange(of: waterAnim) { _, val in
            if val >= 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let earned = calcEarnings(won: won)
                    phase = .result(won: won, earned: earned)
                }
            }
        }
    }

    // MARK: - Result Screen

    private func resultScreen(won: Bool, earned: TimeInterval) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill((won ? Color(red: 0.1, green: 0.8, blue: 0.5) : Color.red).opacity(0.1))
                    .frame(width: 130, height: 130)
                Circle()
                    .stroke((won ? Color(red: 0.1, green: 0.8, blue: 0.5) : Color.red).opacity(0.3), lineWidth: 2)
                    .frame(width: 130, height: 130)
                Image(systemName: won ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.system(size: 60))
                    .foregroundColor(won ? Color(red: 0.1, green: 0.9, blue: 0.6) : .red)
                    .shadow(color: (won ? Color(red: 0.1, green: 0.8, blue: 0.5) : Color.red).opacity(0.5), radius: 20)
            }
            .padding(.bottom, 24)

            Text(won ? "SYSTEMET HÅLLER TRYCKET" : "LÄCKA DETEKTERAD")
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundColor(won ? Color(red: 0.1, green: 0.9, blue: 0.6) : .red)
                .tracking(1)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            Text(won ? "Vattnet nådde utloppet utan förlust." : "Rörsystemet läckte. Kostnader dras.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white: 0.45))
                .padding(.bottom, 28)

            if won && earned > 0 {
                Text("+\(TimeEngine.shortFormatted(earned))")
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.6))
                    .shadow(color: Color(red: 0.1, green: 0.8, blue: 0.5).opacity(0.4), radius: 10)
                    .padding(.bottom, 36)
            } else if !won {
                Text("−\(TimeEngine.shortFormatted(abs(earned)))")
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(.red)
                    .padding(.bottom, 36)
            }

            Button(action: { dismiss() }) {
                Text("STÄNG")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 60)
                    .padding(.vertical, 16)
                    .background(won ? Color(red: 0.1, green: 0.9, blue: 0.6) : Color.red)
                    .clipShape(Capsule())
                    .shadow(color: (won ? Color(red: 0.1, green: 0.8, blue: 0.5) : Color.red).opacity(0.4), radius: 10)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Logic

    private func startGame() {
        // Enkel=1 rotation, Medel=2, Svår=3, Expert=3
        let maxScramble = [1, 2, 3, 3][difficulty]
        grid      = PipeGrid.generate(size: gridSize, maxScramble: maxScramble)
        timeLeft  = timeLimit
        waterAnim = 0
        tapFlash  = nil
        phase     = .playing
    }

    private func rotatePipe(r: Int, c: Int) {
        guard case .playing = phase else { return }
        grid.cells[r][c].rotate()
        tapFlash = "\(r)_\(c)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { tapFlash = nil }
    }

    private func triggerWaterFlow() {
        guard case .playing = phase else { return }
        let won = grid.floodFill()
        waterAnim = 0
        phase = .waterFlowing(won: won)
    }

    private func calcEarnings(won: Bool) -> TimeInterval {
        let zone = GameState.shared.currentZone
        if won {
            awardMiniJobEarnings(minutes: reward)
            let net = TimeInterval(reward * 60) * zone.workMultiplier * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
            NewsManager.shared.addMiniJobCompletedEvent(jobName: "Rörmockaren", earned: net, won: true)
            return net
        } else {
            // Penalty = 1/3 of reward
            let penaltyMin = max(1, reward / 3)
            penalizeMiniJob(minutes: penaltyMin)
            NewsManager.shared.addMiniJobCompletedEvent(jobName: "Rörmockaren", earned: 0, won: false)
            return -TimeInterval(penaltyMin * 60)
        }
    }
}

// MARK: - Cell Renderer

private struct PipeCellView: View {
    let cell: PCell
    let size: CGFloat
    let isFlashing: Bool
    @State private var flowOffset: CGFloat = 0

    private var pipeColor: Color {
        if cell.isSource { return Color(red: 0.1, green: 1.0, blue: 0.5) }
        if cell.isDrain  { return Color(red: 0.1, green: 0.8, blue: 1.0) }
        if cell.isWet    { return Color(red: 0.0, green: 0.7, blue: 1.0) }
        return Color(red: 0.4, green: 0.42, blue: 0.48)
    }

    private var bgColor: Color {
        if isFlashing        { return Color(red: 0.2, green: 0.2, blue: 0.24) }
        if cell.isSource     { return Color(red: 0.02, green: 0.12, blue: 0.08) }
        if cell.isDrain      { return Color(red: 0.02, green: 0.08, blue: 0.14) }
        if cell.isWet        { return Color(red: 0.02, green: 0.06, blue: 0.12) }
        return Color(red: 0.06, green: 0.07, blue: 0.09)
    }

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: size * 0.12)
                .fill(bgColor)
                .frame(width: size - 3, height: size - 3)
                .shadow(color: cell.isWet ? Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.4) : .clear, radius: 4)

            // Pipe canvas
            Canvas { ctx, sz in
                let half  = sz.width / 2
                let reach = sz.width * 0.5
                let thick = sz.width * 0.24

                func rect(_ dir: PDir) -> CGRect {
                    switch dir {
                    case .top:    return CGRect(x: half - thick/2, y: 0,          width: thick,  height: half + thick/2)
                    case .bottom: return CGRect(x: half - thick/2, y: half - thick/2, width: thick, height: reach)
                    case .left:   return CGRect(x: 0,          y: half - thick/2, width: half + thick/2, height: thick)
                    case .right:  return CGRect(x: half - thick/2, y: half - thick/2, width: reach, height: thick)
                    }
                }

                // Pipe body
                let baseCol: GraphicsContext.Shading = .color(pipeColor.opacity(cell.isWet ? 1.0 : 0.75))
                for dir in cell.openings {
                    ctx.fill(Path(roundedRect: rect(dir), cornerRadius: 2), with: baseCol)
                }

                // Center hub
                let hub = CGRect(x: half - thick * 0.65, y: half - thick * 0.65, width: thick * 1.3, height: thick * 1.3)
                ctx.fill(Path(roundedRect: hub, cornerRadius: 3), with: baseCol)

                // Wet glow
                if cell.isWet {
                    let glow: GraphicsContext.Shading = .color(Color(red: 0.3, green: 0.8, blue: 1.0).opacity(0.35))
                    for dir in cell.openings {
                        ctx.fill(Path(roundedRect: rect(dir), cornerRadius: 2), with: glow)
                    }
                    ctx.fill(Path(roundedRect: hub, cornerRadius: 3), with: glow)
                }

                // Metallic highlight stripe
                let highlightCol: GraphicsContext.Shading = .color(Color.white.opacity(0.08))
                for dir in cell.openings {
                    let r = rect(dir)
                    let thinR = CGRect(x: r.minX + 1, y: r.minY + 1, width: r.width * 0.35, height: r.height * 0.35)
                    ctx.fill(Path(roundedRect: thinR, cornerRadius: 1), with: highlightCol)
                }
            }
            .frame(width: size - 3, height: size - 3)

            // Flow droplet animation on wet pipes
            if cell.isWet && !cell.isSource && !cell.isDrain {
                let dir = cell.openings.first ?? .right
                FlowDroplet(direction: dir, size: size, color: Color(red: 0.5, green: 0.9, blue: 1.0))
            }

            // Source/drain markers
            if cell.isSource {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.1, green: 1.0, blue: 0.5).opacity(0.25))
                        .frame(width: size * 0.55, height: size * 0.55)
                    Image(systemName: "drop.fill")
                        .font(.system(size: size * 0.22))
                        .foregroundColor(Color(red: 0.1, green: 1.0, blue: 0.5))
                }
            }
            if cell.isDrain {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.1, green: 0.8, blue: 1.0).opacity(0.25))
                        .frame(width: size * 0.55, height: size * 0.55)
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: size * 0.22))
                        .foregroundColor(Color(red: 0.1, green: 0.8, blue: 1.0))
                }
            }

            // Leaking water drips on open ends facing grid boundary (non-connected ends)
            if !cell.isWet && !cell.openings.isEmpty {
                // Show a small drip indicator on the bottom opening if not connected
                ForEach(Array(cell.openings), id: \.rawValue) { dir in
                    if dir == .bottom {
                        Image(systemName: "drop")
                            .font(.system(size: size * 0.12))
                            .foregroundColor(Color(red: 0.4, green: 0.6, blue: 0.8).opacity(0.3))
                            .offset(y: size * 0.32)
                    }
                }
            }
        }
        .scaleEffect(isFlashing ? 0.88 : 1.0)
        .animation(isFlashing ? .easeOut(duration: 0.12) : nil, value: isFlashing)
    }
}

private struct FlowDroplet: View {
    let direction: PDir
    let size: CGFloat
    let color: Color
    @State private var offset: CGFloat = -1

    var body: some View {
        let travel: CGFloat = size * 0.6
        let isHoriz = direction == .left || direction == .right

        Circle()
            .fill(color.opacity(0.6))
            .frame(width: size * 0.12, height: size * 0.12)
            .offset(
                x: isHoriz ? offset * travel : 0,
                y: isHoriz ? 0 : offset * travel
            )
            .onAppear {
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    offset = 1
                }
            }
    }
}
