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
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        NotificationManager.shared.requestPermission()
        _ = TimeEngine.shared  // Boot the engine immediately
        _ = GameState.shared
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        TimeEngine.shared.saveToKeychainPublic()
    }
}
