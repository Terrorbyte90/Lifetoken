import SwiftUI
import Foundation

// MARK: - Mission Types

enum MissionCategory: String, Codable {
    case survival = "Överlevnad"
    case wealth = "Rikedom"
    case zone = "Zon"
    case casino = "Kasino"
    case work = "Arbete"
    case social = "Social"
}

struct Mission: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let category: MissionCategory
    let icon: String
    let rewardSeconds: TimeInterval
    let targetValue: Double
    let progressKey: String
    var isCompleted: Bool
    var isClaimed: Bool

    var progress: Double {
        UserDefaults.standard.double(forKey: progressKey)
    }
    var progressFraction: Double { min(1.0, progress / targetValue) }
    var isReady: Bool { progress >= targetValue && !isClaimed }
}

class MissionsManager: ObservableObject {
    static let shared = MissionsManager()

    @Published var missions: [Mission] = []
    @Published var showRewardAlert: Bool = false
    @Published var rewardMessage: String = ""

    private let claimedKey = "claimed_missions"
    private var uptimeTimer: Timer?

    private let allMissions: [Mission] = [
        // Survival
        Mission(id: "survive_1d",   title: "Överlev en dag",     description: "Ha mer än 0 sekunder efter 24h.",
                category: .survival, icon: "heart.fill",         rewardSeconds: 7200,
                targetValue: 86400,  progressKey: "total_uptime_seconds", isCompleted: false, isClaimed: false),
        Mission(id: "survive_7d",   title: "Överlev en vecka",   description: "Håll dig vid liv i 7 dagar.",
                category: .survival, icon: "calendar",           rewardSeconds: 86400,
                targetValue: 604800, progressKey: "total_uptime_seconds", isCompleted: false, isClaimed: false),
        Mission(id: "survive_30d",  title: "Månadsöverlevare",   description: "30 dagar utan att time out.",
                category: .survival, icon: "medal.fill",         rewardSeconds: 2592000,
                targetValue: 2592000, progressKey: "total_uptime_seconds", isCompleted: false, isClaimed: false),
        // Wealth
        Mission(id: "earn_1h",     title: "Tjäna 1 timme",       description: "Tjäna totalt 3 600 sekunder.",
                category: .wealth,  icon: "plus.circle.fill",    rewardSeconds: 1800,
                targetValue: 3600,  progressKey: "totalEarned",  isCompleted: false, isClaimed: false),
        Mission(id: "earn_1d",     title: "Tjäna 24 timmar",     description: "Tjäna totalt 86 400 sekunder.",
                category: .wealth,  icon: "banknote.fill",       rewardSeconds: 21600,
                targetValue: 86400, progressKey: "totalEarned",  isCompleted: false, isClaimed: false),
        Mission(id: "earn_1w",     title: "Tjäna 1 vecka",       description: "Tjäna totalt 604 800 sekunder.",
                category: .wealth,  icon: "crown.fill",          rewardSeconds: 172800,
                targetValue: 604800, progressKey: "totalEarned", isCompleted: false, isClaimed: false),
        // Zone progression
        Mission(id: "reach_granslandet", title: "Nå Gränslandet",  description: "Migrera till Gränslandet.",
                category: .zone,    icon: "arrow.up.circle",     rewardSeconds: 14400,
                targetValue: 1,     progressKey: "zone_midgrey_reached", isCompleted: false, isClaimed: false),
        Mission(id: "reach_uppgangen",   title: "Nå Uppgången",   description: "Migrera till Uppgången.",
                category: .zone,    icon: "building.2.fill",     rewardSeconds: 86400,
                targetValue: 1,     progressKey: "zone_aetherpoint_reached", isCompleted: false, isClaimed: false),
        Mission(id: "reach_troskeln",    title: "Nå Tröskeln",    description: "Migrera till Tröskeln och lås upp kasinot.",
                category: .zone,    icon: "star.fill",           rewardSeconds: 604800,
                targetValue: 1,     progressKey: "zone_novalux_reached", isCompleted: false, isClaimed: false),
        // Casino
        Mission(id: "win_poker",   title: "Vinn en pokerpott",   description: "Vinn din första pokerpott.",
                category: .casino,  icon: "suit.spade.fill",     rewardSeconds: 3600,
                targetValue: 1,     progressKey: "poker_wins",   isCompleted: false, isClaimed: false),
        Mission(id: "casino_win_3", title: "3 kasinovinster",    description: "Vinn 3 kasinospel totalt.",
                category: .casino,  icon: "dice.fill",           rewardSeconds: 21600,
                targetValue: 3,     progressKey: "casino_total_wins", isCompleted: false, isClaimed: false),
        // Work
        Mission(id: "complete_job", title: "Slutför ett jobb",   description: "Slutför ditt första arbete.",
                category: .work,    icon: "checkmark.circle.fill", rewardSeconds: 3600,
                targetValue: 1,     progressKey: "jobs_completed", isCompleted: false, isClaimed: false),
        Mission(id: "complete_10jobs", title: "10 jobb klara",   description: "Slutför 10 jobb totalt.",
                category: .work,    icon: "hammer.fill",         rewardSeconds: 86400,
                targetValue: 10,    progressKey: "jobs_completed", isCompleted: false, isClaimed: false),
        // Social
        Mission(id: "pvp_first_raid",  title: "Första rånet",    description: "Genomför ditt första PvP-rån.",
                category: .social,  icon: "bolt.fill",           rewardSeconds: 7200,
                targetValue: 1,     progressKey: "pvp_raids_done", isCompleted: false, isClaimed: false),
        Mission(id: "pvp_win_3",       title: "3 rån vunna",     description: "Vinn 3 PvP-rån totalt.",
                category: .social,  icon: "shield.fill",         rewardSeconds: 43200,
                targetValue: 3,     progressKey: "pvp_raids_won", isCompleted: false, isClaimed: false),
        Mission(id: "nightmarket_buy", title: "Natthandel",      description: "Köp en vara på Nattmarknaden.",
                category: .social,  icon: "moon.stars.fill",     rewardSeconds: 3600,
                targetValue: 1,     progressKey: "nightmarket_purchases", isCompleted: false, isClaimed: false),
        Mission(id: "casino_streak_3", title: "Kasino-streak", description: "Vinn 3 kasinospel i rad utan förlust.",
                category: .social,  icon: "flame.fill",          rewardSeconds: 14400,
                targetValue: 3,     progressKey: "casino_win_streak", isCompleted: false, isClaimed: false),
        Mission(id: "death_survivor",  title: "Andra chansen", description: "Återuppstå från dödläget 5 gånger.",
                category: .social,  icon: "arrow.uturn.backward.circle.fill", rewardSeconds: 21600,
                targetValue: 5,     progressKey: "rebirths_total", isCompleted: false, isClaimed: false),
    ]

