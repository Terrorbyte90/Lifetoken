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
                icon: "trash",           durationSeconds: 7200,   baseEarningsSeconds: 7560,  requiredZone: "Askan",        riskPercentage: 0.05),
        // Spillrorna
        JobType(id: "courier",     name: "Budlöpare",          description: "Leverera brev i grå gator. Enkelt, mestadels säkert.",
                icon: "envelope",        durationSeconds: 7200,   baseEarningsSeconds: 7920,  requiredZone: "Spillrorna",   riskPercentage: 0.10),
        // Betongen
        JobType(id: "factory",     name: "Fabriksarbete",      description: "Monotont löpandsbandarbete. Låg lön, hög säkerhet.",
                icon: "gear",            durationSeconds: 14400,  baseEarningsSeconds: 16200, requiredZone: "Betongen",     riskPercentage: 0.05),
        // Dimman
        JobType(id: "delivery",    name: "Budkörning",         description: "Leverera paket runt zonen. Snabbt men osäkert.",
                icon: "box.truck",       durationSeconds: 7200,   baseEarningsSeconds: 7800,  requiredZone: "Dimman",       riskPercentage: 0.15),
        // Halvmörkret
        JobType(id: "security",    name: "Säkerhetsvakt",      description: "Skydda byggnader. 8h skift, okej lön.",
                icon: "shield",          durationSeconds: 28800,  baseEarningsSeconds: 34560, requiredZone: "Halvmörkret",  riskPercentage: 0.10),
        // Gränslandet
        JobType(id: "assembly",    name: "Monteringsarbete",   description: "Teknisk monteringslinje. Bättre lön.",
                icon: "wrench.and.screwdriver", durationSeconds: 14400, baseEarningsSeconds: 18000, requiredZone: "Gränslandet", riskPercentage: 0.08),
        // Stigarnas Dal
        JobType(id: "technician",  name: "Tekniker",           description: "Reparera maskiner. Kräver kompetens.",
                icon: "cpu",             durationSeconds: 14400,  baseEarningsSeconds: 20160, requiredZone: "Stigarnas Dal", riskPercentage: 0.12),
        JobType(id: "labassist",   name: "Laboratorieassistent", description: "Forska i zonfaciliteter.",
                icon: "flask",           durationSeconds: 21600,  baseEarningsSeconds: 32400, requiredZone: "Stigarnas Dal", riskPercentage: 0.05),
        // Uppgången
        JobType(id: "trader",      name: "Tidshandlare",       description: "Köp/sälj tid på marknaden. Hög risk, hög belöning.",
                icon: "chart.line.uptrend.xyaxis", durationSeconds: 3600, baseEarningsSeconds: 7200, requiredZone: "Uppgången", riskPercentage: 0.30),
        JobType(id: "consultant",  name: "Konsult",            description: "Rådgiv till rikare zoner. Exklusivt arbete.",
                icon: "person.badge.plus", durationSeconds: 14400, baseEarningsSeconds: 43200, requiredZone: "Uppgången", riskPercentage: 0.08),
        // Tröskeln
        JobType(id: "architect",   name: "Tidsarkitekt",       description: "Designa tidssystem för eliten. Betalar extremt bra.",
                icon: "building.columns", durationSeconds: 28800, baseEarningsSeconds: 115200, requiredZone: "Tröskeln",  riskPercentage: 0.15),
        // Klarljuset
        JobType(id: "strategist",  name: "Tidsstrateg",        description: "Planera zonoperationer för Klarljuset-eliten.",
                icon: "chart.bar.xaxis", durationSeconds: 21600, baseEarningsSeconds: 144000, requiredZone: "Klarljuset", riskPercentage: 0.12),
        // Vakttornet
        JobType(id: "banker",      name: "Tidsbanker",         description: "Hantera stora tidskonton. Vakttornet-exklusivt.",
                icon: "banknote",        durationSeconds: 28800, baseEarningsSeconds: 172800, requiredZone: "Vakttornet", riskPercentage: 0.10),
        // Valvet
        JobType(id: "oracle",      name: "Tidsarkiv-Orakel",   description: "Tolka tidsmönster. Kräver extrem precision.",
                icon: "eye.trianglebadge.exclamationmark", durationSeconds: 14400, baseEarningsSeconds: 230400, requiredZone: "Valvet", riskPercentage: 0.20),
        // Evigheten
        JobType(id: "sovereign",   name: "Tidssuverän",        description: "Styra flöden av tid för Evighetens kärna.",
                icon: "sun.max",         durationSeconds: 28800, baseEarningsSeconds: 432000, requiredZone: "Evigheten",  riskPercentage: 0.25),
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
            let zone = GameState.shared.currentZone

            if riskRoll < jobType.riskPercentage {
                let loseFactor = Double.random(in: 0.2...0.5)
                earnings *= (1 - loseFactor)
                let taxed = earnings * (1 - zone.taxRate)
                let boosted = taxed * BoostManager.shared.boosterMultiplier()
                TimeEngine.shared.addTime(boosted)
                GameState.shared.recordEarning(boosted)
                // Skatten till Gregor
                let taxAmount = earnings - taxed
                if taxAmount > 0 {
                    BoardManager.shared.collectTax(amount: taxAmount)
                    BoardManager.shared.recordTaxCollection(taxAmount)
                }
                TransactionLedger.shared.record(label: "\(jobType.name) (avkortad)", amount: boosted)
                lastCompletedJobMessage = "Händelse! \(jobType.name) avkortad.\nIntjänat: \(TimeEngine.shortFormatted(boosted)) (efter skatt + risk)"
            } else {
                let taxed = earnings * (1 - zone.taxRate)
                let boosted = taxed * BoostManager.shared.boosterMultiplier()
                TimeEngine.shared.addTime(boosted)
                GameState.shared.recordEarning(boosted)
                // Skatten till Gregor
                let taxAmount = earnings - taxed
                if taxAmount > 0 {
                    BoardManager.shared.collectTax(amount: taxAmount)
                    BoardManager.shared.recordTaxCollection(taxAmount)
                }
                TransactionLedger.shared.record(label: jobType.name, amount: boosted)
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
    @State private var showJobCompleteToast: Bool = false
    @State private var jobCompleteMessage: String = ""

    // Direktnavigering till aktiva jobb
    @State private var showPipe   = false
    @State private var showSort   = false
    @State private var showBomb   = false
    @State private var showTiming = false

    var availableJobs: [JobType] {
        workManager.availableJobs(for: gameState.currentZone)
    }

    var body: some View {
        ZStack {
            LTScreenBackground(style: .work)

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
        .fullScreenCover(isPresented: $showPipe)   { PipeGameView(difficulty: 0) }
        .fullScreenCover(isPresented: $showSort)   { SortingGameView(difficulty: 0) }
        .fullScreenCover(isPresented: $showBomb)   { BombDefuseView(difficulty: 0) }
        .fullScreenCover(isPresented: $showTiming) { TimingGameView(difficulty: 0) }
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
    }

    // MARK: Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            LTSectionTitle(
                overline: "Arbetsmarknaden",
                title: "Skifta upp tempot i \(gameState.currentZone.name)",
                tint: LTPalette.neonGreen
            )
            .padding(.top, 60)

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
                    icon: "arrow.up.right",
                    text: "x\(String(format: "%.1f", gameState.currentZone.workMultiplier))",
                    tint: .cyan
                )
            }

            Text("Planera lågrisk för stabilitet och ta högrisk när du vill jaga större nettolön.")
                .font(LTFont.body(11))
                .foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)

            LTInfoCallout(
                title: "Hur jobb funkar",
                message: "Ett jobb löper i realtid och betalas ut automatiskt när tiden gått ut. Du kan alltid avbryta ett aktivt jobb utan extra avgift.",
                icon: "clock.arrow.trianglehead.2.counterclockwise.rotate.90",
                tint: .cyan
            )
        }
        .padding(LTSpacing.lg)
        .ltCard(
            color: LTPalette.neonGreen,
            opacity: 0.06,
            radius: LTRadius.md,
            borderOpacity: 0.22,
            shadowColor: LTPalette.neonGreen.opacity(0.15),
            shadowRadius: 10
        )
        .padding(.horizontal)
    }

    // MARK: Health Income Section

    private var healthIncomeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: LTSpacing.xs) {
                    LTSectionTitle(
                        overline: "Din inkomst idag",
                        title: income.jobTitle,
                        tint: .green
                    )
                    Text("Bättre hälsa ger högre dagsinkomst. Optimera steg, sömn och träning för jämn tillväxt.")
                        .font(LTFont.body(10))
                        .foregroundColor(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(TimeEngine.shortFormatted(income.todayBreakdown.total))
                        .font(LTFont.value(22))
                        .foregroundColor(.green)
                    Text("intjänat via hälsa")
                        .font(LTFont.caption(9))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // Breakdown bars
            let total = max(income.todayBreakdown.total, 1)
            Group {
                HealthBar(icon: "figure.walk", label: "Steg  \(income.dailySteps.formatted()) steg", value: income.todayBreakdown.stepsSeconds, maxValue: 21600.0 * gameState.currentZone.stepBonusMultiplier, total: total, color: .green)  // 20k steps × 1.08s × zoneMult
                HealthBar(icon: "flame",              label: "Kalorier",     value: income.todayBreakdown.caloriesSeconds, maxValue: 1200.0,  total: total, color: .orange)
                HealthBar(icon: "bolt.heart",         label: "Träning",      value: income.todayBreakdown.exerciseSeconds, maxValue: 3600.0,  total: total, color: .yellow)
                HealthBar(icon: "moon.zzz",           label: "Sömn",         value: income.todayBreakdown.sleepSeconds,    maxValue: 14400.0, total: total, color: .indigo)
                HealthBar(icon: "figure.stand",       label: "Stå",          value: income.todayBreakdown.standSeconds,    maxValue: 2160.0,  total: total, color: .cyan)
                HealthBar(icon: "brain.head.profile", label: "Mindfulness",  value: income.todayBreakdown.mindfulSeconds,  maxValue: 1800.0,  total: total, color: .purple)
                HealthBar(icon: "waveform.path.ecg",  label: "HRV-bonus",   value: income.todayBreakdown.hrvBonus,         maxValue: 7200.0,  total: total, color: .pink)
            }

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(income.dailySteps.formatted()) steg idag")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green.opacity(0.7))
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
                    Text("Inflation: \(inflation.percentageString) — högre zon kan sänka den (frivilligt)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            LTInfoCallout(
                title: inflation.isCritical ? "Inflationen är kritisk" : "Inflation påverkar netto",
                message: inflation.isCritical
                    ? "Din zon äter upp mer av din tid än normalt. Prioritera återbetalningar och stabil inkomst innan du tar hög risk."
                    : "Håll koll på daglig inflation när du planerar lån, investeringar och zonflytt.",
                icon: inflation.isCritical ? "exclamationmark.triangle.fill" : "chart.line.uptrend.xyaxis",
                tint: inflation.isCritical ? .red : .orange
            )
        }
        .padding(LTSpacing.lg)
        .ltCard(
            color: .green,
            opacity: 0.07,
            radius: LTRadius.md,
            borderOpacity: 0.24,
            shadowColor: .green.opacity(0.12),
            shadowRadius: 8
        )
        .padding(.horizontal)
    }

    // MARK: Jobs Section

    private var jobsSection: some View {
        VStack(spacing: 16) {
            // Mini-jobs section (arcade-style instant jobs)
            VStack(spacing: 10) {
                HStack(spacing: 5) {
                    LTSectionTitle(
                        overline: "Aktiva jobb",
                        title: "Snabba uppdrag med direkt resultat",
                        tint: .purple
                    )
                    Spacer()
                    Text("Arcade")
                        .font(LTFont.caption(9))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        miniJobChip(icon: "pipe.and.drop.fill",    name: "Rörmockaren",      desc: "Fixa rörläggning") { showPipe = true }
                        miniJobChip(icon: "arrow.up.arrow.down",   name: "Sorteringsverket", desc: "Sortera gods")     { showSort = true }
                        miniJobChip(icon: "bolt.circle.fill",      name: "Sprängexperten",   desc: "Defusera bomben")  { showBomb = true }
                        miniJobChip(icon: "timer",                 name: "Tidskalibratorn",  desc: "Kalibreringen")    { showTiming = true }
                    }
                    .padding(.horizontal, 2)
                }

                LTInfoCallout(
                    title: "Snabbspel",
                    message: "Arcade-jobb ger direkt utfall. Högre svårighet höjer både belöning och risk för böter.",
                    icon: "gamecontroller.fill",
                    tint: .purple
                )
            }
            .padding(LTSpacing.md)
            .ltCard(
                color: .purple,
                opacity: 0.06,
                radius: LTRadius.md,
                borderOpacity: 0.18,
                shadowColor: .purple.opacity(0.10),
                shadowRadius: 8
            )
            .padding(.horizontal)

            LTSectionTitle(
                overline: "Tillgängliga jobb",
                title: "\(availableJobs.count) roller upplåsta i din zon",
                tint: .cyan
            )
                .padding(.horizontal)

            LTInfoCallout(
                title: "Jobbflöde",
                message: workManager.activeJob == nil
                    ? "Du kan ha ett långtidsjobb aktivt åt gången. Starta jobb och låt det löpa i bakgrunden."
                    : "Du har redan ett aktivt långtidsjobb. Slutför eller avbryt innan du startar ett nytt.",
                icon: "briefcase.fill",
                tint: .cyan
            )
            .padding(.horizontal)

            if availableJobs.isEmpty {
                LTEmptyStateCard(
                    icon: "briefcase.fill",
                    title: "Inga jobb i din zon ännu",
                    message: "Öka ditt saldo och fortsätt utvecklas i zonen för att låsa upp fler roller.",
                    tint: .cyan
                )
                .padding(.horizontal)
            } else {
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
    }

    // MARK: Income Details

    private var incomeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LTSectionTitle(
                overline: "Inkomstdetaljer",
                title: "Vad som påverkar din nettolön",
                tint: .white
            )

            DetailRow(
                label: "Steg idag",
                value: income.dailySteps.formatted(),
                color: .green,
                description: "Antal steg — varje steg ger \(String(format: "%.1f", IncomeManager.stepRate))s i lön"
            )
            Divider().background(Color.white.opacity(0.06))
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
                    : "Daglig kostnad — högre zon kan sänka inflationen"
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

            LTInfoCallout(
                title: "Tips",
                message: "Sikta på jämna rutiner: stabil hälsolön + låg skuldrisk slår korta toppar över tid.",
                icon: "lightbulb.fill",
                tint: .mint
            )
        }
        .padding()
        .ltCard(radius: LTRadius.sm, borderOpacity: 0.14)
        .padding(.horizontal)
    }

    private func miniJobChip(icon: String, name: String, desc: String, action: @escaping () -> Void) -> some View {
        Button { action() } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.purple.opacity(0.18))
                        .frame(width: 42, height: 42)
                        .shadow(color: .purple.opacity(0.4), radius: 5)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.purple)
                }
                Text(name)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                Text(desc)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }
            .frame(width: 94)
            .padding(.vertical, 10)
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


#Preview {
    WorkView()
        .preferredColorScheme(.dark)
}
