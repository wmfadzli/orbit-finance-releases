import Foundation

/// Parses Claude Code transcripts written under `~/.claude/projects/**/*.jsonl`.
///
/// Each assistant turn is a JSON line shaped roughly like:
/// ```json
/// {
///   "type": "assistant",
///   "timestamp": "2025-06-30T12:34:56.789Z",
///   "requestId": "req_…",
///   "message": {
///     "id": "msg_…",
///     "model": "claude-opus-4-20250514",
///     "usage": {
///       "input_tokens": 4,
///       "output_tokens": 250,
///       "cache_creation_input_tokens": 12000,
///       "cache_read_input_tokens": 20000
///     }
///   }
/// }
/// ```
/// The format has drifted across Claude Code versions, so every field is read
/// defensively and lines without a usage block are skipped.
public struct ClaudeLogParser: UsageLogParser {
    public let provider: Provider = .claude

    public init() {}

    /// Default location of Claude Code logs for the current user.
    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    public func parse(root: URL) throws -> [UsageRecord] {
        var records: [UsageRecord] = []

        JSONL.forEachLine(under: root) { line in
            guard let record = Self.record(from: line) else { return }
            records.append(record)
        }
        return records
    }

    /// Exposed for unit tests: turn one decoded log line into a record, or nil.
    static func record(from line: [String: Any]) -> UsageRecord? {
        // Only assistant turns carry usage; user/summary/system lines don't.
        if let type = line.string("type"), type != "assistant" { return nil }

        guard let message = line.dict("message"),
              let usageDict = message.dict("usage") else { return nil }

        let usage = TokenUsage(
            inputTokens: usageDict.int("input_tokens"),
            outputTokens: usageDict.int("output_tokens"),
            cacheCreationTokens: usageDict.int("cache_creation_input_tokens"),
            cacheReadTokens: usageDict.int("cache_read_input_tokens")
        )
        // Skip lines that decoded but carried no tokens at all.
        guard usage.total > 0 else { return nil }

        let timestamp = TimestampParsing.date(from: line["timestamp"]) ?? Date(timeIntervalSince1970: 0)
        let model = message.string("model") ?? line.string("model") ?? "unknown"

        // De-dup across resumed sessions: Claude Code replays earlier turns into
        // new transcript files. message.id + requestId uniquely identifies a real
        // API response (this mirrors ccusage's dedup strategy).
        let messageId = message.string("id")
        let requestId = line.string("requestId") ?? line.string("request_id")
        let dedupeKey: String? = {
            switch (messageId, requestId) {
            case let (m?, r?): return "\(m)#\(r)"
            case let (m?, nil): return m
            case let (nil, r?): return r
            default: return nil
            }
        }()

        return UsageRecord(
            timestamp: timestamp,
            provider: .claude,
            model: model,
            usage: usage,
            dedupeKey: dedupeKey
        )
    }
}
