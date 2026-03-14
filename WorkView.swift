import SwiftUI
import Foundation

// MARK: - Job Types

struct JobType: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let durationSeconds: TimeInterval     // real-time duration
    let baseEarningsSeconds: TimeInterval // what you earn before tax
    let requiredZone: String              // minimum zone name needed
    let riskPercentage: Double            // chance of event reducing pay (0-1)

    // Net profit estimate (before tax)
    var profitSeconds: TimeInterval { baseEarningsSeconds - durationSeconds }
}

// MARK: - Active Job

struct ActiveJob: Codable {
    let jobId: String
    let startTime: Date
    let durationSeconds: TimeInterval
    let baseEarnings: TimeInterval

    var endTime: Date { startTime.addingTimeInterval(durationSeconds) }
    var isComplete: Bool { Date() >= endTime }
    var progress: Double {
        let elapsed = Date().timeIntervalSince(startTime)
        return min(1.0, elapsed / durationSeconds)
    }
    var timeRemaining: TimeInterval { max(0, endTime.timeIntervalSince(Date())) }
}

// MARK: - Work Manager

class WorkManager: ObservableObject {
    static let shared = WorkManager()

    @Published var activeJob: ActiveJob? = nil
    @Published var lastCompletedJobMessage: String = ""
    @Published var showJobComplete: Bool = false

    private let activeJobKey = "activeWorkJob"
    private var checkTimer: Timer?

    // All available job types across zones
    let allJobs: [JobType] = [
        // Duskline jobs
        JobType(id: "factory",    name: "Fabriksarbete",    description: "Monotont löpandsband-arbete. Låg lön, hög säkerhet.",
                icon: "gear",           durationSeconds: 14400,  baseEarningsSeconds: 16200, requiredZone: "Duskline",    riskPercentage: 0.05),
        JobType(id: "delivery",   name: "Budkörning",       description: "Leverera paket runt zonen. Snabbt men osäkert.",
                icon: "box.truck",      durationSeconds: 7200,   baseEarningsSeconds: 7800,  requiredZone: "Duskline",    riskPercentage: 0.15),
        // Midgrey jobs
        JobType(id: "security",   name: "Säkerhetsvakt",    description: "Skydda byggnader. 8h skift, okej lön.",
                icon: "shield",         durationSeconds: 28800,  baseEarningsSeconds: 34560, requiredZone: "Midgrey",     riskPercentage: 0.10),
        JobType(id: "assembly",   name: "Monteringsarbete", description: "Teknisk monteringslinje. Bättre lön.",
                icon: "wrench.and.screwdriver", durationSeconds: 14400, baseEarningsSeconds: 18000, requiredZone: "Midgrey", riskPercentage: 0.08),
        // Risefield jobs
        JobType(id: "technician", name: "Tekniker",         description: "Reparera maskiner. Kräver kompetens.",
                icon: "cpu",            durationSeconds: 14400,  baseEarningsSeconds: 20160, requiredZone: "Risefield",   riskPercentage: 0.12),
        JobType(id: "labassist",  name: "Laboratorieassistent", description: "Forska i zonfaciliteter.",
                icon: "flask",          durationSeconds: 21600,  baseEarningsSeconds: 32400, requiredZone: "Risefield",   riskPercentage: 0.05),
        // Aetherpoint jobs
        JobType(id: "trader",     name: "Tidshandlare",     description: "Köp/sälj tid på marknaden. Hög risk, hög belöning.",
                icon: "chart.line.uptrend.xyaxis", durationSeconds: 3600, baseEarningsSeconds: 7200, requiredZone: "Aetherpoint", riskPercentage: 0.30),
        JobType(id: "consultant", name: "Konsult",          description: "Rådgiv till rikare zoner. Exklusivt arbete.",
                icon: "person.badge.plus", durationSeconds: 14400, baseEarningsSeconds: 43200, requiredZone: "Aetherpoint", riskPercentage: 0.08),
        // Novalux+
        JobType(id: "architect",  name: "Tidsarkitekt",     description: "Designa tidssystem för eliten. Betalar extremt bra.",
                icon: "building.columns", durationSeconds: 28800, baseEarningsSeconds: 115200, requiredZone: "Novalux",   riskPercentage: 0.15),
        JobType(id: "banker",     name: "Tidsbanker",       description: "Hantera stora tidskonton. Vaultum-exklusivt.",
                icon: "banknote",       durationSeconds: 28800,  baseEarningsSeconds: 172800, requiredZone: "Vaultum",    riskPercentage: 0.10),
    ]

