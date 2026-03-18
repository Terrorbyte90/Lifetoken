import SwiftUI

// MARK: - In Time Clock
// Visar balansen som  YY : DDD : HH : MM : SS
// Inspirerad av filmens "In Time" — neongrön på svart, monospaced.
// Premium: digit-by-digit animation, neon glow-lager, adaptiv färg.

struct InTimeClockView: View {

    let balance: TimeInterval
    let pulseAnim: Bool

    // MARK: Adaptiv neon-färg
    private var displayColor: Color {
        if balance <= 0    { return LTPalette.danger }
        if balance < 3600  { return LTPalette.danger }
        if balance < 21600 { return LTPalette.warning }
        return LTPalette.neonGreen
    }

    // MARK: Tidsdekomposition
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
            unitCell(value: String(format: "%03d", c.yr),  label: "ÅR",  color: col)
            colonSep(color: col)
            unitCell(value: String(format: "%03d", c.day), label: "DAG", color: col)
            colonSep(color: col)
            unitCell(value: String(format: "%02d", c.hr),  label: "TIM", color: col)
            colonSep(color: col)
            unitCell(value: String(format: "%02d", c.min), label: "MIN", color: col)
            colonSep(color: col)
            unitCell(value: String(format: "%02d", c.sec), label: "SEK", color: col)
        }
        .scaleEffect(pulseAnim ? 1.04 : 1.0)
        .animation(LTAnimation.springFast, value: pulseAnim)
    }

    // MARK: - Siffercell med neon-glow
    private func unitCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: LTSpacing.xs) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                // Dubbellager glow: tight + spread
                .shadow(color: color.opacity(0.9), radius: 4)
                .shadow(color: color.opacity(0.4), radius: 10)
                .contentTransition(.numericText(countsDown: true))
                .animation(LTAnimation.fadeFast, value: value)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(color.opacity(0.38))
        }
        .padding(.horizontal, LTSpacing.xs - 1)
    }

    // MARK: - Kolon-separator — justeras mot sifferraden
    private func colonSep(color: Color) -> some View {
        VStack(spacing: LTSpacing.xs) {
            Text(":")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.28))
                .shadow(color: color.opacity(0.3), radius: 4)
            // Osynlig spacer som matchar label-radens höjd
            Text(" ")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
        }
    }
}

// MARK: - Preview
#Preview {
    let healthyBalance: TimeInterval = 94_518_641   // ~3 år 45 dagar
    let warningBalance: TimeInterval = 2_700         // 45 min (röd)
    return ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: LTSpacing.xxxl) {
            InTimeClockView(balance: healthyBalance, pulseAnim: false)
            InTimeClockView(balance: warningBalance,  pulseAnim: true)
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.lg))
    }
}
