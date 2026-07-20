import SwiftUI
import Charts
import UsageCore

/// A labelled row like  "Today        $125.36 · 176.5M tokens".
struct StatRow: View {
    let label: String
    let totals: UsageTotals
    var emphasized: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(emphasized ? .callout.weight(.semibold) : .callout)
                .foregroundStyle(emphasized ? .primary : .secondary)
            Spacer(minLength: 12)
            Text(UsageFormatter.cost(totals.costUSD))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            Text(UsageFormatter.tokensLabeled(totals.usage.total))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// The daily-cost bar chart shown under "Usage Trend".
struct TrendChart: View {
    let trend: [DailyUsage]
    var tint: Color = .accentColor

    private var maxCost: Double {
        max(trend.map(\.totals.costUSD).max() ?? 0, 0.0001)
    }

    var body: some View {
        Chart(trend) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Cost", day.totals.costUSD)
            )
            .cornerRadius(1.5)
            .foregroundStyle(tint.gradient)
        }
        .chartYScale(domain: 0...maxCost)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 34)
    }
}

/// Optional "today vs. daily budget" meter. Only meaningful if the user sets a
/// budget in Settings; otherwise the caller hides it.
struct BudgetMeter: View {
    let spentToday: Double
    let dailyBudget: Double

    private var fraction: Double {
        guard dailyBudget > 0 else { return 0 }
        return min(spentToday / dailyBudget, 1)
    }

    private var barColor: Color {
        switch fraction {
        case ..<0.6: return .green
        case ..<0.85: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Daily budget")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(fraction * 100))% used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }
}

/// One provider's full card: header, trend chart, and the three stat rows.
struct ProviderCard: View {
    let summary: ProviderSummary
    var dailyBudget: Double = 0

    private var tint: Color {
        summary.provider == .claude ? .orange : .teal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(summary.provider.displayName)
                    .font(.headline)
                Spacer()
            }

            if dailyBudget > 0 {
                BudgetMeter(spentToday: summary.today.costUSD, dailyBudget: dailyBudget)
            }

            HStack(alignment: .center) {
                Text("Usage Trend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                TrendChart(trend: summary.dailyTrend, tint: tint)
                    .frame(width: 150)
            }

            VStack(spacing: 6) {
                StatRow(label: "Today", totals: summary.today, emphasized: true)
                StatRow(label: "Yesterday", totals: summary.yesterday)
                StatRow(label: "Last \(summary.dailyTrend.count) Days", totals: summary.last30Days)
            }

            if !summary.projects.isEmpty {
                Divider().padding(.vertical, 2)
                ProjectBreakdown(projects: summary.projects, tint: tint)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Top projects by cost over the trend window, each with a proportion bar.
struct ProjectBreakdown: View {
    let projects: [ProjectUsage]
    var tint: Color = .accentColor
    var maxRows: Int = 5

    private var shown: [ProjectUsage] { Array(projects.prefix(maxRows)) }
    private var maxCost: Double { max(projects.first?.totals.costUSD ?? 0, 0.0001) }
    private var overflow: Int { max(0, projects.count - maxRows) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("By Project")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(shown) { project in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(project.displayName)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(project.project)
                        Spacer(minLength: 8)
                        Text(UsageFormatter.cost(project.totals.costUSD))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                        Text(UsageFormatter.tokens(project.totals.usage.total))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.quaternary)
                            Capsule()
                                .fill(tint.opacity(0.8))
                                .frame(width: geo.size.width * (project.totals.costUSD / maxCost))
                        }
                    }
                    .frame(height: 3)
                }
            }

            if overflow > 0 {
                Text("+ \(overflow) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
