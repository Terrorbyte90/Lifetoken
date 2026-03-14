import SwiftUI

// MARK: - Slot Machine View
//
// 3 reels, 5 symbols. RTP ~94%.
// Jackpot  (3 of a kind — special ⚡): 50x
// 3 of a kind (any other):             5x – 20x
// 2 of a kind:                         0.5x (partial return)
// No match:                            0x (lose stake)
//
// Zone tax applied to all gross winnings via GameState.shared.currentZone.taxRate.
// All time transactions use TimeEngine.shared.

struct SlotMachineView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    // MARK: Symbols
    // Ordered by value: ⚡ > 💎 > ⌚ > ⏳ > 💀
    private let symbols:   [String]  = ["⚡", "💎", "⌚", "⏳", "💀"]
    private let symNames:  [String]  = ["Blixt", "Diamant", "Klocka", "Timglas", "Skalle"]
    // Jackpot multiplier per symbol (index)
    private let symMult:   [Double]  = [50, 20, 15, 10, 5]
    // Relative weight (lower index = rarer)
    private let weights:   [Double]  = [1, 2, 4, 6, 8]   // total 21

    @State private var reels:        [Int]  = [3, 3, 3]   // current displayed symbol index per reel
    @State private var target:       [Int]  = [3, 3, 3]   // determined result before animation
    @State private var spinning:     [Bool] = [false, false, false]
    @State private var isSpinning:   Bool   = false
    @State private var betAmount:    TimeInterval = 300   // default 5 minutes
    @State private var resultMessage: String = ""
    @State private var showResult:   Bool   = false
    @State private var lastWin:      TimeInterval? = nil
    @State private var spinCount:    Int    = 0

    // Spin animation timers — one per reel
    @State private var spinTimers:   [Timer?] = [nil, nil, nil]

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                Spacer()

                reelDisplay

                Spacer()

                payoutTable
                    .padding(.bottom, 8)

                betSection

                spinButton
                    .padding(.bottom, 40)
            }
        }
        .alert("Resultat", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
        .onDisappear { stopAllTimers() }
    }

    // MARK: Sub-views

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Text("COUNTDOWN SLOTS")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.yellow)
        }
        .padding()
        .padding(.top, 20)
    }

    private var reelDisplay: some View {
        VStack(spacing: 16) {
            // Slot frame
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { col in
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 88, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        spinning[col] ? Color.green.opacity(0.6) : Color.white.opacity(0.12),
                                        lineWidth: 1.5
                                    )
                            )

                        Text(symbols[reels[col]])
                            .font(.system(size: 48))
                            .id("\(col)-\(reels[col])-\(spinCount)")
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal:   .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .animation(.easeInOut(duration: 0.07), value: reels[col])
                    }
                }
            }

            // Win line indicator
            if let win = lastWin {
                Text(win > 0
                     ? "+\(TimeEngine.shortFormatted(win))"
                     : "Ingen vinst")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(win > 0 ? .yellow : .red.opacity(0.7))
                    .transition(.opacity)
                    .animation(.easeIn(duration: 0.3), value: lastWin != nil)
            }
        }
    }

    private var payoutTable: some View {
        VStack(spacing: 4) {
            Text("UTDELNING")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
            HStack(spacing: 16) {
                payoutRow(label: "⚡⚡⚡", value: "50x", color: .yellow)
                payoutRow(label: "💎💎💎", value: "20x", color: .cyan)
                payoutRow(label: "2 lika",  value: "0.5x", color: .white.opacity(0.5))
            }
            HStack(spacing: 16) {
                payoutRow(label: "⌚⌚⌚", value: "15x", color: .white)
                payoutRow(label: "⏳⏳⏳", value: "10x", color: .orange)
                payoutRow(label: "💀💀💀", value: "5x",  color: .red)
            }
        }
        .padding(.horizontal)
    }

    private func payoutRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    private var betSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Insats:")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(TimeEngine.shortFormatted(betAmount))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal)

            Slider(
                value: $betAmount,
                in: 60...max(60, min(engine.balance, 86_400 * 7)),
                step: 60
            )
            .accentColor(.green)
            .padding(.horizontal)

            // Quick bet row
            HStack(spacing: 8) {
                ForEach([300.0, 1_800.0, 3_600.0, 21_600.0, 86_400.0], id: \.self) { v in
                    Button { betAmount = min(v, engine.balance) } label: {
                        Text(TimeEngine.shortFormatted(v))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal)

            // Zone multiplier hint
            Text("RTP ~94%  |  Zon: \(gameState.currentZone.name)  |  Skatt: \(Int(gameState.currentZone.taxRate * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
        }
    }

    private var spinButton: some View {
        Button { triggerSpin() } label: {
            Text(isSpinning
                 ? "SNURRAR..."
                 : "SNURRA  (\(TimeEngine.shortFormatted(betAmount)))")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    isSpinning || betAmount > engine.balance
                    ? Color.gray
                    : Color.green
                )
                .cornerRadius(12)
        }
        .disabled(isSpinning || betAmount > engine.balance)
        .padding(.horizontal)
    }

    // MARK: - Spin Logic

    func triggerSpin() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        isSpinning = true
        lastWin    = nil
        spinCount += 1

        // Determine result using weighted random
        target = (0..<3).map { _ in weightedRandom() }

        // Assign spin durations (left stops first, right stops last)
        let durations: [Double] = [
            Double.random(in: 1.5...2.2),
            Double.random(in: 2.0...2.8),
            Double.random(in: 2.5...3.5)
        ]

        for col in 0..<3 {
            spinning[col] = true
            startReelSpin(col: col, duration: durations[col])
        }
    }

    func startReelSpin(col: Int, duration: Double) {
        stopTimer(col: col)

        let interval: TimeInterval = 0.07
        var elapsed: TimeInterval  = 0.0

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { t in
            elapsed += interval

            if elapsed < duration {
                // Randomly cycle through symbols
                DispatchQueue.main.async {
                    reels[col] = Int.random(in: 0..<symbols.count)
                }
            } else {
                t.invalidate()
                DispatchQueue.main.async {
                    reels[col]    = target[col]
                    spinning[col] = false

                    // All reels stopped?
                    if spinning.allSatisfy({ !$0 }) {
                        isSpinning = false
                        evaluateResult()
                    }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        spinTimers[col] = timer
    }

    func stopTimer(col: Int) {
        spinTimers[col]?.invalidate()
        spinTimers[col] = nil
    }

    func stopAllTimers() {
        for i in 0..<3 { stopTimer(col: i) }
    }

    // MARK: Weighted random symbol selection

    func weightedRandom() -> Int {
        let total = weights.reduce(0, +)
        var r     = Double.random(in: 0..<total)
        for (i, w) in weights.enumerated() {
            r -= w
            if r <= 0 { return i }
        }
        return weights.count - 1
    }

    // MARK: Result evaluation

    func evaluateResult() {
        let a = target[0], b = target[1], c = target[2]
        let taxRate = gameState.currentZone.taxRate

        var grossWin: TimeInterval = 0

        if a == b && b == c {
            // Three of a kind
            let mult = symMult[a]
            grossWin = betAmount * mult
        } else if a == b || b == c || a == c {
            // Two of a kind — partial return (0.5x)
            grossWin = betAmount * 0.5
        }
        // else: no match, lose

        if grossWin > 0 {
            let net = grossWin * (1.0 - taxRate)
            TimeEngine.shared.addTime(net)
            GameState.shared.recordEarning(net)
            lastWin = net

            let isJackpot = a == b && b == c && a == 0  // triple lightning
            if isJackpot {
                resultMessage = "JACKPOT! \(symbols[a])\(symbols[a])\(symbols[a])\n+\(TimeEngine.shortFormatted(net)) (efter \(Int(taxRate * 100))% skatt)"
            } else if a == b && b == c {
                resultMessage = "\(symbols[a])\(symbols[a])\(symbols[a])  \(Int(symMult[a]))x!\n+\(TimeEngine.shortFormatted(net)) (efter skatt)"
            } else {
                resultMessage = "Två lika — delåterbetalning\n+\(TimeEngine.shortFormatted(net))"
            }
        } else {
            lastWin       = 0
            resultMessage = "\(symbols[a])  \(symbols[b])  \(symbols[c])\nIngen vinst. Förlorade \(TimeEngine.shortFormatted(betAmount))."
        }

        showResult = true
    }
}
