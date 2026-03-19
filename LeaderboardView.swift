import SwiftUI

struct LeaderboardView: View {
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = false
    @State private var lastUpdated: Date? = nil

    struct LeaderboardEntry: Identifiable, Codable {
        let id: String
        let username: String
        let zoneID: String
        let balance: Double
        let rank: Int
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LTSpacing.md) {
                if let updated = lastUpdated {
                    Text("Uppdaterad: \(updated.formatted(.dateTime.hour().minute()))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(LTSpacing.xl)
                } else if entries.isEmpty {
                    Text("Ingen data tillgänglig.")
                        .foregroundStyle(.secondary)
                        .padding(LTSpacing.xl)
                } else {
                    ForEach(entries) { entry in
                        leaderboardRow(entry)
                    }
                }
            }
            .padding(LTSpacing.lg)
        }
        .navigationTitle("Topplista")
        .task { await fetchLeaderboard() }
        .refreshable { await fetchLeaderboard() }
    }

    private func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        HStack(spacing: LTSpacing.md) {
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

            Text(formatBalance(entry.balance))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(LTPalette.neonGreen)
        }
        .padding(.vertical, LTSpacing.sm)
        .padding(.horizontal, LTSpacing.md)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: LTRadius.xs))
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
        let urlString = "http://209.38.98.107:4000/api/leaderboard?zone=\(zone)&limit=20"
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            entries = try JSONDecoder().decode([LeaderboardEntry].self, from: data)
            lastUpdated = .now
            UserDefaults.standard.set(data, forKey: "cachedLeaderboard_\(zone)")
        } catch {
            if let cached = UserDefaults.standard.data(forKey: "cachedLeaderboard_\(zone)"),
               let decoded = try? JSONDecoder().decode([LeaderboardEntry].self, from: cached) {
                entries = decoded
            }
        }
    }
}
