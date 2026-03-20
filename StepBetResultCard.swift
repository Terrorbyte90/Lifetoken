import SwiftUI

struct StepBetResultCard: View {
    let playerName: String
    let rank: Int
    let totalPlayers: Int
    let steps: Int
    let winnerName: String
    let stakeSeconds: Int
    let accentColor: Color

    private var won: Bool { rank == 1 }

    var body: some View {
        VStack(spacing: LTSpacing.md) {
            // Rubrik
            Text("STEGDUELL RESULTAT")
                .font(LTFont.label(11))
                .foregroundStyle(accentColor)
                .tracking(3)

            // Placering
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("#\(rank)")
                    .font(LTFont.value(40))
                    .foregroundStyle(won ? accentColor : .white)
                Text("av \(totalPlayers)")
                    .font(LTFont.body(14))
                    .foregroundStyle(Color(red: 0.5, green: 0.5, blue: 0.6))
            }

            // Spelarinformation
            VStack(spacing: LTSpacing.xs) {
                HStack(spacing: LTSpacing.xs) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12))
                        .foregroundStyle(accentColor.opacity(0.8))
                    Text("\(playerName): \(steps) steg")
                        .font(LTFont.body(14))
                        .foregroundStyle(.white)
                }

                HStack(spacing: LTSpacing.xs) {
                    Image(systemName: won ? "trophy.fill" : "person.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(won ? LTPalette.gold : Color(red: 0.5, green: 0.5, blue: 0.6))
                    Text("Vinnare: \(winnerName)")
                        .font(LTFont.body(12))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: LTSpacing.xs) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(LTPalette.gold.opacity(0.7))
                    Text("Insats: \(TimeEngine.shortFormatted(TimeInterval(stakeSeconds)))")
                        .font(LTFont.body(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(LTSpacing.lg)
        .frame(width: 390, height: 200)
        .background(
            ZStack {
                Color(red: 0.07, green: 0.08, blue: 0.10)
                LinearGradient(
                    colors: [accentColor.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.md)
                .stroke(accentColor.opacity(0.25), lineWidth: 1)
        )
    }
}
