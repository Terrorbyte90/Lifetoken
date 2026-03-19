import SwiftUI

struct StepBetResultCard: View {
    let playerName: String
    let rank: Int
    let totalPlayers: Int
    let steps: Int
    let winnerName: String
    let stakeSeconds: Int
    let accentColor: Color

    var body: some View {
        VStack(spacing: LTSpacing.md) {
            Text("STEGDUELL RESULTAT")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(accentColor)
                .tracking(3)

            Text("#\(rank) av \(totalPlayers)")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(rank == 1 ? accentColor : .white)

            VStack(spacing: LTSpacing.xs) {
                Text("\(playerName): \(steps) steg")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
                Text("Vinnare: \(winnerName)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Insats: \(stakeSeconds)s")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(LTSpacing.lg)
        .frame(width: 390, height: 200)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
    }
}
