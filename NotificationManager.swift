import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
    }

    // MARK: - Time Low Warnings

    func scheduleTimeLowWarning(secondsRemaining: TimeInterval) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

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

    func sendRaidNotification(from attacker: String, amount: String, won: Bool) {
        let content = UNMutableNotificationContent()
        if won {
            content.title = "💥 Du blev rånad!"
            content.body = "\(attacker) rånade dig på \(amount). Skaffa skydd — migrera till en säkrare zon."
        } else {
            content.title = "🛡️ Rånförsök misslyckat"
            content.body = "\(attacker) försökte råna dig men misslyckades. Din tid är säker."
        }
        content.sound = .defaultCritical
        content.userInfo = ["type": "pvp_raid", "attacker": attacker]
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
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, secondsUntilMidnight), repeats: false)
        let req = UNNotificationRequest(identifier: "daily_payout", content: content, trigger: trigger)
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
