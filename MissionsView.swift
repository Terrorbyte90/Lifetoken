import SwiftUI
import Foundation

// MARK: - Mission Types

enum MissionCategory: String, Codable, CaseIterable {
    case survival = "Överlevnad"
    case wealth   = "Rikedom"
    case zone     = "Zon"
    case casino   = "Kasino"
    case work     = "Arbete"
    case social   = "Social"

    var icon: String {
        switch self {
        case .survival: return "heart.fill"
        case .wealth:   return "banknote.fill"
        case .zone:     return "map.fill"
        case .casino:   return "suit.spade.fill"
        case .work:     return "hammer.fill"
        case .social:   return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .survival: return .red
        case .wealth:   return .yellow
        case .zone:     return .cyan
        case .casino:   return .purple
        case .work:     return .green
        case .social:   return .orange
        }
    }
}

struct Mission: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let category: MissionCategory
    let icon: String
    let rewardSeconds: TimeInterval
    let targetValue: Double        // what to achieve
    let progressKey: String        // UserDefaults key tracking progress
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

    // Static mission definitions
    private let allMissions: [Mission] = [
        // Survival
        Mission(id: "survive_1d",   title: "Överlev en dag",     description: "Ha mer an 0 sekunder efter 24h.",
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
        Mission(id: "reach_midgrey",  title: "Nå Midgrey",       description: "Lås upp Midgrey-zonen.",
                category: .zone,    icon: "arrow.up.circle",     rewardSeconds: 14400,
                targetValue: 1,     progressKey: "zone_midgrey_reached", isCompleted: false, isClaimed: false),
        Mission(id: "reach_aether",   title: "Nå Aetherpoint",   description: "Lås upp Aetherpoint-zonen.",
                category: .zone,    icon: "building.2.fill",     rewardSeconds: 86400,
                targetValue: 1,     progressKey: "zone_aetherpoint_reached", isCompleted: false, isClaimed: false),
        Mission(id: "reach_novalux",  title: "Nå Novalux",       description: "Lås upp Novalux-zonen.",
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
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            MissionsManager.incrementProgress("total_uptime_seconds", by: 60)
            MissionsManager.shared.loadMissions()
        }
    }
}

// MARK: - Missions View

struct MissionsView: View {
    @ObservedObject private var missionsManager = MissionsManager.shared
    @State private var selectedCategory: MissionCategory? = nil

    var filteredMissions: [Mission] {
        if let cat = selectedCategory {
            return missionsManager.missions.filter { $0.category == cat }
        }
        return missionsManager.missions
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("UPPDRAG")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Slutför mål. Tjäna tid.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(.top, 60)
                .padding(.bottom, 16)

                // Category filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "Alla", icon: "square.grid.2x2.fill", color: .white, isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(MissionCategory.allCases, id: \.self) { cat in
                            FilterChip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: selectedCategory == cat) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = selectedCategory == cat ? nil : cat
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filteredMissions) { mission in
                            MissionCard(mission: mission) {
                                missionsManager.claimMission(mission)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }
        }
        .alert("Uppdrag Klart!", isPresented: $missionsManager.showRewardAlert) {
            Button("OK") {}
        } message: { Text(missionsManager.rewardMessage) }
        .onAppear { missionsManager.loadMissions() }
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.75))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? color : Color.white.opacity(0.08))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? color : Color.clear, lineWidth: 1))
        }
    }
}

struct MissionCard: View {
    let mission: Mission
    let onClaim: () -> Void

    private var catColor: Color { mission.category.color }

    var body: some View {
        HStack(spacing: 14) {
            // Ikon med kategori-färg
            ZStack {
                Circle()
                    .fill(mission.isClaimed ? Color.white.opacity(0.04) :
                          (mission.isReady ? Color.yellow.opacity(0.15) : catColor.opacity(0.12)))
                    .frame(width: 44, height: 44)
                Image(systemName: mission.icon)
                    .font(.system(size: 18))
                    .foregroundColor(mission.isClaimed ? .gray.opacity(0.4) :
                                     (mission.isReady ? .yellow : catColor))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.title)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(mission.isClaimed ? .gray.opacity(0.5) : .white)
                        Text(mission.description)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(2)
                    }
                    Spacer()
                    Text("+\(TimeEngine.shortFormatted(mission.rewardSeconds))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(mission.isClaimed ? .gray.opacity(0.4) : .yellow)
                }

                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                            Capsule()
                                .fill(mission.isReady ? Color.yellow : catColor.opacity(0.8))
                                .frame(width: geo.size.width * mission.progressFraction, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(Int(mission.progressFraction * 100))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(width: 32, alignment: .trailing)
                }
            }

            if mission.isReady {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onClaim()
                }) {
                    Text("HÄMTA")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } else if mission.isClaimed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .padding(14)
        .background(mission.isClaimed ? Color.white.opacity(0.02) :
                    (mission.isReady ? Color.yellow.opacity(0.04) : Color.white.opacity(0.05)))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    mission.isReady ? Color.yellow.opacity(0.5) :
                    (mission.isClaimed ? Color.clear : catColor.opacity(0.12)),
                    lineWidth: 1
                )
        )
    }
}