    private init() {
        loadActiveJob()
        startMonitoring()
    }

    func availableJobs(for zone: ZoneProfile) -> [JobType] {
        let zoneOrder = ["Duskline", "Midgrey", "Risefield", "Aetherpoint", "Novalux", "Vaultum", "Solara"]
        guard let playerIdx = zoneOrder.firstIndex(of: zone.name) else { return [] }
        return allJobs.filter { job in
            guard let jobIdx = zoneOrder.firstIndex(of: job.requiredZone) else { return false }
            return jobIdx <= playerIdx
        }
    }

    func startJob(_ job: JobType) -> Bool {
        guard activeJob == nil else { return false }
        let active = ActiveJob(jobId: job.id, startTime: Date(),
                               durationSeconds: job.durationSeconds,
                               baseEarnings: job.baseEarnings(for: GameState.shared.currentZone))
        activeJob = active
        saveActiveJob(active)
        return true
    }

    func checkCompletion() {
        guard let job = activeJob, job.isComplete else { return }
        completeJob(job)
    }

    private func completeJob(_ job: ActiveJob) {
        // Find job type for risk calculation
        if let jobType = allJobs.first(where: { $0.id == job.jobId }) {
            let riskRoll = Double.random(in: 0...1)
            var earnings = job.baseEarnings

            if riskRoll < jobType.riskPercentage {
                // Bad event — lose 20-50% of earnings
                let loseFactor = Double.random(in: 0.2...0.5)
                earnings *= (1 - loseFactor)
                let taxed = earnings * (1 - GameState.shared.currentZone.taxRate)
                let boosted = taxed * BoostManager.shared.boosterMultiplier()
                TimeEngine.shared.addTime(boosted)
                GameState.shared.recordEarning(boosted)
                lastCompletedJobMessage = "Händelse! \(jobType.name) avkortad.\nIntjänat: \(TimeEngine.shortFormatted(boosted)) (efter skatt + risk)"
            } else {
                let taxed = earnings * (1 - GameState.shared.currentZone.taxRate)
                let boosted = taxed * BoostManager.shared.boosterMultiplier()
                TimeEngine.shared.addTime(boosted)
                GameState.shared.recordEarning(boosted)
                lastCompletedJobMessage = "\(jobType.name) klar!\nIntjänat: \(TimeEngine.shortFormatted(boosted)) (efter skatt)"
            }

            MissionsManager.incrementProgress("jobs_completed", by: 1)
        }

        activeJob = nil
        clearActiveJob()
        showJobComplete = true
    }

    private func startMonitoring() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkCompletion()
        }
    }

    private func saveActiveJob(_ job: ActiveJob) {
        if let data = try? JSONEncoder().encode(job) {
            UserDefaults.standard.set(data, forKey: activeJobKey)
        }
    }

    private func loadActiveJob() {
        guard let data = UserDefaults.standard.data(forKey: activeJobKey),
              let job = try? JSONDecoder().decode(ActiveJob.self, from: data) else { return }
        if job.isComplete {
            completeJob(job)
        } else {
            activeJob = job
        }
    }

    private func clearActiveJob() {
        UserDefaults.standard.removeObject(forKey: activeJobKey)
    }

    func cancelJob() {
        activeJob = nil
        clearActiveJob()
    }
}

extension JobType {
    func baseEarnings(for zone: ZoneProfile) -> TimeInterval {
        return baseEarningsSeconds * zone.workMultiplier
    }

    func netEarnings(for zone: ZoneProfile) -> TimeInterval {
        let base = baseEarnings(for: zone)
        return base * (1 - zone.taxRate) * BoostManager.shared.boosterMultiplier()
    }

    func hourlyRate(for zone: ZoneProfile) -> TimeInterval {
        return netEarnings(for: zone) / (durationSeconds / 3600)
    }
}

// MARK: - Work View

struct WorkView: View {
    @ObservedObject private var workManager = WorkManager.shared
    @ObservedObject private var gameState = GameState.shared
    @ObservedObject private var engine = TimeEngine.shared

    @State private var selectedJob: JobType? = nil
    @State private var showConfirm: Bool = false
    @State private var tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var progressValue: Double = 0

