import Foundation

struct Token: Identifiable, Codable {
    let id: UUID
    let name: String
    let value: Double
    let currency: String
    var trend: Double
}

extension Token {
    /// Returns formatted percentage with sign and one decimal place (e.g., +2.5% / -3.1%)
    var trendFormatted: String {
        String(format: "%+.1f%%", trend * 100)
    }

    var isPositive: Bool {
        trend >= 0
    }
}