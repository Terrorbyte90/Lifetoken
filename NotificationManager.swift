import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    static let actionOpenStepDuel = "lt_action_open_step_duel"
    static let actionOpenRaid = "lt_action_open_raid"
    static let actionOpenWork = "lt_action_open_work"
    static let actionOpenHealth = "lt_action_open_health"

    private init() {}

    func requestPermission() {
        registerCategories()
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
    }

    private func registerCategories() {
        let stepOpen = UNNotificationAction(
            identifier: Self.actionOpenStepDuel,
            title: "Öppna Stegduell",
            options: [.foreground]
        )
        let raidOpen = UNNotificationAction(
            identifier: Self.actionOpenRaid,
            title: "Öppna Rån",
            options: [.foreground]
        )
        let workOpen = UNNotificationAction(
            identifier: Self.actionOpenWork,
            title: "Öppna Arbete",
            options: [.foreground]
        )
        let healthOpen = UNNotificationAction(
            identifier: Self.actionOpenHealth,
            title: "Se Hälsoinkomst",
            options: [.foreground]
        )

        let stepCategory = UNNotificationCategory(
            identifier: "lt_step_duel",
            actions: [stepOpen],
            intentIdentifiers: [],
            options: []
        )
        let raidCategory = UNNotificationCategory(
            identifier: "lt_raid",
            actions: [raidOpen],
            intentIdentifiers: [],
            options: []
        )
        let payoutCategory = UNNotificationCategory(
            identifier: "lt_daily_payout",
            actions: [healthOpen, workOpen],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([stepCategory, raidCategory, payoutCategory])
    }

    // MARK: - Time Low Warnings

    func scheduleTimeLowWarning(secondsRemaining: TimeInterval) {
        let warningIDs = ["warning_3600", "warning_10800", "warning_86400"]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: warningIDs)

        let thresholds: [(TimeInterval, String, String)] = [
            (3600,  "⚠️ LIFETOKEN — Kritisk tidsnivå",
             "Bara 1 timme kvar. Gör något NU — arbeta, spela, tjäna tid."),
            (10800, "LIFETOKEN — Varning",
             "3 timmar kvar. Öka inkomsten innan det är för sent."),
            (86400, "LIFETOKEN — 24 timmar kvar",
             "Din klocka tickar. Börja arbeta eller köp mer tid.")
        ]

        for (threshold, title, body) in thresholds {
            guard secondsRemaining > threshold else { continue }
            let delay = secondsRemaining - threshold
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .defaultCritical
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            let req = UNNotificationRequest(identifier: "warning_\(Int(threshold))", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
        }
    }

    // MARK: - Yatzy Challenge Notification

    func sendYatzyChallenge(from challenger: String, stake: String) {
        let content = UNMutableNotificationContent()
        content.title = "🎲 Yatzy-utmaning!"
        content.body = "\(challenger) utmanar dig på Yatzy — insats: \(stake). Svara nu!"
        content.sound = .default
        content.userInfo = ["type": "yatzy_challenge", "challenger": challenger]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "yatzy_challenge_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - PvP Raid Notification

    func sendRaidNotification(target: String, amount: String, won: Bool, backfired: Bool = false) {
        let content = UNMutableNotificationContent()
        if won {
            content.title = "✅ Rån lyckades"
            content.body = "Du tog \(amount) från \(target)."
        } else if backfired {
            content.title = "☠️ Backfire"
            content.body = "\(target) vände rånet. Du förlorade mer än insatsen."
        } else {
            content.title = "🛡️ Rån misslyckades"
            content.body = "\(target) försvarade sig. Du förlorade insatsen."
        }
        content.sound = .defaultCritical
        content.userInfo = ["type": "pvp_raid", "target": target]
        content.categoryIdentifier = "lt_raid"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "raid_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Daily Payout Notification

    func scheduleDailyPayoutReminder(secondsUntilMidnight: TimeInterval) {
        let content = UNMutableNotificationContent()
        content.title = "💰 Hälsoinkomst utbetald!"
        content.body = "Din dagliga lön från hälsodata har betalats ut. Öppna appen för att se hur mycket du tjänat."
        content.sound = .default
        content.categoryIdentifier = "lt_daily_payout"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, secondsUntilMidnight), repeats: false)
        let req = UNNotificationRequest(identifier: "daily_payout", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Rescue Boost Notification

    func scheduleRescueNotification() {
        let content = UNMutableNotificationContent()
        content.title = "LIFETOKEN — Kritisk tidsnivå"
        content.body = "Du har under 2 timmar kvar. En Nöd-boost väntar på dig."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let request = UNNotificationRequest(identifier: "rescue_boost", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Step Duel Challenge Notification

    func sendStepDuelChallenge(from challenger: String, to opponent: String, stake: String, deadline: String) {
        let content = UNMutableNotificationContent()
        content.title = "👟 Stegduell-utmaning!"
        content.body = "\(challenger) utmanar \(opponent) — insats: \(stake), deadline: \(deadline). Acceptera nu!"
        content.sound = .default
        content.categoryIdentifier = "lt_step_duel"
        content.userInfo = ["type": "step_duel", "challenger": challenger]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "step_duel_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }

    // MARK: - Generic Game Alert

    func sendGameAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let req = UNNotificationRequest(identifier: "game_\(Date().timeIntervalSince1970)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
    }
}
