import SwiftUI

// MARK: - Yatzy Lobby View

struct YatzyLobbyView: View {
    @Binding var player1Name: String
    @Binding var betAmount: TimeInterval
    @Binding var gameMode: MultiYatzyMode
    @Binding var selectedOnlineOpponent: ServerUser?
    @Binding var useRandomOpponent: Bool

    let balance: TimeInterval
    let zoneMembers: [ServerUser]
    let onDismiss: () -> Void
    let onStart: () -> Void

    private var betFormatted: String { TimeEngine.shortFormatted(betAmount) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                VStack(spacing: 24) {
                    modeSelectorCard
                    playerNamesCard
                    betCard
                    startButton
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                Spacer()
                Text(TimeEngine.shortFormatted(balance))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.goldYatzy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.goldYatzy.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)

            Text("YATZY")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .kerning(8)
            Text("MULTIPLAYER")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.accentGreen.opacity(0.8))
                .kerning(4)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Mode Selector

    private var modeSelectorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SPELLÄGE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .kerning(2)
            VStack(spacing: 10) {
                modeButton(title: "Mot AI",     subtitle: "Spela mot AI", icon: "cpu",      mode: .vsAI)
                HStack(spacing: 10) {
                    modeButton(title: "Online 1v1", subtitle: "Samma zon",   icon: "wifi",     mode: .onlineOneVsOne)
                    modeButton(title: "Online 3P",  subtitle: "Tre spelare", icon: "person.3", mode: .onlineThreePlayer)
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func modeButton(title: String, subtitle: String, icon: String, mode: MultiYatzyMode) -> some View {
        let selected = gameMode == mode
        return Button { withAnimation(.spring(response: 0.3)) { gameMode = mode } } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(selected ? .black : .white.opacity(0.6))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(selected ? .black : .white)
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(selected ? .black.opacity(0.6) : .white.opacity(0.4))
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.black.opacity(0.7))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.accentGreen : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Player Names Card

    private var playerNamesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SPELARE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .kerning(2)

            nameField(placeholder: "Ditt namn", text: $player1Name, color: .accentGreen)

            switch gameMode {
            case .vsAI:
                opponentRow(name: "AI-motståndare", subtitle: "Spelar optimalt", isOnline: false, isAI: true)

            case .onlineOneVsOne:
                let opponents = zoneMembers.filter { $0.username != player1Name }
                if opponents.isEmpty {
                    opponentRow(name: "Online-AI", subtitle: "Inga spelare online i din zon", isOnline: false, isAI: true)
                } else {
                    onlinePlayerPickerSection(opponents: opponents)
                }

            case .onlineThreePlayer:
                let opponents = zoneMembers.filter { $0.username != player1Name }
                let opp1Name  = opponents.first?.username ?? "Online-AI 1"
                let opp1Zone  = opponents.first?.zone ?? ""
                let opp2Name  = opponents.dropFirst().first?.username ?? "Online-AI 2"
                let opp2Zone  = opponents.dropFirst().first?.zone ?? ""
                opponentRow(
                    name: opp1Name,
                    subtitle: opponents.isEmpty ? "Inga spelare online" : "Online • \(opp1Zone)",
                    isOnline: !opponents.isEmpty,
                    isAI: opponents.isEmpty
                )
                opponentRow(
                    name: opp2Name,
                    subtitle: opponents.count < 2 ? "Inga fler spelare online" : "Online • \(opp2Zone)",
                    isOnline: opponents.count >= 2,
                    isAI: opponents.count < 2
                )
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func opponentRow(name: String, subtitle: String, isOnline: Bool, isAI: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isAI ? Color.red.opacity(0.15) : (isOnline ? Color.cyan.opacity(0.15) : Color.gray.opacity(0.12)))
                    .frame(width: 36, height: 36)
                Text(isAI ? "🤖" : (isOnline ? "👤" : "🤖")).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(isOnline ? .white.opacity(0.85) : (isAI ? .white.opacity(0.7) : .white.opacity(0.5)))
                HStack(spacing: 4) {
                    if !isAI {
                        Circle()
                            .fill(isOnline ? Color.green : Color.gray)
                            .frame(width: 5, height: 5)
                    }
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(isAI ? .red.opacity(0.7) : (isOnline ? .cyan.opacity(0.7) : .white.opacity(0.3)))
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func onlinePlayerPickerSection(opponents: [ServerUser]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    useRandomOpponent.toggle()
                    if useRandomOpponent { selectedOnlineOpponent = nil }
                }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(useRandomOpponent ? Color.cyan.opacity(0.2) : Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                        Image(systemName: "shuffle")
                            .font(.system(size: 16))
                            .foregroundColor(useRandomOpponent ? .cyan : .white.opacity(0.5))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Slumpmässig motståndare")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(useRandomOpponent ? .white : .white.opacity(0.6))
                        Text("Välj en random spelare i din zon")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                    }
                    Spacer()
                    if useRandomOpponent {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(useRandomOpponent ? Color.cyan.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if !useRandomOpponent {
                Text("VÄLJ SPECIFIK SPELARE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .tracking(2)
                    .padding(.top, 4)

                ForEach(opponents) { opponent in
                    let isSelected = selectedOnlineOpponent?.id == opponent.id
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            selectedOnlineOpponent = isSelected ? nil : opponent
                        }
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.accentGreen.opacity(0.2) : Color.white.opacity(0.06))
                                    .frame(width: 36, height: 36)
                                Text("👤").font(.system(size: 18))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(opponent.username)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 5, height: 5)
                                    Text("Online • \(opponent.zone)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.cyan.opacity(0.7))
                                }
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.accentGreen)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.accentGreen.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func nameField(placeholder: String, text: Binding<String>, color: Color) -> some View {
        HStack(spacing: 12) {
            Circle().fill(color.opacity(0.2)).frame(width: 8, height: 8)
            TextField(placeholder, text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .tint(color)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Bet Card

    private var betCard: some View {
        let maxBet = max(100, floor(balance * 0.8))
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("INSATS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(2)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(betFormatted)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.goldYatzy)
                    Text("max 80% av saldo")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            Slider(value: Binding(
                get: { min(betAmount, maxBet) },
                set: { betAmount = $0 }
            ), in: 100...maxBet, step: 60)
                .tint(.goldYatzy)
            HStack {
                Text("100s")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
                Text("Max: \(TimeEngine.shortFormatted(maxBet))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
            }
            VStack(spacing: 6) {
                betInfoRow(icon: "arrow.up.circle.fill",   text: "Vinst: +\(TimeEngine.shortFormatted(betAmount * 2))", color: .accentGreen)
                betInfoRow(icon: "equal.circle.fill",      text: "Oavgjort: +\(betFormatted) tillbaka",                 color: .orange)
                betInfoRow(icon: "arrow.down.circle.fill", text: "Förlust: −\(betFormatted)",                           color: .red.opacity(0.8))
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func betInfoRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
            Text(text).font(.system(size: 11, design: .monospaced)).foregroundColor(color)
            Spacer()
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        let maxBet    = max(100, floor(balance * 0.8))
        let canAfford = betAmount <= balance && betAmount <= maxBet
        return Button(action: onStart) {
            HStack(spacing: 10) {
                Image(systemName: "play.fill").font(.system(size: 14, weight: .bold))
                Text("STARTA SPELET")
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .kerning(2)
            }
            .foregroundColor(canAfford ? .black : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                canAfford
                    ? LinearGradient(colors: [Color.accentGreen, Color(red: 0.1, green: 0.7, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.08)], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: canAfford ? Color.accentGreen.opacity(0.4) : .clear, radius: 12, y: 4)
        }
        .disabled(!canAfford)
    }
}
