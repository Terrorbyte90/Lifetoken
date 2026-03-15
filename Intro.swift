import SwiftUI

// MARK: - Dystopisk Onboarding — 6 steg + namnregistrering

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var step: Int = 0
    @State private var playerName: String = ""
    @State private var nameError: String = ""
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var drainSeconds: Int = 0
    @FocusState private var nameFocused: Bool

    private let drainTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Live drain-räknare — alltid synlig
                HStack {
                    Spacer()
                    Text("−\(drainSeconds)s")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 0.8, green: 0.1, blue: 0.1))
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                }

                Spacer()

                stepContent
                    .opacity(textOpacity)
                    .padding(.horizontal, 28)

                Spacer()

                bottomButton
                    .opacity(buttonOpacity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
            }
        }
        .onAppear { animateIn() }
        .onReceive(drainTimer) { _ in drainSeconds += 1 }
        .preferredColorScheme(.dark)
    }

    // MARK: - Steg-innehåll

    @ViewBuilder
    private var stepContent: some View {
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

    // Steg 1 — Verkligheten
    private var stepVerkligheten: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("VERKLIGHETEN")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .tracking(3)

            Text("Du föddes med exakt 24 timmar.")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .lineSpacing(6)

            Text("Klockan tickar redan.")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 0.2, blue: 0.2))

            Text("Det finns inget sätt att pausa den.")
                .font(.system(size: 16, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .padding(.top, 8)
        }
    }

    // Steg 2 — Systemet
    private var stepSystemet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SYSTEMET")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .tracking(3)

            Text("Styrelsen kontrollerar ekonomin.")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 14) {
                boardMember(name: "GREGOR SKATT", role: "Tar din skatt.", color: Color(red: 0.9, green: 0.3, blue: 0.1))
                boardMember(name: "ARVID TOLL", role: "Tar sin avgift.", color: Color(red: 0.8, green: 0.5, blue: 0.1))
                boardMember(name: "LEON PRENT", role: "Förstör ditt sparande.", color: Color(red: 0.6, green: 0.3, blue: 0.8))
            }

            Text("Det är inte orättvist — det är reglerna.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                .padding(.top, 6)
        }
    }

    // Steg 3 — Makthierarkin
    private var stepMakthierarkin: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MAKTHIERARKIN")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .tracking(3)

            Text("Tre platser i toppen styr världen.")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 12) {
                rankRow(rank: "RANK 1", text: "Kontrollerar all skatteintäkt")
                rankRow(rank: "RANK 2", text: "Drar systemavgiften varje vecka")
                rankRow(rank: "RANK 3", text: "Utlöser inflationsspiken")
            }

            Text("Just nu sitter Styrelsen där.\n\nOm du någonsin har mer tid än dem tar du deras makt.\n\nDet är det enda sättet att förändra systemet.")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                .lineSpacing(5)
                .padding(.top, 6)
        }
    }

    // Steg 4 — Zonerna
    private var stepZonerna: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ZONERNA")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .tracking(3)

            Text("Du börjar i Askan.")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.1))

            Text("Ingen valde att vara här.")
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))

            Text("14 zoner uppåt. Varje zon ger bättre lön, mer makt — och högre skatt.\n\nDe flesta dör i Stigarnas Dal.\n\nKlättra uppåt eller dö försökandes.")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .lineSpacing(5)
                .padding(.top, 4)
        }
    }

    // Steg 5 — Oförlåtande
    private var stepOforlatande: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("VARNING")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.8, green: 0.2, blue: 0.2))
                .tracking(3)

            Text("Det finns inga andra chanser.")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("Nollställs din tid — dör du.")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 0.2, blue: 0.2))

            Text("Systemet bryr sig inte.")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))

            Text("Din hälsa är din lön. Dina steg är din valuta. Sover du dåligt — tjänar du mindre. Rör du dig inte — dör du snabbare.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                .lineSpacing(4)
                .padding(.top, 4)
        }
    }

    // Steg 5b — Acceptansen
    private var stepAcceptansen: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("VILLKOREN")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .tracking(3)

            Text("Den här världen kommer pressa dig att arbeta hårt, vara hänsynslös och tuff.")
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .lineSpacing(5)

            Text("De svaga förlorar sin tid.\nDe starka tar den.")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.1))
                .lineSpacing(4)

            Text("Genom att fortsätta accepterar du villkoren.")
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
        }
    }

    // Steg 6 — Namn
    private var stepNamn: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("REGISTRERING")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.6))
                .tracking(3)

            Text("Vad ska du kallas?")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Text("Ditt namn följer dig tills du dör.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))

            TextField("", text: $playerName)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .tint(.white)
                .padding()
                .background(Color(red: 0.08, green: 0.08, blue: 0.1))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.4)),
                    alignment: .bottom
                )
                .focused($nameFocused)
                .onAppear { nameFocused = true }
                .submitLabel(.done)

            if !nameError.isEmpty {
                Text(nameError)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(red: 0.9, green: 0.2, blue: 0.2))
            }
        }
    }

    // MARK: - Knapp

    private var bottomButton: some View {
        Group {
            if step < 5 {
                Button {
                    nextStep()
                } label: {
                    Text("FORTSÄTT")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                }
            } else if step == 5 {
                Button {
                    nextStep()
                } label: {
                    Text("JAG FÖRSTÅR")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(red: 0.9, green: 0.7, blue: 0.1))
                }
            } else {
                Button {
                    commitName()
                } label: {
                    Text("STARTA LIVET")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(playerName.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color(red: 0.3, green: 0.3, blue: 0.3)
                                    : Color(red: 0.1, green: 0.9, blue: 0.3))
                }
                .disabled(playerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private func nextStep() {
        withAnimation(.easeOut(duration: 0.15)) { textOpacity = 0; buttonOpacity = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            step += 1
            animateIn()
        }
    }

    private func commitName() {
        let name = playerName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            nameError = "Skriv ett namn."
            return
        }
        guard name.count >= 2 else {
            nameError = "För kort. Minst 2 tecken."
            return
        }
        UserDefaults.standard.set(name, forKey: "username")
        GameState.shared.username = name
        UserDefaults.standard.set(true, forKey: "hasLaunched")
        Task { await ServerSync.shared.startup() }
        withAnimation { showOnboarding = false }
    }

    private func animateIn() {
        withAnimation(.easeIn(duration: 0.4)) { textOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeIn(duration: 0.3)) { buttonOpacity = 1 }
        }
    }

    // MARK: - Sub-views

    private func boardMember(name: String, role: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .frame(width: 3)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                Text(role)
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
            }
        }
    }

    private func rankRow(rank: String, text: String) -> some View {
        HStack(spacing: 14) {
            Text(rank)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.1))
                .frame(width: 60, alignment: .leading)
            Text(text)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
        }
    }
}

// MARK: - Legacy IntroView (används ej längre, behålls för kompilatorns skull)

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
