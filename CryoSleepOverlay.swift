import SwiftUI

// MARK: - CryoSleepOverlay

/// Full-screen overlay displayed when CryoSleep is active.
/// Pauses time drain and shows an ice-particle animation with elapsed time.
struct CryoSleepOverlay: View {
    @ObservedObject var timeEngine = TimeEngine.shared
    @State private var elapsed: TimeInterval = 0
    @State private var showWakeAlert = false

    private let particles: [(CGFloat, CGFloat, Double)] = (0..<40).map { _ in
        (CGFloat.random(in: 0...1), CGFloat.random(in: 0...1), Double.random(in: 0.5...2.0))
    }

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    for (x, _, speed) in particles {
                        let yPos = (CGFloat(t * speed).truncatingRemainder(dividingBy: size.height + 20)) - 10
                        let xPos = x * size.width
                        context.fill(
                            Path(ellipseIn: CGRect(x: xPos, y: yPos, width: 3, height: 3)),
                            with: .color(.cyan.opacity(0.6))
                        )
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: LTSpacing.xl) {
                Text("KRYOSÖMN AKTIV")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .tracking(3)

                Text(formattedElapsed)
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)

                Text("Din tid är fryst.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Button("Vakna") {
                    showWakeAlert = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            elapsed += 1
        }
        .alert("Avbryt kryosömn?", isPresented: $showWakeAlert) {
            Button("Vakna", role: .destructive) {
                TimeEngine.shared.deactivateCryoSleep()
            }
            Button("Fortsätt sova", role: .cancel) {}
        } message: {
            Text("Din tidsdrain återupptas omedelbart.")
        }
    }

    private var formattedElapsed: String {
        let h = Int(elapsed) / 3600
        let m = (Int(elapsed) % 3600) / 60
        let s = Int(elapsed) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
