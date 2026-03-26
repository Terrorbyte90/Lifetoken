import SwiftUI
import HealthKit

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

        // Request notification permission
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
