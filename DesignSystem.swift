import SwiftUI

// MARK: - LifeToken Design System
// Centraliserade konstanter för typografi, spacing, animation och färger.
// Inga magic numbers i UI-lagret — allt refereras härifrån.

// MARK: - Spacing

enum LTSpacing {
    /// 4pt — tight micro gap
    static let xs: CGFloat    = 4
    /// 8pt — standard small gap
    static let sm: CGFloat    = 8
    /// 12pt — compact padding
    static let md: CGFloat    = 12
    /// 16pt — standard content padding
    static let lg: CGFloat    = 16
    /// 20pt — generous inner padding
    static let xl: CGFloat    = 20
    /// 24pt — section separation
    static let xxl: CGFloat   = 24
    /// 32pt — large section gap
    static let xxxl: CGFloat  = 32

    /// Standard horizontal edge padding
    static let horizontal: CGFloat = 16
    /// Minimum safe bottom inset for scrollable content (tab bar + buffer)
    static let scrollBottom: CGFloat = 110
}

// MARK: - Corner Radius

enum LTRadius {
    static let xs: CGFloat   = 8
    static let sm: CGFloat   = 12
    static let md: CGFloat   = 16
    static let lg: CGFloat   = 20
    static let xl: CGFloat   = 24
    static let pill: CGFloat = 999
}

// MARK: - Typography

enum LTFont {
    // Display
    static func displayHero(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .black, design: .monospaced)
    }
    static func displayTitle(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    // Headings
    static func heading(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    // Labels
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    static func labelSemibold(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
    // Body
    static func body(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
    // Numeric / value readout
    static func value(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .black, design: .monospaced)
    }
    // Micro caption
    static func caption(_ size: CGFloat = 9) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

// MARK: - Animation Presets

enum LTAnimation {
    /// Standard spring for button presses and card reveals
    static let springFast    = Animation.spring(response: 0.30, dampingFraction: 0.75)
    /// Smooth spring for sheet/modal presentations
    static let springSmooth  = Animation.spring(response: 0.45, dampingFraction: 0.80)
    /// Slower spring for large layout transitions
    static let springGentle  = Animation.spring(response: 0.60, dampingFraction: 0.85)
    /// Quick opacity crossfade
    static let fadeFast      = Animation.easeInOut(duration: 0.18)
    /// Standard crossfade
    static let fade          = Animation.easeInOut(duration: 0.30)
    /// Slow ambient pulse (repeatForever)
    static let ambientPulse  = Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)
}

// MARK: - Palette

enum LTPalette {
    // Core brand
    static let neonGreen    = Color(red: 0.00, green: 1.00, blue: 0.255)   // #00FF41
    static let neonGreenDim = Color(red: 0.15, green: 0.85, blue: 0.35)

    // Status
    static let danger       = Color(red: 1.00, green: 0.20, blue: 0.20)
    static let warning      = Color(red: 1.00, green: 0.70, blue: 0.10)
    static let gold         = Color(red: 1.00, green: 0.85, blue: 0.30)

    // Backgrounds
    static let bg           = Color(red: 0.02, green: 0.03, blue: 0.07)
    static let bgCard       = Color(red: 0.04, green: 0.05, blue: 0.09)
    static let bgElevated   = Color(red: 0.07, green: 0.08, blue: 0.12)

    // Strokes
    static func stroke(_ color: Color, _ opacity: Double = 0.25) -> Color {
        color.opacity(opacity)
    }
}

// MARK: - ViewModifiers

/// Premium card container: dark fill + subtle gradient sheen + rounded corners + optional border
struct LTCardModifier: ViewModifier {
    var color: Color = .white
    var opacity: Double = 0.05
    var radius: CGFloat = LTRadius.md
    var borderOpacity: Double = 0.10
    var shadowColor: Color = .clear
    var shadowRadius: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Color.white.opacity(opacity)
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(color.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 3)
    }
}

/// Accent card: colored gradient bg + matching border
struct LTAccentCardModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = LTRadius.md

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [color.opacity(0.14), color.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(color.opacity(0.30), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

/// Haptic button scale effect
struct LTPressEffect: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(LTAnimation.springFast, value: configuration.isPressed)
    }
}

/// Reduced-motion-safe animation helper
extension View {
    @ViewBuilder
    func ltAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        self.animation(animation, value: value)
    }

    func ltCard(
        color: Color = .white,
        opacity: Double = 0.05,
        radius: CGFloat = LTRadius.md,
        borderOpacity: Double = 0.10,
        shadowColor: Color = .clear,
        shadowRadius: CGFloat = 0
    ) -> some View {
        modifier(LTCardModifier(
            color: color,
            opacity: opacity,
            radius: radius,
            borderOpacity: borderOpacity,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius
        ))
    }

    func ltAccentCard(color: Color, radius: CGFloat = LTRadius.md) -> some View {
        modifier(LTAccentCardModifier(color: color, radius: radius))
    }
}

// MARK: - Shimmer Placeholder

struct LTShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color.white.opacity(0.04), location: phase - 0.3),
                .init(color: Color.white.opacity(0.12), location: phase),
                .init(color: Color.white.opacity(0.04), location: phase + 0.3),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.3
            }
        }
    }
}

// MARK: - Neon Glow Modifier

struct NeonGlowModifier: ViewModifier {
    let color: Color
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(Double(intensity) * 0.9), radius: intensity * 2)
            .shadow(color: color.opacity(Double(intensity) * 0.5), radius: intensity * 5)
    }
}

extension View {
    func neonGlow(_ color: Color, intensity: CGFloat = 1.0) -> some View {
        modifier(NeonGlowModifier(color: color, intensity: intensity))
    }
}

// MARK: - Accessibility

extension View {
    /// Shorthand for common accessibility label + hint combo
    func ltAccessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
}
