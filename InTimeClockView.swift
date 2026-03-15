import SwiftUI

// MARK: - In Time Clock
// Displays balance as  YY : DDD : HH : MM : SS
// inspired by the "In Time" film aesthetic — neon green on dark, monospaced digits.

struct InTimeClockView: View {

    let balance: TimeInterval
    let pulseAnim: Bool

    // MARK: Neon green (#00FF41) for healthy; warning colours preserved
    private var displayColor: Color {
        if balance <= 0    { return .red }
        if balance < 3600  { return .red }
        if balance < 21600 { return .yellow }
        return Color(red: 0, green: 1.0, blue: 65 / 255)   // #00FF41
    }

    // MARK: Time decomposition — strict integer modulo chain, no months/weeks
    private var components: (yr: Int, day: Int, hr: Int, min: Int, sec: Int) {
        let s    = Int(max(0, balance))
        let yr   = s / 31_536_000
        let rem1 = s % 31_536_000
        let day  = rem1 / 86_400
        let rem2 = rem1 % 86_400
        let hr   = rem2 / 3_600
        let rem3 = rem2 % 3_600
        let min  = rem3 / 60
        let sec  = rem3 % 60
        return (yr, day, hr, min, sec)
    }

    var body: some View {
        let c   = components
        let col = displayColor

        HStack(alignment: .top, spacing: 0) {
            unitCell(value: String(format: "%02d",  c.yr),  label: "ÅR",  color: col)
            colonSep(color: col)
            unitCell(value: String(format: "%03d",  c.day), label: "DAG", color: col)
            colonSep(color: col)
            unitCell(value: String(format: "%02d",  c.hr),  label: "TIM", color: col)
            colonSep(color: col)
            unitCell(value: String(format: "%02d",  c.min), label: "MIN", color: col)
            colonSep(color: col)
            unitCell(value: String(format: "%02d",  c.sec), label: "SEK", color: col)
        }
        .scaleEffect(pulseAnim ? 1.04 : 1.0)
    }

    // MARK: - Unit cell: number on top, small label beneath
    private func unitCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(color.opacity(0.4))
        }
        .padding(.horizontal, 3)
    }

    // MARK: - Colon separator — vertically aligned to number row only
    // The invisible spacer text below mirrors the label row height so the
    // colon sits flush with the number row across all cells.
    private func colonSep(color: Color) -> some View {
        VStack(spacing: 3) {
            Text(":")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.3))
            // Height-matching invisible spacer for the label row
            Text(" ")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
    }
}

// MARK: - Preview
#Preview {
    let healthyBalance: TimeInterval = 94_518_641   // ~3 years 45 days
    let warningBalance: TimeInterval = 2_700         // 45 min (red)
    return ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 32) {
            InTimeClockView(balance: healthyBalance, pulseAnim: false)
            InTimeClockView(balance: warningBalance,  pulseAnim: true)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