    private init() {
        loadMissions()
        startUptimeTracking()
    }

    func loadMissions() {
        let claimed = Set(UserDefaults.standard.stringArray(forKey: claimedKey) ?? [])
        missions = allMissions.map { m in
            var updated = m
            updated.isClaimed = claimed.contains(m.id)
            updated.isCompleted = m.progress >= m.targetValue
            return updated
        }
    }

    func claimMission(_ mission: Mission) {
        guard mission.isReady else { return }
        let taxed = mission.rewardSeconds * (1 - GameState.shared.currentZone.taxRate)
        TimeEngine.shared.addTime(taxed)
        GameState.shared.recordEarning(taxed)

        var claimed = UserDefaults.standard.stringArray(forKey: claimedKey) ?? []
        claimed.append(mission.id)
        UserDefaults.standard.set(claimed, forKey: claimedKey)

        rewardMessage = "'\(mission.title)' klar!\n+\(TimeEngine.shortFormatted(taxed)) har lagts till."
        showRewardAlert = true
        loadMissions()
    }

    static func incrementProgress(_ key: String, by amount: Double = 1) {
        let current = UserDefaults.standard.double(forKey: key)
        UserDefaults.standard.set(current + amount, forKey: key)
    }

    private func startUptimeTracking() {
        uptimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MissionsManager.incrementProgress("total_uptime_seconds", by: 60)
            self?.loadMissions()
        }
    }
}

// MARK: - Missions View

struct MissionsView: View {
    @ObservedObject private var missionsManager = MissionsManager.shared
    @State private var selectedCategory: MissionCategory? = nil
    @State private var headerVisible: Bool = false

    var filteredMissions: [Mission] {
        let sorted = missionsManager.missions.sorted { a, b in
            // Redo-to-claim first, then in-progress, then claimed
            if a.isReady != b.isReady { return a.isReady }
            if a.isClaimed != b.isClaimed { return !a.isClaimed }
            return a.progressFraction > b.progressFraction
        }
        if let cat = selectedCategory {
            return sorted.filter { $0.category == cat }
        }
        return sorted
    }

