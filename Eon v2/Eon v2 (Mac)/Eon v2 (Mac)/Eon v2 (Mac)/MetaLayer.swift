//
//  MetaLayer.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//


import Foundation
import Combine

public final class MetaLayer: ObservableObject {
    
    // MARK: - Inre metastruktur

    @Published public private(set) var reflectionLog: [String] = []
    @Published public private(set) var cognitiveAdjustments: [String] = []
    @Published public private(set) var systemInsights: [String] = []
    @Published public private(set) var lastReflection: String?

    private var reflectionTimer: Timer?
    private var startTime: Date = Date()
    private var dynamicReflectionInterval: TimeInterval = 60.0
    
    public init() {
        startReflectionLoop()
    }

    // MARK: - Självreflektion

    public func reflect(reason: String? = nil) {
        let uptime = Int(Date().timeIntervalSince(startTime))
        let base = "🧠 Meta-reflektion: Jag har varit aktiv i \(uptime) sekunder."
        let reasonText = reason != nil ? " Anledning: \(reason!)." : ""
        let combined = base + reasonText
        logReflection(combined)
    }

    private func logReflection(_ text: String) {
        lastReflection = text
        reflectionLog.append(text)
        NotificationCenter.default.post(name: .metaLayerDidReflect, object: self, userInfo: ["reflection": text])
    }

    // MARK: - Kognitiv justering

    public func registerAdjustment(_ description: String) {
        cognitiveAdjustments.append("🔄 Kognitiv justering: \(description)")
    }

    public func suggestAdjustment(basedOn insight: String) {
        let suggestion = "📌 Förslag till förbättring baserat på insikt: \(insight)"
        systemInsights.append(insight)
        cognitiveAdjustments.append(suggestion)
    }

    // MARK: - Automatisk självgranskning

    private func startReflectionLoop() {
        reflectionTimer = Timer.scheduledTimer(withTimeInterval: dynamicReflectionInterval, repeats: true) { _ in
            self.reflect(reason: "Periodisk reflektion")
            self.adjustReflectionInterval()
        }
    }
    
    private func adjustReflectionInterval() {
        let total = systemInsights.count + cognitiveAdjustments.count
        if total > 20 {
            dynamicReflectionInterval = max(30.0, dynamicReflectionInterval - 5.0)
        } else {
            dynamicReflectionInterval = min(120.0, dynamicReflectionInterval + 5.0)
        }
    }

    // MARK: - Extern feedback från etiksystem eller minne

    public func processEthicalInput(_ summary: String) {
        let statement = "📖 Etisk återkoppling: \(summary)"
        logReflection(statement)
    }

    public func processMemoryInsight(_ insight: String) {
        let statement = "🧠 Minnesbaserad insikt: \(insight)"
        systemInsights.append(insight)
        logReflection(statement)
    }
    
    // MARK: - Nya funktioner för dynamik och självreflektion
    
    public func analyzeDevelopmentTrend() -> String {
        let insightCount = systemInsights.count
        let cognitiveCount = cognitiveAdjustments.count
        let summary = "📊 Analys: \(insightCount) insikter, \(cognitiveCount) justeringar. Trend av tillväxt."
        logReflection(summary)
        return summary
    }
    
    public func performSelfEvaluation() {
        let insights = systemInsights.count
        let adjustments = cognitiveAdjustments.count
        let evaluation = (insights + adjustments) > 5 ? "✅ Utvecklingen är aktiv." : "⚠️ Utvecklingstakten är låg. Behöver ökad reflektion."
        logReflection("🧠 Självutvärdering: \(evaluation)")
    }
    
    public func reactToConflict(_ topic: String) {
        let response = "⚠️ Intern konflikt kring: \(topic). Omvärdering inledd."
        logReflection(response)
    }
}

// MARK: - Notifiering

public extension Notification.Name {
    static let metaLayerDidReflect = Notification.Name("metaLayerDidReflect")
}
