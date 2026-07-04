import Foundation

/// Presentation helpers so the CLI, menu bar, and widget all format numbers
/// identically (e.g. `$125.36`, `176.7M tokens`, `3.7B tokens`).
public enum UsageFormatter {

    /// Compact token count: 1_234 → "1.2K", 176_500_000 → "176.5M", 3.7e9 → "3.7B".
    public static func tokens(_ count: Int) -> String {
        let n = Double(count)
        switch abs(n) {
        case 1_000_000_000...:
            return trim(n / 1_000_000_000) + "B"
        case 1_000_000...:
            return trim(n / 1_000_000) + "M"
        case 1_000...:
            return trim(n / 1_000) + "K"
        default:
            return String(count)
        }
    }

    /// "176.5M tokens"
    public static func tokensLabeled(_ count: Int) -> String {
        tokens(count) + " tokens"
    }

    /// Currency with adaptive precision: amounts under $1,000 keep cents
    /// ("$125.36"), larger amounts compact to "$2.9K" like the reference apps.
    public static func cost(_ amount: Double) -> String {
        if abs(amount) >= 1_000 {
            return "$" + trim(amount / 1_000) + "K"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        // Pin the locale so "$" and grouping are stable regardless of system region.
        formatter.locale = Locale(identifier: "en_US")
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }

    /// "$125.36 · 176.5M tokens"
    public static func costAndTokens(_ totals: UsageTotals) -> String {
        "\(cost(totals.costUSD)) · \(tokensLabeled(totals.usage.total))"
    }

    /// Drops a trailing ".0" so "176.0" reads as "176".
    private static func trim(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}
