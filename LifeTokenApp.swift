import SwiftUI
import HealthKit
import UserNotifications

@main
struct LifeTokenApp: App {
    let persistenceController = PersistenceController.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(ZoneManager.shared)
                .environmentObject(ThemeEngine.shared)
                .preferredColorScheme(.dark)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Boot core singletons
        _ = TimeEngine.shared
        _ = GameState.shared
        _ = InflationManager.shared
        _ = MarketManager.shared
        _ = ChallengeManager.shared
        _ = AchievementManager.shared

        // Request notification permission
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestPermission()

        // Request HealthKit authorization on every launch
        HealthKitManager.shared.requestAuthorization { granted in
            if granted {
                IncomeManager.shared.loadAndRefresh()
            }
        }

        // Startup: auto-login with stored username if no token, then sync
        Task {
            await ServerSync.shared.startup()           // handles auto-login
            let balance = await MainActor.run { TimeEngine.shared.balance }
            await ServerSync.shared.syncBalance(balance)
            await ServerSync.shared.fetchZoneMembers()
            await ServerSync.shared.fetchLeaderboard()
        }

        // Check midnight health-income award (catches missed midnight if app was closed)
        IncomeManager.shared.checkAndAwardDailyHealthIncome()

        // Adaptive engine boot: rescue notification + session tracking
        Task { @MainActor in
            AdaptiveEngine.shared.scheduleRescueNotificationIfNeeded()
            BehaviorTracker.shared.recordSession(
                hourOfDay: Calendar.current.component(.hour, from: Date()),
                durationSeconds: 0,
                primaryActivity: "launch"
            )
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Refresh health data and re-check award when returning from background
        IncomeManager.shared.loadAndRefresh()
        IncomeManager.shared.checkAndAwardDailyHealthIncome()
        Task {
            await ServerSync.shared.checkHealth()
            await ServerSync.shared.fetchServerBalance()
            let balance = await MainActor.run { TimeEngine.shared.balance }
            await ServerSync.shared.syncBalance(balance)
            await ServerSync.shared.fetchZoneMembers()
            await ServerSync.shared.refreshAdminStatus()
            await ServerSync.shared.startRealtimeUpdates()
            await ServerSync.shared.flushDeferredRequests()
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        TimeEngine.shared.saveToKeychainPublic()
        Task {
            let balance = await MainActor.run { TimeEngine.shared.balance }
            await ServerSync.shared.syncBalance(balance)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        TimeEngine.shared.saveToKeychainPublic()
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case NotificationManager.actionOpenStepDuel:
            UserDefaults.standard.set(4, forKey: "selectedTab")
            NotificationCenter.default.post(name: .openStepDuelFromNotification, object: nil)
        case NotificationManager.actionOpenRaid:
            UserDefaults.standard.set(4, forKey: "selectedTab")
            NotificationCenter.default.post(name: .openRaidFromNotification, object: nil)
        case NotificationManager.actionOpenWork:
            UserDefaults.standard.set(1, forKey: "selectedTab")
        case NotificationManager.actionOpenHealth:
            UserDefaults.standard.set(0, forKey: "selectedTab")
        default:
            break
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let openStepDuelFromNotification = Notification.Name("lt.open.stepduel")
    static let openRaidFromNotification = Notification.Name("lt.open.raid")
}
