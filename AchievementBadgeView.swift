import SwiftUI

// MARK: - Achievement Badge View

struct AchievementBadgeView: View {
    @ObservedObject private var achievementManager = AchievementManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: AchievementManager.Achievement.AchievementCategory? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LTScreenBackground(style: .neutral)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: LTSpacing.lg) {
                        statsHeader
                        categoryFilter
                        achievementsGrid
                    }
                    .padding(.top, LTSpacing.md)
                    .padding(.bottom, LTSpacing.scrollBottom)
                }
            }
            .navigationTitle("PRESTATIONER")
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

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(spacing: LTSpacing.md) {
            HStack(spacing: LTSpacing.xl) {
                VStack(spacing: LTSpacing.xs) {
                    Text("\(achievementManager.totalUnlocked)")
                        .font(LTFont.displayTitle(32))
                        .foregroundColor(.yellow)
                    Text("Låsta upp")
                        .font(LTFont.caption())
                        .foregroundColor(.white.opacity(0.4))
                }

                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.1))

                VStack(spacing: LTSpacing.xs) {
                    Text("\(achievementManager.achievements.count)")
                        .font(LTFont.displayTitle(32))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Totalt")
                        .font(LTFont.caption())
                        .foregroundColor(.white.opacity(0.4))
                }

                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.1))

                VStack(spacing: LTSpacing.xs) {
                    Text(TimeEngine.shortFormatted(achievementManager.totalEarned))
                        .font(LTFont.displayTitle(24))
                        .foregroundColor(.green)
                    Text("Tid tjänad")
                        .font(LTFont.caption())
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding( LTSpacing.lg)
        .ltCard(color: .yellow, opacity: 0.05, radius: LTRadius.md, borderOpacity: 0.15)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LTSpacing.sm) {
                categoryButton(nil, title: "Alla", icon: "square.grid.2x2.fill")

                ForEach(AchievementManager.Achievement.AchievementCategory.allCases, id: \.self) { category in
                    categoryButton(category, title: category.displayName, icon: category.icon)
                }
            }
            .padding(.horizontal, LTSpacing.md)
        }
    }

    private func categoryButton(_ category: AchievementManager.Achievement.AchievementCategory?, title: String, icon: String) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: LTSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(LTFont.caption())
            }
            .padding(.horizontal, LTSpacing.md)
            .padding(.vertical, LTSpacing.sm)
            .background(isSelected ? Color.yellow.opacity(0.2) : Color.white.opacity(0.05))
            .foregroundColor(isSelected ? .yellow : .white.opacity(0.6))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // MARK: - Achievements Grid

    private var achievementsGrid: some View {
        let filteredAchievements = selectedCategory == nil
            ? achievementManager.achievements
            : achievementManager.achievements.filter { $0.category == selectedCategory }

        let columns = [
            GridItem(.flexible(), spacing: LTSpacing.md),
            GridItem(.flexible(), spacing: LTSpacing.md)
        ]

        return LazyVGrid(columns: columns, spacing: LTSpacing.md) {
            ForEach(filteredAchievements) { achievement in
                achievementCard(achievement)
            }
        }
        .padding(.horizontal, LTSpacing.md)
    }

    private func achievementCard(_ achievement: Achievement) -> some View {
        VStack(spacing: LTSpacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? categoryColor(achievement.category).opacity(0.2) : Color.white.opacity(0.03))
                    .frame(width: 56, height: 56)

                Image(systemName: achievement.icon)
                    .font(.system(size: 24))
                    .foregroundColor(achievement.isUnlocked ? categoryColor(achievement.category) : .white.opacity(0.2))
            }

            // Title
            Text(achievement.title)
                .font(LTFont.body(12, weight: .semibold))
                .foregroundColor(achievement.isUnlocked ? .white : .white.opacity(0.5))
                .multilineTextAlignment(.center)

            // Description
            Text(achievement.description)
                .font(LTFont.caption())
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Reward
            if achievement.rewardSeconds > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                    Text(TimeEngine.shortFormatted(achievement.rewardSeconds))
                        .font(LTFont.caption())
                }
                .foregroundColor(achievement.isUnlocked ? .green : .white.opacity(0.3))
            }

            // Status
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.2))
            }
        }
        .padding(LTSpacing.md)
        .frame(maxWidth: .infinity)
        .ltCard(
            color: achievement.isUnlocked ? categoryColor(achievement.category) : .gray,
            opacity: achievement.isUnlocked ? 0.1 : 0.03,
            radius: LTRadius.sm,
            borderOpacity: achievement.isUnlocked ? 0.3 : 0.1
        )
    }

    // MARK: - Helpers

    private func categoryColor(_ category: AchievementManager.Achievement.AchievementCategory) -> Color {
        switch category {
        case .health: return .red
        case .work: return .blue
        case .casino: return .purple
        case .social: return .cyan
        case .survival: return .green
        case .special: return .yellow
        }
    }
}

// MARK: - Category Extension

extension AchievementManager.Achievement.AchievementCategory {
    var displayName: String {
        switch self {
        case .health: return "Hälsa"
        case .work: return "Arbete"
        case .casino: return "Kasino"
        case .social: return "Social"
        case .survival: return "Överlevnad"
        case .special: return "Special"
        }
    }

    var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .work: return "briefcase.fill"
        case .casino: return "dice.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .survival: return "heart.fill"
        case .special: return "star.fill"
        }
    }
}

// MARK: - CaseIterable for Category

extension AchievementManager.Achievement.AchievementCategory: CaseIterable {}

// MARK: - Preview

#Preview {
    AchievementBadgeView()
}
