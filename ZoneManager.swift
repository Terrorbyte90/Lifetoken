//
//  ZoneManager.swift
//  LifeToken
//
//  Created by Ted Svärd on 2025-05-16.
//

import Foundation

public class ZoneManager: ObservableObject {
    static let shared = ZoneManager()
    
    private let timeKey = "lifeSecondsRemaining"
    private let lastZoneKey = "lastKnownZoneName"
    
    func currentZone(forTime seconds: TimeInterval) -> ZoneProfile {
        return ZoneProfile.currentZone(forTime: seconds)
    }
    
    func evaluateZoneChange(currentTime: TimeInterval) {
        let currentZone = ZoneProfile.currentZone(forTime: currentTime)
        let previousZoneName = UserDefaults.standard.string(forKey: lastZoneKey)
        
        if previousZoneName != currentZone.name {
            logZoneChange(from: previousZoneName, to: currentZone.name, at: Date(), lifeSeconds: currentTime)
            UserDefaults.standard.set(currentZone.name, forKey: lastZoneKey)
        }
    }

    private func logZoneChange(from previous: String?, to current: String, at date: Date, lifeSeconds: TimeInterval) {
        print("ZONBYTE: Från \(previous ?? "okänd") till \(current) @ \(date) (\(Int(lifeSeconds)) sekunder kvar)")
        // Future implementation: save to CoreData or server log
    }
}
