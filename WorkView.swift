import SwiftUI
import Foundation

// MARK: - Job Types

struct JobType: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let durationSeconds: TimeInterval
    let baseEarningsSeconds: TimeInterval
    let requiredZone: String
    let riskPercentage: Double

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

    // All available job types across 14 zones
    let allJobs: [JobType] = [
        // Grundskiftet / Krypdalen
        JobType(id: "scavenger",   name: "Skrotsamlare",       description: "Samla skrot i zonen. Bottenlön men alltid arbete.",
                icon: "trash",           durationSeconds: 7200,   baseEarningsSeconds: 7560,  requiredZone: "Grundskiftet", riskPercentage: 0.05),
        // Gråbotten
        JobType(id: "courier",     name: "Budlöpare",          description: "Leverera brev i grå gator. Enkelt, mestadels säkert.",
                icon: "envelope",        durationSeconds: 7200,   baseEarningsSeconds: 7920,  requiredZone: "Gråbotten",    riskPercentage: 0.10),
        // Skymring
        JobType(id: "factory",     name: "Fabriksarbete",      description: "Monotont löpandsbandarbete. Låg lön, hög säkerhet.",
                icon: "gear",            durationSeconds: 14400,  baseEarningsSeconds: 16200, requiredZone: "Skymring",     riskPercentage: 0.05),
        // Halvmörker
        JobType(id: "delivery",    name: "Budkörning",         description: "Leverera paket runt zonen. Snabbt men osäkert.",
                icon: "box.truck",       durationSeconds: 7200,   baseEarningsSeconds: 7800,  requiredZone: "Halvmörker",   riskPercentage: 0.15),
        // Duskline
        JobType(id: "security",    name: "Säkerhetsvakt",      description: "Skydda byggnader. 8h skift, okej lön.",
                icon: "shield",          durationSeconds: 28800,  baseEarningsSeconds: 34560, requiredZone: "Duskline",     riskPercentage: 0.10),
        // Midgrey
        JobType(id: "assembly",    name: "Monteringsarbete",   description: "Teknisk monteringslinje. Bättre lön.",
                icon: "wrench.and.screwdriver", durationSeconds: 14400, baseEarningsSeconds: 18000, requiredZone: "Midgrey", riskPercentage: 0.08),
        // Risefield
        JobType(id: "technician",  name: "Tekniker",           description: "Reparera maskiner. Kräver kompetens.",
                icon: "cpu",             durationSeconds: 14400,  baseEarningsSeconds: 20160, requiredZone: "Risefield",   riskPercentage: 0.12),
        JobType(id: "labassist",   name: "Laboratorieassistent", description: "Forska i zonfaciliteter.",
                icon: "flask",           durationSeconds: 21600,  baseEarningsSeconds: 32400, requiredZone: "Risefield",   riskPercentage: 0.05),
        // Aetherpoint
        JobType(id: "trader",      name: "Tidshandlare",       description: "Köp/sälj tid på marknaden. Hög risk, hög belöning.",
                icon: "chart.line.uptrend.xyaxis", durationSeconds: 3600, baseEarningsSeconds: 7200, requiredZone: "Aetherpoint", riskPercentage: 0.30),
        JobType(id: "consultant",  name: "Konsult",            description: "Rådgiv till rikare zoner. Exklusivt arbete.",
                icon: "person.badge.plus", durationSeconds: 14400, baseEarningsSeconds: 43200, requiredZone: "Aetherpoint", riskPercentage: 0.08),
        // Novalux
        JobType(id: "architect",   name: "Tidsarkitekt",       description: "Designa tidssystem för eliten. Betalar extremt bra.",
                icon: "building.columns", durationSeconds: 28800, baseEarningsSeconds: 115200, requiredZone: "Novalux",   riskPercentage: 0.15),
        // Kronvakt
        JobType(id: "strategist",  name: "Tidsstrateg",        description: "Planera zonoperationer för Kronvakt-eliten.",
                icon: "chart.bar.xaxis", durationSeconds: 21600, baseEarningsSeconds: 144000, requiredZone: "Kronvakt",   riskPercentage: 0.12),
        // Vaultum
        JobType(id: "banker",      name: "Tidsbanker",         description: "Hantera stora tidskonton. Vaultum-exklusivt.",
                icon: "banknote",        durationSeconds: 28800, baseEarningsSeconds: 172800, requiredZone: "Vaultum",    riskPercentage: 0.10),
        // Zenit
        JobType(id: "oracle",      name: "Tidsarkiv-Orakel",   description: "Tolka tidsmönster. Kräver extrem precision.",
                icon: "eye.trianglebadge.exclamationmark", durationSeconds: 14400, baseEarningsSeconds: 230400, requiredZone: "Zenit", riskPercentage: 0.20),
        // Solara
        JobType(id: "sovereign",   name: "Tidssuverän",        description: "Styra flöden av tid för Solaras kärna.",
                icon: "sun.max",         durationSeconds: 28800, baseEarningsSeconds: 432000, requiredZone: "Solara",     riskPercentage: 0.25),
    ]

    private init() {
        loadActiveJob()
        startMonitoring()
    }

    func availableJobs(for zone: ZoneProfile) -> [JobType] {
        return allJobs.filter { job in
            guard let jobZone = ZoneProfile.allZones.first(where: { $0.name == job.requiredZone }) else { return false }
            return jobZone.index <= zone.index
        }
    }

    func startJob(_ job: JobType) -> Bool {
        guard activeJob == nil else { return false }
        let active = ActiveJob(
            jobId: job.id,
            startTime: Date(),
            durationSeconds: job.durationSeconds,
            baseEarnings: job.baseEarnings(for: GameState.shared.currentZone)
        )
        activeJob = active
        saveActiveJob(active)
        return true
    }

    func checkCompletion() {
        guard let job = activeJob, job.isComplete else { return }
        completeJob(job)
    }

    private func completeJob(_ job: ActiveJob) {
        if let jobType = allJobs.first(where: { $0.id == job.jobId }) {
            let riskRoll = Double.random(in: 0...1)
            var earnings = job.baseEarnings

            if riskRoll < jobType.riskPercentage {
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

    func netEarningsInflated(for zone: ZoneProfile) -> TimeInterval {
        return InflationManager.shared.deflatedEarnings(netEarnings(for: zone))
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
    @ObservedObject private var income = IncomeManager.shared
    @ObservedObject private var inflation = InflationManager.shared

    @State private var selectedJob: JobType? = nil
    @State private var showConfirm: Bool = false
    @State private var tickTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var showMiniJobsFromWork = false
    @State private var showJobCompleteToast: Bool = false
    @State private var jobCompleteMessage: String = ""

    var availableJobs: [JobType] {
        workManager.availableJobs(for: gameState.currentZone)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.05), Color.black],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerSection
                    healthIncomeSection
                    if let job = workManager.activeJob {
                        ActiveJobCard(job: job, onCancel: { workManager.cancelJob() })
                            .onReceive(tickTimer) { _ in workManager.checkCompletion() }
                    }
                    jobsSection
                    incomeDetailsSection
                    Spacer(minLength: 100)
                }
            }
        }
        .onDisappear { tickTimer.upstream.connect().cancel() }
        .sheet(isPresented: $showConfirm) {
            if let job = selectedJob {
                JobConfirmSheet(job: job, zone: gameState.currentZone) {
                    _ = workManager.startJob(job)
                    showConfirm = false
                } onCancel: {
                    showConfirm = false
                }
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: workManager.showJobComplete) { _, isShowing in
            if isShowing {
                jobCompleteMessage = workManager.lastCompletedJobMessage
                withAnimation(.spring()) { showJobCompleteToast = true }
                workManager.showJobComplete = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation(.easeOut) { showJobCompleteToast = false }
                }
            }
        }
        .overlay(alignment: .top) {
            if showJobCompleteToast {
                JobCompleteToast(message: jobCompleteMessage)
                    .padding(.top, 54)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showMiniJobsFromWork) { NavigationStack { MiniJobsView() } }
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("ARBETSMARKNADEN")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.top, 60)
            Text("Zon: \(gameState.currentZone.name)  |  Skatt: \(Int(gameState.currentZone.taxRate * 100))%")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Health Income Section

    private var healthIncomeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DIN INKOMST IDAG")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.8))
                    Text(income.jobTitle)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeEngine.shortFormatted(income.todayBreakdown.total))
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundColor(.green)
                    Text("tjänat via hälsa")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Breakdown bars
            let total = max(income.todayBreakdown.total, 1)
            Group {
                HealthBar(icon: "figure.walk",       label: "Steg",         value: income.todayBreakdown.stepsSeconds,    maxValue: 21600.0 * gameState.currentZone.stepBonusMultiplier, total: total, color: .green)  // 20k steps × 1.08s × zoneMult
                HealthBar(icon: "flame",              label: "Kalorier",     value: income.todayBreakdown.caloriesSeconds, maxValue: 1200.0,  total: total, color: .orange)
                HealthBar(icon: "bolt.heart",         label: "Träning",      value: income.todayBreakdown.exerciseSeconds, maxValue: 3600.0,  total: total, color: .yellow)
                HealthBar(icon: "moon.zzz",           label: "Sömn",         value: income.todayBreakdown.sleepSeconds,    maxValue: 14400.0, total: total, color: .indigo)
                HealthBar(icon: "figure.stand",       label: "Stå",          value: income.todayBreakdown.standSeconds,    maxValue: 2160.0,  total: total, color: .cyan)
                HealthBar(icon: "brain.head.profile", label: "Mindfulness",  value: income.todayBreakdown.mindfulSeconds,  maxValue: 1800.0,  total: total, color: .purple)
                HealthBar(icon: "waveform.path.ecg",  label: "HRV-bonus",   value: income.todayBreakdown.hrvBonus,         maxValue: 7200.0,  total: total, color: .pink)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text("Tjänat via hälsa idag: \(TimeEngine.shortFormatted(income.todayBreakdown.total))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text("Lön utbetalas vid 00.00")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.6))
                if inflation.isCritical {
                    Text("KRITISK INFLATION: \(inflation.percentageString)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                } else if inflation.isWarning {
                    Text("Inflation: \(inflation.percentageString) — uppgradera zon!")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.2), lineWidth: 1))
        .padding(.horizontal)
    }

    // MARK: Jobs Section

    private var jobsSection: some View {
        VStack(spacing: 16) {
            // Mini-jobs section (arcade-style instant jobs)
            VStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.purple)
                    Text("AKTIVA JOBB")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.purple.opacity(0.8))
                        .tracking(2)
                    Spacer()
                    Text("Spela via Dashboard → Arbete")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        miniJobChip(icon: "pipe.and.drop.fill",    name: "Rörmockaren",    desc: "Fixa rörläggning")
                        miniJobChip(icon: "terminal.fill",          name: "Kodknäckaren",   desc: "Knäck koden")
                        miniJobChip(icon: "arrow.up.arrow.down",    name: "Sorteringsverket", desc: "Sortera gods")
                        miniJobChip(icon: "bolt.circle.fill",       name: "Sprängexperten", desc: "Defusera bomben")
                        miniJobChip(icon: "timer",                  name: "Tidskalibratorn", desc: "Kalibreringen")
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 10)
            .background(Color.purple.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.12), lineWidth: 1))
            .padding(.horizontal)

            // Regular jobs
            Text("TILLGÄNGLIGA JOBB")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            ForEach(availableJobs) { job in
                JobCard(
                    job: job,
                    zone: gameState.currentZone,
                    isDisabled: workManager.activeJob != nil,
                    inflationMultiplier: inflation.currentMultiplier
                ) {
                    selectedJob = job
                    showConfirm = true
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Income Details

    private var incomeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INKOMSTDETALJER")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))

            DetailRow(
                label: "Skattesats",
                value: "\(Int(gameState.currentZone.taxRate * 100))%",
                color: .yellow,
                description: "Statens andel — dras automatiskt vid varje utbetalning"
            )
            Divider().background(Color.white.opacity(0.06))
            DetailRow(
                label: "Boost-multiplikator",
                value: "×\(String(format: "%.2f", BoostManager.shared.boosterMultiplier()))",
                color: .green,
                description: "Bonus från aktiva boosters — multiplicerar hela inkomsten"
            )
            Divider().background(Color.white.opacity(0.06))
            DetailRow(
                label: "Zonmultiplikator",
                value: "×\(String(format: "%.1f", gameState.currentZone.workMultiplier))",
                color: .cyan,
                description: "Din zons effektivitet — högre zon ger mer per tidsenhet"
            )
            Divider().background(Color.white.opacity(0.06))
            DetailRow(
                label: "Inflation/dag",
                value: TimeEngine.shortFormatted(inflation.dailyInflationCostSeconds),
                color: inflation.isCritical ? .red : .orange,
                description: inflation.isCritical
                    ? "KRITISK — din tid förlorar värde snabbare än du tjänar"
                    : "Daglig kostnad — uppgradera zon för att sänka inflationen"
            )
            if inflation.isWarning {
                Divider().background(Color.white.opacity(0.06))
                DetailRow(
                    label: "Inflationstakt",
                    value: inflation.percentageString,
                    color: .red,
                    description: "Aktuell takt — sänker köpkraften på din sparade tid"
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal)
    }

    private func miniJobChip(icon: String, name: String, desc: String) -> some View {
        Button { showMiniJobsFromWork = true } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.18))
                        .frame(width: 36, height: 36)
                        .shadow(color: .purple.opacity(0.4), radius: 5)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.purple)
                }
                Text(name)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                Text(desc)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }
            .frame(width: 80)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.2), lineWidth: 1))
        }
    }

    func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Health Bar

