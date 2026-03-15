import Foundation
import SwiftUI

public class ZoneManager: ObservableObject {
    static let shared = ZoneManager()
    private let lastZoneKey = "lastKnownZoneName"

    @Published var currentZone: ZoneProfile = .grundskiftet

    private init() {
        // Restore last known zone from UserDefaults (preserves hysteresis)
        if let saved = UserDefaults.standard.string(forKey: lastZoneKey),
           let zone = ZoneProfile.allZones.first(where: { $0.name == saved }) {
            currentZone = zone
        } else {
            currentZone = ZoneProfile.currentZone(forTime: TimeEngine.shared.balance)
            UserDefaults.standard.set(currentZone.name, forKey: lastZoneKey)
        }
    }

    func currentZoneProfile(forTime seconds: TimeInterval) -> ZoneProfile {
        return ZoneProfile.currentZone(forTime: seconds)
    }

    /// Called periodically to check if zone should change.
    /// Uses fallThresholdSeconds for downgrade (hysteresis) and unlockRequirementSeconds for upgrade.
    func evaluateZoneChange(currentTime: TimeInterval) {
        let current = currentZone

        // Check if we qualify for a HIGHER zone automatically
        let naturalZone = ZoneProfile.currentZone(forTime: currentTime)
        if naturalZone.index > current.index {
            DispatchQueue.main.async {
                self.currentZone = naturalZone
                UserDefaults.standard.set(naturalZone.name, forKey: self.lastZoneKey)
            }
            return
        }

        // Check if we've fallen BELOW the current zone's fallThreshold → downgrade
        if currentTime < current.fallThresholdSeconds && current.index > 0 {
            // Find the highest zone whose fallThreshold we still meet
            let fallZone = ZoneProfile.allZones.reversed().first {
                currentTime >= $0.fallThresholdSeconds
            } ?? .grundskiftet
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

        // Must meet unlock requirement
        guard balance >= zone.unlockRequirementSeconds else {
            let needed = TimeEngine.shortFormatted(zone.unlockRequirementSeconds)
            return (false, "Kräver \(needed) för att låsa upp \(zone.name). Fortsätt tjäna tid.")
        }

        // Must be able to afford entry cost
        guard balance >= zone.entryCostSeconds else {
            let needed = TimeEngine.shortFormatted(zone.entryCostSeconds)
            return (false, "Otillräcklig tid. Inträde kostar \(needed).")
        }

        // After paying entry, ensure balance >= fallThreshold so player doesn't immediately fall back
        let afterCost = balance - zone.entryCostSeconds
        if afterCost < zone.fallThresholdSeconds {
            let buffer = TimeEngine.shortFormatted(zone.entryCostSeconds + zone.fallThresholdSeconds)
            return (false, "Du behöver totalt \(buffer) (inträde + säkerhetsbuffert) för att inte falla tillbaka direkt.")
        }

        let success = TimeEngine.shared.deductTime(zone.entryCostSeconds)
        if success {
            DispatchQueue.main.async {
                self.currentZone = zone
                UserDefaults.standard.set(zone.name, forKey: self.lastZoneKey)
            }
            return (true, "Välkommen till \(zone.name)! Kostnad: \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
        }
        return (false, "Migrationen misslyckades. Försök igen.")
    }
}
