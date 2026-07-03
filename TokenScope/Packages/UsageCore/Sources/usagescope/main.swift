import Foundation
import UsageCore

// A tiny terminal front-end for UsageCore. It exists to (a) let you verify the
// numbers the app will show without opening Xcode, and (b) serve as a runnable
// reference for how to drive the library.
//
//   swift run usagescope
//   swift run usagescope --json
//   swift run usagescope --days 14
//   swift run usagescope --claude-dir /path/to/.claude/projects

struct Options {
    var json = false
    var days = 30
    var claudeDir: URL = ClaudeLogParser.defaultRoot
    var codexDir: URL = CodexLogParser.defaultRoot
    var codexEnabled = FileManager.default.fileExists(atPath: CodexLogParser.defaultRoot.path)
}

func parseArgs(_ args: [String]) -> Options {
    var options = Options()
    var i = 0
    while i < args.count {
        switch args[i] {
        case "--json":
            options.json = true
        case "--days":
            i += 1
            if i < args.count, let d = Int(args[i]) { options.days = max(1, d) }
        case "--claude-dir":
            i += 1
            if i < args.count { options.claudeDir = URL(fileURLWithPath: args[i]) }
        case "--codex-dir":
            i += 1
            if i < args.count {
                options.codexDir = URL(fileURLWithPath: args[i])
                options.codexEnabled = true
            }
        case "--no-codex":
            options.codexEnabled = false
        case "-h", "--help":
            print("""
            usagescope — token usage from local Claude Code / Codex logs

            Usage: usagescope [options]
              --json               Emit the raw snapshot as JSON
              --days N             Trend window length (default 30)
              --claude-dir PATH    Override ~/.claude/projects
              --codex-dir PATH     Override ~/.codex/sessions (enables Codex)
              --no-codex           Skip Codex parsing
              -h, --help           Show this help
            """)
            exit(0)
        default:
            break
        }
        i += 1
    }
    return options
}

func sparkline(_ trend: [DailyUsage]) -> String {
    let blocks = Array("▁▂▃▄▅▆▇█")
    let values = trend.map { $0.totals.costUSD }
    guard let maxValue = values.max(), maxValue > 0 else {
        return String(repeating: "▁", count: trend.count)
    }
    return String(values.map { value -> Character in
        let idx = Int((value / maxValue) * Double(blocks.count - 1))
        return blocks[min(max(idx, 0), blocks.count - 1)]
    })
}

func printSummary(_ summary: ProviderSummary) {
    print("── \(summary.provider.displayName) " + String(repeating: "─", count: max(0, 40 - summary.provider.displayName.count)))
    print("  Trend       \(sparkline(summary.dailyTrend))")
    print("  Today       \(UsageFormatter.costAndTokens(summary.today))")
    print("  Yesterday   \(UsageFormatter.costAndTokens(summary.yesterday))")
    print("  Last \(summary.dailyTrend.count) Days \(UsageFormatter.costAndTokens(summary.last30Days))")
    print("")
}

let options = parseArgs(Array(CommandLine.arguments.dropFirst()))

let service = UsageService(
    sources: [
        .claude(root: options.claudeDir),
        .codex(root: options.codexDir, enabled: options.codexEnabled),
    ],
    trendDays: options.days
)
let snapshot = service.snapshot()

if options.json {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    if let data = try? encoder.encode(snapshot),
       let string = String(data: data, encoding: .utf8) {
        print(string)
    }
} else {
    print("")
    for summary in snapshot.providers where !summary.dailyTrend.isEmpty {
        printSummary(summary)
    }
    if snapshot.providers.allSatisfy({ $0.last30Days.totalTokens == 0 }) {
        print("No usage found. Checked:")
        print("  Claude: \(options.claudeDir.path)")
        if options.codexEnabled { print("  Codex:  \(options.codexDir.path)") }
        print("Is Claude Code installed and used on this machine?")
    }
}
