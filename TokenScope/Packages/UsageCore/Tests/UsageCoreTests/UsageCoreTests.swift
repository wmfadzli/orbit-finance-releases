import XCTest
@testable import UsageCore

final class PricingTests: XCTestCase {
    func testOpusPricing() {
        let pricing = PricingTable.default
        // 1M input + 1M output on Opus = $15 + $75.
        let usage = TokenUsage(inputTokens: 1_000_000, outputTokens: 1_000_000)
        XCTAssertEqual(pricing.cost(for: usage, model: "claude-opus-4-20250514"), 90, accuracy: 1e-6)
    }

    func testCacheTokensPriced() {
        let pricing = PricingTable.default
        let usage = TokenUsage(cacheCreationTokens: 1_000_000, cacheReadTokens: 1_000_000)
        // Sonnet cache-write 3.75 + cache-read 0.30.
        XCTAssertEqual(pricing.cost(for: usage, model: "claude-sonnet-4"), 4.05, accuracy: 1e-6)
    }

    func testLongestKeyWins() {
        let pricing = PricingTable.default
        // "haiku-3" must beat the generic "haiku" entry.
        XCTAssertEqual(pricing.pricing(for: "claude-haiku-3-5").inputPerMTok, 0.80, accuracy: 1e-6)
        XCTAssertEqual(pricing.pricing(for: "claude-haiku-4-5").inputPerMTok, 1.00, accuracy: 1e-6)
    }

    func testUnknownModelUsesFallbackNotZero() {
        let pricing = PricingTable.default
        let usage = TokenUsage(inputTokens: 1_000_000)
        XCTAssertGreaterThan(pricing.cost(for: usage, model: "some-future-model"), 0)
    }
}

final class ClaudeParsingTests: XCTestCase {
    func testParsesAssistantUsageLine() {
        let line: [String: Any] = [
            "type": "assistant",
            "timestamp": "2025-06-30T12:34:56.789Z",
            "requestId": "req_1",
            "message": [
                "id": "msg_1",
                "model": "claude-opus-4-20250514",
                "usage": [
                    "input_tokens": 10,
                    "output_tokens": 20,
                    "cache_creation_input_tokens": 30,
                    "cache_read_input_tokens": 40,
                ],
            ],
        ]
        let record = ClaudeLogParser.record(from: line)
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.usage.total, 100)
        XCTAssertEqual(record?.model, "claude-opus-4-20250514")
        XCTAssertEqual(record?.dedupeKey, "msg_1#req_1")
    }

    func testSkipsNonAssistantAndEmptyLines() {
        XCTAssertNil(ClaudeLogParser.record(from: ["type": "user", "message": ["content": "hi"]]))
        XCTAssertNil(ClaudeLogParser.record(from: [
            "type": "assistant",
            "message": ["usage": ["input_tokens": 0, "output_tokens": 0]],
        ]))
    }
}

final class AggregatorTests: XCTestCase {
    private func makeNow() -> Date {
        // Fixed reference: 2025-06-30 18:00 UTC.
        DateComponents(calendar: .current, timeZone: TimeZone(identifier: "UTC"),
                       year: 2025, month: 6, day: 30, hour: 18).date!
    }

    func testTodayYesterdayBuckets() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let aggregator = UsageAggregator(pricing: .default, calendar: cal)

        let now = DateComponents(calendar: cal, year: 2025, month: 6, day: 30, hour: 18).date!
        let today = DateComponents(calendar: cal, year: 2025, month: 6, day: 30, hour: 9).date!
        let yesterday = DateComponents(calendar: cal, year: 2025, month: 6, day: 29, hour: 9).date!

        let records = [
            UsageRecord(timestamp: today, provider: .claude, model: "sonnet",
                        usage: TokenUsage(inputTokens: 1_000_000)),
            UsageRecord(timestamp: yesterday, provider: .claude, model: "sonnet",
                        usage: TokenUsage(inputTokens: 2_000_000)),
        ]
        let summary = aggregator.summarize(records, provider: .claude, now: now, trendDays: 30)

        XCTAssertEqual(summary.today.usage.inputTokens, 1_000_000)
        XCTAssertEqual(summary.yesterday.usage.inputTokens, 2_000_000)
        XCTAssertEqual(summary.last30Days.usage.inputTokens, 3_000_000)
        XCTAssertEqual(summary.dailyTrend.count, 30)
        XCTAssertEqual(summary.today.costUSD, 3, accuracy: 1e-6)   // 1M input * $3 sonnet
    }

    func testDeduplication() {
        let ts = Date()
        let records = [
            UsageRecord(timestamp: ts, provider: .claude, model: "sonnet",
                        usage: TokenUsage(inputTokens: 100), dedupeKey: "dupe"),
            UsageRecord(timestamp: ts, provider: .claude, model: "sonnet",
                        usage: TokenUsage(inputTokens: 100), dedupeKey: "dupe"),
        ]
        let deduped = UsageAggregator.deduplicate(records)
        XCTAssertEqual(deduped.count, 1)
    }

    func testTrendIsZeroFilledAndOrdered() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let aggregator = UsageAggregator(pricing: .default, calendar: cal)
        let now = DateComponents(calendar: cal, year: 2025, month: 6, day: 30, hour: 18).date!

        let summary = aggregator.summarize([], provider: .claude, now: now, trendDays: 7)
        XCTAssertEqual(summary.dailyTrend.count, 7)
        // Ascending by date.
        XCTAssertTrue(zip(summary.dailyTrend, summary.dailyTrend.dropFirst()).allSatisfy { $0.date < $1.date })
        XCTAssertTrue(summary.dailyTrend.allSatisfy { $0.totals.totalTokens == 0 })
    }
}

final class FormatterTests: XCTestCase {
    func testTokenFormatting() {
        XCTAssertEqual(UsageFormatter.tokens(999), "999")
        XCTAssertEqual(UsageFormatter.tokens(1_500), "1.5K")
        XCTAssertEqual(UsageFormatter.tokens(176_500_000), "176.5M")
        XCTAssertEqual(UsageFormatter.tokens(3_700_000_000), "3.7B")
    }

    func testCostFormatting() {
        XCTAssertEqual(UsageFormatter.cost(125.36), "$125.36")
        XCTAssertEqual(UsageFormatter.cost(2_900), "$2.9K")
        XCTAssertEqual(UsageFormatter.cost(12_000), "$12K")
    }
}

final class CodexParsingTests: XCTestCase {
    func testParsesNestedTokenCount() {
        let line: [String: Any] = [
            "type": "event_msg",
            "timestamp": "2025-06-30T10:00:00.000Z",
            "payload": [
                "type": "token_count",
                "info": [
                    "model": "gpt-5",
                    "last_token_usage": [
                        "input_tokens": 1_000,
                        "output_tokens": 500,
                        "cached_input_tokens": 400,
                    ],
                ],
            ],
        ]
        let record = CodexLogParser.record(from: line)
        XCTAssertNotNil(record)
        // cached tokens are split out of input: input 1000-400=600, cacheRead 400.
        XCTAssertEqual(record?.usage.inputTokens, 600)
        XCTAssertEqual(record?.usage.cacheReadTokens, 400)
        XCTAssertEqual(record?.usage.outputTokens, 500)
        XCTAssertEqual(record?.provider, .codex)
    }
}
