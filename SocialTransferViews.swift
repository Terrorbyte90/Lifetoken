import SwiftUI

// MARK: - Lend Sheet

struct LendSheetView: View {
    let npc: NPCPlayer
    @Binding var lendAmount: TimeInterval
    @Binding var lendDays: Int
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine = TimeEngine.shared
    let onConfirm: () -> Void

    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotif  = UINotificationFeedbackGenerator()

    var projectedReturn: TimeInterval {
        lendAmount * (1 + (npc.loanInterestRate / 30) * Double(lendDays))
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.05).ignoresSafeArea()
            VStack(spacing: LTSpacing.xl) {
                HStack {
                    Button {
                        hapticLight.impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(LTSpacing.sm)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(LTPressEffect())
                    .accessibilityLabel("Stäng")
                    Spacer()
                    Text("LÅN TILL \(npc.name.uppercased())")
                        .font(LTFont.heading(16))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 36)
                }
                .padding(LTSpacing.lg)

                Text(npc.avatar)
                    .font(.system(size: 56))
                    .accessibilityHidden(true)

                VStack(spacing: LTSpacing.xs + 2) {
                    Text("Månadsränta: \(Int(npc.loanInterestRate * 100))%")
                        .font(LTFont.body(14))
                        .foregroundColor(.yellow)
                    Text(String(format: "Pålitlighet: %.0f%%", npc.reliability * 100))
                        .font(LTFont.body(13))
                        .foregroundColor(npc.reliability > 0.8 ? .green : .orange)
                    if npc.reliability < 0.7 {
                        Text("Hög risk för utebliven återbetalning!")
                            .font(LTFont.body(11))
                            .foregroundColor(.red)
                    }
                }

                LTInfoCallout(
                    title: "Risk & avkastning",
                    message: "Högre ränta kan ge bättre avkastning men låg pålitlighet ökar risken att förlora utlånad tid.",
                    icon: "chart.line.uptrend.xyaxis",
                    tint: npc.reliability > 0.8 ? .green : .orange
                )
                .padding(.horizontal, LTSpacing.horizontal)

                VStack(spacing: LTSpacing.sm) {
                    HStack {
                        Text("Belopp")
                            .font(LTFont.body(11))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text(TimeEngine.shortFormatted(lendAmount))
                            .font(LTFont.value(15))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(LTAnimation.springFast, value: lendAmount)
                    }
                    Slider(value: $lendAmount,
                           in: 3600...max(7200, min(engine.balance * 0.9, 86400 * 365)),
                           step: 3600)
                        .tint(.green)
                        .accessibilityLabel("Lånebelopp")
                        .accessibilityValue(TimeEngine.shortFormatted(lendAmount))

                    HStack(spacing: LTSpacing.xs + 2) {
                        ForEach([3, 7, 14, 30, 60], id: \.self) { d in
                            Button("\(d)d") {
                                hapticLight.impactOccurred()
                                withAnimation(LTAnimation.springFast) { lendDays = d }
                            }
                            .font(LTFont.label(11))
                            .foregroundColor(lendDays == d ? .black : .white)
                            .padding(.horizontal, LTSpacing.sm)
                            .padding(.vertical, LTSpacing.xs + 1)
                            .background(lendDays == d ? Color.green : Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                            .buttonStyle(LTPressEffect())
                            .accessibilityLabel("\(d) dagar")
                            .accessibilityAddTraits(lendDays == d ? .isSelected : [])
                        }
                    }

                    VStack(spacing: 3) {
                        HStack {
                            Text("Förväntad återbetalning")
                                .font(LTFont.body(11))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text(TimeEngine.shortFormatted(projectedReturn))
                                .font(LTFont.heading(13))
                                .foregroundColor(.green)
                                .contentTransition(.numericText())
                                .animation(LTAnimation.springFast, value: projectedReturn)
                        }
                        HStack {
                            Text("Ränteintäkt")
                                .font(LTFont.body(11))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                            Text("+\(TimeEngine.shortFormatted(projectedReturn - lendAmount))")
                                .font(LTFont.body(11))
                                .foregroundColor(.green.opacity(0.6))
                                .contentTransition(.numericText())
                                .animation(LTAnimation.springFast, value: projectedReturn)
                        }
                    }
                }
                .padding(.horizontal, LTSpacing.horizontal)

                Button {
                    hapticNotif.notificationOccurred(.success)
                    onConfirm()
                } label: {
                    Text("BEKRÄFTA LÅN")
                        .font(LTFont.heading(16))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LTSpacing.lg)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                }
                .buttonStyle(LTPressEffect())
                .padding(.horizontal, LTSpacing.horizontal)
                .accessibilityLabel("Bekräfta lån på \(TimeEngine.shortFormatted(lendAmount)) till \(npc.name)")

                Spacer()
            }
        }
    }
}