struct HealthBar: View {
    let icon: String
    let label: String
    let value: TimeInterval
    let maxValue: Double
    let total: TimeInterval
    let color: Color

    var fraction: Double { min(1.0, value / Swift.max(maxValue, 1)) }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)

            Text(TimeEngine.shortFormatted(value))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(value > 0 ? color : .white.opacity(0.3))
                .frame(width: 52, alignment: .trailing)
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    let color: Color
    var description: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }
            if let desc = description {
                Text(desc)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.28))
                    .lineLimit(2)
            }
        }
    }
}

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

    var body: some View {
        Button(action: { if !isDisabled { onTap() } }) {
            VStack(spacing: 0) {
                // Top colored stripe
                accentColor.opacity(isDisabled ? 0.15 : 0.6)
                    .frame(height: 2)

                HStack(spacing: 14) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(accentColor.opacity(isDisabled ? 0.06 : 0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: job.icon)
                            .font(.system(size: 18))
                            .foregroundColor(isDisabled ? .gray : accentColor)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.name)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(isDisabled ? .gray.opacity(0.6) : .white)
                        Text(job.description)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(isDisabled ? 0.2 : 0.4))
                            .lineLimit(2)
                    }

                    Spacer()

                    // Earnings column
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("+\(TimeEngine.shortFormatted(job.netEarningsInflated(for: zone)))")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(isDisabled ? .gray.opacity(0.4) : accentColor)
                        Text(formatDur(job.durationSeconds))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                        if job.riskPercentage > 0.10 {
                            Text("Risk \(Int(job.riskPercentage * 100))%")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.red.opacity(0.7))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
        }
        .disabled(isDisabled)
        .background(Color(red: 0.06, green: 0.07, blue: 0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(isDisabled ? 0.05 : 0.2), lineWidth: 1))
        .opacity(isDisabled ? 0.5 : 1.0)
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
                        Spacer()
                        Text("Klar om \(TimeEngine.shortFormatted(job.timeRemaining))")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundColor(.green)
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
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.25), lineWidth: 1))
        .shadow(color: Color.green.opacity(0.1), radius: 12, y: 4)
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
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text(job.description)
                    .font(.system(size: 11, design: .monospaced))
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

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Avbryt")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button(action: onConfirm) {
                    Text("STARTA JOBB")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(Color(red: 0.05, green: 0.07, blue: 0.06))
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
                    .lineLimit(2)
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

#Preview {
    WorkView()
        .preferredColorScheme(.dark)
}
