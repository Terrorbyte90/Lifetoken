import SwiftUI
import Foundation

// MARK: - Job Card

struct JobCard: View {
    let job: JobType
    let zone: ZoneProfile
    let isDisabled: Bool
    let inflationMultiplier: Double
    let onTap: () -> Void

    private var accentColor: Color {
        if isDisabled { return .gray }
        if job.riskPercentage > 0.20 { return Color(red: 0.9, green: 0.3, blue: 0.1) }
        if job.riskPercentage > 0.10 { return .orange }
        return .green
    }

    private var riskLabel: String {
        let value = Int(job.riskPercentage * 100)
        if value >= 25 { return "Hög risk \(value)%" }
        if value >= 12 { return "Medelrisk \(value)%" }
        return "Låg risk \(value)%"
    }

    var body: some View {
        Button(action: {
            guard !isDisabled else { return }
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: LTSpacing.sm) {
                HStack(spacing: LTSpacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(accentColor.opacity(isDisabled ? 0.08 : 0.16))
                            .frame(width: 48, height: 48)
                        Image(systemName: job.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(isDisabled ? .gray : accentColor)
                    }

                    VStack(alignment: .leading, spacing: LTSpacing.xs - 1) {
                        Text(job.name.uppercased())
                            .font(LTFont.heading(13))
                            .foregroundColor(isDisabled ? .gray.opacity(0.65) : .white)
                            .lineLimit(1)
                        Text(job.description)
                            .font(LTFont.body(10))
                            .foregroundColor(.white.opacity(isDisabled ? 0.22 : 0.48))
                            .lineLimit(2)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: LTSpacing.xs - 1) {
                        Text("+\(TimeEngine.shortFormatted(job.netEarningsInflated(for: zone)))")
                            .font(LTFont.heading(13))
                            .foregroundColor(isDisabled ? .gray.opacity(0.45) : accentColor)
                        Text(formatDur(job.durationSeconds))
                            .font(LTFont.caption(9))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }

                HStack(spacing: LTSpacing.xs) {
                    LTStatPill(
                        icon: "speedometer",
                        text: "\(TimeEngine.shortFormatted(job.hourlyRate(for: zone))) / h",
                        tint: .cyan
                    )
                    LTStatPill(
                        icon: "exclamationmark.triangle.fill",
                        text: riskLabel,
                        tint: job.riskPercentage > 0.18 ? .red : .orange
                    )
                    Spacer()
                }
            }
            .padding(14)
        }
        .disabled(isDisabled)
        .buttonStyle(LTPressEffect(scale: 0.98))
        .background(
            LinearGradient(
                colors: [accentColor.opacity(isDisabled ? 0.05 : 0.10), Color(red: 0.05, green: 0.06, blue: 0.09)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.sm)
                .stroke(accentColor.opacity(isDisabled ? 0.08 : 0.28), lineWidth: 1)
        )
        .shadow(color: accentColor.opacity(isDisabled ? 0.0 : 0.08), radius: 10, y: 3)
        .opacity(isDisabled ? 0.5 : 1.0)
        .accessibilityLabel("\(job.name), \(job.description)")
        .accessibilityHint(isDisabled ? "Inaktiverat — ett jobb pågår redan" : "Dubbeltryck för att starta jobbet")
    }

    func formatDur(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60
        return h > 0 ? "\(h)h\(m > 0 ? " \(m)m" : "")" : "\(m)m"
    }
}

// MARK: - Active Job Card

struct ActiveJobCard: View {
    let job: ActiveJob
    let onCancel: () -> Void
    @State private var progress: Double = 0
    @State private var pulsing: Bool = false
    @State private var tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var jobType: JobType? {
        WorkManager.shared.allJobs.first(where: { $0.id == job.jobId })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top accent bar
            LinearGradient(
                colors: [Color.green.opacity(0.8), Color.green.opacity(0.3)],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(height: 2)
            .clipShape(RoundedRectangle(cornerRadius: 1))

            VStack(alignment: .leading, spacing: 16) {
                // Header row
                HStack(spacing: 14) {
                    // Animated icon
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Circle()
                            .stroke(Color.green.opacity(pulsing ? 0.5 : 0.15), lineWidth: 2)
                            .frame(width: 52, height: 52)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulsing)
                        Image(systemName: jobType?.icon ?? "briefcase.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .shadow(color: .green, radius: 3)
                            Text("PÅGÅENDE")
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .foregroundColor(.green.opacity(0.8))
                                .tracking(3)
                        }
                        Text(jobType?.name ?? job.jobId)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: onCancel) {
                        Text("Avbryt")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.red.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                // Progress section
                VStack(spacing: 8) {
                    HStack {
                        Text("\(Int(progress * 100))% klar")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                            .contentTransition(.numericText())
                            .animation(LTAnimation.fadeFast, value: Int(progress * 100))
                        Spacer()
                        Text("Klar om \(TimeEngine.shortFormatted(job.timeRemaining))")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(LTPalette.neonGreen)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(LTAnimation.fadeFast, value: job.timeRemaining)
                    }

                    // Custom progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.9, blue: 0.5), Color(red: 0.1, green: 0.7, blue: 0.3)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 8)
                                .shadow(color: Color.green.opacity(0.4), radius: 4)
                                .animation(.easeInOut(duration: 0.8), value: progress)
                        }
                    }
                    .frame(height: 8)
                }

                // Earnings preview
                if let jt = jobType {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green.opacity(0.5))
                        Text("Förväntat: ~\(TimeEngine.shortFormatted(jt.netEarnings(for: GameState.shared.currentZone)))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .padding(18)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.10, blue: 0.06), Color(red: 0.03, green: 0.07, blue: 0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
        .overlay(RoundedRectangle(cornerRadius: LTRadius.md).stroke(LTPalette.neonGreen.opacity(0.22), lineWidth: 1))
        .shadow(color: LTPalette.neonGreen.opacity(0.12), radius: 14, y: 4)
        .padding(.horizontal)
        .onAppear {
            progress = job.progress
            pulsing = true
        }
        .onReceive(tickTimer) { _ in
            progress = job.progress
        }
        .onDisappear { tickTimer.upstream.connect().cancel() }
    }
}

// MARK: - Job Confirm Sheet

struct JobConfirmSheet: View {
    let job: JobType
    let zone: ZoneProfile
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Image(systemName: job.icon)
                    .font(.system(size: 32))
                    .foregroundColor(.green)
                Text(job.name)
                    .font(LTFont.displayTitle(20))
                    .foregroundColor(.white)
                Text(job.description)
                    .font(LTFont.body(11))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            HStack(spacing: 20) {
                VStack(spacing: 3) {
                    Text("TID")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    let h = Int(job.durationSeconds) / 3600
                    let m = (Int(job.durationSeconds) % 3600) / 60
                    Text(h > 0 ? "\(h)h \(m)m" : "\(m)m")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Divider().frame(height: 30).background(Color.white.opacity(0.2))
                VStack(spacing: 3) {
                    Text("NETTOLÖN")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text("~\(TimeEngine.shortFormatted(job.netEarnings(for: zone)))")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                Divider().frame(height: 30).background(Color.white.opacity(0.2))
                VStack(spacing: 3) {
                    Text("RISK")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text("\(Int(job.riskPercentage * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(job.riskPercentage > 0.15 ? .red : .orange)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)

            HStack(spacing: LTSpacing.md) {
                Button(action: {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    onCancel()
                }) {
                    Text("Avbryt")
                        .font(LTFont.heading(13))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                }
                .buttonStyle(LTPressEffect())
                Button(action: {
                    let notif = UINotificationFeedbackGenerator()
                    notif.notificationOccurred(.success)
                    onConfirm()
                }) {
                    Text("STARTA JOBB")
                        .font(LTFont.heading(13))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [LTPalette.neonGreen, LTPalette.neonGreenDim],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                        .shadow(color: LTPalette.neonGreen.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(LTPressEffect())
            }
            .padding(.horizontal, LTSpacing.xxl)
            .padding(.bottom, LTSpacing.lg)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.08, blue: 0.07), Color(red: 0.03, green: 0.05, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - Job Complete Toast

struct JobCompleteToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("JOBB KLART!")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
                    .tracking(2)
                Text(message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(3)
            }
            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(red: 0.04, green: 0.12, blue: 0.06), Color(red: 0.03, green: 0.08, blue: 0.04)],
                           startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.green.opacity(0.2), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }
}
