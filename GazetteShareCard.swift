import SwiftUI

/// Dedicated shareable card — rendered to PNG via ImageRenderer
struct GazetteShareCard: View {
    let headline: String
    let ingress: String
    let playerName: String
    let date: Date
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: LTSpacing.md) {
            HStack {
                Text("LIFETOKEN GAZETTE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                Spacer()
                Text(date.formatted(.dateTime.day().month().year()))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Rectangle()
                .frame(height: 1)
                .foregroundStyle(accentColor)

            Text(headline.uppercased())
                .font(.system(size: 18, weight: .black, design: .default))
                .foregroundStyle(.white)
                .lineLimit(3)

            Text(ingress)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(4)

            Spacer()

            Text(playerName)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(accentColor)
        }
        .padding(LTSpacing.lg)
        .frame(width: 390, height: 220)
        .background(Color(hex: "#1A1A1A") ?? Color(red: 0.102, green: 0.102, blue: 0.102))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
    }
}
