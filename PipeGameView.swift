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

    static func generate(size: Int) -> PipeGrid {
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
            // Scramble rotation (+1 or +2 or +3)
            let scramble = Int.random(in: 1...3)
            cell.rotation = (cell.rotation + scramble) % 4
            cells[r][c] = cell
        }

        // 3. Fill non-path cells with random (non-cross) pipes
        for r in 0..<size {
            for c in 0..<size {
                if !pathSet.contains("\(r)_\(c)") {
                    let t = [PType.cap, .straight, .corner, .tee].randomElement()!
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

    private let gridSizes:  [Int]    = [4, 6, 8, 10]
    private let timeLimits: [Int]    = [30, 25, 20, 15]
    private let rewards:    [Int]    = [12, 22, 38, 65]

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
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color(red:0.2,green:0.8,blue:0.5))
                Text("RÖRMOCKAREN")
                    .font(.system(size: 20, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)
                Text(["ENKEL","MEDEL","SVÅR","EXPERT"][difficulty])
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white:0.35))
                    .tracking(4)
            }

            VStack(spacing: 8) {
                pipeInfoRow("Rutnät", "\(gridSize)×\(gridSize)", .white)
                pipeInfoRow("Tidsgräns", "\(timeLimit)s", .yellow)
                pipeInfoRow("Lön vid vinst", "\(reward) min", Color(red:0.2,green:0.8,blue:0.5))
                pipeInfoRow("Roterar", "Tryck på rör", Color(white:0.5))
                pipeInfoRow("Vatten flödar", "automatiskt när tid är ute", Color(white:0.5))
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 32)

            Button(action: startGame) {
                Text("KOPPLA RÖREN")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.black)
                    .tracking(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(red:0.2,green:0.8,blue:0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
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
        VStack(spacing: 0) {
            // Status bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(Color(red:0.2,green:0.8,blue:0.5))
                    Text("RÖRMOCKAREN")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                // Timer
                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 3).frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: CGFloat(timeLeft) / CGFloat(timeLimit))
                        .stroke(timeLeft < 6 ? Color.red : Color(red:0.2,green:0.8,blue:0.5),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timeLeft)
                    Text("\(timeLeft)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                }
                Button("Flöda nu") {
                    triggerWaterFlow()
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red:0.2,green:0.8,blue:0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(red:0.2,green:0.8,blue:0.5).opacity(0.15))
                .clipShape(Capsule())
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
                .foregroundColor(Color(red:0.2,green:0.8,blue:0.5))
                Spacer()
                HStack(spacing: 4) {
                    Text("UTLOPP")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    Image(systemName: "arrow.right").font(.system(size: 10))
                }
                .foregroundColor(Color(red:0.2,green:0.8,blue:0.5))
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
        .onChange(of: waterAnim) { val in
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
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill((won ? Color(red:0.2,green:0.8,blue:0.5) : Color.orange).opacity(0.12))
                    .frame(width: 110, height: 110)
                Image(systemName: won ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.system(size: 54))
                    .foregroundColor(won ? Color(red:0.2,green:0.8,blue:0.5) : .orange)
            }

            VStack(spacing: 8) {
                Text(won ? "SYSTEMET HÅLLER TRYCKET" : "LÄCKA — NOLL LÖN")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(won ? .white : .orange)
                    .tracking(2)
                if won {
                    Text("Flödet nådde utloppet utan läcka.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white:0.4))
                } else {
                    Text("Rörsystemet var inkopplat. Lönet uteblev.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white:0.4))
                }
            }

            if won && earned > 0 {
                Text("+\(TimeEngine.shortFormatted(earned))")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red:0.2,green:0.8,blue:0.5))
            }

            Button("Stäng") { dismiss() }
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(won ? Color(red:0.2,green:0.8,blue:0.5) : Color.orange)
                .clipShape(Capsule())

            Spacer()
        }
    }

    // MARK: - Logic

    private func startGame() {
        grid     = PipeGrid.generate(size: gridSize)
        timeLeft = timeLimit
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
        guard won else { return 0 }
        awardMiniJobEarnings(minutes: reward)
        let zone = GameState.shared.currentZone
        return TimeInterval(reward * 60) * zone.workMultiplier * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
    }

    private func pipeInfoRow(_ label: String, _ value: String, _ col: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white:0.45))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(col)
        }
    }
}

// MARK: - Cell Renderer

private struct PipeCellView: View {
    let cell:       PCell
    let size:       CGFloat
    let isFlashing: Bool

    private var pipeColor: Color {
        if cell.isSource || cell.isDrain { return Color(red:0.2,green:0.9,blue:0.5) }
        if cell.isWet { return Color(red:0.1,green:0.6,blue:1.0) }
        return Color(red:0.45,green:0.45,blue:0.5)
    }

    private var bgColor: Color {
        if isFlashing { return Color(white:0.15) }
        if cell.isSource || cell.isDrain { return Color(red:0.05,green:0.15,blue:0.1) }
        return Color(red:0.07,green:0.07,blue:0.09)
    }

    var body: some View {
        ZStack {
            // Cell background
            RoundedRectangle(cornerRadius: 4)
                .fill(bgColor)
                .frame(width: size - 2, height: size - 2)

            // Pipe segments via Canvas
            Canvas { ctx, sz in
                let half  = sz.width / 2
                let reach = sz.width * 0.46
                let thick = sz.width * 0.22

                func segment(_ dir: PDir) -> Path {
                    var p = Path()
                    switch dir {
                    case .top:
                        p.addRect(CGRect(x: half - thick/2, y: 0, width: thick, height: half + thick/2))
                    case .bottom:
                        p.addRect(CGRect(x: half - thick/2, y: half - thick/2, width: thick, height: reach))
                    case .left:
                        p.addRect(CGRect(x: 0, y: half - thick/2, width: half + thick/2, height: thick))
                    case .right:
                        p.addRect(CGRect(x: half - thick/2, y: half - thick/2, width: reach, height: thick))
                    }
                    return p
                }

                let col: GraphicsContext.Shading = .color(pipeColor)
                for dir in cell.openings { ctx.fill(segment(dir), with: col) }

                // Center hub
                let hub = CGRect(x: half - thick*0.6, y: half - thick*0.6, width: thick*1.2, height: thick*1.2)
                ctx.fill(Path(roundedRect: hub, cornerRadius: 3), with: col)

                // Wet glow overlay
                if cell.isWet {
                    let glow: GraphicsContext.Shading = .color(Color(red:0.1,green:0.7,blue:1.0).opacity(0.3))
                    for dir in cell.openings { ctx.fill(segment(dir), with: glow) }
                    ctx.fill(Path(roundedRect: hub, cornerRadius: 3), with: glow)
                }
            }
            .frame(width: size - 2, height: size - 2)

            // Source/Drain arrow
            if cell.isSource {
                Image(systemName: "arrow.right")
                    .font(.system(size: size * 0.16))
                    .foregroundColor(Color(red:0.1,green:0.9,blue:0.5))
                    .offset(x: -(size * 0.36))
            }
            if cell.isDrain {
                Image(systemName: "arrow.right")
                    .font(.system(size: size * 0.16))
                    .foregroundColor(Color(red:0.1,green:0.9,blue:0.5))
                    .offset(x: size * 0.36)
            }
        }
        .animation(isFlashing ? .easeOut(duration: 0.15) : nil, value: isFlashing)
    }
}
