import SwiftUI

// MARK: - Game Over View

struct YatzyGameOverView: View {
    let players: [YatzyPlayerState]
    let winnerIndex: Int?
    let isTie: Bool
    let gameMode: MultiYatzyMode
    let betAmount: TimeInterval
    @Binding var resultAnimating: Bool
    let onPlayAgain: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: 60)
                resultHeader.padding(.bottom, 32)
                finalScoreCard.padding(.horizontal, 20).padding(.bottom, 24)
                actionButtonsGameOver.padding(.horizontal, 20)
                Spacer(minLength: 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                resultAnimating = true
            }
        }
    }

    // MARK: - Computed Properties

    private var resultColor: Color {
        if isTie { return .orange }
        return winnerIndex == 0 ? .accentGreen : .red
    }

    private var resultEmoji: String {
        if isTie { return "🤝" }
        return winnerIndex == 0 ? "🏆" : "💀"
    }

    private var resultTitle: String {
        if isTie { return "OAVGJORT" }
        guard let w = winnerIndex, players.indices.contains(w) else { return "SPELET KLART" }
        if w == 0 { return players[0].name.prefix(8).uppercased() }
        switch gameMode {
        case .vsAI:                               return "AI VANN"
        case .onlineOneVsOne, .onlineThreePlayer: return players[w].name.prefix(8).uppercased()
        }
    }

    private var resultSubtitle: String {
        guard players.count >= 2 else { return "" }
        return players.map { "\($0.name.prefix(6)): \($0.grandTotal)p" }.joined(separator: "  ")
    }

    private var earningsText: String {
        if isTie { return "±0 (insats tillbaka)" }
        if winnerIndex == 0 {
            let opponents = players.count - 1
            return "+\(TimeEngine.shortFormatted(betAmount * Double(opponents)))"
        }
        return "−\(TimeEngine.shortFormatted(betAmount))"
    }

    // MARK: - Result Header

    private var resultHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(resultColor.opacity(0.15))
                    .frame(width: 110, height: 110)
                    .scaleEffect(resultAnimating ? 1 : 0.5)
                Text(resultEmoji)
                    .font(.system(size: 58))
                    .scaleEffect(resultAnimating ? 1 : 0.3)
                    .opacity(resultAnimating ? 1 : 0)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.65), value: resultAnimating)

            Text(resultTitle)
                .font(.system(size: 32, weight: .black, design: .monospaced))
                .foregroundColor(resultColor)
                .kerning(3)
                .opacity(resultAnimating ? 1 : 0)
                .offset(y: resultAnimating ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: resultAnimating)

            Text(resultSubtitle)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .opacity(resultAnimating ? 1 : 0)
                .animation(.easeIn(duration: 0.4).delay(0.3), value: resultAnimating)

            VStack(spacing: 4) {
                Text("RESULTAT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .kerning(2)
                HStack(spacing: 6) {
                    Image(systemName: winnerIndex == 0 ? "arrow.up.circle.fill" : (isTie ? "equal.circle.fill" : "arrow.down.circle.fill"))
                        .font(.system(size: 16))
                        .foregroundColor(resultColor)
                    Text(earningsText)
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundColor(resultColor)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(resultColor.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(resultColor.opacity(0.25), lineWidth: 1))
            .opacity(resultAnimating ? 1 : 0)
            .scaleEffect(resultAnimating ? 1 : 0.85)
            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.4), value: resultAnimating)
        }
    }

    // MARK: - Final Score Card

    private var finalScoreCard: some View {
        VStack(spacing: 0) {
            Text("SLUTRESULTAT")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .kerning(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(0..<players.count, id: \.self) { i in
                let p            = players[i]
                let color: Color = i == 0 ? .accentGreen : .orange
                let isWinner     = winnerIndex == i

                HStack(spacing: 12) {
                    if gameMode == .vsAI && i == 1 {
                        Text("🤖").font(.system(size: 20))
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(p.name)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(color)
                            if isWinner && !isTie {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.goldYatzy)
                            }
                        }
                        Text("Övre: \(p.upperTotal)\(p.hasBonus ? " +50 bonus" : "")  Nedre: \(p.lowerTotal)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Text("\(p.grandTotal)")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundColor(isWinner && !isTie ? .goldYatzy : color.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(isWinner && !isTie ? color.opacity(0.08) : Color.clear)

                if i < players.count - 1 {
                    Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                }
            }

            Divider().background(Color.white.opacity(0.06))

            if !players.isEmpty {
                HStack {
                    Text("Bonusgräns (övre ≥63): +50p")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
    }

    // MARK: - Action Buttons

    private var actionButtonsGameOver: some View {
        VStack(spacing: 10) {
            Button(action: onPlayAgain) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("SPELA IGEN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.accentGreen)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.accentGreen.opacity(0.35), radius: 10, y: 4)
            }
            Button(action: onDismiss) {
                Text("AVSLUTA")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
