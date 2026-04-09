import SwiftUI
import Charts

// MARK: - Statistics View

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTimeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case day = "Idag"
        case week = "Vecka"
        case month = "Månad"
        case all = "Alltid"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LTScreenBackground(style: .neutral)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: LTSpacing.lg) {
                        timeRangeSelector
                        balanceChart
                        incomeExpenseSection
                        activityBreakdown
                        streakSection
                    }
                    .padding(.top, LTSpacing.md)
                    .padding(.bottom, LTSpacing.scrollBottom)
                }
            }
            .navigationTitle("STATISTIK")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { dismiss() }
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LTSpacing.sm) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTimeRange = range
                        }
                    } label: {
                        Text(range.rawValue)
                            .font(LTFont.footnote())
                            .padding(.horizontal, LTSpacing.md)
                            .padding(.vertical, LTSpacing.sm)
                            .background(selectedTimeRange == range ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                            .foregroundColor(selectedTimeRange == range ? .cyan : .white.opacity(0.6))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedTimeRange == range ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, LTSpacing.md)
        }
    }

    // MARK: - Balance Chart

    private var balanceChart: some View {
        VStack(alignment: .leading, spacing: LTSpacing.md) {
            Text("TIDSBALANS") // Time Balance
                .font(LTFont.caption())
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)

            Chart {
                ForEach(chartData, id: \.date) { item in
                    LineMark(
                        x: .value("Datum", item.date),
                        y: .value("Balans", item.balance)
                    )
                    .foregroundStyle(Color.cyan.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Datum", item.date),
                        y: .value("Balans", item.balance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.1))
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text(TimeEngine.shortFormatted(Double(intValue)))
                                .font(LTFont.caption())
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(LTSpacing.lg)
        .ltCard(color: .cyan, opacity: 0.05, radius: LTRadius.md, borderOpacity: 0.15)
    }

    // MARK: - Income/Expense Section

    private var incomeExpenseSection: some View {
        HStack(spacing: LTSpacing.md) {
            statCard(
                title: "TID FÖRTJÄNAD",
                value: TimeEngine.formatted(totalIncome),
                icon: "arrow.up.circle.fill",
                color: .green
            )

            statCard(
                title: "TID SPENDERAD",
                value: TimeEngine.formatted(totalExpense),
                icon: "arrow.down.circle.fill",
                color: .red
            )
        }
        .padding(.horizontal, LTSpacing.md)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: LTSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(LTFont.caption())
                    .foregroundColor(.white.opacity(0.4))
            }

            Text(value)
                .font(LTFont.displayTitle(24))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LTSpacing.md)
        .ltCard(color: color, opacity: 0.05, radius: LTRadius.sm, borderOpacity: 0.15)
    }

    // MARK: - Activity Breakdown

    private var activityBreakdown: some View {
        VStack(alignment: .leading, spacing: LTSpacing.md) {
            Text("AKTIVITETER") // Activities
                .font(LTFont.caption())
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)

            VStack(spacing: LTSpacing.sm) {
                activityRow(icon: "figure.walk", title: "Hälsa & Steg", hours: healthHours, color: .red)
                activityRow(icon: "briefcase.fill", title: "Arbete", hours: workHours, color: .blue)
                activityRow(icon: "dice.fill", title: "Kasino", hours: casinoHours, color: .purple)
                activityRow(icon: "cart.fill", title: "Marknad", hours: marketHours, color: .orange)
                activityRow(icon: "gift.fill", title: "Utmaningar", hours: challengeHours, color: .yellow)
            }
        }
        .padding(LTSpacing.lg)
        .ltCard(color: .gray, opacity: 0.05, radius: LTRadius.md, borderOpacity: 0.15)
        .padding(.horizontal, LTSpacing.md)
    }

    private func activityRow(icon: String, title: String, hours: Double, color: Color) -> some View {
        let percentage = totalHours > 0 ? hours / totalHours : 0

        return HStack(spacing: LTSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .font(LTFont.body(12))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(String(format: "%.1f h", hours))
                .font(LTFont.body(12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.6))
                        .frame(width: geometry.size.width * percentage, height: 4)
                }
            }
            .frame(width: 60, height: 4)
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: LTSpacing.md) {
            Text("STREAKS") // Streaks
                .font(LTFont.caption())
                .foregroundColor(.white.opacity(0.4))
                .tracking(2)

            HStack(spacing: LTSpacing.md) {
                streakCard(title: "Inloggning", days: loginStreak, icon: "flame.fill", color: .orange)
                streakCard(title: "Hälsa", days: healthStreak, icon: "heart.fill", color: .red)
                streakCard(title: "Arbete", days: workStreak, icon: "hammer.fill", color: .blue)
            }
        }
        .padding(LTSpacing.lg)
        .ltCard(color: .orange, opacity: 0.05, radius: LTRadius.md, borderOpacity: 0.15)
        .padding(.horizontal, LTSpacing.md)
    }

    private func streakCard(title: String, days: Int, icon: String, color: Color) -> some View {
        VStack(spacing: LTSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text("\(days)")
                .font(LTFont.displayTitle(28))
                .foregroundColor(.white)

            Text("dagar")
                .font(LTFont.caption())
                .foregroundColor(.white.opacity(0.4))

            Text(title)
                .font(LTFont.caption())
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(LTSpacing.md)
        .ltCard(color: color, opacity: 0.08, radius: LTRadius.sm, borderOpacity: 0.2)
    }

    // MARK: - Computed Properties

    private var chartData: [BalanceData] {
        // Generate sample data based on selected time range
        let calendar = Calendar.current
        let now = Date()

        switch selectedTimeRange {
        case .day:
            return (0..<24).map { hour in
                let date = calendar.date(byAdding: .hour, value: -hour, to: now)!
                return BalanceData(date: date, balance: Double.random(in: 3600...86400))
            }.reversed()
        case .week:
            return (0..<7).map { day in
                let date = calendar.date(byAdding: .day, value: -day, to: now)!
                return BalanceData(date: date, balance: Double.random(in: 3600...86400))
            }.reversed()
        case .month:
            return (0..<30).map { day in
                let date = calendar.date(byAdding: .day, value: -day, to: now)!
                return BalanceData(date: date, balance: Double.random(in: 3600...86400))
            }.reversed()
        case .all:
            return (0..<365).map { day in
                let date = calendar.date(byAdding: .day, value: -day, to: now)!
                return BalanceData(date: date, balance: Double.random(in: 3600...86400))
            }.reversed()
        }
    }

    private var totalIncome: TimeInterval {
        GameState.shared.totalEarned
    }

    private var totalExpense: TimeInterval {
        GameState.shared.totalSpent
    }

    private var totalHours: Double {
        healthHours + workHours + casinoHours + marketHours + challengeHours
    }

    private var healthHours: Double { 12.5 }
    private var workHours: Double { 8.0 }
    private var casinoHours: Double { 3.5 }
    private var marketHours: Double { 2.0 }
    private var challengeHours: Double { 1.5 }

    private var loginStreak: Int { GameState.shared.loginStreak }
    private var healthStreak: Int { 0 }
    private var workStreak: Int { 0 }
}

// MARK: - Supporting Types

struct BalanceData: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Double
}

// MARK: - Preview

#Preview {
    StatisticsView()
}
