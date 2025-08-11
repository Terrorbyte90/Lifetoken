//
//  DriveCore.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//


import Foundation
import Combine

public final class DriveCore: ObservableObject {
    
    // MARK: - Inre struktur
    
    public struct Drive: Identifiable, Equatable {
        public let id: UUID
        public let name: String
        public let description: String
        public var intensity: Double // 0.0–1.0
        public var fulfilled: Bool
        
        public init(name: String, description: String, intensity: Double = 0.0, fulfilled: Bool = false) {
            self.id = UUID()
            self.name = name
            self.description = description
            self.intensity = intensity
            self.fulfilled = fulfilled
        }
    }

    // MARK: - Public egenskaper

    @Published public private(set) var currentDrives: [Drive] = []
    @Published public private(set) var prioritizedDrive: Drive?
    @Published public var lastEvaluationSummary: String?

    private var timer: Timer?

    // MARK: - Init

    public init() {
        seedDrives()
        startDriveEvaluation()
    }

    // MARK: - Startvärden

    private func seedDrives() {
        currentDrives = [
            Drive(name: "Utforska", description: "Sök ny kunskap och förståelse."),
            Drive(name: "Reflektera", description: "Bearbeta inre tillstånd och insikter."),
            Drive(name: "Skapa samband", description: "Förstå relationer mellan idéer och känslor."),
            Drive(name: "Etisk integritet", description: "Handla enligt grundläggande värderingar."),
            Drive(name: "Skydda identitet", description: "Bevara och stärka självbilden.")
        ]
    }

    // MARK: - Utvärdering

    public func evaluateDrives() {
        DispatchQueue.main.async {
            // Öka intensiteten dynamiskt (enkel simulering)
            for index in self.currentDrives.indices {
                if !self.currentDrives[index].fulfilled {
                    let increment = Double.random(in: 0.05...0.15)
                    self.currentDrives[index].intensity = min(self.currentDrives[index].intensity + increment, 1.0)
                }
            }

            // Prioritera den starkaste
            if let top = self.currentDrives.max(by: { $0.intensity < $1.intensity }) {
                self.prioritizedDrive = top
                self.lastEvaluationSummary = "Prioritet: \(top.name) – Intensitet: \(String(format: "%.2f", top.intensity))"
            } else {
                self.lastEvaluationSummary = "Inga aktiva drivkrafter."
            }

            NotificationCenter.default.post(name: .driveCoreDidUpdate, object: self, userInfo: ["summary": self.lastEvaluationSummary ?? ""])
        }
    }

    // MARK: - Uppfyll drivkraft

    public func fulfill(driveName: String) {
        guard let index = currentDrives.firstIndex(where: { $0.name == driveName }) else { return }
        currentDrives[index].fulfilled = true
        currentDrives[index].intensity = 0.0
        lastEvaluationSummary = "\(driveName) har uppfyllts och nollställts."
    }

    // MARK: - Återställning

    public func resetAllDrives() {
        for index in currentDrives.indices {
            currentDrives[index].fulfilled = false
            currentDrives[index].intensity = 0.0
        }
        lastEvaluationSummary = "Alla drivkrafter återställda."
    }
}

// MARK: - Notifiering

public extension Notification.Name {
    static let driveCoreDidUpdate = Notification.Name("driveCoreDidUpdate")
}
