import Foundation
import SwiftUI

// MARK: - Nyhetsflödet — Världens Röst
// Automatiskt genererat flöde baserat på faktisk speldata.
// Kall, faktabaserad, dystopisk ton. Alltid tidsstämplat.

struct NewsItem: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let headline: String
    let body: String
    let category: NewsCategory
    let priority: NewsPriority

    enum NewsCategory: String, Codable {
        case systemFee      = "SYSTEMAVGIFT"
        case inflation      = "INFLATION"
        case taxation       = "SKATT"
        case rankChange     = "MAKTHIERARKI"
        case nightMarket    = "NATTMARKNADEN"
        case healthIncome   = "HÄLSOINKOMST"
        case stepBet        = "STEGDUELL"
        case revolution     = "REVOLUTION"
        case playerJoin     = "REKRYTERING"
        case miniJob        = "AKTIVT JOBB"
        case general        = "SYSTEM"
        case playerDeath    = "DÖDSFALL"
    }

    enum NewsPriority: Int, Codable {
        case low = 0
        case medium = 1
        case high = 2
        case breaking = 3
    }

    var categoryColor: Color {
        switch category {
        case .systemFee:    return Color(red: 0.8, green: 0.6, blue: 0.1)
        case .inflation:    return Color(red: 0.9, green: 0.3, blue: 0.1)
        case .taxation:     return Color(red: 0.9, green: 0.3, blue: 0.1)
        case .rankChange:   return Color(red: 0.3, green: 0.9, blue: 0.4)
        case .nightMarket:  return Color(red: 0.5, green: 0.3, blue: 0.9)
        case .healthIncome: return Color(red: 0.2, green: 0.7, blue: 0.9)
        case .stepBet:      return Color(red: 0.1, green: 0.8, blue: 0.5)
        case .revolution:   return Color(red: 0.9, green: 0.9, blue: 0.1)
        case .playerJoin:   return Color(red: 0.3, green: 0.9, blue: 0.5)
        case .miniJob:      return Color(red: 0.2, green: 0.7, blue: 0.9)
        case .general:      return Color(red: 0.5, green: 0.5, blue: 0.5)
        case .playerDeath:  return Color(red: 0.7, green: 0.05, blue: 0.05)
        }
    }

    var formattedTime: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "Europe/Stockholm")
        return fmt.string(from: timestamp)
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        fmt.locale = Locale(identifier: "sv_SE")
        fmt.timeZone = TimeZone(identifier: "Europe/Stockholm")
        return fmt.string(from: timestamp)
    }
}

// MARK: - News Manager

class NewsManager: ObservableObject {
    static let shared = NewsManager()

    @Published var items: [NewsItem] = []

    private let maxItems = 100
    private let storageKey = "newsItems"

    private init() {
        loadItems()
        // Generera välkomstnyhet om tomt
        if items.isEmpty {
            addItem(
                headline: "SYSTEMET STARTAR",
                body: "En ny spelare har registrerats. Klockan tickar. Styrelsen noterar.",
                category: .general,
                priority: .medium
            )
        }
    }

    // MARK: - Persistence