    var availableJobs: [JobType] {
        workManager.availableJobs(for: gameState.currentZone)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text("ARBETSMARKNADEN")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.top, 60)
                        Text("Zon: \(gameState.currentZone.name) | Skatt: \(Int(gameState.currentZone.taxRate * 100))%")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Active job display
                    if let job = workManager.activeJob {
                        ActiveJobCard(job: job, onCancel: {
                            workManager.cancelJob()
                        })
                        .onReceive(tickTimer) { _ in
                            progressValue = job.progress
                            workManager.checkCompletion()
                        }
                    }

                    // Available jobs list
                    VStack(spacing: 12) {
                        ForEach(availableJobs) { job in
                            JobCard(job: job, zone: gameState.currentZone, isDisabled: workManager.activeJob != nil) {
                                selectedJob = job
                                showConfirm = true
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Income breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        Text("INKOMSTDETALJER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        HStack {
                            Text("Skattesats:")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("\(Int(gameState.currentZone.taxRate * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                        HStack {
                            Text("Boost-multiplikator:")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("x\(String(format: "%.1f", BoostManager.shared.boosterMultiplier()))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        HStack {
                            Text("Zonmultiplikator:")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text("x\(String(format: "%.1f", gameState.currentZone.workMultiplier))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    Spacer(minLength: 100)
                }
            }
        }
        .alert("Starta jobb?", isPresented: $showConfirm) {
            Button("Starta") {
                if let job = selectedJob {
                    let success = workManager.startJob(job)
                    if success {
                        let gen = UIImpactFeedbackGenerator(style: .heavy)
                        gen.impactOccurred()
                    }
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            if let job = selectedJob {
                Text("'\(job.name)' tar \(formatDuration(job.durationSeconds)).\nFörväntad nettolön: ~\(TimeEngine.shortFormatted(job.netEarnings(for: gameState.currentZone)))")
            }
        }
        .alert("Jobb Klart!", isPresented: $workManager.showJobComplete) {
            Button("OK") {}
        } message: {
            Text(workManager.lastCompletedJobMessage)
        }
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Job Card

struct JobCard: View {
    let job: JobType
    let zone: ZoneProfile
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !isDisabled { onTap() } }) {
            HStack(spacing: 14) {
                Image(systemName: job.icon)
                    .font(.system(size: 22))
                    .foregroundColor(isDisabled ? .gray : .green)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isDisabled ? .gray : .white)
                    Text(job.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Label(formatDur(job.durationSeconds), systemImage: "clock")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        Label("~\(TimeEngine.shortFormatted(job.netEarnings(for: zone)))", systemImage: "plus.circle")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green.opacity(0.8))
                        if job.riskPercentage > 0.1 {
                            Label("\(Int(job.riskPercentage * 100))% risk", systemImage: "exclamationmark.triangle")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.8))
                        }
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(14)
            .background(isDisabled ? Color.white.opacity(0.02) : Color.white.opacity(0.07))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(isDisabled ? 0 : 0.15), lineWidth: 1))
        }
        .disabled(isDisabled)
    }

    func formatDur(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        return h > 0 ? "\(h)h\(m > 0 ? " \(m)m" : "")" : "\(m)m"
    }
}

// MARK: - Active Job Card

struct ActiveJobCard: View {
    let job: ActiveJob
    let onCancel: () -> Void
    @State private var progress: Double = 0
    @State private var tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var jobName: String {
        WorkManager.shared.allJobs.first(where: { $0.id == job.jobId })?.name ?? "Pågående jobb"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PÅGÅENDE JOBB")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.7))
                    Text(jobName)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    let gen = UIImpactFeedbackGenerator(style: .medium)
                    gen.impactOccurred()
                    onCancel()
                } label: {
                    Text("Avbryt")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red.opacity(0.7))
                }
            }

            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08)).frame(height: 7)
                        Capsule()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.green.opacity(0.7), .green]),
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * progress, height: 7)
                    }
                }
                .frame(height: 7)
                .onReceive(tickTimer) { _ in
                    withAnimation(.linear(duration: 0.5)) { progress = job.progress }
                }
                .onAppear { progress = job.progress }

                HStack {
                    Text("\(Int(progress * 100))% klar")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow.opacity(0.7))
                        Text(TimeEngine.shortFormatted(job.timeRemaining))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.25), lineWidth: 1))
        .padding(.horizontal)
    }
}
