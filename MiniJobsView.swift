import SwiftUI

// MARK: - Mini Job Difficulty

struct MiniJobDiff: Identifiable {
    let id: Int
    let label: String
    let timeSeconds: Int
    let rewardBest: Int      // minutes
    let rewardNormal: Int
    let rewardWorse: Int
    let penalty: Int         // minutes (positive = deducted)
}

// MARK: - Pay Table Helper

func awardMiniJobEarnings(minutes: Int, jobName: String = "Aktivt jobb") {
    guard minutes > 0 else { return }
    let zone = GameState.shared.currentZone
    let raw = TimeInterval(minutes * 60) * zone.workMultiplier
    let net = raw * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
    TimeEngine.shared.addTime(net)
    GameState.shared.recordEarning(net)
    TransactionLedger.shared.record(label: jobName, amount: net)
}

func penalizeMiniJob(minutes: Int, jobName: String = "Aktivt jobb") {
    guard minutes > 0 else { return }
    let penalty = TimeInterval(minutes * 60)
    _ = TimeEngine.shared.deductTime(penalty)
    TransactionLedger.shared.record(label: "\(jobName) — böter", amount: -penalty)
}

// MARK: - Hub View

struct MiniJobsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var gameState = GameState.shared

    @State private var showPipe = false
    @State private var pipeLevel = 0
    @State private var showCode = false
    @State private var codeLevel = 0
    @State private var showSort = false
    @State private var sortLevel = 0
    @State private var showBomb = false
    @State private var bombLevel = 0
    @State private var showTiming = false
    @State private var timingLevel = 0

    var body: some View {
        ZStack {
            LTScreenBackground(style: .work)

            ScrollView(showsIndicators: false) {
                VStack(spacing: LTSpacing.lg) {
                    headerSection

                    MiniJobCard(
                        name: "Rörmockaren",
                        subtitle: "Vattenflödet",
                        icon: "drop.fill",
                        color: Color(red: 0.2, green: 0.8, blue: 0.5),
                        flavor: "Sätt ihop rören innan trycket spräcker systemet.",
                        diffs: pipeDiffs,
                        selectedLevel: $pipeLevel,
                        zone: gameState.currentZone,
                        onStart: { showPipe = true },
                        hasPenalty: true
                    )
                    MiniJobCard(
                        name: "Kodknäckaren",
                        subtitle: "Sekvensbrytaren",
                        icon: "keyboard.fill",
                        color: Color(red: 0.1, green: 0.9, blue: 0.3),
                        flavor: "Bryt kodlåset innan tiden går ut. Få försök, hög utdelning.",
                        diffs: codeDiffs,
                        selectedLevel: $codeLevel,
                        zone: gameState.currentZone,
                        onStart: { showCode = true }
                    )
                    MiniJobCard(
                        name: "Sorteringsverket",
                        subtitle: "Fallande Kaos",
                        icon: "arrow.down.square.fill",
                        color: Color(red: 0.9, green: 0.55, blue: 0.1),
                        flavor: "Sortera rätt under press. Fel fraktionering kostar tid.",
                        diffs: sortDiffs,
                        selectedLevel: $sortLevel,
                        zone: gameState.currentZone,
                        onStart: { showSort = true },
                        hasPenalty: true
                    )
                    MiniJobCard(
                        name: "Sprängämnesexperten",
                        subtitle: "En Tråd",
                        icon: "bolt.fill",
                        color: Color(red: 0.95, green: 0.2, blue: 0.1),
                        flavor: "Läs ledtråden snabbt och klipp exakt rätt tråd.",
                        diffs: bombDiffs,
                        selectedLevel: $bombLevel,
                        zone: gameState.currentZone,
                        onStart: { showBomb = true },
                        hasPenalty: true
                    )
                    MiniJobCard(
                        name: "Tidskalibratorn",
                        subtitle: "Precision",
                        icon: "timer",
                        color: Color(red: 0.1, green: 0.8, blue: 0.95),
                        flavor: "Kalibrera perfekt timing. Millisekunder avgör lönen.",
                        diffs: timingDiffs,
                        selectedLevel: $timingLevel,
                        zone: gameState.currentZone,
                        onStart: { showTiming = true },
                        hasPenalty: true
                    )

                    Spacer(minLength: LTSpacing.scrollBottom)
                }
                .padding(.top, 58)
                .padding(.horizontal, LTSpacing.horizontal)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                        Text("Stäng")
                            .font(LTFont.body(11))
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .fullScreenCover(isPresented: $showPipe) { PipeGameView(difficulty: pipeLevel) }
        .fullScreenCover(isPresented: $showCode) { CodeBreakerView(difficulty: codeLevel) }
        .fullScreenCover(isPresented: $showSort) { SortingGameView(difficulty: sortLevel) }
        .fullScreenCover(isPresented: $showBomb) { BombDefuseView(difficulty: bombLevel) }
        .fullScreenCover(isPresented: $showTiming) { TimingGameView(difficulty: timingLevel) }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            LTSectionTitle(
                overline: "Jobbcentral",
                title: "Välj aktivt jobb för \(gameState.currentZone.name)",
                tint: LTPalette.neonGreen
            )
            Text("Nettolön i korten är beräknad efter zonbonus, skatt och aktiv booster.")
                .font(LTFont.body(10))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: LTSpacing.xs) {
                LTStatPill(
                    icon: gameState.currentZone.zoneIcon,
                    text: gameState.currentZone.name,
                    tint: gameState.currentZone.color
                )
                LTStatPill(
                    icon: "percent",
                    text: "Skatt \(Int(gameState.currentZone.taxRate * 100))%",
                    tint: .orange
                )
                LTStatPill(
                    icon: "bolt.circle.fill",
                    text: "Boost x\(String(format: "%.1f", BoostManager.shared.boosterMultiplier()))",
                    tint: .cyan
                )
            }
        }
        .padding(LTSpacing.lg)
        .ltCard(
            color: LTPalette.neonGreen,
            opacity: 0.06,
            radius: LTRadius.md,
            borderOpacity: 0.20,
            shadowColor: LTPalette.neonGreen.opacity(0.12),
            shadowRadius: 8
        )
    }

    // MARK: - Pay tables

    var pipeDiffs: [MiniJobDiff] { [
        MiniJobDiff(id: 0, label: "Enkel", timeSeconds: 30, rewardBest: 6, rewardNormal: 6, rewardWorse: 0, penalty: 2),
        MiniJobDiff(id: 1, label: "Medel", timeSeconds: 25, rewardBest: 11, rewardNormal: 11, rewardWorse: 0, penalty: 4),
        MiniJobDiff(id: 2, label: "Svår", timeSeconds: 20, rewardBest: 19, rewardNormal: 19, rewardWorse: 0, penalty: 6),
        MiniJobDiff(id: 3, label: "Expert", timeSeconds: 15, rewardBest: 32, rewardNormal: 32, rewardWorse: 0, penalty: 11),
        MiniJobDiff(id: 4, label: "Legende", timeSeconds: 10, rewardBest: 64, rewardNormal: 64, rewardWorse: 0, penalty: 17),
    ] }
    var codeDiffs: [MiniJobDiff] { [
        MiniJobDiff(id: 0, label: "Enkel", timeSeconds: 90, rewardBest: 9, rewardNormal: 6, rewardWorse: 3, penalty: 0),
        MiniJobDiff(id: 1, label: "Medel", timeSeconds: 90, rewardBest: 15, rewardNormal: 10, rewardWorse: 5, penalty: 0),
        MiniJobDiff(id: 2, label: "Svår", timeSeconds: 90, rewardBest: 25, rewardNormal: 16, rewardWorse: 8, penalty: 0),
        MiniJobDiff(id: 3, label: "Expert", timeSeconds: 60, rewardBest: 40, rewardNormal: 26, rewardWorse: 13, penalty: 0),
        MiniJobDiff(id: 4, label: "Legende", timeSeconds: 40, rewardBest: 80, rewardNormal: 52, rewardWorse: 26, penalty: 0),
    ] }
    var sortDiffs: [MiniJobDiff] { [
        MiniJobDiff(id: 0, label: "Enkel", timeSeconds: 60, rewardBest: 7, rewardNormal: 4, rewardWorse: 1, penalty: 2),
        MiniJobDiff(id: 1, label: "Medel", timeSeconds: 60, rewardBest: 12, rewardNormal: 7, rewardWorse: 2, penalty: 4),
        MiniJobDiff(id: 2, label: "Svår", timeSeconds: 45, rewardBest: 21, rewardNormal: 11, rewardWorse: 3, penalty: 6),
        MiniJobDiff(id: 3, label: "Expert", timeSeconds: 40, rewardBest: 35, rewardNormal: 19, rewardWorse: 5, penalty: 10),
        MiniJobDiff(id: 4, label: "Legende", timeSeconds: 25, rewardBest: 70, rewardNormal: 38, rewardWorse: 10, penalty: 15),
    ] }
    var bombDiffs: [MiniJobDiff] { [
        MiniJobDiff(id: 0, label: "Enkel", timeSeconds: 20, rewardBest: 10, rewardNormal: 6, rewardWorse: 0, penalty: 5),
        MiniJobDiff(id: 1, label: "Medel", timeSeconds: 15, rewardBest: 17, rewardNormal: 10, rewardWorse: 0, penalty: 10),
        MiniJobDiff(id: 2, label: "Svår", timeSeconds: 12, rewardBest: 30, rewardNormal: 17, rewardWorse: 0, penalty: 20),
        MiniJobDiff(id: 3, label: "Expert", timeSeconds: 8, rewardBest: 50, rewardNormal: 30, rewardWorse: 0, penalty: 40),
        MiniJobDiff(id: 4, label: "Legende", timeSeconds: 5, rewardBest: 100, rewardNormal: 60, rewardWorse: 0, penalty: 60),
    ] }
    var timingDiffs: [MiniJobDiff] { [
        MiniJobDiff(id: 0, label: "Enkel", timeSeconds: 90, rewardBest: 8, rewardNormal: 5, rewardWorse: 2, penalty: 2),
        MiniJobDiff(id: 1, label: "Medel", timeSeconds: 90, rewardBest: 14, rewardNormal: 9, rewardWorse: 4, penalty: 4),
        MiniJobDiff(id: 2, label: "Svår", timeSeconds: 90, rewardBest: 22, rewardNormal: 14, rewardWorse: 7, penalty: 7),
        MiniJobDiff(id: 3, label: "Expert", timeSeconds: 90, rewardBest: 37, rewardNormal: 24, rewardWorse: 12, penalty: 11),
        MiniJobDiff(id: 4, label: "Legende", timeSeconds: 60, rewardBest: 74, rewardNormal: 48, rewardWorse: 24, penalty: 17),
    ] }
}

