import Foundation

/// A type that can turn a provider's on-disk logs into `UsageRecord`s.
public protocol UsageLogParser: Sendable {
    var provider: Provider { get }
    /// Returns every usage record found under `root`. Missing directories yield `[]`.
    func parse(root: URL) throws -> [UsageRecord]
}

/// Shared helpers for reading newline-delimited JSON logs line by line.
enum JSONL {
    /// Enumerates `*.jsonl` files under `root` (recursively) and calls `handler`
    /// once per non-empty line with the decoded top-level object.
    static func forEachLine(under root: URL,
                            handler: ([String: Any]) -> Void) {
        forEachFile(under: root) { url in
            forEachLine(inFile: url, handler: handler)
        }
    }

    /// Enumerates `*.jsonl` files under `root` (recursively), passing each file's
    /// URL to `handler`. Missing directories yield nothing.
    static func forEachFile(under root: URL, handler: (URL) -> Void) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return }

        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            handler(url)
        }
    }

    /// Streams one file so a multi-GB log never has to sit in memory at once.
    static func forEachLine(inFile url: URL,
                            handler: ([String: Any]) -> Void) {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        var buffer = Data()
        let newline = UInt8(ascii: "\n")

        func drain(_ complete: Bool) {
            while let idx = buffer.firstIndex(of: newline) {
                let lineData = buffer.subdata(in: buffer.startIndex..<idx)
                buffer.removeSubrange(buffer.startIndex...idx)
                decode(lineData, handler)
            }
            if complete, !buffer.isEmpty {
                decode(buffer, handler)
                buffer.removeAll()
            }
        }

        while case let chunk = handle.readData(ofLength: 1 << 20), !chunk.isEmpty {
            buffer.append(chunk)
            drain(false)
        }
        drain(true)
    }

    private static func decode(_ data: Data, _ handler: ([String: Any]) -> Void) {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data),
              let dict = object as? [String: Any] else { return }
        handler(dict)
    }
}

/// Lenient timestamp parsing: Claude/Codex logs use fractional-second ISO-8601,
/// but be forgiving about the fractional part and about epoch numbers.
enum TimestampParsing {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(from any: Any?) -> Date? {
        switch any {
        case let string as String:
            return withFraction.date(from: string) ?? plain.date(from: string)
        case let number as Double:
            // Heuristic: values past year ~2001 in seconds vs. milliseconds.
            return Date(timeIntervalSince1970: number > 5_000_000_000 ? number / 1000 : number)
        case let number as Int:
            return date(from: Double(number))
        default:
            return nil
        }
    }
}

// MARK: - Dictionary digging helpers

extension Dictionary where Key == String, Value == Any {
    func int(_ key: String) -> Int {
        switch self[key] {
        case let v as Int: return v
        case let v as Double: return Int(v)
        case let v as String: return Int(v) ?? 0
        default: return 0
        }
    }
    func string(_ key: String) -> String? { self[key] as? String }
    func dict(_ key: String) -> [String: Any]? { self[key] as? [String: Any] }
}