    private func loadItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([NewsItem].self, from: data) else { return }
        items = decoded
    }

    private func saveItems() {
        guard let data = try? JSONEncoder().encode(Array(items.prefix(maxItems))) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Generella metoder

    func addItem(headline: String, body: String, category: NewsItem.NewsCategory, priority: NewsItem.NewsPriority) {
        let item = NewsItem(
            id: UUID().uuidString,
            timestamp: Date(),
            headline: headline,
            body: body,
            category: category,
            priority: priority
        )
        DispatchQueue.main.async {
            self.items.insert(item, at: 0)
            if self.items.count > self.maxItems { self.items = Array(self.items.prefix(self.maxItems)) }
            self.saveItems()
        }
    }

    // MARK: - Händelsespecifika metoder

    func addSystemFeeEvent(percent: Double, totalStolen: TimeInterval) {
        let pct = String(format: "%.0f", percent * 100)
        let total = TimeEngine.shortFormatted(totalStolen)
        let timeStr = currentTimeString()
        addItem(
            headline: "SYSTEMAVGIFT DRAGEN",
            body: "Arvid Toll tog \(pct)% av alla spelares balans kl \(timeStr). Totalt: \(total) stulet.",
            category: .systemFee,
            priority: .high
        )
    }

    func addInflationSpikeEvent(hour: String) {
        addItem(
            headline: "INFLATIONSSPIK",
            body: "Leon Prent utlöste en tryckning kl \(hour). Inflationen steg kraftigt under en timme.",
            category: .inflation,
            priority: .high
        )
    }

    func addTaxationEvent(amount: TimeInterval) {
        let total = TimeEngine.shortFormatted(amount)
        addItem(
            headline: "GREGOR SKATT — SKATTEINKOMST",
            body: "Gregors balans har vuxit med \(total) denna vecka i takt med att spelarna betalat skatt.",
            category: .taxation,
            priority: .low
        )
    }

    func addRankChangeEvent(playerName: String, role: PowerRole) {
        let roleTitle = role.subtitle
        addItem(
            headline: "NY MAKTHAVARE",
            body: "\(playerName) har passerat \(role.title) och kontrollerar nu positionen som \(roleTitle).",
            category: .rankChange,
            priority: .breaking
        )
    }

    func addHealthIncomeEvent(amount: TimeInterval, breakdown: HealthIncomeBreakdown) {
        let name = GameState.shared.username
        let amt  = TimeEngine.shortFormatted(amount)
        addItem(
            headline: "HÄLSOINKOMST UTBETALD",
            body: "\(name) fick \(amt) i hälsoinkomst för dagen. \(breakdown.stepsSeconds > 0 ? "Steg bidrog mest." : "Minimal aktivitet registrerad.")",
            category: .healthIncome,
            priority: .low
        )
    }

    func addNightMarketEvent(sellerName: String, outcome: String) {
        addItem(
            headline: "NATTMARKNADEN",
            body: "\(sellerName) \(outcome)",
            category: .nightMarket,
            priority: .medium
        )
    }

    func addStepBetEvent(winner: String, loser: String, amount: TimeInterval) {
        let amt = TimeEngine.shortFormatted(amount)
        addItem(
            headline: "STEGDUELL AVGJORD",
            body: "\(winner) besegrade \(loser) och vann \(amt).",
            category: .stepBet,
            priority: .medium
        )
    }

    func addRevolutionWarningEvent(playerName: String, targetName: String, gap: TimeInterval) {
        let gapStr = TimeEngine.shortFormatted(gap)
        addItem(
            headline: "REVOLUTION?",
            body: "Spelaren \(playerName) är nu \(gapStr) under \(targetName)s balans. Systemet bevakar situationen.",
            category: .revolution,
            priority: .high
        )
    }

    // MARK: - Spelhändelser

    func addPlayerJoinEvent(username: String, zoneName: String) {
        let flavors = [
            "Klockan har aktiverats. Nedräkningen är i gång.",
            "En ny kugge i maskineriet. Systemet noterar.",
            "Välkommen till dystopian. Du har redan börjat förlora tid.",
            "Registrerad. Din tid är nu en handelsvara."
        ]
        addItem(
            headline: "NY MEDBORGARE REGISTRERAD",
            body: "\(username) har aktiverat sin tidsmätare i \(zoneName). \(flavors.randomElement() ?? "")",
            category: .playerJoin,
            priority: .low
        )
    }

    func addMiniJobCompletedEvent(jobName: String, earned: TimeInterval, won: Bool) {
        let name = GameState.shared.username
        if won {
            let amt = TimeEngine.shortFormatted(earned)
            addItem(
                headline: "JOBB SLUTFÖRT",
                body: "\(name) slutförde '\(jobName)' och fick \(amt) i lön.",
                category: .miniJob,
                priority: .low
            )
        } else {
            addItem(
                headline: "JOBB MISSLYCKAT",
                body: "\(name) misslyckades med '\(jobName)'. Böter dragna.",
                category: .miniJob,
                priority: .low
            )
        }
    }

    func addPlayerDeathEvent(username: String) {
        let deathMessages = [
            "\(username) har förlorat allt. Klockan stannade. Det gör den alltid.",
            "En spelare försvann i natt. \(username) finns inte längre i systemet.",
            "\(username) är borta. Ingen sörjer i Lifetoken.",
            "Systemet raderade \(username). Det var bara en tidsfråga.",
            "\(username) gick in i evigheten mot sin vilja."
        ]
        let message = deathMessages.randomElement() ?? "\(username) är borta."
        addItem(
            headline: "SPELAREN \(username.uppercased()) ÄR BORTA",
            body: message,
            category: .playerDeath,
            priority: .breaking
        )
    }

    // MARK: - Helpers

    private func currentTimeString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        fmt.timeZone = TimeZone(identifier: "Europe/Stockholm")
        return fmt.string(from: Date())
    }

    // Kolla om spelaren är nära att ta en maktposition
    func checkRevolutionThreshold() {
        let playerBalance = TimeEngine.shared.balance
        let playerName = GameState.shared.username
        guard !playerName.isEmpty else { return }

        for member in BoardManager.shared.members {
            let gap = member.balance - playerBalance
            if gap > 0 && gap < (3 * 365.25 * 86400) { // inom 3 år
                addRevolutionWarningEvent(playerName: playerName, targetName: member.displayName, gap: gap)
            }
        }
    }
}

