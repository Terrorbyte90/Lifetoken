import Foundation
import SwiftUI

// MARK: - Achievement Model

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let rewardSeconds: TimeInterval
    var isUnlocked: Bool
    var unlockedAt: Date?

    enum AchievementCategory: String, Codable {
        case health
        case work
        case casino
        case social
        case survival
        case special
    }
}

// MARK: - Achievement Manager

class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    @Published var achievements: [Achievement] = []
    @Published var totalUnlocked: Int = 0
    @Published var totalEarned: TimeInterval = 0

    private let achievementsKey = "achievements_v1"

    private init() {
        initializeAchievements()
        loadProgress()
    }

    // MARK: - Public Methods

    func unlockAchievement(id: String) {
        guard let index = achievements.firstIndex(where: { $0.id == id }) else { return }
        guard !achievements[index].isUnlocked else { return }

        achievements[index].isUnlocked = true
        achievements[index].unlockedAt = Date()

        totalUnlocked += 1
        totalEarned += achievements[index].rewardSeconds

        // Award time reward
        TimeEngine.shared.addTime(achievements[index].rewardSeconds)
        GameState.shared.recordEarning(achievements[index].rewardSeconds)

        saveProgress()
    }

    func checkAndUnlock(achievementId: String) {
        unlockAchievement(id: achievementId)
    }

    // MARK: - Private Methods

    private func initializeAchievements() {
        achievements = [
            // Health achievements
            Achievement(
                id: "first_steps",
                title: "Första stegen",
                description: "Gå 1,000 steg totalt",
                icon: "figure.walk",
                category: .health,
                rewardSeconds: 1800, // 30 min
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "step_master",
                title: "Stegmästare",
                description: "Gå 100,000 steg totalt",
                icon: "figure.walk.motion",
                category: .health,
                rewardSeconds: 36000, // 10 hours
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "marathon",
                title: "Maraton",
                description: "Gå 42,195 steg på en dag",
                icon: "flame.fill",
                category: .health,
                rewardSeconds: 14400, // 4 hours
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "early_bird",
                title: "Fågeln",
                description: "Stiga upp före kl. 06:00",
                icon: "sun.horizon.fill",
                category: .health,
                rewardSeconds: 3600, // 1 hour
                isUnlocked: false,
                unlockedAt: nil
            ),

            // Work achievements
            Achievement(
                id: "first_work",
                title: "Första arbetsdagen",
                description: "Arbeta för första gången",
                icon: "briefcase.fill",
                category: .work,
                rewardSeconds: 1800, // 30 min
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "hard_worker",
                title: "Arbetare",
                description: "Arbeta i totalt 100 timmar",
                icon: "hammer.fill",
                category: .work,
                rewardSeconds: 86400, // 24 hours
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "work_ethic",
                title: "Arbetsmoral",
                description: "Arbeta 7 dagar i rad",
                icon: "calendar.badge.clock",
                category: .work,
                rewardSeconds: 43200, // 12 hours
                isUnlocked: false,
                unlockedAt: nil
            ),

            // Casino achievements
            Achievement(
                id: "first_win",
                title: "Första vinsten",
                description: "Vinn ett kasinospel",
                icon: "dice.fill",
                category: .casino,
                rewardSeconds: 1800, // 30 min
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "lucky_streak",
                title: "Tur i kast",
                description: "Vinn 5 kasinospel i rad",
                icon: "clover.fill",
                category: .casino,
                rewardSeconds: 7200, // 2 hours
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "high_roller",
                title: "High Roller",
                description: "Vinn 10 timmar på kasinot",
                icon: "dollarsign.circle.fill",
                category: .casino,
                rewardSeconds: 36000, // 10 hours
                isUnlocked: false,
                unlockedAt: nil
            ),

            // Social achievements
            Achievement(
                id: "social_butterfly",
                title: "Social fjäril",
                description: "Skicka 50 chattmeddelanden",
                icon: "bubble.left.and.bubble.right.fill",
                category: .social,
                rewardSeconds: 3600, // 1 hour
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "zone_champion",
                title: "Zonmästare",
                description: "Var aktiv i din zon i 30 dagar",
                icon: "map.fill",
                category: .social,
                rewardSeconds: 86400, // 24 hours
                isUnlocked: false,
                unlockedAt: nil
            ),

            // Survival achievements
            Achievement(
                id: "survivor_week",
                title: "Överlevare",
                description: "Överlev 7 dagar",
                icon: "heart.fill",
                category: .survival,
                rewardSeconds: 43200, // 12 hours
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "survivor_month",
                title: "Månadens överlevare",
                description: "Överlev 30 dagar",
                icon: "star.fill",
                category: .survival,
                rewardSeconds: 172800, // 48 hours
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "century_club",
                title: "Århundradet",
                description: "Överlev 100 dagar",
                icon: "crown.fill",
                category: .survival,
                rewardSeconds: 604800, // 1 week
                isUnlocked: false,
                unlockedAt: nil
            ),

            // Special achievements
            Achievement(
                id: "streak_7",
                title: "Veckostreak",
                description: "Logga in 7 dagar i rad",
                icon: "flame.circle.fill",
                category: .special,
                rewardSeconds: 21600, // 6 hours
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "streak_30",
                title: "Månadsstreak",
                description: "Logga in 30 dagar i rad",
                icon: "flame.circle.fill",
                category: .special,
                rewardSeconds: 86400, // 24 hours
                isUnlocked: false,
                unlockedAt: nil
            ),
            Achievement(
                id: "millionaire",
                title: "Miljonär",
                description: "Ha 1,000,000 sekunder (278 timmar) i balans",
                icon: "banknote.fill",
                category: .special,
                rewardSeconds: 0, // Achievement only
                isUnlocked: false,
                unlockedAt: nil
            )
        ]
    }

    private func loadProgress() {
        if let data = UserDefaults.standard.data(forKey: achievementsKey),
           let saved = try? JSONDecoder().decode([Achievement].self, from: data) {
            // Merge saved progress with achievement definitions
            for (index, achievement) in achievements.enumerated() {
                if let savedAchievement = saved.first(where: { $0.id == achievement.id }) {
                    achievements[index].isUnlocked = savedAchievement.isUnlocked
                    achievements[index].unlockedAt = savedAchievement.unlockedAt
                }
            }
        }

        totalUnlocked = achievements.filter { $0.isUnlocked }.count
        totalEarned = achievements.filter { $0.isUnlocked }.reduce(0) { $0 + $1.rewardSeconds }
    }

    private func saveProgress() {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: achievementsKey)
        }
    }
}
