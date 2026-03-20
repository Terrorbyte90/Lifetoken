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

    /// Netto utdelnings-multiplikator på den ursprungliga insatsen (exklusive insatsåterbetalning).
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

    @State private var betAmount:      TimeInterval = 300
    @State private var selectedBet:    RouletteBet = .red
    @State private var selectedNumber: Int = 7
    @State private var isSpinning:     Bool = false
    @State private var result:         Int? = nil
    @State private var resultMessage:  String = ""
    @State private var showResult:     Bool = false
    @State private var showConfetti:   Bool = false
    @State private var wheelAngle:     Double = 0
    @State private var ballAngle:      Double = 0
    @State private var history:        [Int] = []
    @State private var showResultBanner: Bool = false
    @State private var lastWin:        Bool = false

    // Europeisk roulette röda nummer
    private let redNumbers = Set([1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36])

    // Spel-typer i rutnätet (exkluderar .number som har eget UI)
    private let gridBets: [RouletteBet] = [
        .red, .black, .odd, .even, .low, .high, .dozen1, .dozen2, .dozen3
    ]

    // Mörkgrön filtbakgrund
    private let feltBackground = Color(red: 0.02, green: 0.08, blue: 0.02)

    var body: some View {
        ZStack {
            feltBackground.ignoresSafeArea()

            // Subtil mönstrad filttextur
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.12, blue: 0.04).opacity(0.6),
                    Color(red: 0.01, green: 0.05, blue: 0.01).opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        wheelSection
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

            // Resultatbanner med glöd-effekt
            if showResultBanner {
                VStack {
                    Spacer()
                    resultBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 40)
                }
            }
        }
        .alert("Resultat", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
        .overlay {
            if showConfetti {
                CasinoParticleView()
                    .environmentObject(ThemeEngine.shared)
            }
        }
    }

    // MARK: - Delvyer

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(10)
                    .background(Color.black.opacity(0.4))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text("EUROPEISK ROULETT")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text("37 fickor · Hus 2.7%")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.6))
            }
            Spacer()
            Text(TimeEngine.shortFormatted(engine.balance))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.yellow.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
        }
        .padding()
        .padding(.top, 20)
        .background(Color.black.opacity(0.3))
    }

    // Hjulsektionen med rotation-animation
    private var wheelSection: some View {
        ZStack {
            // Yttre dekorativ ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 0.8, green: 0.65, blue: 0.1), Color(red: 0.5, green: 0.4, blue: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 196, height: 196)
                .shadow(color: .yellow.opacity(0.3), radius: 8)

            // Hjulkropp
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.08, green: 0.08, blue: 0.08), Color(red: 0.03, green: 0.03, blue: 0.03)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 90
                    )
                )
                .frame(width: 188, height: 188)
                .rotationEffect(.degrees(wheelAngle))
                .animation(.easeOut(duration: 3.0), value: wheelAngle)

            // Numrerade segment som färgade tick-märken
            ForEach(0..<37, id: \.self) { num in
                let angle = Double(num) * (360.0 / 37.0)
                let isRed = redNumbers.contains(num)
                ZStack {
                    // Färgat segment
                    Rectangle()
                        .fill(num == 0 ? Color(red: 0.1, green: 0.6, blue: 0.1) : (isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(white: 0.15)))
                        .frame(width: 3, height: 55)
                        .offset(y: -40)
                    // Nummer-label
                    Text("\(num)")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                        .offset(y: -72)
                }
                .rotationEffect(.degrees(angle + wheelAngle))
                .animation(.easeOut(duration: 3.0), value: wheelAngle)
            }

            // Rörlig boll
            Circle()
                .fill(
                    RadialGradient(colors: [.white, Color(white: 0.8)], center: .topLeading, startRadius: 1, endRadius: 6)
                )
                .frame(width: 12, height: 12)
                .shadow(color: .white.opacity(0.8), radius: 4)
                .offset(y: -78)
                .rotationEffect(.degrees(ballAngle))
                .animation(.easeOut(duration: 3.5), value: ballAngle)

            // Centrum-nav
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.3, green: 0.25, blue: 0.05), Color(red: 0.1, green: 0.08, blue: 0.02)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(Circle().stroke(Color.yellow.opacity(0.5), lineWidth: 1.5))
                .shadow(color: .yellow.opacity(0.3), radius: 6)

            // Resultatsiffra i centrum
            if let r = result {
                Text("\(r)")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(numberColor(r))
                    .shadow(color: numberColor(r).opacity(0.8), radius: 6)
            } else {
                Image(systemName: "circle.dotted")
                    .foregroundColor(.yellow.opacity(0.4))
            }
        }
        .frame(width: 196, height: 196)
        .padding(.top, 8)
    }

    private var resultBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: lastWin ? "star.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(lastWin ? .yellow : .red)
            Text(lastWin ? "VINST!" : "INGEN VINST")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(lastWin ? .yellow : .red)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(lastWin ? Color.yellow.opacity(0.6) : Color.red.opacity(0.4), lineWidth: 1.5)
                )
        )
        .shadow(color: (lastWin ? Color.yellow : Color.red).opacity(0.5), radius: 16)
    }

    private var historyRow: some View {
        Group {
            if !history.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HISTORIK")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .tracking(4)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(history.suffix(14).enumerated()), id: \.offset) { _, num in
                                // Färgad chip med vitt nummer
                                ZStack {
                                    Circle()
                                        .fill(chipColor(num))
                                        .frame(width: 30, height: 30)
                                        .shadow(color: chipColor(num).opacity(0.5), radius: 4)
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        .frame(width: 30, height: 30)
                                    Text("\(num)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }

    // Satsningsrutnät med mörkgrön filtupplevelse och guldkanter
    private var betTypeGrid: some View {
        VStack(spacing: 10) {
            Text("VÄLJ SATS")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .tracking(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(gridBets, id: \.self) { bet in
                    Button { selectedBet = bet } label: {
                        VStack(spacing: 3) {
                            Text(bet.displayLabel)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                            Text(bet.payoutLabel)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedBet == bet
                                ? Color(red: 0.1, green: 0.4, blue: 0.15)
                                : Color(red: 0.04, green: 0.14, blue: 0.06)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedBet == bet
                                        ? Color(red: 0.7, green: 0.6, blue: 0.1)
                                        : Color(red: 0.2, green: 0.4, blue: 0.2).opacity(0.5),
                                    lineWidth: selectedBet == bet ? 1.5 : 0.5
                                )
                        )
                        .foregroundColor(selectedBet == bet ? .white : .white.opacity(0.7))
                        .shadow(color: selectedBet == bet ? Color.yellow.opacity(0.2) : .clear, radius: 6)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var numberBetSection: some View {
        VStack(spacing: 8) {
            Button { selectedBet = .number } label: {
                HStack {
                    // Chip med valt nummer
                    ZStack {
                        Circle()
                            .fill(chipColor(selectedNumber))
                            .frame(width: 28, height: 28)
                        Text("\(selectedNumber)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Text("NUMMER (\(selectedNumber))  —  x36")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Spacer()
                    Image(systemName: selectedBet == .number ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedBet == .number ? .yellow : .white.opacity(0.3))
                }
                .padding(12)
                .background(
                    selectedBet == .number
                        ? Color(red: 0.1, green: 0.4, blue: 0.15)
                        : Color(red: 0.04, green: 0.14, blue: 0.06)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            selectedBet == .number
                                ? Color(red: 0.7, green: 0.6, blue: 0.1)
                                : Color(red: 0.2, green: 0.4, blue: 0.2).opacity(0.5),
                            lineWidth: selectedBet == .number ? 1.5 : 0.5
                        )
                )
                .foregroundColor(.white)
            }
            .padding(.horizontal)

            if selectedBet == .number {
                HStack {
                    ZStack {
                        Circle().fill(Color.green).frame(width: 20, height: 20)
                        Text("0").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(selectedNumber) },
                            set: { selectedNumber = Int($0) }
                        ),
                        in: 0...36, step: 1
                    )
                    .tint(Color(red: 0.7, green: 0.6, blue: 0.1))
                    ZStack {
                        Circle().fill(Color.red).frame(width: 20, height: 20)
                        Text("36").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var betAmountSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("INSATS:")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
                Text(TimeEngine.shortFormatted(betAmount))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.4), radius: 6)
            }
            .padding(.horizontal)

            Slider(
                value: $betAmount,
                in: 60...max(120, min(engine.balance, 86400 * 30)),
                step: 60
            )
            .tint(Color(red: 0.7, green: 0.6, blue: 0.1))
            .padding(.horizontal)

            // Snabbvalstknappar
            HStack(spacing: 8) {
                ForEach([300.0, 1800.0, 3600.0, 21600.0], id: \.self) { amt in
                    Button {
                        betAmount = min(amt, engine.balance)
                    } label: {
                        Text(TimeEngine.shortFormatted(amt))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow.opacity(0.8))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.yellow.opacity(0.2), lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var spinButton: some View {
        Button { spin() } label: {
            HStack(spacing: 10) {
                Image(systemName: isSpinning ? "circle.dotted" : "arrow.clockwise.circle.fill")
                    .font(.system(size: 18))
                Text(isSpinning
                     ? "SNURRAR..."
                     : "SNURRA  (\(TimeEngine.shortFormatted(betAmount)))")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
            }
            .foregroundColor(isSpinning || betAmount > engine.balance ? Color.white.opacity(0.4) : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                if isSpinning || betAmount > engine.balance {
                    Color(white: 0.2)
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.7, green: 0.6, blue: 0.1), Color(red: 0.5, green: 0.4, blue: 0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(
                color: isSpinning ? .clear : Color.yellow.opacity(0.4),
                radius: 10, y: 4
            )
        }
        .disabled(isSpinning || betAmount > engine.balance)
        .padding(.horizontal)
    }

    // MARK: - Spellogik

    private func chipColor(_ n: Int) -> Color {
        if n == 0 { return Color(red: 0.1, green: 0.55, blue: 0.1) }
        return redNumbers.contains(n)
            ? Color(red: 0.75, green: 0.1, blue: 0.1)
            : Color(red: 0.12, green: 0.12, blue: 0.14)
    }

    private func numberColor(_ n: Int) -> Color {
        if n == 0 { return .green }
        return redNumbers.contains(n) ? .red : .white
    }

    func spin() {
        guard TimeEngine.shared.deductTime(betAmount) else { return }
        isSpinning = true
        result = nil
        showResultBanner = false

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
            let gross   = betAmount * (selectedBet.payout + 1.0)
            let taxRate = gameState.currentZone.taxRate
            let net     = gross * (1.0 - taxRate)
            TimeEngine.shared.addTime(net)
            GameState.shared.recordEarning(net - betAmount)
            MissionsManager.incrementProgress("casino_total_wins")
            TransactionLedger.shared.record(label: "Roulette — vinst", amount: net - betAmount)
            resultMessage = "Vinst! Nummer \(n)\n+\(TimeEngine.shortFormatted(net - betAmount)) (efter \(Int(taxRate * 100))% skatt)"
            showConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showConfetti = false }
        } else {
            TransactionLedger.shared.record(label: "Roulette — förlust", amount: -betAmount)
            resultMessage = "Nummer \(n) — ingen vinst.\nFörlorade \(TimeEngine.shortFormatted(betAmount))."
        }

        lastWin = win
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showResultBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showResultBanner = false }
        }
        showResult = true
    }
}

#Preview {
    RouletteGameView()
        .preferredColorScheme(.dark)
}
