import Foundation
import SwiftUI

public class ZoneManager: ObservableObject {
    static let shared = ZoneManager()
    private let lastZoneKey = "lastKnownZoneName"

    @Published var currentZone: ZoneProfile = .askan

    private init() {
        // One-time reset: all users start in Askan (first zone)
        let startKey = "zone_start_v1"
        if !UserDefaults.standard.bool(forKey: startKey) {
            UserDefaults.standard.set(true, forKey: startKey)
            UserDefaults.standard.removeObject(forKey: lastZoneKey)
        }
        // Restore last known zone from UserDefaults; default to Askan
        if let saved = UserDefaults.standard.string(forKey: lastZoneKey),
           let zone = ZoneProfile.allZones.first(where: { $0.name == saved }) {
            currentZone = zone
        } else {
            currentZone = .askan
            UserDefaults.standard.set(ZoneProfile.askan.name, forKey: lastZoneKey)
        }
    }

    func currentZoneProfile(forTime seconds: TimeInterval) -> ZoneProfile {
        return ZoneProfile.currentZone(forTime: seconds)
    }

    /// Called periodically to check if zone should change.
    /// Uses fallThresholdSeconds for downgrade (hysteresis) and unlockRequirementSeconds for upgrade.
    func evaluateZoneChange(currentTime: TimeInterval) {
        let current = currentZone

        // Check if we've fallen BELOW the current zone's fallThreshold → downgrade
        if currentTime < current.fallThresholdSeconds && current.index > 0 {
            // Find the highest zone whose fallThreshold we still meet
            let fallZone = ZoneProfile.allZones.reversed().first {
                currentTime >= $0.fallThresholdSeconds
            } ?? .askan
            if fallZone.index < current.index {
                DispatchQueue.main.async {
                    self.currentZone = fallZone
                    UserDefaults.standard.set(fallZone.name, forKey: self.lastZoneKey)
                }
            }
        }
    }

    /// Attempt to manually migrate to a target zone — costs entryCostSeconds.
    /// The player stays in the new zone until balance drops below fallThresholdSeconds.
    func migrateToZone(_ zone: ZoneProfile) -> (success: Bool, message: String) {
        let balance = TimeEngine.shared.balance

        // For free zones (Grundskiftet), just migrate
        if zone.entryCostSeconds == 0 {
            DispatchQueue.main.async {
                self.currentZone = zone
                UserDefaults.standard.set(zone.name, forKey: self.lastZoneKey)
            }
            return (true, "Välkommen till \(zone.name)!")
        }

        // Must be able to afford entry cost
        guard balance >= zone.entryCostSeconds else {
            let needed = TimeEngine.shortFormatted(zone.entryCostSeconds)
            return (false, "Otillräcklig tid. Inträde kostar \(needed).")
        }

        // After paying entry, ensure balance stays above fallThreshold
        // so player doesn't immediately fall back down
        let afterCost = balance - zone.entryCostSeconds
        if zone.fallThresholdSeconds > 0 && afterCost < zone.fallThresholdSeconds {
            let totalNeeded = TimeEngine.shortFormatted(zone.entryCostSeconds + zone.fallThresholdSeconds)
            return (false, "Du behöver totalt \(totalNeeded) för att klara inträdet och inte falla tillbaka direkt.")
        }

        let success = TimeEngine.shared.deductTime(zone.entryCostSeconds)
        if success {
            DispatchQueue.main.async {
                self.currentZone = zone
                UserDefaults.standard.set(zone.name, forKey: self.lastZoneKey)
                self.triggerZoneMissionProgress(for: zone)
            }
            return (true, "Välkommen till \(zone.name)! Kostnad: \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
        }
        return (false, "Migrationen misslyckades. Försök igen.")
    }

    private func triggerZoneMissionProgress(for zone: ZoneProfile) {
        switch zone.index {
        case 5: MissionsManager.incrementProgress("zone_midgrey_reached")
        case 7: MissionsManager.incrementProgress("zone_aetherpoint_reached")
        case 8: MissionsManager.incrementProgress("zone_novalux_reached")
        default: break
        }
    }
}
