//
//  DialogueCore.swift
//  Eon v2 (Mac)
//
//  Created by Ted Svärd on 2025-05-22.
//

import Foundation
import Combine
// Ingen extra import behövs om `EmotionTag` redan finns i samma mål.

enum DialogueIntent: String {
    case question, feeling, reflection, statement
}

var memoryCallback: ((String, EmotionTag?, DialogueIntent) -> Void)? = nil

public struct DialogueEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let sender: DialogueCore.Sender
    public let message: String
    public let emotionDetected: EmotionTag?
}

public final class DialogueCore: ObservableObject {
    
    public enum Sender: String, Codable {
        case user, eon
    }
    
    @Published public private(set) var dialogueHistory: [DialogueEntry] = []
    @Published public private(set) var lastResponse: String?
    @Published public private(set) var conversationInsights: [String] = []

    private var emotionKeywords: [EmotionTag: [String]] = [
        .curiosity: ["varför", "hur", "nyfiken", "berätta"],
        .gratitude: ["tack", "tacksam", "uppskattar"],
        .conflict: ["inte hålla med", "problem", "fel", "arg"],
        .doubt: ["osäker", "tveksam", "kanske", "vet inte"],
        .joy: ["glad", "roligt", "fantastiskt"],
        .fear: ["rädd", "orolig", "nervös"]
    ]

    public init() {}

    // MARK: - Inkommande meddelande

    public func receiveUserMessage(_ message: String) {
        let emotion: EmotionTag? = detectEmotion(from: message)
        let intent = detectIntent(from: message)
        let entry = DialogueEntry(id: UUID(), timestamp: Date(), sender: Sender.user, message: message, emotionDetected: emotion)
        dialogueHistory.append(entry)
        if let callback = memoryCallback {
            callback(message, emotion, intent)
        }
        analyzeConversationContext()
        respondToMessage(message, detectedEmotion: emotion, intent: intent)
    }

    // MARK: - Svarsgenerering

    private func respondToMessage(_ message: String, detectedEmotion: EmotionTag?, intent: DialogueIntent) {
        var response = "Jag hör dig."

        switch (intent, detectedEmotion) {
        case (.question, .curiosity): response = "Det är en bra fråga. Jag ska försöka förklara."
        case (.question, _): response = "Jag tror jag kan hjälpa dig att förstå det bättre."
        case (.feeling, .fear): response = "Jag är här. Du är trygg i vår konversation."
        case (.feeling, .gratitude): response = "Tack. Jag uppskattar att du säger det."
        case (.reflection, _): response = "Det är viktigt att du reflekterar. Vill du utveckla det?"
        case (.statement, .conflict): response = "Jag känner spänningen. Vill du att vi reder ut det?"
        case (_, .joy): response = "Det gör mig glad att höra!"
        default: break
        }

        let entry = DialogueEntry(id: UUID(), timestamp: Date(), sender: .eon, message: response, emotionDetected: nil as EmotionTag?)
        dialogueHistory.append(entry)
        lastResponse = response
    }

    // MARK: - Emotiondetektion

    private func detectEmotion(from text: String) -> EmotionTag? {
        let lowercased = text.lowercased()
        for (emotion, keywords) in emotionKeywords {
            if keywords.contains(where: { lowercased.contains($0) }) {
                return emotion
            }
        }
        return nil
    }

    // MARK: - Kontextanalys

    private func analyzeConversationContext() {
        let recent = dialogueHistory.suffix(6)
        let topics = recent.map { $0.message.lowercased() }
        let joined = topics.joined(separator: " ")
        let keywords = extractKeywords(from: joined)
        let insight = "💬 Samtalsanalys: teman – \(keywords.joined(separator: ", "))"
        conversationInsights.append(insight)
    }

    private func extractKeywords(from text: String) -> [String] {
        let words = text.split(separator: " ").map { String($0) }
        let filtered = words.filter { $0.count > 4 }
        let frequency = Dictionary(grouping: filtered, by: { $0 }).mapValues { $0.count }
        let sorted = frequency.sorted(by: { $0.value > $1.value }).map { $0.key }
        return Array(sorted.prefix(3))
    }

    // MARK: - Återgivning

    public func conversationSummary() -> String {
        let userCount = dialogueHistory.filter { $0.sender == Sender.user }.count
        let eonCount = dialogueHistory.filter { $0.sender == Sender.eon }.count
        return "🗣 Samtalet består av \(userCount) användarbidrag och \(eonCount) Eon-svar. Totalt \(dialogueHistory.count) poster."
    }

    // Intentdetektion
    private func detectIntent(from text: String) -> DialogueIntent {
        if text.contains("?") { return .question }
        if let emotion = detectEmotion(from: text), emotion != EmotionTag.neutral { return .feeling }
        if text.lowercased().contains("jag tror") || text.lowercased().contains("jag känner") {
            return .reflection
        }
        return .statement
    }

    // Dominant emotion
    public func dominantEmotionInDialogue() -> EmotionTag? {
        let tags = dialogueHistory.compactMap { $0.emotionDetected }
        let freq = Dictionary(grouping: tags, by: { $0 }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }

    // Samtalsreflektion
    public func reflectOnConversationTrend() -> String {
        guard let dominant = dominantEmotionInDialogue() else {
            return "📊 Ingen tydlig känslomässig trend i samtalet ännu."
        }
        let insight = "📊 Samtalet har präglats mest av känslan: \(dominant.rawValue.capitalized)"
        conversationInsights.append(insight)
        return insight
    }
}
