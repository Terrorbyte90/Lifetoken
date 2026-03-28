import SwiftUI

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var lastUpdated: Date? = nil
    @State private var dataSourceLabel: String = "Server"
    @State private var loadErrorMessage: String? = nil

    struct LeaderboardEntry: Identifiable, Codable {
        let id: String
        let username: String
        let zoneID: String
        let balance: Double
        let rank: Int
    }

    var body: some View {
        ZStack {
            LTScreenBackground(style: .social).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LTSpacing.md) {
                    LTInfoCallout(
                        title: "Zonrankning",
                        message: "Visar topp 20 i \(GameState.shared.currentZone.name.capitalized). Källa: \(dataSourceLabel). Endast ditt saldo visas öppet.",
                        icon: "chart.bar.fill",
                        tint: .green
                    )

                    HStack(spacing: LTSpacing.sm) {
                        if let updated = lastUpdated {
                            LTStatPill(icon: "clock.fill", text: updated.formatted(.dateTime.hour().minute()), tint: .white.opacity(0.8))
                        }
                        LTStatPill(icon: "externaldrive.connected.to.line.below.fill", text: dataSourceLabel, tint: dataSourceLabel == "Server" ? .green : .orange)
                    }

                    if let loadErrorMessage {
                        LTInfoCallout(
                            title: "Anslutning",
                            message: loadErrorMessage,
                            icon: "wifi.exclamationmark",
                            tint: .orange
                        )
                    }

                    if isLoading {
                        VStack(spacing: LTSpacing.sm) {
                            ForEach(0..<5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: LTRadius.xs)
                                    .fill(Color.white.opacity(0.05))
                                    .frame(height: 52)
                                    .overlay(LTShimmerView().clipShape(RoundedRectangle(cornerRadius: LTRadius.xs)))
                            }
                        }
                        .padding(.top, LTSpacing.xs)
                    } else if entries.isEmpty {
                        LTEmptyStateCard(
                            icon: "person.3.sequence.fill",
                            title: "Ingen topplista tillgänglig",
                            message: "Kunde inte hämta ranking för din zon just nu. Dra ner för att uppdatera när anslutningen är tillbaka.",
                            tint: .white
                        )
                    } else {
                        ForEach(entries) { entry in
                            leaderboardRow(entry)
                        }
                    }
                }
                .padding(LTSpacing.lg)
                .padding(.bottom, LTSpacing.scrollBottom)
            }
        }
        .navigationTitle("Topplista")
        .task { await fetchLeaderboard() }
        .refreshable { await fetchLeaderboard() }
    }

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        // Dölj saldon för andra spelare — visa bara eget saldo
        let myUsername = UserDefaults.standard.string(forKey: "username") ?? ""
        let balanceText = entry.username == myUsername ? formatBalance(entry.balance) : "???"

        return HStack(spacing: LTSpacing.md) {
            Text("#\(entry.rank)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(entry.rank <= 3 ? LTPalette.gold : .secondary)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.username)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(entry.zoneID.capitalized)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(balanceText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(entry.username == myUsername ? LTPalette.neonGreen : Color.white.opacity(0.3))
        }
        .padding(.vertical, LTSpacing.sm)
        .padding(.horizontal, LTSpacing.md)
        .ltCard(color: entry.rank <= 3 ? LTPalette.gold : .white, opacity: 0.05, radius: LTRadius.xs, borderOpacity: 0.16)
    }

    private func formatBalance(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }

    private func fetchLeaderboard() async {
        isLoading = true
        defer { isLoading = false }
        let zone = GameState.shared.currentZone.name
        do {
            let users = try await ServerSync.shared.fetchZoneLeaderboard(zone: zone, limit: 20)
            entries = users.enumerated().map { index, user in
                LeaderboardEntry(
                    id: user.id,
                    username: user.username,
                    zoneID: user.zone,
                    balance: user.timeBalance ?? 0,
                    rank: index + 1
                )
            }
            loadErrorMessage = nil
            dataSourceLabel = "Server"
            lastUpdated = .now
            if let data = try? JSONEncoder().encode(entries) {
                UserDefaults.standard.set(data, forKey: "cachedLeaderboard_\(zone)")
            }
        } catch {
            if let cached = UserDefaults.standard.data(forKey: "cachedLeaderboard_\(zone)"),
               let decoded = try? JSONDecoder().decode([LeaderboardEntry].self, from: cached) {
                entries = decoded
                dataSourceLabel = "Cache"
                loadErrorMessage = "Visar senast sparad topplista eftersom servern inte svarade."
                lastUpdated = .now
            } else {
                entries = []
                dataSourceLabel = "Ingen data"
                loadErrorMessage = "Kunde inte nå servern och ingen cache hittades."
            }
        }
    }
}
