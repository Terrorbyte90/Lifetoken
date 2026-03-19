import SwiftUI

// MARK: - ZoneLoreView

struct ZoneLoreView: View {
    let zoneID: ZoneID

    @Environment(\.dismiss) private var dismiss

    private var lore: ZoneLoreData? { ZoneLore.data(for: zoneID) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let lore {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: LTSpacing.lg) {
                        ambientSection(lore)
                        npcSection(lore.zonalNPC)
                        eventsSection(lore)
                        proverbSection(lore.zonalProverb)
                        Spacer(minLength: LTSpacing.scrollBottom)
                    }
                    .padding(.horizontal, LTSpacing.horizontal)
                    .padding(.top, LTSpacing.lg)
                }
            } else {
                Text("Lore ej tillgänglig för denna zon.")
                    .font(LTFont.body(14))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .navigationTitle(lore.map { "LORE: \($0.zoneID.uppercased())" } ?? "LORE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Ambient

    private func ambientSection(_ lore: ZoneLoreData) -> some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            Text("ATMOSFÄR")
                .font(LTFont.caption(9))
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)

            Text(lore.ambientText)
                .font(LTFont.body(14))
                .foregroundColor(.white.opacity(0.75))
                .italic()
                .lineSpacing(5)
                .padding(LTSpacing.md)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: LTRadius.md)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }

    // MARK: - NPC

    private func npcSection(_ character: ZoneCharacter) -> some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            Text("LOKAL KONTAKT")
                .font(LTFont.caption(9))
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)

            HStack(spacing: LTSpacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.1))
                        .frame(width: 46, height: 46)
                        .overlay(Circle().stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.cyan.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(character.name)
                        .font(LTFont.heading(15))
                        .foregroundColor(.white)
                    Text(character.role.uppercased())
                        .font(LTFont.caption(9))
                        .foregroundColor(.cyan.opacity(0.7))
                        .tracking(1)
                }
                Spacer()
            }
            .padding(LTSpacing.md)
            .background(Color.cyan.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.md))
            .overlay(RoundedRectangle(cornerRadius: LTRadius.md).stroke(Color.cyan.opacity(0.15), lineWidth: 1))

            HStack(spacing: LTSpacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow.opacity(0.6))
                Text(character.secret)
                    .font(LTFont.body(12))
                    .foregroundColor(.yellow.opacity(0.7))
                    .italic()
            }
            .padding(.horizontal, LTSpacing.md)
            .padding(.vertical, LTSpacing.sm)
            .background(Color.yellow.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
        }
    }

    // MARK: - Historical Events

    private func eventsSection(_ lore: ZoneLoreData) -> some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            Text("HISTORIK")
                .font(LTFont.caption(9))
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)

            ForEach(Array(lore.historicalEvents.enumerated()), id: \.offset) { idx, event in
                let unlocked = ZoneLore.isUnlocked(zoneID: zoneID, day: event.dayOffset)
                loreEventRow(event: event, index: idx, unlocked: unlocked)
                    .onAppear {
                        if !unlocked {
                            ZoneLore.markUnlocked(zoneID: zoneID, day: event.dayOffset)
                        }
                    }
            }
        }
    }

    private func loreEventRow(event: LoreEvent, index: Int, unlocked: Bool) -> some View {
        HStack(alignment: .top, spacing: LTSpacing.md) {
            VStack(spacing: 0) {
                Circle()
                    .fill(unlocked ? Color.white.opacity(0.3) : Color.white.opacity(0.08))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: LTSpacing.xs) {
                Text(event.title.uppercased())
                    .font(LTFont.label(11))
                    .foregroundColor(unlocked ? .white : .white.opacity(0.25))
                    .tracking(1)

                if unlocked {
                    Text(event.body)
                        .font(LTFont.body(13))
                        .foregroundColor(.white.opacity(0.65))
                        .lineSpacing(4)
                } else {
                    Text("Lås upp dag \(event.dayOffset + 1)")
                        .font(LTFont.body(12))
                        .foregroundColor(.white.opacity(0.2))
                        .italic()
                }
            }
            .padding(.bottom, LTSpacing.md)
        }
    }

    // MARK: - Proverb

    private func proverbSection(_ proverb: String) -> some View {
        VStack(spacing: LTSpacing.sm) {
            Divider().background(Color.white.opacity(0.08))

            Text("\u{201E}\(proverb)\u{201C}")
                .font(LTFont.body(13))
                .foregroundColor(.white.opacity(0.35))
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, LTSpacing.md)
        }
    }
}
