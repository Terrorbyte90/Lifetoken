import SwiftUI
import UserNotifications

// MARK: - Dystopisk Onboarding — 6 steg + namnregistrering
// Premium: stegindikator, spring-animationer, neon-accenter, haptics

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @StateObject private var onboarding = OnboardingEngine.shared
    @State private var step: Int = 0
    @State private var playerName: String = ""
    @State private var nameError: String = ""
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 20
    @State private var buttonOpacity: Double = 0
    @State private var drainSeconds: Int = 0
    @FocusState private var nameFocused: Bool

    private let drainTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let totalSteps = 7   // steg 0–6

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Subtil bakgrundsglow vars färg matchar steg
            RadialGradient(
                colors: [stepAccentColor.opacity(0.06), .clear],
                center: UnitPoint(x: 0.5, y: 0.25),
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            .animation(LTAnimation.fade, value: step)

            VStack(spacing: 0) {
                topBar
                Spacer()
                stepContent
                    .opacity(contentOpacity)
                    .offset(y: contentOffset)
                    .padding(.horizontal, LTSpacing.xxl + LTSpacing.xs)
                Spacer()
                bottomSection
                    .opacity(buttonOpacity)
                    .padding(.horizontal, LTSpacing.xxl)
                    .padding(.bottom, 52)
            }
        }
        .onAppear { animateIn() }
        .onReceive(drainTimer) { _ in drainSeconds += 1 }
        .preferredColorScheme(.dark)
    }

    // MARK: - Toppfält (drain + stegindikator)

    private var topBar: some View {
        HStack(alignment: .top) {
            // Stegindikator (prickar)
            HStack(spacing: LTSpacing.xs) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? stepAccentColor : Color.white.opacity(0.12))
                        .frame(width: i == step ? 18 : 6, height: 4)
                        .animation(LTAnimation.springFast, value: step)
                }
            }
            .padding(.top, 64)
            .padding(.leading, LTSpacing.xl)

            Spacer()

            // Live drain-räknare
            VStack(alignment: .trailing, spacing: 2) {
                Text("−\(drainSeconds)s")
                    .font(LTFont.value(15))
                    .foregroundColor(LTPalette.danger)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(LTAnimation.fadeFast, value: drainSeconds)
                Text("DRÄNERAS")
                    .font(LTFont.caption(7))
                    .foregroundColor(LTPalette.danger.opacity(0.45))
                    .tracking(2)
            }
            .padding(.top, 60)
            .padding(.trailing, LTSpacing.xl)
        }
    }

    // MARK: - Steg-innehåll

    @ViewBuilder
    private var stepContent: some View {
        if onboarding.currentStep == 0.5 {
            stepHealthKit
        } else {
            switch step {
            case 0: stepVerkligheten
            case 1: stepSystemet
            case 2: stepMakthierarkin
            case 3: stepZonerna
            case 4: stepOforlatande
            case 5: stepAcceptansen
            case 6: stepNamn
            default: EmptyView()
            }
        }
    }

    // Steg 0.5 — HealthKit-tillåtelse
    private var stepHealthKit: some View {
        VStack(spacing: 24) {
            Text("Dina steg ger dig tid.")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(LTPalette.neonGreen)
            Text("Lifetoken läser dina hälsodata — ingenting delas.")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Godkänn") {
                HealthKitManager.shared.requestAuthorization { granted in
                    Task { @MainActor in
                        OnboardingEngine.shared.setHealthKitAccess(granted)
                        step = 1
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Hoppa över") {
                OnboardingEngine.shared.healthKitDenied()
                step = 1
            }
            .foregroundStyle(.secondary)
        }
    }

    // Steg 0 — Verkligheten
    private var stepVerkligheten: some View {
        VStack(alignment: .leading, spacing: LTSpacing.xxl) {
            stepLabel("VERKLIGHETEN")

            Text("Du har 10 dagar på dig.")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineSpacing(6)

            Text("Klockan tickar redan.")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(LTPalette.danger)
                .neonGlow(LTPalette.danger, intensity: 0.4)

            Text("Tjäna mer tid — eller dö.")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, LTSpacing.sm)
        }
    }

    // Steg 1 — Systemet
    private var stepSystemet: some View {
        VStack(alignment: .leading, spacing: LTSpacing.xl) {
            stepLabel("SYSTEMET")

            Text("Styrelsen kontrollerar ekonomin.")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: LTSpacing.md) {
                boardMember(name: "GREGOR SKATT", role: "Tar din skatt.",
                            color: Color(red: 0.9, green: 0.3, blue: 0.1))
                boardMember(name: "ARVID TOLL",   role: "Tar sin avgift.",
                            color: Color(red: 0.8, green: 0.5, blue: 0.1))
                boardMember(name: "LEON PRENT",   role: "Förstör ditt sparande.",
                            color: Color(red: 0.6, green: 0.3, blue: 0.8))
            }

            Text("Det är inte orättvist — det är reglerna.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.38))
                .padding(.top, LTSpacing.xs)
        }
    }

    // Steg 2 — Makthierarkin
    private var stepMakthierarkin: some View {
        VStack(alignment: .leading, spacing: LTSpacing.xl) {
            stepLabel("MAKTHIERARKIN")

            Text("Tre platser i toppen styr världen.")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: LTSpacing.md) {
                rankRow(rank: "RANK 1", text: "Kontrollerar all skatteintäkt")
                rankRow(rank: "RANK 2", text: "Drar systemavgiften varje vecka")
                rankRow(rank: "RANK 3", text: "Utlöser inflationsspiken")
            }
            .padding(LTSpacing.md)
            .background(LTPalette.gold.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: LTRadius.sm)
                .stroke(LTPalette.gold.opacity(0.15), lineWidth: 1))

            Text("Just nu sitter Styrelsen där.\n\nOm du någonsin har mer tid än dem tar du deras makt.\n\nDet är det enda sättet att förändra systemet.")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(5)
                .padding(.top, LTSpacing.xs)
        }
    }

    // Steg 3 — Zonerna
    private var stepZonerna: some View {
        VStack(alignment: .leading, spacing: LTSpacing.xl) {
            stepLabel("ZONERNA")

            Text("Du börjar i Askan.")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.1))
                .neonGlow(Color(red: 0.9, green: 0.3, blue: 0.1), intensity: 0.3)

            Text("Ingen valde att vara här.")
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.65))

            Text("14 zoner uppåt. Varje zon ger bättre lön, mer makt — och högre skatt.\n\nDe flesta dör i Stigarnas Dal.\n\nKlättra uppåt eller dö försökandes.")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
                .lineSpacing(5)
                .padding(.top, LTSpacing.xs)
        }
    }

    // Steg 4 — Oförlåtande
    private var stepOforlatande: some View {
        VStack(alignment: .leading, spacing: LTSpacing.xl) {
            stepLabel("VARNING", color: LTPalette.danger)

            Text("Det finns inga andra chanser.")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("Nollställs din tid — dör du.")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(LTPalette.danger)
                .neonGlow(LTPalette.danger, intensity: 0.35)

            Text("Systemet bryr sig inte.")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.38))

            Text("Din hälsa är din lön. Dina steg ger tid. Tjäna på jobbet, vinn på kasinot, råna andra spelare — gör vad som krävs.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.42))
                .lineSpacing(4)
                .padding(.top, LTSpacing.xs)
        }
    }

    // Steg 5 — Acceptansen
    private var stepAcceptansen: some View {
        VStack(alignment: .leading, spacing: LTSpacing.xxl) {
            stepLabel("VILLKOREN")

            Text("Den här världen kommer pressa dig att arbeta hårt, vara hänsynslös och tuff.")
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .lineSpacing(5)

            Text("De svaga förlorar sin tid.\nDe starka tar den.")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(LTPalette.gold)
                .lineSpacing(4)
                .neonGlow(LTPalette.gold, intensity: 0.3)

            Text("Genom att fortsätta accepterar du villkoren.")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
        }
    }

    // Steg 6 — Namn
    private var stepNamn: some View {
        VStack(alignment: .leading, spacing: LTSpacing.xl) {
            stepLabel("REGISTRERING")

            Text("Vad ska du kallas?")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("Ditt namn följer dig tills du dör.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.38))

            // Input-fält med neon-underline
            VStack(alignment: .leading, spacing: 0) {
                TextField("", text: $playerName)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tint(LTPalette.neonGreen)
                    .padding(.vertical, LTSpacing.md)
                    .padding(.horizontal, LTSpacing.sm)
                    .focused($nameFocused)
                    .onAppear { nameFocused = true }
                    .submitLabel(.done)
                    .accessibilityLabel("Ange ditt spelarnamn")

                // Animated bottom border
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                LTPalette.neonGreen.opacity(playerName.isEmpty ? 0.3 : 0.8),
                                LTPalette.neonGreenDim.opacity(playerName.isEmpty ? 0.1 : 0.4)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .shadow(color: LTPalette.neonGreen.opacity(playerName.isEmpty ? 0 : 0.5), radius: 4)
                    .animation(LTAnimation.fade, value: playerName.isEmpty)
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))

            if !nameError.isEmpty {
                HStack(spacing: LTSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(nameError)
                        .font(LTFont.body(12))
                }
                .foregroundColor(LTPalette.danger)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Nedre sektion (knapp + skip)

    private var bottomSection: some View {
        VStack(spacing: LTSpacing.md) {
            mainButton

            // Steg-räknare
            Text("\(step + 1) av \(totalSteps)")
                .font(LTFont.caption(9))
                .foregroundColor(.white.opacity(0.18))
                .tracking(2)
        }
    }

    @ViewBuilder
    private var mainButton: some View {
        if onboarding.currentStep == 0.5 {
            EmptyView() // HealthKit screen has its own Godkänn/Hoppa över buttons
        } else if step < 5 {
            actionButton(
                label: "FORTSÄTT",
                color: .white,
                textColor: .black
            ) { nextStep() }
        } else if step == 5 {
            actionButton(
                label: "JAG FÖRSTÅR",
                color: LTPalette.gold,
                textColor: .black
            ) { nextStep() }
        } else {
            let nameReady = !playerName.trimmingCharacters(in: .whitespaces).isEmpty
            actionButton(
                label: "STARTA LIVET",
                color: nameReady ? LTPalette.neonGreen : Color.white.opacity(0.12),
                textColor: nameReady ? .black : .white.opacity(0.3)
            ) { commitName() }
            .disabled(!nameReady)
        }
    }

    private func actionButton(
        label: String,
        color: Color,
        textColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            Text(label)
                .font(LTFont.heading(15))
                .foregroundColor(textColor)
                .tracking(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                .shadow(color: color.opacity(0.3), radius: 10, y: 4)
        }
        .buttonStyle(LTPressEffect())
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    private var stepAccentColor: Color {
        switch step {
        case 0: return LTPalette.danger
        case 1: return Color(red: 0.8, green: 0.5, blue: 0.1)
        case 2: return LTPalette.gold
        case 3: return Color(red: 0.9, green: 0.3, blue: 0.1)
        case 4: return LTPalette.danger
        case 5: return LTPalette.gold
        case 6: return LTPalette.neonGreen
        default: return .white
        }
    }

    private func nextStep() {
        withAnimation(LTAnimation.fade) {
            contentOpacity = 0
            contentOffset = -12
            buttonOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onboarding.advance()
            // Step 0.5 is the HealthKit screen — integer step stays at 0 until HealthKit resolves
            if onboarding.currentStep != 0.5 {
                step = Int(onboarding.currentStep)
            }
            contentOffset = 20
            animateIn()
        }
    }

    private func commitName() {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            withAnimation(LTAnimation.springFast) { nameError = "Skriv ett namn." }
            return
        }
        guard name.count >= 2 else {
            withAnimation(LTAnimation.springFast) { nameError = "För kort. Minst 2 tecken." }
            return
        }
        let notif = UINotificationFeedbackGenerator()
        notif.notificationOccurred(.success)
        UserDefaults.standard.set(name, forKey: "username")
        GameState.shared.username = name
        OnboardingEngine.shared.completeOnboarding()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        Task { await ServerSync.shared.startup() }
        withAnimation(LTAnimation.springSmooth) { showOnboarding = false }
    }

    private func animateIn() {
        withAnimation(LTAnimation.springSmooth) {
            contentOpacity = 1
            contentOffset = 0
        }
        withAnimation(LTAnimation.springSmooth.delay(0.18)) {
            buttonOpacity = 1
        }
    }

    // MARK: - Sub-vyer

    private func stepLabel(_ text: String, color: Color = Color.white.opacity(0.4)) -> some View {
        Text(text)
            .font(LTFont.caption(11))
            .foregroundColor(color)
            .tracking(3)
    }

    private func boardMember(name: String, role: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: LTSpacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3)
                .shadow(color: color.opacity(0.5), radius: 3)
            VStack(alignment: .leading, spacing: LTSpacing.xs) {
                Text(name)
                    .font(LTFont.heading(13))
                    .foregroundColor(color)
                Text(role)
                    .font(LTFont.body(13))
                    .foregroundColor(.white.opacity(0.60))
            }
        }
    }

    private func rankRow(rank: String, text: String) -> some View {
        HStack(spacing: LTSpacing.lg) {
            Text(rank)
                .font(LTFont.label(11))
                .foregroundColor(LTPalette.gold)
                .frame(width: 60, alignment: .leading)
            Text(text)
                .font(LTFont.body(13))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

// MARK: - Legacy IntroView (behålls för kompatibilitet)

struct IntroView: View {
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore = false
    var body: some View {
        OnboardingView(showOnboarding: .constant(true))
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
        .preferredColorScheme(.dark)
}
