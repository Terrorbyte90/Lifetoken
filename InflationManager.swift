import Foundation
import SwiftUI

// MARK: - Inflation Manager
// Symboliserar In Time-filmens ekonomiska inflation:
// Ju längre du bor i en zon, desto dyrare blir allting.
// Lönerna minskar i reell köpkraft — du måste klättra uppåt eller kollapsa.

enum InflationSeverity {
    case stable, rising, high, critical

    var color: Color {
        switch self {
        case .stable:   return .green
        case .rising:   return .yellow
        case .high:     return .orange
        case .critical: return .red
        }
    }

    var label: String {
        switch self {
        case .stable:   return "STABIL"
        case .rising:   return "STIGANDE"
        case .high:     return "HÖG"
        case .critical: return "KRITISK"
        }
    }

    var icon: String {
        switch self {
        case .stable:   return "checkmark.circle.fill"
        case .rising:   return "arrow.up.right"
        case .high:     return "exclamationmark.triangle.fill"
        case .critical: return "flame.fill"
        }
    }
}

class InflationManager: ObservableObject {
    static let shared = InflationManager()

    @Published var inflationMultiplier: Double = 1.0
    @Published var daysInZone: Double = 0

    private let zoneEntryKey  = "inflation_zone_entry_date"
    private let zoneNameKey   = "inflation_current_zone"

    private var trackedZoneName: String = ""
    private var zoneEntryDate: Date = Date()
    private var updateTimer: Timer?

    private init() {
        loadState()
        startUpdating()
    }

    // MARK: - Persistence

    private func loadState() {
        trackedZoneName = UserDefaults.standard.string(forKey: zoneNameKey) ?? ""
        if let d = UserDefaults.standard.object(forKey: zoneEntryKey) as? Date {
            zoneEntryDate = d
        } else {
            zoneEntryDate = Date()
            UserDefaults.standard.set(zoneEntryDate, forKey: zoneEntryKey)
        }
        recalculate()
    }

    private func saveState() {
        UserDefaults.standard.set(zoneEntryDate, forKey: zoneEntryKey)
        UserDefaults.standard.set(trackedZoneName, forKey: zoneNameKey)
    }

    // MARK: - Zone Entry

    /// Call when the player enters a new zone (migration or first load)
    func onZoneEntered(_ zone: ZoneProfile) {
        guard zone.name != trackedZoneName else { return }
        trackedZoneName = zone.name
        zoneEntryDate = Date()
        saveState()
        recalculate()
    }

    // MARK: - Calculation

    private func startUpdating() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.recalculate()
        }
    }

    private func recalculate() {
        daysInZone = max(0, Date().timeIntervalSince(zoneEntryDate) / 86400)
        let zone = ZoneProfile.allZones.first { $0.name == trackedZoneName } ?? .duskline
        inflationMultiplier = max(1.0, 1.0 + daysInZone * zone.inflationRatePerDay)
    }

    // MARK: - Public API

    /// Apply inflation penalty to job/income earnings. More days = less pay.
    func applyToEarnings(_ earnings: TimeInterval) -> TimeInterval {
        return earnings / inflationMultiplier
    }

    var severity: InflationSeverity {
        switch inflationMultiplier {
        case ..<1.1:  return .stable
        case ..<1.25: return .rising
        case ..<1.5:  return .high
        default:      return .critical
        }
    }

    var percentLabel: String {
        let pct = Int((inflationMultiplier - 1.0) * 100)
        return pct == 0 ? "0%" : "+\(pct)%"
    }

    var daysLabel: String {
        let d = Int(daysInZone)
        return d == 1 ? "1 dag" : "\(d) dagar"
    }
}
