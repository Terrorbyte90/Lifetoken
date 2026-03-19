import SwiftUI

// MARK: - Color Extensions (shared)

extension Color {
    static let goldYatzy   = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let accentGreen = Color(red: 0.2, green: 0.9, blue: 0.4)
}

// MARK: - Die Dot View

struct DieDotView: View {
    let value: Int
    let size: CGFloat

    // Dot layout per face value: positions as (x, y) in a 3x3 grid (0-based)
    private func dotPositions(for value: Int) -> [(Int, Int)] {
        switch value {
        case 1: return [(1,1)]
        case 2: return [(0,0),(2,2)]
        case 3: return [(0,0),(1,1),(2,2)]
        case 4: return [(0,0),(2,0),(0,2),(2,2)]
        case 5: return [(0,0),(2,0),(1,1),(0,2),(2,2)]
        case 6: return [(0,0),(2,0),(0,1),(2,1),(0,2),(2,2)]
        default: return []
        }
    }

    var body: some View {
        let dotSize: CGFloat  = size * 0.14
        let padding: CGFloat  = size * 0.16

        ZStack {
            ForEach(Array(dotPositions(for: value).enumerated()), id: \.offset) { _, pos in
                let col      = CGFloat(pos.0)
                let row      = CGFloat(pos.1)
                let cellSize = (size - padding * 2) / 3.0
                let x        = padding + cellSize * col + cellSize / 2
                let y        = padding + cellSize * row + cellSize / 2

                Circle()
                    .fill(Color.white)
                    .frame(width: dotSize, height: dotSize)
                    .shadow(color: .white.opacity(0.6), radius: 1)
                    .offset(
                        x: x - size / 2,
                        y: y - size / 2
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Die View

struct MultiDieView: View {
    let value: Int
    var held: Bool      = false
    var isRolling: Bool = false
    var isAI: Bool      = false
    var size: CGFloat   = 60

    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat        = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18)
                .fill(
                    LinearGradient(
                        colors: heldGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: shadowColor, radius: held ? 8 : 4, x: 0, y: held ? 4 : 2)

            RoundedRectangle(cornerRadius: size * 0.18)
                .stroke(borderColor, lineWidth: held ? 2.5 : 1)
                .frame(width: size, height: size)

            DieDotView(value: max(1, min(6, value)), size: size)
        }
        .rotationEffect(.degrees(rotationAngle))
        .scaleEffect(held ? 1.08 : scale)
        .onChange(of: isRolling) { _, rolling in
            if rolling {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                    rotationAngle = Double.random(in: -25...25)
                    scale = 0.88
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    rotationAngle = 0
                    scale = 1.0
                }
            }
        }
    }

    private var heldGradient: [Color] {
        if held {
            return [
                Color(red: 0.12, green: 0.32, blue: 0.18),
                Color(red: 0.06, green: 0.18, blue: 0.10)
            ]
        } else if isAI {
            return [
                Color(red: 0.22, green: 0.06, blue: 0.08),
                Color(red: 0.12, green: 0.03, blue: 0.04)
            ]
        } else {
            return [
                Color(red: 0.18, green: 0.18, blue: 0.22),
                Color(red: 0.08, green: 0.08, blue: 0.12)
            ]
        }
    }

    private var borderColor: Color {
        if held  { return Color.accentGreen.opacity(0.85) }
        if isAI  { return Color.red.opacity(0.3) }
        return Color.white.opacity(0.15)
    }

    private var shadowColor: Color {
        if held  { return Color.accentGreen.opacity(0.5) }
        if isAI  { return Color.red.opacity(0.3) }
        return Color.black.opacity(0.5)
    }
}
