import SwiftUI

struct GazetteView: View {
    @StateObject private var engine = EventEngine.shared
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false

    private var todaysEvents: [GameEvent] {
        engine.recentEvents.filter {
            Calendar.current.isDateInToday($0.occurredAt)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LTSpacing.xl) {
                // Header
                VStack(alignment: .leading, spacing: LTSpacing.xs) {
                    Text("LIFETOKEN GAZETTE")
                        .font(LTFont.displayTitle())
                        .foregroundStyle(LTPalette.neonGreen)
                    Text(Date.now.formatted(.dateTime.day().month(.wide).year()))
                        .font(LTFont.body())
                        .foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(LTPalette.neonGreen)
                }

                if todaysEvents.isEmpty {
                    Text("Inga händelser att rapportera idag. Klockan tickar.")
                        .font(LTFont.body())
                        .foregroundStyle(.secondary)
                        .padding(.vertical, LTSpacing.xl)
                } else {
                    ForEach(todaysEvents, id: \.eventID) { event in
                        GazetteArticleRow(event: event)
                    }
                }

                // Share button
                if let topEvent = todaysEvents.first {
                    Button {
                        renderAndShare(event: topEvent)
                    } label: {
                        Label("Dela dagens Gazette", systemImage: "square.and.arrow.up")
                            .font(LTFont.body())
                            .foregroundStyle(LTPalette.neonGreen)
                            .frame(maxWidth: .infinity)
                            .padding(LTSpacing.md)
                            .overlay(RoundedRectangle(cornerRadius: LTRadius.sm).stroke(LTPalette.neonGreen))
                    }
                }
            }
            .padding(LTSpacing.lg)
        }
        .navigationTitle("Gazette")
        .sheet(isPresented: $showShareSheet) {
            if let img = shareImage {
                ShareSheet(activityItems: [img])
            }
        }
    }

    private func renderAndShare(event: GameEvent) {
        let card = GazetteShareCard(
            headline: event.headlineTemplate,
            ingress: "Händelsen inträffade i \(event.zoneID.capitalized) klockan \(event.occurredAt.formatted(.dateTime.hour().minute())).",
            playerName: GameState.shared.username,
            date: event.occurredAt,
            accentColor: LTPalette.neonGreen
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        shareImage = renderer.uiImage
        showShareSheet = true
    }
}

// MARK: - Article Row

struct GazetteArticleRow: View {
    let event: GameEvent
    var body: some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            Text(event.headlineTemplate.uppercased())
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
            Text(event.occurredAt.formatted(.dateTime.hour().minute()))
                .font(LTFont.body())
                .foregroundStyle(.secondary)
            Rectangle().frame(height: 0.5).foregroundStyle(.secondary.opacity(0.3))
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
