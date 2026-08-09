import SwiftUI

/// Confetti particles on casino win. Uses SwiftUI Canvas.
/// Requires ThemeEngine as @EnvironmentObject.
struct CasinoParticleView: View {
    @EnvironmentObject var theme: ThemeEngine

    private struct Particle {
        let x: CGFloat
        let size: CGFloat
        let speed: Double
        let wobble: Double
    }

    private let particles: [Particle] = (0..<50).map { _ in
        Particle(
            x: CGFloat.random(in: 0...1),
            size: CGFloat.random(in: 4...10),
            speed: Double.random(in: 0.3...1.0),
            wobble: Double.random(in: 1...3)
        )
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for p in particles {
                    let y = CGFloat(t * p.speed).truncatingRemainder(dividingBy: size.height + 20) - 10
                    let x = p.x * size.width + CGFloat(sin(t * p.wobble) * 15)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: p.size, height: p.size)),
                        with: .color(theme.current.accent.opacity(0.85))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
