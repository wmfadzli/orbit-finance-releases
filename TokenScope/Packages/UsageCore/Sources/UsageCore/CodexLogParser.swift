import Foundation

/// Parses OpenAI Codex CLI session logs under `~/.codex/sessions/**/*.jsonl`.
///
/// ⚠️ Experimental. The Codex CLI log schema is not documented and has changed
/// between releases, so this parser scans defensively for a `token_count` /
/// `token_usage` payload rather than assuming an exact shape. If your Codex logs
/// look different, tweak `record(from:)` — the rest of the pipeline is identical
/// to the Claude path.
///
/// Observed shapes it handles:
/// ```json
/// {"type":"event_msg","payload":{"type":"token_count",
///   "info":{"total_token_usage":{"input_tokens":…,"output_tokens":…,"cached_input_tokens":…}}}}
/// {"timestamp":"…","type":"token_count",
///   "usage":{"input_tokens":…,"output_tokens":…,"cached_input_tokens":…},"model":"gpt-5"}
/// ```
public struct CodexLogParser: UsageLogParser {
    public let provider: Provider = .codex

    public init() {}

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/sessions")
    }

    public func parse(root: URL) throws -> [UsageRecord] {
        var records: [UsageRecord] = []
        JSONL.forEachLine(under: root) { line in
            guard let record = Self.record(from: line) else { return }
            records.append(record)
        }
        return records
    }

    static func record(from line: [String: Any]) -> UsageRecord? {
        // The usage block may be nested under `payload.info` or sit at the top level.
        let payload = line.dict("payload") ?? line
        let info = payload.dict("info") ?? payload

        // Prefer the per-turn delta. `total_token_usage` is a running cumulative
        // total for the whole session, so summing it across events would badly
        // overcount — only fall back to it when no delta field exists.
        guard let usageDict = info.dict("last_token_usage")
                ?? info.dict("token_usage")
                ?? info.dict("usage")
                ?? line.dict("usage")
                ?? info.dict("total_token_usage") else { return nil }

        let cached = usageDict["cached_input_tokens"] != nil
            ? usageDict.int("cached_input_tokens")
            : usageDict.int("cache_read_input_tokens")

        // Codex counts cached tokens inside input_tokens; split them out so we can
        // price the cache-read discount and avoid double counting the total.
        let rawInput = usageDict.int("input_tokens")
        let input = max(0, rawInput - cached)

        let usage = TokenUsage(
            inputTokens: input,
            outputTokens: usageDict.int("output_tokens"),
            cacheCreationTokens: 0,
            cacheReadTokens: cached
        )
        guard usage.total > 0 else { return nil }

        let timestamp = TimestampParsing.date(from: line["timestamp"])
            ?? TimestampParsing.date(from: payload["timestamp"])
            ?? Date(timeIntervalSince1970: 0)
        let model = info.string("model")
            ?? payload.string("model")
            ?? line.string("model")
            ?? "gpt-5"

        return UsageRecord(
            timestamp: timestamp,
            provider: .codex,
            model: model,
            usage: usage,
            dedupeKey: line.string("id") ?? payload.string("id")
        )
    }
}
