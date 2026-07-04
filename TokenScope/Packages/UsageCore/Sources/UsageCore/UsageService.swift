import Foundation

/// Configuration for one provider: which parser to run and where its logs live.
public struct ProviderSource: Sendable {
    public var provider: Provider
    public var parser: UsageLogParser
    public var root: URL
    public var enabled: Bool

    public init(provider: Provider, parser: UsageLogParser, root: URL, enabled: Bool = true) {
        self.provider = provider
        self.parser = parser
        self.root = root
        self.enabled = enabled
    }

    public static func claude(root: URL = ClaudeLogParser.defaultRoot, enabled: Bool = true) -> ProviderSource {
        ProviderSource(provider: .claude, parser: ClaudeLogParser(), root: root, enabled: enabled)
    }

    public static func codex(root: URL = CodexLogParser.defaultRoot, enabled: Bool = true) -> ProviderSource {
        ProviderSource(provider: .codex, parser: CodexLogParser(), root: root, enabled: enabled)
    }
}

/// The one entry point the app and CLI call: read every enabled source and
/// return a fully-priced `UsageSnapshot`.
public struct UsageService: Sendable {
    public var sources: [ProviderSource]
    public var aggregator: UsageAggregator
    public var trendDays: Int

    public init(sources: [ProviderSource],
                pricing: PricingTable = .loaded(),
                trendDays: Int = 30) {
        self.sources = sources
        self.aggregator = UsageAggregator(pricing: pricing)
        self.trendDays = trendDays
    }

    /// Convenience: Claude enabled, Codex enabled only if its log dir exists.
    public static func standard(pricing: PricingTable = .loaded()) -> UsageService {
        let codexRoot = CodexLogParser.defaultRoot
        let codexExists = FileManager.default.fileExists(atPath: codexRoot.path)
        return UsageService(
            sources: [
                .claude(),
                .codex(root: codexRoot, enabled: codexExists),
            ],
            pricing: pricing
        )
    }

    /// Builds a snapshot as of `now`. Parser failures are isolated per provider:
    /// one bad source yields an empty summary rather than failing the whole load.
    public func snapshot(now: Date = Date()) -> UsageSnapshot {
        var summaries: [ProviderSummary] = []
        for source in sources where source.enabled {
            let records = (try? source.parser.parse(root: source.root)) ?? []
            let summary = aggregator.summarize(
                records,
                provider: source.provider,
                now: now,
                trendDays: trendDays
            )
            summaries.append(summary)
        }
        return UsageSnapshot(generatedAt: now, providers: summaries)
    }
}
