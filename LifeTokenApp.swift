//
//  LifeTokenApp.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//

import SwiftUI

@main
struct LifeTokenApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