// MARK: - Job Card

private struct MiniJobCard: View {
    let name: String
    let subtitle: String
    let icon: String
    let color: Color
    let flavor: String
    let diffs: [MiniJobDiff]
    @Binding var selectedLevel: Int
    let zone: ZoneProfile
    let onStart: () -> Void
    var hasPenalty: Bool = false

    @State private var expanded = false

    private var levelIndex: Int {
        guard !diffs.isEmpty else { return 0 }
        return min(max(selectedLevel, 0), diffs.count - 1)
    }

    private var diff: MiniJobDiff { diffs[levelIndex] }

    private func projectedNet(minutes: Int) -> TimeInterval {
        guard minutes > 0 else { return 0 }
        let raw = TimeInterval(minutes * 60) * zone.workMultiplier
        return raw * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            Button(action: toggleExpanded) {
                HStack(spacing: LTSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.opacity(expanded ? 0.22 : 0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(color)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.uppercased())
                            .font(LTFont.heading(13))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(LTFont.body(10))
                            .foregroundColor(color.opacity(0.85))
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(diff.label.uppercased())
                            .font(LTFont.caption(9))
                            .foregroundColor(color.opacity(0.95))
                        Text("+\(TimeEngine.shortFormatted(projectedNet(minutes: diff.rewardBest)))")
                            .font(LTFont.heading(12))
                            .foregroundColor(color)
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .buttonStyle(LTPressEffect(scale: 0.98))

            if expanded {
                VStack(alignment: .leading, spacing: LTSpacing.sm) {
                    Text(flavor)
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: LTSpacing.xs) {
                            ForEach(diffs) { d in
                                Button(d.label.uppercased()) {
                                    withAnimation(LTAnimation.springFast) { selectedLevel = d.id }
                                }
                                .font(LTFont.caption(9))
                                .foregroundColor(levelIndex == d.id ? .black : color.opacity(0.85))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(levelIndex == d.id ? color : color.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(color.opacity(0.25), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.vertical, 1)
                    }

                    HStack(spacing: LTSpacing.xs) {
                        LTStatPill(icon: "hourglass", text: "\(diff.timeSeconds)s", tint: .white)
                        LTStatPill(
                            icon: "clock.badge.checkmark.fill",
                            text: "Max +\(TimeEngine.shortFormatted(projectedNet(minutes: diff.rewardBest)))",
                            tint: color
                        )
                        if hasPenalty {
                            LTStatPill(
                                icon: "exclamationmark.triangle.fill",
                                text: "Fel −\(TimeEngine.shortFormatted(TimeInterval(diff.penalty * 60)))",
                                tint: .red
                            )
                        }
                    }

                    VStack(spacing: 6) {
                        payoutRow(label: "Perfekt", minutes: diff.rewardBest, tint: color)
                        payoutRow(label: "Stabil", minutes: diff.rewardNormal, tint: .white)
                        payoutRow(label: "Nära", minutes: diff.rewardWorse, tint: .orange)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))

                    Button(action: startPressed) {
                        HStack(spacing: LTSpacing.sm) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("STARTA \(diff.label.uppercased())")
                                .font(LTFont.heading(12))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                        .shadow(color: color.opacity(0.30), radius: 8, y: 3)
                    }
                    .buttonStyle(LTPressEffect(scale: 0.98))
                    .accessibilityLabel("Starta \(name) på svårighetsgrad \(diff.label)")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(LTSpacing.md)
        .background(
            LinearGradient(
                colors: [color.opacity(expanded ? 0.12 : 0.06), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.md)
                .stroke(expanded ? color.opacity(0.40) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func payoutRow(label: String, minutes: Int, tint: Color) -> some View {
        HStack {
            Text(label.uppercased())
                .font(LTFont.caption(9))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
            if minutes > 0 {
                Text("+\(TimeEngine.shortFormatted(projectedNet(minutes: minutes)))")
                    .font(LTFont.body(10))
                    .foregroundColor(tint)
            } else {
                Text("0")
                    .font(LTFont.body(10))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
    }

    private func toggleExpanded() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        withAnimation(LTAnimation.springFast) { expanded.toggle() }
    }

    private func startPressed() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        onStart()
    }
}