// MARK: - Nyhetsflödets UI

struct NewsFeedView: View {
    @ObservedObject private var newsManager = NewsManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(newsManager.items) { item in
                        newsRow(item)
                        Divider().background(Color(red: 0.1, green: 0.1, blue: 0.15))
                    }
                }
                .padding(.top, 60)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Stäng") { dismiss() }
                    .foregroundColor(.white)
                    .font(.system(size: 13, design: .monospaced))
            }
        }
    }

    private func newsRow(_ item: NewsItem) -> some View {
        // Dödsfall visas med röd bakgrund och röd text; milstolpar i guld
        let isDeath      = item.category == .playerDeath
        let isMilestone  = item.category == .rankChange || item.category == .revolution

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.category.rawValue)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(item.categoryColor)
                    .tracking(2)
                if isDeath {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 9))
                        .foregroundColor(Color(red: 0.7, green: 0.05, blue: 0.05))
                }
                Spacer()
                Text("\(item.formattedDate) \(item.formattedTime)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
            }
            Text(item.headline)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(
                    isDeath     ? Color(red: 0.85, green: 0.1, blue: 0.1) :
                    isMilestone ? Color(red: 0.95, green: 0.82, blue: 0.2) :
                    .white
                )
                .lineLimit(2)
            Text(item.body)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(
                    isDeath     ? Color(red: 0.65, green: 0.15, blue: 0.15) :
                    isMilestone ? Color(red: 0.75, green: 0.65, blue: 0.2) :
                    Color(red: 0.6, green: 0.6, blue: 0.6)
                )
                .lineSpacing(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isDeath
                ? Color(red: 0.12, green: 0.02, blue: 0.02)
                : Color.clear
        )
    }
}

// MARK: - Kompakt nyhetsflöde (för dashboard-widget)

struct NewsFeedWidget: View {
    @ObservedObject private var newsManager = NewsManager.shared
    var maxItems: Int = 3

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("NYHETSFLÖDET")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                    .tracking(3)
                Spacer()
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.4, green: 0.8, blue: 0.4))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider().background(Color(red: 0.15, green: 0.15, blue: 0.2))

            ForEach(newsManager.items.prefix(maxItems)) { item in
                let isDeath     = item.category == .playerDeath
                let isMilestone = item.category == .rankChange || item.category == .revolution

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.category.rawValue)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(item.categoryColor)
                            .tracking(2)
                        if isDeath {
                            Image(systemName: "xmark.octagon.fill")
                                .font(.system(size: 8))
                                .foregroundColor(Color(red: 0.7, green: 0.05, blue: 0.05))
                        }
                        Spacer()
                        Text(item.formattedTime)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.4))
                    }
                    Text(item.headline)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(
                            isDeath     ? Color(red: 0.85, green: 0.1, blue: 0.1) :
                            isMilestone ? Color(red: 0.95, green: 0.82, blue: 0.2) :
                            .white
                        )
                        .lineLimit(1)
                    Text(item.body)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(
                            isDeath     ? Color(red: 0.65, green: 0.15, blue: 0.15) :
                            isMilestone ? Color(red: 0.75, green: 0.65, blue: 0.2) :
                            Color(red: 0.55, green: 0.55, blue: 0.55)
                        )
                        .lineLimit(2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isDeath
                        ? Color(red: 0.12, green: 0.02, blue: 0.02)
                        : Color.clear
                )

                if item.id != newsManager.items.prefix(maxItems).last?.id {
                    Divider().background(Color(red: 0.1, green: 0.1, blue: 0.14))
                }
            }

            if newsManager.items.isEmpty {
                Text("Inga händelser registrerade ännu.")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                    .padding(.vertical, 16)
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.15, green: 0.15, blue: 0.2), lineWidth: 1))
    }
}
