import SwiftUI

// MARK: - Daily Challenge View

struct DailyChallengeView: View {
    @ObservedObject private var challengeManager = ChallengeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LTScreenBackground(style: .neutral)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: LTSpacing.lg) {
                        if let challenge = challengeManager.todayChallenge {
                            currentChallengeCard(challenge)
                        } else {
                            noChallengeCard
                        }

                        completedChallengesSection
                    }
                    .padding(.top, LTSpacing.md)
                    .padding(.bottom, LTSpacing.scrollBottom)
                }
            }
            .navigationTitle("DAGLIG UTMANING")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Current Challenge Card

    private func currentChallengeCard(_ challenge: DailyChallenge) -> some View {
        VStack(spacing: LTSpacing.md) {
            // Header with category icon
            HStack {
                categoryIcon(for: challenge.category)
                Text(challenge.category.rawValue.uppercased())
                    .font(LTFont.caption())
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
                Spacer()
                if challenge.isCompleted {
                    Label("Klar", systemImage: "checkmark.circle.fill")
                        .font(LTFont.caption())
                        .foregroundColor(.green)
                }
            }

            // Title
            Text(challenge.title)
                .font(LTFont.displayTitle(24))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Description
            Text(challenge.description)
                .font(LTFont.body(14))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Progress bar
            VStack(spacing: LTSpacing.xs) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)

                        Capsule()
                            .fill(progressColor(for: challenge.category))
                            .frame(width: geo.size.width * challenge.progress, height: 8)
                            .shadow(color: progressColor(for: challenge.category).opacity(0.5), radius: 4)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(challenge.currentValue) / \(challenge.targetValue)")
                        .font(LTFont.caption())
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text("\(Int(challenge.progress * 100))%")
                        .font(LTFont.caption())
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Reward
            HStack {
                Label("Belöning", systemImage: "clock.fill")
                    .font(LTFont.caption())
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text(TimeEngine.shortFormatted(challenge.rewardSeconds))
                    .font(LTFont.heading(16))
                    .foregroundColor(.green)
            }

            // Claim button
            if challenge.isCompleted {
                Button {
                    challengeManager.claimReward()
                } label: {
                    HStack {
                        Image(systemName: "gift.fill")
                        Text("Hämta belöning")
                    }
                    .font(LTFont.button())
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LTSpacing.md)
                    .background(
                        LinearGradient(
                            colors: [.green, .green.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: LTRadius.sm))
                }
            }
        }
        .padding(LTSpacing.lg)
        .ltCard(color: progressColor(for: challenge.category), opacity: 0.08, radius: LTRadius.md, borderOpacity: 0.2)
    }

    // MARK: - No Challenge Card

    private var noChallengeCard: some View {
        VStack(spacing: LTSpacing.md) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("Ingen utmaning idag")
                .font(LTFont.heading(16))
                .foregroundColor(.white.opacity(0.6))

            Text("Starta om appen för att generera en ny utmaning")
                .font(LTFont.body(12))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding(LTSpacing.xl)
        .ltCard(color: .gray, opacity: 0.05, radius: LTRadius.md, borderOpacity: 0.1)
    }

    // MARK: - Completed Challenges Section

    private var completedChallengesSection: some View {
        VStack(alignment: .leading, spacing: LTSpacing.md) {
            Text("AVSLUTADE")
                .font(LTFont.caption())
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)

            if challengeManager.completedChallenges.isEmpty {
                Text("Inga avslutade utmaningar ännu")
                    .font(LTFont.body(12))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, LTSpacing.xl)
            } else {
                ForEach(challengeManager.completedChallenges.reversed().prefix(10)) { challenge in
                    completedChallengeRow(challenge)
                }
            }
        }
        .padding(LTSpacing.lg)
        .ltCard(color: .gray, opacity: 0.03, radius: LTRadius.sm, borderOpacity: 0.1)
    }

    private func completedChallengeRow(_ challenge: DailyChallenge) -> some View {
        HStack {
            categoryIcon(for: challenge.category)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(LTFont.body(12))
                    .foregroundColor(.white)
                Text(TimeEngine.shortFormatted(challenge.rewardSeconds))
                    .font(LTFont.caption())
                    .foregroundColor(.green.opacity(0.7))
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding(.vertical, LTSpacing.xs)
    }

    // MARK: - Helpers

    private func categoryIcon(for category: DailyChallenge.ChallengeCategory) -> some View {
        let icon: String
        let color: Color

        switch category {
        case .health:
            icon = "heart.fill"
            color = .red
        case .work:
            icon = "briefcase.fill"
            color = .blue
        case .casino:
            icon = "dice.fill"
            color = .purple
        case .social:
            icon = "bubble.left.and.bubble.right.fill"
            color = .cyan
        }

        return Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundColor(color)
    }

    private func progressColor(for category: DailyChallenge.ChallengeCategory) -> Color {
        switch category {
        case .health: return .red
        case .work: return .blue
        case .casino: return .purple
        case .social: return .cyan
        }
    }
}

// MARK: - Preview

#Preview {
    DailyChallengeView()
}
