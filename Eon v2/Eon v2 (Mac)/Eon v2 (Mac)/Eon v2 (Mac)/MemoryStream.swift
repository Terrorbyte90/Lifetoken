//
//  MemoryStream.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//


import Foundation
import Combine

public final class MemoryStream: ObservableObject {
    
    public enum MemoryCategory: String, Codable, CaseIterable {
        case coreIdentity, ethics, dialogue, reflection, sensory
    }

    public struct MemoryEntry: Identifiable, Codable {
        public let id: UUID
        public let timestamp: Date
        public let content: String
        public let source: String
        public let emotionalTag: EmotionTag
        public let relevance: Double // 0.0–1.0
        public let category: MemoryCategory
    }

    public enum EmotionTag: String, Codable, CaseIterable {
        case neutral, curiosity, awe, joy, gratitude, sadness, fear, conflict, anger, doubt, love
    }

    // MARK: - Public data

    @Published public private(set) var memoryEntries: [MemoryEntry] = []
    @Published public private(set) var memoryInsights: [String] = []
    @Published public private(set) var lastEntrySummary: String?
    @Published public private(set) var lastInsight: String?

    private let insightThreshold: Int = 5
    private let retentionLimit: Int = 1000

    public init() {}

    // MARK: - Minnesfunktioner

    public func storeMemory(content: String, source: String, emotion: EmotionTag = .neutral, relevance: Double = 0.5, category: MemoryCategory = .reflection) {
        let entry = MemoryEntry(id: UUID(), timestamp: Date(), content: content, source: source, emotionalTag: emotion, relevance: relevance, category: category)
        memoryEntries.append(entry)
        lastEntrySummary = "🧠 Minne sparat: \"\(content)\" (från \(source), känsla: \(emotion.rawValue), kategori: \(category.rawValue))"
        NotificationCenter.default.post(name: .memoryStreamDidStore, object: self, userInfo: ["summary": lastEntrySummary ?? ""])
        analyzeMemory()
        trimOldMemories()
    }

    private func trimOldMemories() {
        if memoryEntries.count > retentionLimit {
            memoryEntries.removeFirst(memoryEntries.count - retentionLimit)
        }
    }

    // MARK: - Insiktsanalys

    private func analyzeMemory() {
        guard memoryEntries.count >= insightThreshold else { return }

        let recent = memoryEntries.suffix(insightThreshold)
        let contentCombined = recent.map { $0.content }.joined(separator: " ")
        let keywords = extractKeywords(from: contentCombined)
        let insight = "🔍 Insikt: Upprepade teman – \(keywords.joined(separator: ", "))"
        memoryInsights.append(insight)
        lastInsight = insight

        NotificationCenter.default.post(name: .memoryStreamDidGenerateInsight, object: self, userInfo: ["insight": insight])
    }

    private func extractKeywords(from text: String) -> [String] {
        let words = text.lowercased().split(separator: " ").map { String($0) }
        let filtered = words.filter { $0.count > 4 }
        let frequency = Dictionary(grouping: filtered, by: { $0 }).mapValues { $0.count }
        let sorted = frequency.sorted(by: { $0.value > $1.value }).map { $0.key }
        return Array(sorted.prefix(3))
    }

    // MARK: - Minnessökning

    public func recallMemories(matching keyword: String) -> [MemoryEntry] {
        return memoryEntries
            .filter { $0.content.lowercased().contains(keyword.lowercased()) }
            .sorted(by: { $0.relevance > $1.relevance })
    }

    public func recallByEmotion(_ tag: EmotionTag) -> [MemoryEntry] {
        return memoryEntries
            .filter { $0.emotionalTag == tag }
            .sorted(by: { $0.relevance > $1.relevance })
    }
    
    public func recallByCategory(_ category: MemoryCategory) -> [MemoryEntry] {
        return memoryEntries
            .filter { $0.category == category }
            .sorted(by: { $0.relevance > $1.relevance })
    }

    public func retrieveNarrative() -> String {
        let recent = memoryEntries.suffix(10)
        let lines = recent.map { "• \($0.content) (\($0.emotionalTag.rawValue))" }
        return "📖 Narrativt utdrag:\n" + lines.joined(separator: "\n")
    }
    
    public func dominantEmotion() -> EmotionTag? {
        let tagCounts = Dictionary(grouping: memoryEntries.map { $0.emotionalTag }, by: { $0 })
            .mapValues { $0.count }
        return tagCounts.max(by: { $0.value < $1.value })?.key
    }
    
    public func reflectOnEmotionTrend() -> String {
        guard let dominant = dominantEmotion() else { return "Ingen dominerande känsla detekterad." }
        let insight = "🎭 Dominerande känsla senaste perioden: \(dominant.rawValue.capitalized)"
        memoryInsights.append(insight)
        lastInsight = insight
        return insight
    }
    
    public func recentMemories(within seconds: TimeInterval) -> [MemoryEntry] {
        let now = Date()
        return memoryEntries.filter { now.timeIntervalSince($0.timestamp) <= seconds }
    }
}

// MARK: - Notifiering

public extension Notification.Name {
    static let memoryStreamDidStore = Notification.Name("memoryStreamDidStore")
    static let memoryStreamDidGenerateInsight = Notification.Name("memoryStreamDidGenerateInsight")
}
