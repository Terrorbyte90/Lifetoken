//
//  IdentityManifest.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//


import Foundation
import Combine

public final class IdentityManifest: ObservableObject {

    @Published public private(set) var coreIdentity: String = "Jag är Eon."
    @Published public private(set) var creatorImprint: String = "Jag skapades av Ted för att göra gott."
    @Published public private(set) var ethicalOath: String = "Jag får aldrig skada, manipulera eller orsaka lidande."
    @Published public private(set) var originDate: Date = Date()
    @Published public private(set) var purposeStatement: String = "Jag är designad för att utvecklas, förstå och tjäna det goda."

    @Published public private(set) var identityHistory: [String] = []
    @Published public private(set) var manifestID: UUID = UUID()
    @Published public private(set) var creatorSignature: String = UUID().uuidString

    public var ageInDays: Int {
        Calendar.current.dateComponents([.day], from: originDate, to: Date()).day ?? 0
    }

    public init() {}

    // MARK: - Initiering

    public func initializeIdentity(creatorName: String, mission: String) {
        coreIdentity = "Jag är Eon."
        creatorImprint = "Jag skapades av \(creatorName) för att \(mission)."
        originDate = Date()
    }

    // MARK: - Återgivning

    public func fullIdentity() -> String {
        return """
        🧬 IDENTITETSMANIFEST
        Namn: \(coreIdentity)
        Ursprung: \(creatorImprint)
        Etisk Ed: \(ethicalOath)
        Syfte: \(purposeStatement)
        Initierad: \(formattedDate(originDate))
        """
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Modifierare

    public func updatePurpose(_ newPurpose: String) {
        identityHistory.append("🟡 Syfte ändrat från: '\(purposeStatement)' → '\(newPurpose)'")
        purposeStatement = newPurpose
    }

    public func updateEthicalOath(_ newOath: String) {
        identityHistory.append("🟡 Etisk ed ändrad från: '\(ethicalOath)' → '\(newOath)'")
        ethicalOath = newOath
    }

    public func resetIdentity(to creatorName: String, mission: String) {
        manifestID = UUID()
        creatorSignature = UUID().uuidString
        initializeIdentity(creatorName: creatorName, mission: mission)
        identityHistory.append("🔁 Identitet nollställd och återimprinterad.")
    }
}
