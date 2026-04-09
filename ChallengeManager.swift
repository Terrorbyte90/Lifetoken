import Foundation
import SwiftUI

// MARK: - Challenge Model

struct DailyChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let targetValue: Int
    let currentValue: Int
    let rewardSeconds: TimeInterval
    let category: ChallengeCategory
    let isCompleted: Bool
    let expiresAt: Date

    enum ChallengeCategory: String, Codable {
        case health
        case work
        case casino
        case social
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(Double(currentValue) / Double(targetValue), 1.0)
    }
}

// MARK: - Challenge Manager

class ChallengeManager: ObservableObject {
    static let shared = ChallengeManager()

    @Published var todayChallenge: DailyChallenge?
    @Published var completedChallenges: [DailyChallenge] = []

    private let challengeKey = "daily_challenge"
    private let completedKey = "completed_challenges"

    private init() {
        loadOrGenerateChallenge()
    }

    // MARK: - Public Methods

    func loadOrGenerateChallenge() {
        let today = Calendar.current.startOfDay(for: Date())
        let storedDate = UserDefaults.standard.object(forKey: "challenge_date") as? Date

        if let stored = storedDate, Calendar.current.isDate(stored, inSameDayAs: today) {
            // Load existing challenge for today
            if let data = UserDefaults.standard.data(forKey: challengeKey),
               let challenge = try? JSONDecoder().decode(DailyChallenge.self, from: data) {
                todayChallenge = challenge
            }
        } else {
            // Generate new challenge for today
            generateDailyChallenge()
        }

        loadCompletedChallenges()
    }

    func updateProgress(for category: DailyChallenge.ChallengeCategory, amount: Int) {
        guard var challenge = todayChallenge,
              challenge.category == category,
              !challenge.isCompleted else { return }

        let newValue = challenge.currentValue + amount
        let isCompleted = newValue >= challenge.targetValue

        var updatedChallenge = DailyChallenge(
            id: challenge.id,
            title: challenge.title,
            description: challenge.description,
            targetValue: challenge.targetValue,
            currentValue: newValue,
            rewardSeconds: challenge.rewardSeconds,
            category: challenge.category,
            isCompleted: isCompleted,
            expiresAt: challenge.expiresAt
        )

        todayChallenge = updatedChallenge
        saveChallenge(updatedChallenge)

        if isCompleted {
            completeChallenge(updatedChallenge)
        }
    }

    func claimReward() {
        guard let challenge = todayChallenge, challenge.isCompleted else { return }

        TimeEngine.shared.addTime(challenge.rewardSeconds)
        GameState.shared.recordEarning(challenge.rewardSeconds)

        // Reset with new challenge
        generateDailyChallenge()
    }

    // MARK: - Private Methods

    private func generateDailyChallenge() {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())

        let challenge: DailyChallenge

        switch weekday {
        case 2: // Monday - Steps
            challenge = DailyChallenge(
                id: UUID().uuidString,
                title: "Måndagsmotion",
                description: "Gå 10,000 steg idag",
                targetValue: 10000,
                currentValue: 0,
                rewardSeconds: 3600, // 1 hour
                category: .health,
                isCompleted: false,
                expiresAt: calendar.startOfDay(for: Date().addingTimeInterval(86400))
            )
        case 3: // Tuesday - Work
            challenge = DailyChallenge(
                id: UUID().uuidString,
                title: "Tisdagsarbete",
                description: "Arbeta i 2 timmar",
                targetValue: 7200,
                currentValue: 0,
                rewardSeconds: 7200, // 2 hours
                category: .work,
                isCompleted: false,
                expiresAt: calendar.startOfDay(for: Date().addingTimeInterval(86400))
            )
        case 4: // Wednesday - Steps
            challenge = DailyChallenge(
                id: UUID().uuidString,
                title: "Onsdagsvandring",
                description: "Gå 15,000 steg idag",
                targetValue: 15000,
                currentValue: 0,
                rewardSeconds: 5400, // 1.5 hours
                category: .health,
                isCompleted: false,
                expiresAt: calendar.startOfDay(for: Date().addingTimeInterval(86400))
            )
        case 5: // Thursday - Casino
            challenge = DailyChallenge(
                id: UUID().uuidString,
                title: "Torsdagslycka",
                description: "Vinn 3 kasinospel",
                targetValue: 3,
                currentValue: 0,
                rewardSeconds: 10800, // 3 hours
                category: .casino,
                isCompleted: false,
                expiresAt: calendar.startOfDay(for: Date().addingTimeInterval(86400))
            )
        case 6: // Friday - Work
            challenge = DailyChallenge(
                id: UUID().uuidString,
                title: "Fredagsarbete",
                description: "Arbeta i 3 timmar",
                targetValue: 10800,
                currentValue: 0,
                rewardSeconds: 10800, // 3 hours
                category: .work,
                isCompleted: false,
                expiresAt: calendar.startOfDay(for: Date().addingTimeInterval(86400))
            )
        case 7: // Saturday - Health
            challenge = DailyChallenge(
                id: UUID().uuidString,
                title: "Lördagsmotion",
                description: "Bränn 500 kalorier",
                targetValue: 500,
                currentValue: 0,
                rewardSeconds: 7200, // 2 hours
                category: .health,
                isCompleted: false,
                expiresAt: calendar.startOfDay(for: Date().addingTimeInterval(86400))
            )
        default: // Sunday - Social
            challenge = DailyChallenge(
                id: UUID().uuidString,
                title: "Söndagssocial",
                description: "Skicka 5 chattmeddelanden i din zon",
                targetValue: 5,
                currentValue: 0,
                rewardSeconds: 1800, // 30 minutes
                category: .social,
                isCompleted: false,
                expiresAt: calendar.startOfDay(for: Date().addingTimeInterval(86400))
            )
        }

        todayChallenge = challenge
        saveChallenge(challenge)
        UserDefaults.standard.set(Date(), forKey: "challenge_date")
    }

    private func saveChallenge(_ challenge: DailyChallenge) {
        if let data = try? JSONEncoder().encode(challenge) {
            UserDefaults.standard.set(data, forKey: challengeKey)
        }
    }

    private func loadCompletedChallenges() {
        if let data = UserDefaults.standard.data(forKey: completedKey),
           let challenges = try? JSONDecoder().decode([DailyChallenge].self, from: data) {
            completedChallenges = challenges
        }
    }

    private func completeChallenge(_ challenge: DailyChallenge) {
        completedChallenges.append(challenge)

        // Keep only last 30 completed challenges
        if completedChallenges.count > 30 {
            completedChallenges = Array(completedChallenges.suffix(30))
        }

        if let data = try? JSONEncoder().encode(completedChallenges) {
            UserDefaults.standard.set(data, forKey: completedKey)
        }
    }
}
