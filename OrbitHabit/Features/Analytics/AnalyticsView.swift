import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortIndex) private var habits: [Habit]

    private var metrics: HabitMetricsCalculator {
        HabitMetricsCalculator(calendar: environment.calendar)
    }

    private var weekRate: Double {
        metrics.overallCompletionRate(for: habits, endingAt: environment.now(), days: 7)
    }

    private var dailyRates: [Double] {
        metrics.datesEnding(at: environment.now(), count: 7).map { day in
            metrics.overallCompletionRate(for: habits, endingAt: day, days: 1)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    overallCard
                    habitBreakdown
                    trendSection
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppTheme.background)
            .navigationTitle("分析")
        }
    }

    private var overallCard: some View {
        OrbitCard {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今週の達成率")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(weekRate, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                }
                Spacer()
                OrbitProgressRing(progress: weekRate, color: AppTheme.accentColor)
                    .frame(width: 112, height: 112)
            }
        }
    }

    @ViewBuilder
    private var habitBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("習慣別")
                .font(.title3.weight(.bold))

            if habits.isEmpty {
                OrbitCard {
                    ContentUnavailableView(
                        "分析できる習慣がありません",
                        systemImage: "chart.bar.xaxis",
                        description: Text("今日タブから習慣を追加してください。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            } else {
                ForEach(habits) { habit in
                    HabitMetricRow(
                        habit: habit,
                        rate: metrics.completionRate(for: habit, endingAt: environment.now(), days: 7)
                    )
                }
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推移")
                .font(.title3.weight(.bold))
            OrbitCard {
                VStack(spacing: 10) {
                    MiniTrendChart(values: dailyRates)
                        .frame(height: 120)
                    HStack {
                        ForEach(metrics.datesEnding(at: environment.now(), count: 7), id: \.self) { date in
                            Text(date, format: .dateTime.weekday(.narrow))
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }
}

private struct HabitMetricRow: View {
    let habit: Habit
    let rate: Double

    var body: some View {
        OrbitCard {
            HStack(spacing: 12) {
                HabitIcon(name: habit.iconName, color: AppTheme.color(for: habit.accentToken))
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(habit.name)
                            .font(.headline)
                        Spacer()
                        Text(rate, format: .percent.precision(.fractionLength(0)))
                            .font(.headline)
                    }
                    ProgressView(value: rate)
                        .tint(AppTheme.color(for: habit.accentToken))
                }
            }
        }
    }
}

private struct MiniTrendChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let step = values.count > 1 ? width / CGFloat(values.count - 1) : width
            let points = values.enumerated().map { index, value in
                CGPoint(x: CGFloat(index) * step, y: height - (CGFloat(value) * height))
            }

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                }
                .stroke(AppTheme.secondaryText.opacity(0.5), lineWidth: 1)

                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(AppTheme.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(AppTheme.background)
                        .overlay(Circle().stroke(AppTheme.accentColor, lineWidth: 2))
                        .frame(width: 10, height: 10)
                        .position(point)
                }
            }
        }
        .accessibilityLabel("直近7日の達成率推移")
    }
}

#Preview {
    AnalyticsView()
        .modelContainer(PreviewContainer.shared)
        .environment(AppEnvironment.live)
        .preferredColorScheme(.dark)
}
