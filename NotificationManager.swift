import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleTimeLowWarning(secondsRemaining: TimeInterval) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        let thresholds: [(TimeInterval, String)] = [
            (3600, "Kritiskt! Du har bara 1 timme kvar att leva."),
            (10800, "Varning: 3 timmar kvar. Börja arbeta!"),
            (86400, "24 timmar kvar. Öka inkomsten.")
        ]

        for (threshold, message) in thresholds {
            if secondsRemaining > threshold {
                let delay = secondsRemaining - threshold
                let content = UNMutableNotificationContent()
                content.title = "LIFETOKEN"
                content.body = message
                content.sound = .default
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(identifier: "warning_\(Int(threshold))", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
    }
}
