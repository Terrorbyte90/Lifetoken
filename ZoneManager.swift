import Foundation
import SwiftUI

public class ZoneManager: ObservableObject {
    static let shared = ZoneManager()
    private let lastZoneKey = "lastKnownZoneName"

    @Published var currentZone: ZoneProfile = .duskline

    private init() {
        currentZone = ZoneProfile.currentZone(forTime: TimeEngine.shared.balance)
    }

    func currentZoneProfile(forTime seconds: TimeInterval) -> ZoneProfile {
        return ZoneProfile.currentZone(forTime: seconds)
    }

    func evaluateZoneChange(currentTime: TimeInterval) {
        let newZone = ZoneProfile.currentZone(forTime: currentTime)
        let previousZoneName = UserDefaults.standard.string(forKey: lastZoneKey)
        if previousZoneName != newZone.name {
            UserDefaults.standard.set(newZone.name, forKey: lastZoneKey)
            DispatchQueue.main.async { self.currentZone = newZone }
        }
    }

    /// Attempt to migrate to a target zone — costs entryCostSeconds
    func migrateToZone(_ zone: ZoneProfile) -> (success: Bool, message: String) {
        let balance = TimeEngine.shared.balance
        guard balance >= zone.entryCostSeconds else {
            return (false, "Otillracklig tid. Du behover \(TimeEngine.shortFormatted(zone.entryCostSeconds)).")
        }
        guard zone.unlockRequirementSeconds <= balance else {
            return (false, "Du uppfyller inte kraven for \(zone.name).")
        }
        let success = TimeEngine.shared.deductTime(zone.entryCostSeconds)
        if success {
            currentZone = zone
            UserDefaults.standard.set(zone.name, forKey: lastZoneKey)
            return (true, "Valkommen till \(zone.name)! Kostnad: \(TimeEngine.shortFormatted(zone.entryCostSeconds))")
        }
        return (false, "Migrationen misslyckades.")
    }
}
