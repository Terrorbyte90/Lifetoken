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

func awardMiniJobEarnings(minutes: Int) {
    guard minutes > 0 else { return }
    let zone  = GameState.shared.currentZone
    let raw   = TimeInterval(minutes * 60) * zone.workMultiplier
    let net   = raw * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
    TimeEngine.shared.addTime(net)
    GameState.shared.recordEarning(net)
}

func penalizeMiniJob(minutes: Int) {
    guard minutes > 0 else { return }
    _ = TimeEngine.shared.deductTime(TimeInterval(minutes * 60))
}

// MARK: - Hub View

struct MiniJobsView: View {
    @Environment(\.dismiss) var dismiss

    @State private var showPipe   = false; @State private var pipeLevel   = 0
    @State private var showCode   = false; @State private var codeLevel   = 0
    @State private var showSort   = false; @State private var sortLevel   = 0
    @State private var showBomb   = false; @State private var bombLevel   = 0
    @State private var showTiming = false; @State private var timingLevel = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red:0.04,green:0.04,blue:0.06), Color.black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // ── Header ──────────────────────────────
                    VStack(spacing: 6) {
                        Text("AKTIVA JOBB")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(6)
                        Text("Fem arbeten. Ingen nåd för slarviga.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(white: 0.3))
                    }
                    .padding(.top, 64)
                    .padding(.bottom, 28)

                    // ── Cards ────────────────────────────────
                    MiniJobCard(
                        name: "Rörmockaren",    subtitle: "Vattenflödet",
                        icon: "drop.fill",      color: Color(red:0.2,green:0.8,blue:0.5),
                        flavor: "Sätt ihop rören innan vattnet når dig. Läcker det — straff.",
                        diffs: pipeDiffs, selectedLevel: $pipeLevel,
                        onStart: { showPipe = true },
                        hasPenalty: true
                    )
                    MiniJobCard(
                        name: "Kodknäckaren",   subtitle: "Sekvensbrytaren",
                        icon: "keyboard.fill",   color: Color(red:0.1,green:0.9,blue:0.3),
                        flavor: "Systemet har ett lösenord. Du har fem försök.",
                        diffs: codeDiffs, selectedLevel: $codeLevel,
                        onStart: { showCode = true }
                    )
                    MiniJobCard(
                        name: "Sorteringsverket", subtitle: "Fallande Kaos",
                        icon: "arrow.down.square.fill", color: Color(red:0.9,green:0.55,blue:0.1),
                        flavor: "Allt faller. Du bestämmer vart. Fel källsortering ger avgifter.",
                        diffs: sortDiffs, selectedLevel: $sortLevel,
                        onStart: { showSort = true },
                        hasPenalty: true
                    )
                    MiniJobCard(
                        name: "Sprängämnesexperten", subtitle: "En Tråd",
                        icon: "bolt.fill",      color: Color(red:0.95,green:0.2,blue:0.1),
                        flavor: "Fel tråd. Fel val. Inget liv.",
                        diffs: bombDiffs, selectedLevel: $bombLevel,
                        onStart: { showBomb = true },
                        hasPenalty: true
                    )
                    MiniJobCard(
                        name: "Tidskalibratorn", subtitle: "Precision eller Ingenting",
                        icon: "timer",           color: Color(red:0.1,green:0.8,blue:0.95),
                        flavor: "Systemet kräver exakthet. Inte ungefär. Dålig kalibrering ger kostnader.",
                        diffs: timingDiffs, selectedLevel: $timingLevel,
                        onStart: { showTiming = true },
                        hasPenalty: true
                    )

                    Spacer(minLength: 60)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .fullScreenCover(isPresented: $showPipe)   { PipeGameView(difficulty: pipeLevel) }
        .fullScreenCover(isPresented: $showCode)   { CodeBreakerView(difficulty: codeLevel) }
        .fullScreenCover(isPresented: $showSort)   { SortingGameView(difficulty: sortLevel) }
        .fullScreenCover(isPresented: $showBomb)   { BombDefuseView(difficulty: bombLevel) }
        .fullScreenCover(isPresented: $showTiming) { TimingGameView(difficulty: timingLevel) }
    }

    // ── Pay tables ───────────────────────────────────────────────────

    var pipeDiffs: [MiniJobDiff] { [
        MiniJobDiff(id:0, label:"Enkel",  timeSeconds:30, rewardBest:6,  rewardNormal:6,  rewardWorse:0, penalty:2),
        MiniJobDiff(id:1, label:"Medel",  timeSeconds:25, rewardBest:11, rewardNormal:11, rewardWorse:0, penalty:4),
        MiniJobDiff(id:2, label:"Svår",   timeSeconds:20, rewardBest:19, rewardNormal:19, rewardWorse:0, penalty:6),
        MiniJobDiff(id:3, label:"Expert", timeSeconds:15, rewardBest:32, rewardNormal:32, rewardWorse:0, penalty:11),
    ]}
    var codeDiffs: [MiniJobDiff] { [
        MiniJobDiff(id:0, label:"Enkel",  timeSeconds:90, rewardBest:9,  rewardNormal:6,  rewardWorse:3,  penalty:0),
        MiniJobDiff(id:1, label:"Medel",  timeSeconds:90, rewardBest:15, rewardNormal:10, rewardWorse:5,  penalty:0),
        MiniJobDiff(id:2, label:"Svår",   timeSeconds:90, rewardBest:25, rewardNormal:16, rewardWorse:8,  penalty:0),
        MiniJobDiff(id:3, label:"Expert", timeSeconds:60, rewardBest:40, rewardNormal:26, rewardWorse:13, penalty:0),
    ]}
    var sortDiffs: [MiniJobDiff] { [
        MiniJobDiff(id:0, label:"Enkel",  timeSeconds:60, rewardBest:7,  rewardNormal:4,  rewardWorse:1,  penalty:2),
        MiniJobDiff(id:1, label:"Medel",  timeSeconds:60, rewardBest:12, rewardNormal:7,  rewardWorse:2,  penalty:4),
        MiniJobDiff(id:2, label:"Svår",   timeSeconds:45, rewardBest:21, rewardNormal:11, rewardWorse:3,  penalty:6),
        MiniJobDiff(id:3, label:"Expert", timeSeconds:40, rewardBest:35, rewardNormal:19, rewardWorse:5,  penalty:10),
    ]}
    var bombDiffs: [MiniJobDiff] { [
        MiniJobDiff(id:0, label:"Enkel",  timeSeconds:20, rewardBest:10, rewardNormal:6,  rewardWorse:0, penalty:5),
        MiniJobDiff(id:1, label:"Medel",  timeSeconds:15, rewardBest:17, rewardNormal:10, rewardWorse:0, penalty:10),
        MiniJobDiff(id:2, label:"Svår",   timeSeconds:12, rewardBest:30, rewardNormal:17, rewardWorse:0, penalty:20),
        MiniJobDiff(id:3, label:"Expert", timeSeconds:8,  rewardBest:50, rewardNormal:30, rewardWorse:0, penalty:40),
    ]}
    var timingDiffs: [MiniJobDiff] { [
        MiniJobDiff(id:0, label:"Enkel",  timeSeconds:90, rewardBest:8,  rewardNormal:5,  rewardWorse:2,  penalty:2),
        MiniJobDiff(id:1, label:"Medel",  timeSeconds:90, rewardBest:14, rewardNormal:9,  rewardWorse:4,  penalty:4),
        MiniJobDiff(id:2, label:"Svår",   timeSeconds:90, rewardBest:22, rewardNormal:14, rewardWorse:7,  penalty:7),
        MiniJobDiff(id:3, label:"Expert", timeSeconds:90, rewardBest:37, rewardNormal:24, rewardWorse:12, penalty:11),
    ]}
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
    let onStart: () -> Void
    var hasPenalty: Bool = false

    @State private var expanded = false

    var diff: MiniJobDiff { diffs[selectedLevel] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Tap header ──────────────────────────────
            Button(action: { withAnimation(.spring(response: 0.35)) { expanded.toggle() } }) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(color.opacity(expanded ? 0.25 : 0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(color)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name.uppercased())
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(1)
                        Text(subtitle)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(color.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(16)
            }

            // ── Expanded content ──────────────────────
            if expanded {
                VStack(alignment: .leading, spacing: 16) {
                    Rectangle()
                        .fill(color.opacity(0.15))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    Text(flavor)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(white: 0.45))
                        .padding(.horizontal, 16)

                    // Difficulty selector
                    HStack(spacing: 6) {
                        ForEach(diffs) { d in
                            Button(d.label) { withAnimation { selectedLevel = d.id } }
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(selectedLevel == d.id ? .black : color.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedLevel == d.id ? color : color.opacity(0.1))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)

                    // Pay preview
                    VStack(spacing: 6) {
                        HStack {
                            Label("Max lön", systemImage: "clock.badge.checkmark.fill")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.5))
                            Spacer()
                            Text("\(diff.rewardBest) min")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(color)
                        }
                        HStack {
                            Label("Tid", systemImage: "hourglass")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.5))
                            Spacer()
                            Text("\(diff.timeSeconds)s")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        if hasPenalty {
                            HStack {
                                Label("Straff vid fel", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.red.opacity(0.7))
                                Spacer()
                                Text("−\(diff.penalty) min")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Start button
                    Button(action: onStart) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 13))
                            Text("STARTA — \(diff.label.uppercased())")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(expanded ? 0.06 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(expanded ? color.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }
}
