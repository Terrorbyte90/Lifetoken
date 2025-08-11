//
//  LumiraApp.swift
//  Lumira
//
//  Created by Ted Svärd on 2025-06-12.
//

import SwiftUI

@main
struct LumiraApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
