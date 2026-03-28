import SwiftUI

// MARK: - Scorecard View

/// Full scorecard grid showing all categories and player scores.
struct YatzyScorecardView: View {
    let players: [YatzyPlayerState]
    let currentPlayerIndex: Int
    let currentDice: [Int]
    let canScore: Bool
    let isCurrentPlayerAI: Bool
    let onSelectCategory: (MultiYatzyCategory) -> Void

    var body: some View {
        VStack(spacing: 0) {
            scorecardGuide
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Header row
            headerRow

            Divider()
                .background(Color.white.opacity(0.08))

            // Upper section
            sectionHeader(title: "ÖVRE SEKTION")

            ForEach(MultiYatzyCategory.allCases.filter { $0.isUpperSection }) { cat in
                scoreRow(category: cat)
            }

            // Bonus row
            bonusRow

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.vertical, 4)

            // Lower section
            sectionHeader(title: "NEDRE SEKTION")

            ForEach(MultiYatzyCategory.allCases.filter { !$0.isUpperSection }) { cat in
                scoreRow(category: cat)
            }

            // Total row
            totalRow
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var scorecardGuide: some View {
        LTInfoCallout(
            title: isCurrentPlayerAI ? "AI beräknar" : "Välj kategori",
            message: isCurrentPlayerAI
                ? "AI väljer automatiskt bästa tillgängliga kategori för sin tur."
                : "Gröna värden visar möjlig poäng med nuvarande tärningar. Tryck på en rad för att låsa poängen.",
            icon: isCurrentPlayerAI ? "cpu.fill" : "tablecells.fill",
            tint: isCurrentPlayerAI ? .orange : .accentGreen
        )
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("KATEGORI")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .kerning(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<players.count, id: \.self) { i in
                let color: Color = i == 0 ? .accentGreen : .orange
                Text(players[i].name.prefix(5).uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.7))
                    .kerning(0.5)
                    .frame(width: 48, alignment: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Section Header

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.25))
            .kerning(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    // MARK: - Score Row

    private func scoreRow(category: MultiYatzyCategory) -> some View {
        let isActive = canScore && !isCurrentPlayerAI
            && currentPlayerIndex < players.count
            && players[currentPlayerIndex].scores[category] == nil
        let potential = multiYatzyScore(for: category, dice: currentDice)

        return Button {
            if isActive { onSelectCategory(category) }
        } label: {
            HStack(spacing: 0) {
                // Category name
                Text(category.displayName)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(isActive ? .white : .white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Scores for each player
                ForEach(0..<players.count, id: \.self) { i in
                    let p     = players[i]
                    let score = p.scores[category]
                    let isCurrent = i == currentPlayerIndex
                    let color: Color = i == 0 ? .accentGreen : .orange

                    Group {
                        if let s = score {
                            Text(s == 0 ? "—" : "\(s)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(s == 0 ? color.opacity(0.25) : color.opacity(0.9))
                                .strikethrough(s == 0, color: color.opacity(0.3))
                        } else if isCurrent && isActive {
                            Text(potential > 0 ? "\(potential)" : "0")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(potential > 0 ? color.opacity(0.55) : .white.opacity(0.2))
                        } else {
                            Text("—")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.12))
                        }
                    }
                    .frame(width: 48, alignment: .center)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                isActive && potential > 0
                    ? Color.accentGreen.opacity(0.07)
                    : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
    }

    // MARK: - Bonus Row

    private var bonusRow: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Bonus")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.goldYatzy.opacity(0.8))
                Text("≥63p → +50p")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<players.count, id: \.self) { i in
                let p      = players[i]
                let upper  = p.upperTotal
                let needed = max(0, 63 - upper)
                let color: Color = i == 0 ? .accentGreen : .orange

                VStack(spacing: 1) {
                    if p.hasBonus {
                        Text("+50")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.goldYatzy)
                    } else {
                        Text("\(upper)/63")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(color.opacity(0.5))
                        if needed > 0 {
                            Text("−\(needed)")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.white.opacity(0.25))
                        }
                    }
                }
                .frame(width: 48, alignment: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.goldYatzy.opacity(0.04))
    }

    // MARK: - Total Row

    private var totalRow: some View {
        HStack(spacing: 0) {
            Text("TOTAL")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(0..<players.count, id: \.self) { i in
                let p     = players[i]
                let color: Color = i == 0 ? .accentGreen : .orange
                Text("\(p.grandTotal)")
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .foregroundColor(color)
                    .frame(width: 48, alignment: .center)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
