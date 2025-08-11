//
//  Eon_v2__Mac_App.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//

import SwiftUI

@main
struct Eon_v2__Mac_App: App {
    var body: some Scene {
        WindowGroup {
            EonDashboard(
                dialogueCore: DialogueCore(),
                memoryStream: MemoryStream(),
                streamManager: StreamManager(),
                selfNarrative: SelfNarrative(),
                identityManifest: IdentityManifest(),
                securityCore: SecurityCore(),
                evolutionLoop: EvolutionLoop()
            )
        }
    }
}