    private var claimedCount: Int { missionsManager.missions.filter { $0.isClaimed }.count }
    private var totalCount: Int { missionsManager.missions.count }
    private var readyCount: Int { missionsManager.missions.filter { $0.isReady }.count }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [LTPalette.bg, Color.black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                missionsHeader
                categoryFilter
                missionsList
            }
        }
        .alert("Uppdrag Klart!", isPresented: $missionsManager.showRewardAlert) {
            Button("Utmärkt") {}
        } message: { Text(missionsManager.rewardMessage) }
        .onAppear {
            missionsManager.loadMissions()
            withAnimation(LTAnimation.springSmooth.delay(0.1)) { headerVisible = true }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header med progress-sammanfattning

    private var missionsHeader: some View {
        VStack(spacing: LTSpacing.sm) {
            Text("UPPDRAG")
                .font(LTFont.displayTitle(22))
                .foregroundColor(.white)
                .tracking(4)
                .padding(.top, LTSpacing.xxxl + LTSpacing.sm)

            // Overall progress bar
            VStack(spacing: LTSpacing.xs) {
                HStack {
                    Text("\(claimedCount) / \(totalCount) avklarade")
                        .font(LTFont.caption(9))
                        .foregroundColor(.white.opacity(0.35))
                        .tracking(2)
                    Spacer()
                    Text("\(Int(Double(claimedCount) / Double(max(totalCount, 1)) * 100))%")
                        .font(LTFont.caption(9))
                        .foregroundColor(LTPalette.neonGreenDim.opacity(0.7))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [LTPalette.neonGreen, LTPalette.neonGreenDim],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * CGFloat(claimedCount) / CGFloat(max(totalCount, 1)),
                                height: 3
                            )
                            .shadow(color: LTPalette.neonGreen.opacity(0.5), radius: 4)
                            .animation(LTAnimation.springSmooth, value: claimedCount)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, LTSpacing.horizontal)
            .opacity(headerVisible ? 1 : 0)
            .offset(y: headerVisible ? 0 : 8)

            HStack(spacing: LTSpacing.sm) {
                LTStatPill(icon: "checkmark.circle.fill", text: "\(claimedCount) klara", tint: .green)
                LTStatPill(icon: "gift.fill", text: "\(readyCount) att hämta", tint: LTPalette.gold)
            }
            .padding(.top, LTSpacing.xs)

            LTInfoCallout(
                title: "Uppdragssystem",
                message: "Filtrera per kategori och hämta belöningar direkt när ett uppdrag är redo. Redo-uppdrag sorteras överst.",
                icon: "list.bullet.clipboard.fill",
                tint: .cyan
            )
            .padding(.horizontal, LTSpacing.horizontal)
            .padding(.top, LTSpacing.xs)
        }
        .padding(.bottom, LTSpacing.md)
    }

    // MARK: - Kategorifilter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LTSpacing.sm) {
                FilterChip(label: "Alla", isSelected: selectedCategory == nil) {
                    withAnimation(LTAnimation.springFast) { selectedCategory = nil }
                }
                ForEach([MissionCategory.survival, .wealth, .zone, .casino, .work, .social], id: \.self) { cat in
                    FilterChip(label: cat.rawValue, isSelected: selectedCategory == cat) {
                        withAnimation(LTAnimation.springFast) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, LTSpacing.horizontal)
        }
        .padding(.bottom, LTSpacing.md)
    }

    // MARK: - Uppdragslista

    private var missionsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: LTSpacing.sm) {
                ForEach(filteredMissions) { mission in
                    MissionCard(mission: mission) {
                        missionsManager.claimMission(mission)
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                }

                if filteredMissions.isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, LTSpacing.horizontal)
            .padding(.bottom, LTSpacing.scrollBottom)
        }
        .animation(LTAnimation.springFast, value: selectedCategory)
    }

    private var emptyState: some View {
        LTEmptyStateCard(
            icon: "checkmark.seal.fill",
            title: "Inga uppdrag i vald kategori",
            message: "Byt filter eller fortsätt spela så låses fler uppdrag upp.",
            tint: .white
        )
        .padding(.top, 36)
    }
}

// MARK: - FilterChip (omdesignad)

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            Text(label)
                .font(LTFont.label(11))
                .foregroundColor(isSelected ? .black : .white.opacity(0.65))
                .padding(.horizontal, LTSpacing.md)
                .padding(.vertical, LTSpacing.sm - 2)
                .background(isSelected ? LTPalette.neonGreen : Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? LTPalette.neonGreen.opacity(0.5) : Color.white.opacity(0.10),
                            lineWidth: 1
                        )
                )
                .shadow(color: isSelected ? LTPalette.neonGreen.opacity(0.35) : .clear, radius: 6)
        }
        .buttonStyle(LTPressEffect(scale: 0.94))
        .animation(LTAnimation.springFast, value: isSelected)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - MissionCard (premium omdesign)

