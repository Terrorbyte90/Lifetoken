import SwiftUI

@main
struct LifeTokenApp: App {
    let persistenceController = PersistenceController.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(ZoneManager.shared)
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

        // Startup: auto-login with stored username if no token, then sync
        let balance = TimeEngine.shared.balance
        Task {
            await ServerSync.shared.startup()           // handles auto-login
            await ServerSync.shared.syncBalance(balance)
            await ServerSync.shared.fetchZoneMembers()
            await ServerSync.shared.fetchLeaderboard()
        }

        // Check midnight health-income award (catches missed midnight if app was closed)
        IncomeManager.shared.checkAndAwardDailyHealthIncome()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Re-check health award when returning from background (covers midnight scenarios)
        IncomeManager.shared.checkAndAwardDailyHealthIncome()
        let balance = TimeEngine.shared.balance
        Task {
            await ServerSync.shared.checkHealth()
            await ServerSync.shared.syncBalance(balance)
            await ServerSync.shared.fetchZoneMembers()
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        TimeEngine.shared.saveToKeychainPublic()
        let balance = TimeEngine.shared.balance
        Task { await ServerSync.shared.syncBalance(balance) }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        TimeEngine.shared.saveToKeychainPublic()
    }
}
