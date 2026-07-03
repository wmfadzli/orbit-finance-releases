import WidgetKit
import SwiftUI
import Charts
import UsageCore

// MARK: - Timeline

struct UsageEntry: TimelineEntry {
    let date: Date
    let summary: ProviderSummary?
}

struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), summary: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let current = entry()
        // Refresh roughly every 15 minutes; the app also nudges us on each reload.
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: current.date) ?? current.date
        completion(Timeline(entries: [current], policy: .after(next)))
    }

    private func entry() -> UsageEntry {
        let snapshot = SharedUsageStore.read()
        return UsageEntry(date: Date(), summary: snapshot?.summary(for: .claude))
    }

    static let sample = ProviderSummary(
        provider: .claude,
        today: UsageTotals(usage: TokenUsage(inputTokens: 176_500_000), costUSD: 125.36),
        yesterday: UsageTotals(usage: TokenUsage(inputTokens: 165_100_000), costUSD: 111.88),
        last30Days: UsageTotals(usage: TokenUsage(inputTokens: 3_700_000_000), costUSD: 2_900),
        dailyTrend: (0..<30).map { i in
            DailyUsage(
                date: Calendar.current.date(byAdding: .day, value: -29 + i, to: Date()) ?? Date(),
                totals: UsageTotals(costUSD: Double((i * 7 + 13) % 40) + 5)
            )
        }
    )
}

// MARK: - Views

struct TokenScopeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            small
        default:
            medium
        }
    }

    private var summary: ProviderSummary? { entry.summary }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Today", systemImage: "gauge.with.dots.needle.33percent")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(UsageFormatter.cost(summary?.today.costUSD ?? 0))
                .font(.title2.weight(.bold))
                .minimumScaleFactor(0.6)
            Text(UsageFormatter.tokensLabeled(summary?.today.usage.total ?? 0))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            sparkline
        }
        .padding(12)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(summary?.provider.displayName ?? "Claude",
                      systemImage: "gauge.with.dots.needle.33percent")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("Today")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(UsageFormatter.cost(summary?.today.costUSD ?? 0))
                    .font(.title.weight(.bold))
                Text(UsageFormatter.tokensLabeled(summary?.today.usage.total ?? 0))
                    .font(.caption).foregroundStyle(.secondary)
            }
            sparkline.frame(height: 40)
            HStack {
                metric("Yesterday", summary?.yesterday)
                Spacer()
                metric("Last 30d", summary?.last30Days)
            }
        }
        .padding(14)
    }

    private func metric(_ label: String, _ totals: UsageTotals?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(UsageFormatter.cost(totals?.costUSD ?? 0))
                .font(.caption.weight(.semibold)).monospacedDigit()
        }
    }

    @ViewBuilder private var sparkline: some View {
        if let trend = summary?.dailyTrend, !trend.isEmpty {
            Chart(trend) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Cost", day.totals.costUSD)
                )
                .cornerRadius(1)
                .foregroundStyle(Color.orange.gradient)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
        } else {
            Color.clear
        }
    }
}

// MARK: - Widget

struct TokenScopeWidget: Widget {
    let kind = "TokenScopeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageProvider()) { entry in
            TokenScopeWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Token Usage")
        .description("Today's Claude Code spend and a 30-day trend.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct TokenScopeWidgetBundle: WidgetBundle {
    var body: some Widget {
        TokenScopeWidget()
    }
}
