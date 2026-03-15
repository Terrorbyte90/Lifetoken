import SwiftUI

// MARK: - Roulette Bet Types

enum RouletteBet: String, CaseIterable, Hashable {
    case red    = "Röd"
    case black  = "Svart"
    case odd    = "Udda"
    case even   = "Jämn"
    case high   = "19–36"
    case low    = "1–18"
    case dozen1 = "1–12"
    case dozen2 = "13–24"
    case dozen3 = "25–36"
    case number = "Nummer"

    /// Net payout multiplier on the original bet (excluding stake return).
    var payout: Double {
        switch self {
        case .red, .black, .odd, .even, .high, .low: return 1.0
        case .dozen1, .dozen2, .dozen3:              return 2.0
        case .number:                                return 35.0
        }
    }

    var probability: Double {
        switch self {
        case .red, .black, .odd, .even, .high, .low: return 18.0 / 37.0
        case .dozen1, .dozen2, .dozen3:              return 12.0 / 37.0
        case .number:                                return  1.0 / 37.0
        }
    }

    var displayLabel: String { rawValue }
    var payoutLabel: String  { "x\(Int(payout + 1))" }
}

// MARK: - RouletteGameView

struct RouletteGameView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine    = TimeEngine.shared
    @ObservedObject private var gameState = GameState.shared

    @State private var betAmount:     TimeInterval = 300   // 5 minutes default
    @State private var selectedBet:   RouletteBet = .red
    @State private var selectedNumber: Int = 7
    @State private var isSpinning:    Bool = false
    @State private var result:        Int? = nil
    @State private var resultMessage: String = ""
    @State private var showResult:    Bool = false
    @State private var wheelAngle:    Double = 0
    @State private var ballAngle:     Double = 0
    @State private var history:       [Int] = []

    // European roulette red numbers
    private let redNumbers = Set([1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36])

    // Bet types that appear in the grid (excludes .number which has custom UI)
    private let gridBets: [RouletteBet] = [
        .red, .black, .odd, .even, .low, .high, .dozen1, .dozen2, .dozen3
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        wheelView
                        historyRow
                        betTypeGrid
                        numberBetSection
                        betAmountSection
                        spinButton
                        Spacer(minLength: 80)
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .alert("Resultat", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
    }

    // MARK: Sub-views

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Text("TIME ROULETTE")
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

    private var wheelView: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                .frame(width: 172, height: 172)

            // Wheel body
            Circle()
                .fill(Color(red: 0.10, green: 0.10, blue: 0.10))
                .frame(width: 164, height: 164)
                .rotationEffect(.degrees(wheelAngle))

            // Number segments as colored ticks
            ForEach(0..<37, id: \.self) { num in
                let angle = Double(num) * (360.0 / 37.0)
                let isRed = redNumbers.contains(num)
                Rectangle()
                    .fill(num == 0 ? Color.green : (isRed ? Color.red : Color.white.opacity(0.85)))
                    .frame(width: 2, height: 60)
                    .offset(y: -30)
                    .rotationEffect(.degrees(angle + wheelAngle))
            }

            // Ball
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .offset(y: -62)
                .rotationEffect(.degrees(ballAngle))

            // Center hub
            Circle()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.07))
                .frame(width: 48, height: 48)

            // Result number in center
            if let r = result {
                Text("\(r)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(numberColor(r))
            } else {
                Image(systemName: "circle.dotted")
                    .foregroundColor(.green.opacity(0.4))
            }
        }
        .frame(width: 172, height: 172)
    }

    private var historyRow: some View {
        Group {
            if !history.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(history.suffix(14).enumerated()), id: \.offset) { _, num in
                            Text("\(num)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(numberColor(num))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private var betTypeGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 8
        ) {
            ForEach(gridBets, id: \.self) { bet in
                Button { selectedBet = bet } label: {
                    VStack(spacing: 2) {
                        Text(bet.displayLabel)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                        Text(bet.payoutLabel)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedBet == bet ? Color.green.opacity(0.25) : Color.white.opacity(0.07))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedBet == bet ? Color.green : Color.clear, lineWidth: 1)
                    )
                    .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
    }

    private var numberBetSection: some View {
        VStack(spacing: 8) {
            Button { selectedBet = .number } label: {
                HStack {
                    Text("NUMMER (\(selectedNumber))  —  x36")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Spacer()
                    Image(systemName: selectedBet == .number ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.green)
                }
                .padding(10)
                .background(selectedBet == .number ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
                .cornerRadius(10)
                .foregroundColor(.white)
            }
            .padding(.horizontal)

            if selectedBet == .number {
                HStack {
                    Text("0")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                    Slider(
                        value: Binding(
                            get: { Double(selectedNumber) },
                            set: { selectedNumber = Int($0) }
                        ),
                        in: 0...36, step: 1
                    )
                    .accentColor(.red)
                    Text("36")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.horizontal)
            }
        }
    }

    private var betAmountSection: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Insats:")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(TimeEngine.shortFormatted(betAmount))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal)

            Slider(
                value: $betAmount,
                in: 60...max(60, min(engine.balance, 86400 * 30)),
                step: 60
            )
            .accentColor(.green)
            .padding(.horizontal)

            // Quick-bet buttons
            HStack(spacing: 8) {
                ForEach([300.0, 1800.0, 3600.0, 21600.0], id: \.self) { amt in
                    Button {
                        betAmount = min(amt, engine.balance)
                    } label: {
                        Text(TimeEngine.shortFormatted(amt))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var spinButton: some View {
        Button { spin() } label: {
            Text(isSpinning
                 ? "SNURRAR..."
                 : "SNURRA  (\(TimeEngine.shortFormatted(betAmount)))")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSpinning || betAmount > engine.balance
                             ? Color.gray
                             : Color.green)
                .cornerRadius(12)
        }
        .disabled(isSpinning || betAmount > engine.balance)
        .padding(.horizontal)
    }

    // MARK: - Game Logic

    private func numberColor(_ n: Int) -> Color {
        if n == 0 { return .green }
        return redNumbers.contains(n) ? .red : .white
    }

    func spin() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        isSpinning = true
        result = nil

        let spinResult   = Int.random(in: 0...36)
        let spinDuration = Double.random(in: 2.8...4.2)

        withAnimation(.easeOut(duration: spinDuration)) {
            wheelAngle += Double.random(in: 900...1620)
            ballAngle  += Double.random(in: 1440...2880)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            self.result    = spinResult
            self.isSpinning = false
            self.history.append(spinResult)
            self.evaluateBet(spinResult)
        }
    }

    func evaluateBet(_ n: Int) {
        let isRed = redNumbers.contains(n)
        var win = false

        switch selectedBet {
        case .red:    win = n != 0 && isRed
        case .black:  win = n != 0 && !isRed
        case .odd:    win = n != 0 && n % 2 == 1
        case .even:   win = n != 0 && n % 2 == 0
        case .low:    win = n >= 1  && n <= 18
        case .high:   win = n >= 19 && n <= 36
        case .dozen1: win = n >= 1  && n <= 12
        case .dozen2: win = n >= 13 && n <= 24
        case .dozen3: win = n >= 25 && n <= 36
        case .number: win = n == selectedNumber
        }

        if win {
            // Gross return = stake + winnings
            let gross   = betAmount * (selectedBet.payout + 1.0)
            let taxRate = gameState.currentZone.taxRate
            let net     = gross * (1.0 - taxRate)
            TimeEngine.shared.addTime(net)
            GameState.shared.recordEarning(net - betAmount)
            resultMessage = "Vinst! Nummer \(n)\n+\(TimeEngine.shortFormatted(net - betAmount)) (efter \(Int(taxRate * 100))% skatt)"
        } else {
            resultMessage = "Nummer \(n) — ingen vinst.\nFörlorade \(TimeEngine.shortFormatted(betAmount))."
        }
        showResult = true
    }
}

#Preview {
    RouletteGameView()
        .preferredColorScheme(.dark)
}
