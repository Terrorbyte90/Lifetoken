import Foundation

// MARK: - Zone Identity
/// Stable string identifier for zones. Examples: "askan", "novalux", "vaultum"
typealias ZoneID = String

/// Produces a stable zone identifier from display names or legacy ids.
/// Examples:
/// - "Uppgången" -> "uppgangen"
/// - "Stigarnas Dal" -> "stigarnasdal"
func normalizeZoneID(_ raw: String) -> ZoneID {
    let folded = raw
        .lowercased()
        .folding(options: .diacriticInsensitive, locale: .current)
    let scalars = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    return String(String.UnicodeScalarView(scalars))
}

// MARK: - Player Event Protocol
/// Represents any significant game event for the narrative/gazette system.
protocol PlayerEvent {
    var eventID: String { get }
    var occurredAt: Date { get }
    var zoneID: ZoneID { get }
    var isOneTime: Bool { get }
}

// MARK: - Narrative Event Category
enum EventCategory: String, Codable, CaseIterable {
    case casinoWin
    case zoneUpgrade
    case death
    case streak
    case pvpWin
    case investment
    case factionWar
}
