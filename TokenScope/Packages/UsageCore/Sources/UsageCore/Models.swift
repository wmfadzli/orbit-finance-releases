import Foundation

/// A source of token usage that TokenScope can read.
public enum Provider: String, Codable, CaseIterable, Sendable {
    case claude
    case codex

    public var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }
}

/// Raw token counts for a single API response.
public struct TokenUsage: Codable, Equatable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var cacheCreationTokens: Int
    public var cacheReadTokens: Int

    public init(inputTokens: Int = 0,
                outputTokens: Int = 0,
                cacheCreationTokens: Int = 0,
                cacheReadTokens: Int = 0) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
    }

    /// Total tokens across every category. This is what the menu bar reports as "tokens".
    public var total: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    public static let zero = TokenUsage()

    public static func + (lhs: TokenUsage, rhs: TokenUsage) -> TokenUsage {
        TokenUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            cacheCreationTokens: lhs.cacheCreationTokens + rhs.cacheCreationTokens,
            cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens
        )
    }

    public static func += (lhs: inout TokenUsage, rhs: TokenUsage) {
        lhs = lhs + rhs
    }
}

/// One assistant response parsed out of a provider log line.
public struct UsageRecord: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var provider: Provider
    public var model: String
    public var usage: TokenUsage
    /// A stable identity used to de-duplicate records that appear in more than
    /// one log file (Claude Code copies messages across resumed sessions).
    public var dedupeKey: String?
    /// The project this turn belongs to — the working directory (`cwd`) it ran
    /// in, or nil when the log didn't record one.
    public var project: String?

    public init(timestamp: Date,
                provider: Provider,
                model: String,
                usage: TokenUsage,
                dedupeKey: String? = nil,
                project: String? = nil) {
        self.timestamp = timestamp
        self.provider = provider
        self.model = model
        self.usage = usage
        self.dedupeKey = dedupeKey
        self.project = project
    }
}

/// Usage attributed to a single project (working directory) over a time window.
public struct ProjectUsage: Codable, Equatable, Sendable, Identifiable {
    /// Full project identifier (usually an absolute path).
    public var project: String
    public var totals: UsageTotals

    public var id: String { project }

    public init(project: String, totals: UsageTotals) {
        self.project = project
        self.totals = totals
    }

    /// The last path component, e.g. "/Users/me/dev/myapp" → "myapp".
    public var displayName: String {
        let trimmed = project.hasSuffix("/") ? String(project.dropLast()) : project
        let name = trimmed.split(separator: "/").last.map(String.init) ?? trimmed
        return name.isEmpty ? project : name
    }
}

/// Aggregated usage + computed cost for a set of records (a day, a provider, a range…).
public struct UsageTotals: Codable, Equatable, Sendable {
    public var usage: TokenUsage
    public var costUSD: Double

    public init(usage: TokenUsage = .zero, costUSD: Double = 0) {
        self.usage = usage
        self.costUSD = costUSD
    }

    public var totalTokens: Int { usage.total }

    public static func + (lhs: UsageTotals, rhs: UsageTotals) -> UsageTotals {
        UsageTotals(usage: lhs.usage + rhs.usage, costUSD: lhs.costUSD + rhs.costUSD)
    }

    public static func += (lhs: inout UsageTotals, rhs: UsageTotals) {
        lhs = lhs + rhs
    }
}

/// Usage for a single calendar day (in the user's local time zone).
public struct DailyUsage: Codable, Equatable, Sendable, Identifiable {
    public var date: Date          // start-of-day, local time
    public var totals: UsageTotals

    public var id: Date { date }

    public init(date: Date, totals: UsageTotals) {
        self.date = date
        self.totals = totals
    }
}

/// Everything the UI needs for one provider: rolling totals plus a daily trend.
public struct ProviderSummary: Codable, Equatable, Sendable, Identifiable {
    public var provider: Provider
    public var today: UsageTotals
    public var yesterday: UsageTotals
    public var last30Days: UsageTotals
    /// Oldest → newest daily buckets, suitable for a sparkline / bar chart.
    public var dailyTrend: [DailyUsage]
    /// Per-project usage over the trend window, sorted by cost (highest first).
    public var projects: [ProjectUsage]

    public var id: Provider { provider }

    public init(provider: Provider,
                today: UsageTotals = .init(),
                yesterday: UsageTotals = .init(),
                last30Days: UsageTotals = .init(),
                dailyTrend: [DailyUsage] = [],
                projects: [ProjectUsage] = []) {
        self.provider = provider
        self.today = today
        self.yesterday = yesterday
        self.last30Days = last30Days
        self.dailyTrend = dailyTrend
        self.projects = projects
    }
}

/// The full snapshot the app renders and shares with the widget.
public struct UsageSnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var providers: [ProviderSummary]

    public init(generatedAt: Date, providers: [ProviderSummary]) {
        self.generatedAt = generatedAt
        self.providers = providers
    }

    public static let empty = UsageSnapshot(generatedAt: .distantPast, providers: [])

    public func summary(for provider: Provider) -> ProviderSummary? {
        providers.first { $0.provider == provider }
    }
}
