import SwiftUI

struct GazetteView: View {
    @StateObject private var engine = EventEngine.shared
    @State private var shareImage: UIImage? = nil
    @State private var showShareSheet = false

    private var todaysEvents: [GameEvent] {
        engine.recentEvents
            .filter { Calendar.current.isDateInToday($0.occurredAt) }
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    var body: some View {
        ZStack {
            LTScreenBackground(style: .neutral).ignoresSafeArea()

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

                    LTInfoCallout(
                        title: "Dagens rapport",
                        message: "Gazette visar händelser från idag i din världstid. Senaste händelser ligger högst upp.",
                        icon: "newspaper.fill",
                        tint: LTPalette.neonGreen
                    )

                    if todaysEvents.isEmpty {
                        LTEmptyStateCard(
                            icon: "clock.badge.questionmark",
                            title: "Inga händelser ännu",
                            message: "När spelhändelser inträffar idag visas de här med tid och zon.",
                            tint: LTPalette.neonGreen
                        )
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
                        .padding(.top, LTSpacing.sm)
                    }
                }
                .padding(LTSpacing.lg)
                .padding(.bottom, LTSpacing.scrollBottom)
            }
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: LTSpacing.xs) {
                    Text(event.headlineTemplate.uppercased())
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                    HStack(spacing: LTSpacing.sm) {
                        LTStatPill(
                            icon: "clock.fill",
                            text: event.occurredAt.formatted(.dateTime.hour().minute()),
                            tint: .white.opacity(0.8)
                        )
                        LTStatPill(
                            icon: "location.fill",
                            text: event.zoneID.capitalized,
                            tint: LTPalette.neonGreen
                        )
                    }
                }
                Spacer(minLength: LTSpacing.md)
                Text(event.occurredAt, style: .relative)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Rectangle().frame(height: 0.5).foregroundStyle(.secondary.opacity(0.3))
        }
        .padding(LTSpacing.md)
        .ltCard(color: LTPalette.neonGreen, opacity: 0.04, radius: LTRadius.sm, borderOpacity: 0.15)
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
