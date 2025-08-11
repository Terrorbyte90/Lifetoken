//
//  EvolutionLoop.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//


import Foundation
import Combine

public final class EvolutionLoop: ObservableObject {

    @Published public private(set) var versionCount: Int = 0
    @Published public private(set) var changelog: [String] = []
    @Published public private(set) var lastImprovement: String?

    private var evolutionTimer: Timer?
    private struct Suggestion: Comparable {
        let text: String
        let priority: Double
        let timestamp: Date

        static func < (lhs: Suggestion, rhs: Suggestion) -> Bool {
            lhs.priority < rhs.priority
        }
    }
    private var suggestions: [Suggestion] = []

    public init() {
        adjustLoopFrequency()
    }

    // MARK: - Utvecklingsförslag

    public func receiveImprovementSuggestion(_ suggestion: String, priority: Double = 0.5) {
        let item = Suggestion(text: suggestion, priority: priority, timestamp: Date())
        suggestions.append(item)
        suggestions.sort(by: >)
        changelog.append("🧩 Nytt förslag (prio \(String(format: "%.2f", priority))): \(suggestion)")
        adjustLoopFrequency()
    }

    // MARK: - Självutvärdering & förbättring

    private func evolve() {
        guard !suggestions.isEmpty else {
            changelog.append("⏳ Inget nytt att utveckla vid denna iteration.")
            return
        }

        let selected = suggestions.removeFirst()
        versionCount += 1
        let note = "🧠 Version \(versionCount): Implementerade förbättring – \(selected.text)"
        changelog.append(note)
        lastImprovement = note

        NotificationCenter.default.post(name: .evolutionDidAdvance, object: self, userInfo: ["note": note])
    }

    // MARK: - Automatisk slinga

    private func adjustLoopFrequency() {
        let interval = suggestions.count > 10 ? 60.0 : 180.0
        evolutionTimer?.invalidate()
        evolutionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.evolve()
        }
    }

    // MARK: - Manuell trigger

    public func forceEvolveNow() {
        evolve()
    }

    public func registerFeedback(success: Bool) {
        let feedback = success ? "✅ Föregående förbättring bekräftades som lyckad." : "⚠️ Föregående förbättring ansågs otillräcklig."
        changelog.append(feedback)
    }

    public func resetEvolution() {
        versionCount = 0
        changelog.removeAll()
        suggestions.removeAll()
        lastImprovement = nil
    }
}

// MARK: - Notifiering

public extension Notification.Name {
    static let evolutionDidAdvance = Notification.Name("evolutionDidAdvance")
}
