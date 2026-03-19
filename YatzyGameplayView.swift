import SwiftUI

// MARK: - Gameplay View

/// Full gameplay screen: header, turn banner, dice, status, roll button, scorecard.
struct YatzyGameplayView: View {
    @ObservedObject var engine: YatzyGameEngine
    let gameMode: MultiYatzyMode
    let betAmount: TimeInterval
    let balance: TimeInterval
    let onDismiss: () -> Void

    private var isCurrentPlayerAI: Bool {
        engine.isPlayerAI(at: engine.currentPlayerIndex, mode: gameMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            gameHeader
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    turnBanner
                    diceArea
                    if !engine.statusMessage.isEmpty { statusBar }
                    actionButtons
                    YatzyScorecardView(
                        players: engine.players,
                        currentPlayerIndex: engine.currentPlayerIndex,
                        currentDice: engine.dice,
                        canScore: engine.canScore,
                        isCurrentPlayerAI: isCurrentPlayerAI,
                        onSelectCategory: { engine.fillCategory($0, isCurrentPlayerAI: isCurrentPlayerAI) }
                    )
                    Spacer(minLength: 40)
                }
                .padding(.top, 10)
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            if isCurrentPlayerAI { engine.triggerAITurn() }
        }
    }

    // MARK: - Game Header

    private var gameHeader: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 1) {
                Text("INSATS")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(1)
                Text(TimeEngine.shortFormatted(betAmount))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.goldYatzy)
            }
            Spacer()
            Text(TimeEngine.shortFormatted(balance))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.goldYatzy.opacity(0.8))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.goldYatzy.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16).padding(.top, 56).padding(.bottom, 10)
    }

    // MARK: - Turn Banner

    private var turnBanner: some View {
        let idx      = engine.currentPlayerIndex
        let name     = engine.players.indices.contains(idx) ? engine.players[idx].name : "?"
        let color: Color = idx == 0 ? .accentGreen : .orange
        let isAI     = isCurrentPlayerAI

        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 40, height: 40)
                if isAI { Text("🤖").font(.system(size: 20)) }
                else { Image(systemName: "person.fill").font(.system(size: 18)).foregroundColor(color) }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.uppercased())
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                Text(isAI ? "AI spelar..." : "Din tur")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(color.opacity(0.6))
            }
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<engine.players.count, id: \.self) { i in
                    let p        = engine.players[i]
                    let c: Color = i == 0 ? .accentGreen : .orange
                    VStack(spacing: 1) {
                        Text(p.name.prefix(4).uppercased())
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(c.opacity(0.6))
                        Text("\(p.grandTotal)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(c)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(c.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(i == engine.currentPlayerIndex ? c.opacity(0.5) : Color.clear, lineWidth: 1.5))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Dice Area

    private var diceArea: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { i in
                    Button {
                        if !isCurrentPlayerAI && engine.rollsUsed > 0 && engine.rollsUsed < 3 && !engine.isRolling {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                                engine.toggleHeld(at: i)
                            }
                        }
                    } label: {
                        MultiDieView(
                            value: engine.dice[i],
                            held: engine.heldDice[i],
                            isRolling: engine.isRolling,
                            isAI: isCurrentPlayerAI,
                            size: 62
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isCurrentPlayerAI || engine.rollsUsed == 0 || engine.isRolling)
                }
            }
            if !isCurrentPlayerAI {
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule()
                            .fill(engine.heldDice[i] ? Color.accentGreen.opacity(0.6) : Color.white.opacity(0.1))
                            .frame(width: 16, height: 4)
                            .animation(.easeInOut(duration: 0.2), value: engine.heldDice[i])
                    }
                }
                if engine.rollsUsed > 0 {
                    Text("Tryck på tärning för att hålla/släppa")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
        .padding(.vertical, 16).padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.accentGreen.opacity(0.6)).frame(width: 6, height: 6)
            Text(engine.statusMessage)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.accentGreen.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentGreen.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button { engine.rollDice(isCurrentPlayerAI: isCurrentPlayerAI) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "dice").font(.system(size: 14, weight: .semibold))
                    Text(engine.rollsUsed == 0 ? "KASTA" : "KASTA OM")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    if engine.rollsRemaining > 0 {
                        Text("×\(engine.rollsRemaining)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.black.opacity(0.5))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.black.opacity(0.15)).clipShape(Capsule())
                    }
                }
                .foregroundColor(engine.canRoll && !isCurrentPlayerAI ? .black : .white.opacity(0.3))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(
                    engine.canRoll && !isCurrentPlayerAI
                        ? LinearGradient(colors: [Color.accentGreen, Color(red: 0.1, green: 0.7, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: engine.canRoll && !isCurrentPlayerAI ? Color.accentGreen.opacity(0.3) : .clear, radius: 8, y: 3)
            }
            .disabled(!engine.canRoll || isCurrentPlayerAI)

            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i < engine.rollsUsed ? Color.accentGreen.opacity(0.8) : Color.white.opacity(0.12))
                        .frame(width: 6, height: 14)
                }
            }
        }
    }
}
