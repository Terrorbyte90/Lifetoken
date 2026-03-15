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

        // Sync balance with server on launch
        let balance = TimeEngine.shared.balance
        Task {
            await ServerSync.shared.syncBalance(balance)
            await ServerSync.shared.fetchZoneMembers()
        }

        return true
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
