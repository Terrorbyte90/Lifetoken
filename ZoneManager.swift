import Foundation
import SwiftUI

public class ZoneManager: ObservableObject {
    static let shared = ZoneManager()
    private let lastZoneKey = "lastKnownZoneName"

    @Published var currentZone: ZoneProfile = .askan
    @Published var availableUpgrade: ZoneProfile? = nil

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
        updateAvailableUpgrade(currentTime: currentTime)

        // Downgrade only after the hysteresis floor is crossed. This preserves
        // voluntary migration and avoids oscillating at the unlock boundary.
        if currentTime < current.fallThresholdSeconds && current.index > 0 {
            // Find the highest zone whose fallThreshold we still meet
            let fallZone = ZoneProfile.allZones.reversed().first {
                currentTime >= $0.fallThresholdSeconds
            } ?? .askan
            if fallZone.index < current.index {
                DispatchQueue.main.async {
                    self.applyZoneChange(to: fallZone, trackProgress: false)
                }
            }
        }
    }

    /// Attempt to manually migrate to a target zone — costs entryCostSeconds.
    /// The player stays in the new zone until balance drops below fallThresholdSeconds.
    func migrateToZone(_ zone: ZoneProfile) -> (success: Bool, message: String) {
        let current = currentZone
        let balance = TimeEngine.shared.balance

        if zone == current {
            return (false, "Du är redan i \(zone.name).")
        }

        if zone.index > current.index + 1 {
            return (false, "Du kan bara uppgradera till nästa zon i taget.")
        }

        if zone.index > current.index && balance < zone.unlockRequirementSeconds {
            let req = TimeEngine.shortFormatted(zone.unlockRequirementSeconds)
            return (false, "Zonen är inte upplåst ännu. Du behöver \(req) i saldo för att låsa upp den.")
        }

        // For free zones (Grundskiftet), just migrate
        if zone.entryCostSeconds == 0 {
            DispatchQueue.main.async {
                self.applyZoneChange(to: zone, trackProgress: true)
            }
            return (true, "Välkommen till \(zone.name)!")
        }

        // Must be able to afford entry cost
        guard balance >= zone.entryCostSeconds else {
            let needed = TimeEngine.shortFormatted(zone.entryCostSeconds)
            return (false, "Otillräcklig tid. Inträde kostar \(needed).")
        }

        // A migration is only valid when the unlock reserve, entry fee and
        // hysteresis reserve all survive the same atomic transaction.
        if !zone.canAffordMigration(with: balance) {
            let totalNeeded = TimeEngine.shortFormatted(zone.unlockRequirementSeconds + zone.entryCostSeconds + zone.fallThresholdSeconds)
            return (false, "Du behöver totalt \(totalNeeded) för att klara inträdet och inte falla tillbaka direkt.")
        }

        let success = TimeEngine.shared.deductTime(zone.entryCostSeconds)
        if success {
            DispatchQueue.main.async {
                self.applyZoneChange(to: zone, trackProgress: true)
            }
            return (true, "Välkommen till \(zone.name)! Kostnad: \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
        }
        return (false, "Migrationen misslyckades. Försök igen.")
    }

    private func applyZoneChange(to zone: ZoneProfile, trackProgress: Bool) {
        guard currentZone != zone else { return }
        currentZone = zone
        UserDefaults.standard.set(zone.name, forKey: lastZoneKey)
        TimeEngine.shared.setDrainRate(zone.drainRate)
        updateAvailableUpgrade(currentTime: TimeEngine.shared.balance)
        if trackProgress {
            triggerZoneMissionProgress(for: zone)
        }
    }

    private func updateAvailableUpgrade(currentTime: TimeInterval) {
        let current = currentZone
        let nextIndex = current.index + 1
        let nextZone = ZoneProfile.allZones.first { $0.index == nextIndex }
        let candidate: ZoneProfile? = {
            guard let nextZone else { return nil }
            return currentTime >= nextZone.unlockRequirementSeconds ? nextZone : nil
        }()
        if availableUpgrade?.name != candidate?.name {
            DispatchQueue.main.async {
                self.availableUpgrade = candidate
            }
        }
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
