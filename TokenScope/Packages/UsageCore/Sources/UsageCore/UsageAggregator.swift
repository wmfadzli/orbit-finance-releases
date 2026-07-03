import Foundation

/// Turns a flat list of `UsageRecord`s into a `ProviderSummary` (rolling totals
/// plus a per-day trend), pricing each record as it goes.
public struct UsageAggregator: Sendable {
    public let pricing: PricingTable
    public var calendar: Calendar

    public init(pricing: PricingTable = .default, calendar: Calendar = .current) {
        self.pricing = pricing
        self.calendar = calendar
    }

    /// - Parameters:
    ///   - records: records for a single provider (mixed providers are grouped by caller).
    ///   - now: reference "current time" (injectable for tests).
    ///   - trendDays: how many trailing days the sparkline should cover.
    public func summarize(_ records: [UsageRecord],
                          provider: Provider,
                          now: Date,
                          trendDays: Int = 30) -> ProviderSummary {
        let deduped = Self.deduplicate(records)

        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
        // last30Days window is inclusive of today, i.e. today plus the prior 29 days.
        let windowStart = calendar.date(byAdding: .day, value: -(trendDays - 1), to: startOfToday)!

        var perDay: [Date: UsageTotals] = [:]
        var today = UsageTotals()
        var yesterday = UsageTotals()
        var window = UsageTotals()

        for record in deduped {
            let cost = pricing.cost(for: record.usage, model: record.model)
            let totals = UsageTotals(usage: record.usage, costUSD: cost)
            let day = calendar.startOfDay(for: record.timestamp)

            if day >= windowStart {
                perDay[day, default: UsageTotals()] += totals
                window += totals
            }
            if day == startOfToday { today += totals }
            else if day == startOfYesterday { yesterday += totals }
        }

        // Emit a dense trend: one bucket per day in the window, zero-filled.
        var trend: [DailyUsage] = []
        trend.reserveCapacity(trendDays)
        for offset in 0..<trendDays {
            let day = calendar.date(byAdding: .day, value: offset, to: windowStart)!
            trend.append(DailyUsage(date: day, totals: perDay[day] ?? UsageTotals()))
        }

        return ProviderSummary(
            provider: provider,
            today: today,
            yesterday: yesterday,
            last30Days: window,
            dailyTrend: trend
        )
    }

    /// Drops records sharing a `dedupeKey`, keeping the first occurrence.
    /// Records without a key are always kept.
    static func deduplicate(_ records: [UsageRecord]) -> [UsageRecord] {
        var seen = Set<String>()
        var result: [UsageRecord] = []
        result.reserveCapacity(records.count)
        for record in records {
            if let key = record.dedupeKey {
                if seen.contains(key) { continue }
                seen.insert(key)
            }
            result.append(record)
        }
        return result
    }
}
