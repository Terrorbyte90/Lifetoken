//
//  Persistence.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//

import CoreData
import os.log

struct PersistenceController {
    static let shared = PersistenceController()
    private static let logger = Logger(subsystem: "com.lifetoken.app", category: "Persistence")

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            logger.error("Preview store save failed: \(nsError.localizedDescription, privacy: .public)")
            viewContext.rollback()
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "LifeToken")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                Self.logger.error("Persistent store failed (\(storeDescription.url?.absoluteString ?? "unknown", privacy: .public)): \(error.localizedDescription, privacy: .public)")
                // Keep app alive instead of hard-crashing in production.
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
