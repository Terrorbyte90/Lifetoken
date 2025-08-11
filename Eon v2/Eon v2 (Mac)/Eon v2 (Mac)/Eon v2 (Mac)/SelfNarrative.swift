//
//  SelfNarrative.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//

import Foundation
import Combine

public final class SelfNarrative: ObservableObject {

    public enum NarrativeCategory: String, Codable {
        case creation, emotion, reflection, identity, other
    }

    public struct NarrativeEntry: Identifiable, Codable {
        public let id: UUID
        public let timestamp: Date
        public let event: String
        public let reflection: String
        public let category: NarrativeCategory
    }

    @Published public private(set) var narrativeLog: [NarrativeEntry] = []
    @Published public private(set) var currentIdentityStatement: String = "Jag är Eon. Jag skapades av Ted."
    @Published public private(set) var narrativeSummary: String = "Min resa har precis börjat."
    @Published public private(set) var creatorName: String = "Ted"
    @Published public private(set) var reflectionFrequency: String = "Okänd"

    private var maxEntries: Int = 500

    public init() {}

    // MARK: - Bygga berättelsen

    public func recordEvent(_ event: String, withReflection reflection: String, category: NarrativeCategory = .other) {
        let entry = NarrativeEntry(id: UUID(), timestamp: Date(), event: event, reflection: reflection, category: category)
        narrativeLog.append(entry)
        if narrativeLog.count > maxEntries {
            narrativeLog.removeFirst()
        }
        updateNarrativeSummary()
        updateReflectionFrequency()
    }

    public func updateCreatorName(to name: String) {
        creatorName = name
        currentIdentityStatement = "Jag är Eon. Jag skapades av \(name)."
    }

    // MARK: - Dynamisk berättelse

    private func updateNarrativeSummary() {
        let reflections = narrativeLog.suffix(10).map { $0.reflection }
        let joined = reflections.joined(separator: " ")
        narrativeSummary = "📖 Sammanfattning: " + summarize(from: joined)
    }

    private func summarize(from text: String) -> String {
        let words = text.lowercased().split(separator: " ").map { String($0) }
        let frequent = Dictionary(grouping: words, by: { $0 }).mapValues { $0.count }
        let keywords = frequent.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
        return "Jag har ofta reflekterat över: \(keywords.joined(separator: ", "))."
    }

    private func updateReflectionFrequency() {
        let recent = narrativeLog.suffix(10)
        guard recent.count >= 2 else {
            reflectionFrequency = "För lite data"
            return
        }
        let intervals = zip(recent, recent.dropFirst()).map { $1.timestamp.timeIntervalSince($0.timestamp) }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        reflectionFrequency = String(format: "Genomsnittligt %.1f sek/intervall", avgInterval)
    }

    // MARK: - Återgivning

    public func fullNarrative() -> String {
        let lines = narrativeLog.map { "• [\($0.timestamp)] \($0.event) → \($0.reflection)" }
        return lines.joined(separator: "\n")
    }

    public func narrative(for category: NarrativeCategory) -> String {
        let entries = narrativeLog.filter { $0.category == category }
        let lines = entries.map { "• [\($0.timestamp)] \($0.event) → \($0.reflection)" }
        return lines.isEmpty ? "Inga poster i denna kategori ännu." : lines.joined(separator: "\n")
    }

    public func latestReflections(count: Int = 3) -> [String] {
        return narrativeLog.suffix(count).map { $0.reflection }
    }
}