struct MissionCard: View {
    let mission: Mission
    let onClaim: () -> Void

    private var accentColor: Color {
        if mission.isClaimed     { return .white.opacity(0.25) }
        if mission.isReady       { return LTPalette.gold }
        switch mission.category {
        case .survival: return .red
        case .wealth:   return LTPalette.neonGreenDim
        case .zone:     return .cyan
        case .casino:   return .purple
        case .work:     return .orange
        case .social:   return .blue
        }
    }

    @State private var claimScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: LTSpacing.md) {
            // Icon container med progress-ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 2)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: mission.progressFraction)
                    .stroke(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 48, height: 48)
                    .animation(LTAnimation.springSmooth, value: mission.progressFraction)
                Image(systemName: mission.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(mission.isClaimed ? accentColor.opacity(0.4) : accentColor)
                    .shadow(color: accentColor.opacity(mission.isClaimed ? 0 : 0.6), radius: 5)
            }

            // Content
            VStack(alignment: .leading, spacing: LTSpacing.xs) {
                HStack(spacing: LTSpacing.xs) {
                    Text(mission.title)
                        .font(LTFont.heading(13))
                        .foregroundColor(mission.isClaimed ? .white.opacity(0.35) : .white)
                        .strikethrough(mission.isClaimed, color: .white.opacity(0.2))
                    Spacer(minLength: 0)
                    Text("+\(TimeEngine.shortFormatted(mission.rewardSeconds))")
                        .font(LTFont.label(10))
                        .foregroundColor(mission.isClaimed ? .white.opacity(0.2) : accentColor)
                }

                Text(mission.description)
                    .font(LTFont.body(10))
                    .foregroundColor(.white.opacity(mission.isClaimed ? 0.20 : 0.42))
                    .lineLimit(1)

                // Progress bar (vertikal layout med label)
                HStack(spacing: LTSpacing.sm) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * mission.progressFraction, height: 4)
                                .shadow(color: accentColor.opacity(0.5), radius: 3)
                                .animation(LTAnimation.springSmooth, value: mission.progressFraction)
                        }
                    }
                    .frame(height: 4)

                    Text("\(Int(mission.progressFraction * 100))%")
                        .font(LTFont.caption(9))
                        .foregroundColor(.white.opacity(0.30))
                        .frame(width: 28, alignment: .trailing)
                }
            }

            // Claim / done indicator
            Group {
                if mission.isReady && !mission.isClaimed {
                    Button(action: {
                        let notif = UINotificationFeedbackGenerator()
                        notif.notificationOccurred(.success)
                        withAnimation(LTAnimation.springFast) { claimScale = 0.92 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            withAnimation(LTAnimation.springFast) { claimScale = 1.0 }
                            onClaim()
                        }
                    }) {
                        Text("HÄMTA")
                            .font(LTFont.caption(10))
                            .foregroundColor(.black)
                            .padding(.horizontal, LTSpacing.sm + 2)
                            .padding(.vertical, LTSpacing.sm)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
                            .shadow(color: accentColor.opacity(0.4), radius: 6)
                            .scaleEffect(claimScale)
                    }
                    .accessibilityLabel("Hämta belöning: \(mission.title)")
                } else if mission.isClaimed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.18))
                        .accessibilityLabel("Avklarad")
                }
            }
            .frame(width: 58, alignment: .trailing)
        }
        .padding(LTSpacing.md)
        .background(
            ZStack {
                Color.white.opacity(mission.isClaimed ? 0.02 : 0.055)
                if mission.isReady && !mission.isClaimed {
                    LinearGradient(
                        colors: [accentColor.opacity(0.10), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: LTRadius.sm)
                .stroke(
                    mission.isReady && !mission.isClaimed
                        ? accentColor.opacity(0.45)
                        : Color.white.opacity(0.06),
                    lineWidth: 1
                )
        )
        .shadow(
            color: (mission.isReady && !mission.isClaimed) ? accentColor.opacity(0.15) : .clear,
            radius: 10, x: 0, y: 3
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mission.title), \(mission.description), \(Int(mission.progressFraction * 100)) procent klar")
    }
}

#Preview {
    MissionsView()
        .preferredColorScheme(.dark)
}