// MARK: - Transfer Sheet

struct TransferSheetView: View {
    let user: ServerUser
    @Binding var amount: TimeInterval
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var engine = TimeEngine.shared
    let onConfirm: () -> Void

    private let hapticLight  = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)
    private let hapticNotif  = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.05).ignoresSafeArea()
            VStack(spacing: LTSpacing.xxl) {
                HStack {
                    Button {
                        hapticLight.impactOccurred()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(LTSpacing.sm)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(LTPressEffect())
                    .accessibilityLabel("Stäng")
                    Spacer()
                    Text("DELA TID")
                        .font(LTFont.heading(16))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 36)
                }
                .padding(LTSpacing.lg)

                VStack(spacing: LTSpacing.xs + 2) {
                    Text(user.avatar.isEmpty ? "👤" : user.avatar)
                        .font(.system(size: 50))
                        .accessibilityHidden(true)
                    Text(user.username)
                        .font(LTFont.heading(18))
                        .foregroundColor(.white)
                    Text("Zon: \(user.zone)")
                        .font(LTFont.body(12))
                        .foregroundColor(.green.opacity(0.8))
                }

                VStack(spacing: LTSpacing.md) {
                    HStack {
                        Text("Belopp")
                            .font(LTFont.body(11))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        Text(TimeEngine.shortFormatted(amount))
                            .font(LTFont.value(15))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                            .animation(LTAnimation.springFast, value: amount)
                    }
                    Slider(value: $amount,
                           in: 60...max(120, min(engine.balance * 0.5, 86400 * 7)),
                           step: 60)
                        .tint(.green)
                        .accessibilityLabel("Överföringsbelopp")
                        .accessibilityValue(TimeEngine.shortFormatted(amount))

                    HStack(spacing: LTSpacing.xs + 2) {
                        ForEach([600.0, 1800.0, 3600.0, 21600.0, 86400.0], id: \.self) { v in
                            Button(TimeEngine.shortFormatted(v)) {
                                hapticLight.impactOccurred()
                                withAnimation(LTAnimation.springFast) {
                                    amount = min(v, engine.balance * 0.5)
                                }
                            }
                            .font(LTFont.caption(9))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, LTSpacing.xs + 2)
                            .padding(.vertical, LTSpacing.xs)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .buttonStyle(LTPressEffect())
                            .accessibilityLabel(TimeEngine.shortFormatted(v))
                        }
                    }
                }
                .padding(.horizontal, LTSpacing.horizontal)

                LTInfoCallout(
                    title: "Avgifter",
                    message: "Zonskatt på \(Int(GameState.shared.currentZone.taxRate * 100))% dras på överföringen enligt din nuvarande zonregel.",
                    icon: "percent",
                    tint: .yellow
                )
                .padding(.horizontal, LTSpacing.horizontal)

                Button {
                    hapticNotif.notificationOccurred(.success)
                    onConfirm()
                } label: {
                    Text("SKICKA \(TimeEngine.shortFormatted(amount))")
                        .font(LTFont.heading(15))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LTSpacing.lg)
                        .background(amount <= engine.balance ? Color.green : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                }
                .disabled(amount > engine.balance)
                .buttonStyle(LTPressEffect())
                .padding(.horizontal, LTSpacing.horizontal)
                .accessibilityLabel("Skicka \(TimeEngine.shortFormatted(amount)) till \(user.username)")
                .accessibilityHint(amount > engine.balance ? "Otillräcklig balans" : "")

                Spacer()
            }
        }
    }
}
