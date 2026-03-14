import Foundation
import SwiftUI

public class ZoneManager: ObservableObject {
    static let shared = ZoneManager()
    private let lastZoneKey = "lastKnownZoneName"

    private let zoneOrder: [String] = [
        "Duskline", "Midgrey", "Risefield", "Aetherpoint", "Novalux", "Vaultum", "Solara"
    ]

    @Published var currentZone: ZoneProfile = .duskline

    private init() {
        let savedName = UserDefaults.standard.string(forKey: lastZoneKey)
        if let name = savedName,
           let zone = ZoneProfile.allZones.first(where: { $0.name == name }) {
            currentZone = zone
        } else {
            currentZone = ZoneProfile.currentZone(forTime: TimeEngine.shared.balance)
        }
        InflationManager.shared.onZoneEntered(currentZone)
    }

    // MARK: - Zone Helpers

    var nextZone: ZoneProfile? {
        guard let idx = zoneOrder.firstIndex(of: currentZone.name),
              idx + 1 < zoneOrder.count,
              let zone = ZoneProfile.allZones.first(where: { $0.name == zoneOrder[idx + 1] })
        else { return nil }
        return zone
    }

    var currentZoneIndex: Int {
        zoneOrder.firstIndex(of: currentZone.name) ?? 0
    }

    func currentZoneProfile(forTime seconds: TimeInterval) -> ZoneProfile {
        return ZoneProfile.currentZone(forTime: seconds)
    }

    func evaluateZoneChange(currentTime: TimeInterval) {
        let newZone = ZoneProfile.currentZone(forTime: currentTime)
        if newZone.name != currentZone.name {
            UserDefaults.standard.set(newZone.name, forKey: lastZoneKey)
            DispatchQueue.main.async {
                self.currentZone = newZone
                InflationManager.shared.onZoneEntered(newZone)
            }
        }
    }

    // MARK: - Migration (zone-by-zone only)

    /// Attempt to migrate to the NEXT adjacent zone. Cannot skip zones.
    func migrateToNextZone() -> (success: Bool, message: String) {
        guard let target = nextZone else {
            return (false, "Du är redan i den högsta zonen, Solara.")
        }
        return migrateToZone(target)
    }

    func canMigrateToNext() -> Bool {
        guard let next = nextZone else { return false }
        let bal = TimeEngine.shared.balance
        return bal >= next.entryCostSeconds && bal >= next.unlockRequirementSeconds
    }

    func migrateToZone(_ zone: ZoneProfile) -> (success: Bool, message: String) {
        let balance = TimeEngine.shared.balance

        // Enforce adjacent-zone-only rule
        guard let currentIdx = zoneOrder.firstIndex(of: currentZone.name),
              let targetIdx  = zoneOrder.firstIndex(of: zone.name)
        else { return (false, "Okänd zon.") }

        guard targetIdx == currentIdx + 1 else {
            if targetIdx <= currentIdx {
                return (false, "Du kan inte flytta till en lägre zon.")
            }
            let nextName = zoneOrder[currentIdx + 1]
            return (false, "Du måste gå zon för zon. Nästa zon är \(nextName).")
        }

        // Balance check
        guard balance >= zone.entryCostSeconds else {
            let need = TimeEngine.shortFormatted(zone.entryCostSeconds - balance)
            return (false, "Du saknar \(need). Inträde kostar \(TimeEngine.shortFormatted(zone.entryCostSeconds)).")
        }

        guard balance >= zone.unlockRequirementSeconds else {
            return (false, "Du uppfyller inte minimikravet för \(zone.name).")
        }

        // Deduct entry cost
        guard TimeEngine.shared.deductTime(zone.entryCostSeconds) else {
            return (false, "Migrationen misslyckades — otillräcklig tid.")
        }

        // Update zone
        DispatchQueue.main.async {
            self.currentZone = zone
            UserDefaults.standard.set(zone.name, forKey: self.lastZoneKey)
            GameState.shared.currentZone = zone
            InflationManager.shared.onZoneEntered(zone)
        }

        return (true, "Välkommen till \(zone.name)! Kostnad: \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
    }
}
