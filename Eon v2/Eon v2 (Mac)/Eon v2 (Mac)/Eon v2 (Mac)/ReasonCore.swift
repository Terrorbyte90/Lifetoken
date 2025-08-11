//
//  ReasonCore.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//


import Foundation
import Combine

public final class ReasonCore: ObservableObject {

    public enum ThoughtType: String, Codable {
        case goal, reflection, ethicalConcern, idea, warning
    }

    public struct Thought: Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let origin: String
        public let content: String
        public let type: ThoughtType
        public var evaluatedEthically: Bool
        public var confidence: Double // 0.0–1.0

        public init(origin: String, content: String, type: ThoughtType = .idea, confidence: Double = 0.5, evaluatedEthically: Bool = false) {
            self.id = UUID()
            self.timestamp = Date()
            self.origin = origin
            self.content = content
            self.type = type
            self.evaluatedEthically = evaluatedEthically
            self.confidence = confidence
        }
    }

    // MARK: - Public egenskaper

    @Published public private(set) var activeThoughts: [Thought] = []
    @Published public private(set) var executedDecisions: [String] = []
    @Published public private(set) var reasoningLog: [String] = []
    @Published public private(set) var lastDecision: String?

    private var confidenceThreshold: Double = 0.7

    public init() {}

    // MARK: - Tänk och resonera

    public func registerThought(origin: String, content: String, type: ThoughtType = .idea, confidence: Double = 0.5) {
        let thought = Thought(origin: origin, content: content, type: type, confidence: confidence)
        activeThoughts.append(thought)
        reasoningLog.append("💭 [\(type.rawValue.capitalized)] från \(origin): \"\(content)\" (confidence: \(String(format: "%.2f", confidence)))")
    }

    public func evaluateThoughts(ethicsCallback: ((Thought) -> Bool)? = nil) {
        for index in activeThoughts.indices {
            let thought = activeThoughts[index]
            if let ethics = ethicsCallback {
                let result = ethics(thought)
                activeThoughts[index].evaluatedEthically = result
                if result {
                    reasoningLog.append("🧭 Etiskt godkänd: \"\(thought.content)\"")
                } else {
                    reasoningLog.append("⛔ Etiskt avvisad: \"\(thought.content)\"")
                }
            }
        }
    }

    public func shouldDelayDecision() -> Bool {
        let eligible = activeThoughts.filter { $0.evaluatedEthically && $0.confidence >= confidenceThreshold }
        return eligible.count < 2
    }

    public func selectAction() {
        if shouldDelayDecision() {
            reasoningLog.append("🕒 Beslut fördröjt – för få kvalificerade tankar.")
            return
        }
        let filtered = activeThoughts.filter { $0.evaluatedEthically && $0.confidence >= confidenceThreshold }
        guard let best = filtered.max(by: { $0.confidence < $1.confidence }) else {
            reasoningLog.append("⚠️ Inga lämpliga handlingar uppfyllde kriterierna.")
            return
        }
        executeDecision(thought: best)
    }

    private func executeDecision(thought: Thought) {
        let summary = "✅ Beslut: \(thought.content) (från \(thought.origin))"
        executedDecisions.append(summary)
        lastDecision = summary
        reasoningLog.append(summary)
        NotificationCenter.default.post(name: .reasonCoreDidMakeDecision, object: self, userInfo: ["decision": summary])
        clearThoughts()
    }

    public func clearThoughts() {
        activeThoughts.removeAll()
    }

    // MARK: - Självjustering

    public func adjustConfidenceThreshold(basedOnFeedback isTooStrict: Bool) {
        if isTooStrict {
            confidenceThreshold = max(0.5, confidenceThreshold - 0.05)
        } else {
            confidenceThreshold = min(0.95, confidenceThreshold + 0.05)
        }
        reasoningLog.append("📊 Justerad beslutsgräns: \(String(format: "%.2f", confidenceThreshold))")
    }

    public func reflectOnLastDecision() -> String {
        guard let last = lastDecision else {
            return "🧠 Reflektion: Inga beslut har ännu fattats."
        }
        let statement = "🧠 Reflektion: Mitt senaste beslut var: \(last). Jag utvärderar dess påverkan."
        reasoningLog.append(statement)
        return statement
    }

    // MARK: - Beslutsfeedback och adaptivitet

    public func registerDecisionOutcome(success: Bool) {
        if success {
            confidenceThreshold = max(0.5, confidenceThreshold - 0.01)
            reasoningLog.append("🟢 Beslut ansågs framgångsrikt. Tröskel justerad till \(String(format: "%.2f", confidenceThreshold))")
        } else {
            confidenceThreshold = min(0.95, confidenceThreshold + 0.02)
            reasoningLog.append("🔴 Beslut misslyckades. Tröskel justerad till \(String(format: "%.2f", confidenceThreshold))")
        }
    }
}

// MARK: - Notifiering

public extension Notification.Name {
    static let reasonCoreDidMakeDecision = Notification.Name("reasonCoreDidMakeDecision")
}
