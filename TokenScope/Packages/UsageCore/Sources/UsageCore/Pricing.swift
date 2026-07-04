import Foundation

/// Per-million-token USD prices for one model.
public struct ModelPricing: Codable, Equatable, Sendable {
    public var inputPerMTok: Double
    public var outputPerMTok: Double
    public var cacheWritePerMTok: Double
    public var cacheReadPerMTok: Double

    public init(inputPerMTok: Double,
                outputPerMTok: Double,
                cacheWritePerMTok: Double,
                cacheReadPerMTok: Double) {
        self.inputPerMTok = inputPerMTok
        self.outputPerMTok = outputPerMTok
        self.cacheWritePerMTok = cacheWritePerMTok
        self.cacheReadPerMTok = cacheReadPerMTok
    }

    public func cost(for usage: TokenUsage) -> Double {
        let m = 1_000_000.0
        return Double(usage.inputTokens) / m * inputPerMTok
            + Double(usage.outputTokens) / m * outputPerMTok
            + Double(usage.cacheCreationTokens) / m * cacheWritePerMTok
            + Double(usage.cacheReadTokens) / m * cacheReadPerMTok
    }
}

/// Resolves a model id (e.g. "claude-opus-4-20250514") to prices.
///
/// Matching is done by substring so new dated snapshots keep working without a
/// code change. Prices can be overridden at runtime by dropping a JSON file at
/// `~/.config/tokenscope/pricing.json` shaped like `{"opus": {"inputPerMTok": …}}`.
public struct PricingTable: Sendable {
    /// Ordered longest-key-first so "haiku-4" beats "haiku".
    private let entries: [(key: String, pricing: ModelPricing)]
    private let fallback: ModelPricing

    public init(entries: [String: ModelPricing], fallback: ModelPricing) {
        self.entries = entries
            .sorted { $0.key.count > $1.key.count }
            .map { ($0.key.lowercased(), $0.value) }
        self.fallback = fallback
    }

    public func pricing(for model: String) -> ModelPricing {
        let m = model.lowercased()
        for entry in entries where m.contains(entry.key) {
            return entry.pricing
        }
        return fallback
    }

    public func cost(for usage: TokenUsage, model: String) -> Double {
        pricing(for: model).cost(for: usage)
    }

    /// Published Anthropic + OpenAI list prices (USD / million tokens).
    /// Cache-write assumes the default 5-minute TTL; cache-read is the discounted rate.
    public static let `default` = PricingTable(
        entries: [
            // ── Anthropic Claude ──────────────────────────────────────────
            "opus":         ModelPricing(inputPerMTok: 15,   outputPerMTok: 75,  cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50),
            "sonnet":       ModelPricing(inputPerMTok: 3,    outputPerMTok: 15,  cacheWritePerMTok: 3.75,  cacheReadPerMTok: 0.30),
            "haiku-3":      ModelPricing(inputPerMTok: 0.80, outputPerMTok: 4,   cacheWritePerMTok: 1.00,  cacheReadPerMTok: 0.08),
            "haiku":        ModelPricing(inputPerMTok: 1.00, outputPerMTok: 5,   cacheWritePerMTok: 1.25,  cacheReadPerMTok: 0.10),
            // ── OpenAI (Codex CLI) ────────────────────────────────────────
            // Cache-read = OpenAI "cached input"; there is no separate cache-write charge.
            "gpt-5-mini":   ModelPricing(inputPerMTok: 0.25, outputPerMTok: 2,   cacheWritePerMTok: 0.25,  cacheReadPerMTok: 0.025),
            "gpt-5":        ModelPricing(inputPerMTok: 1.25, outputPerMTok: 10,  cacheWritePerMTok: 1.25,  cacheReadPerMTok: 0.125),
            "o4-mini":      ModelPricing(inputPerMTok: 1.10, outputPerMTok: 4.40, cacheWritePerMTok: 1.10, cacheReadPerMTok: 0.275),
            "codex":        ModelPricing(inputPerMTok: 1.50, outputPerMTok: 6,   cacheWritePerMTok: 1.50,  cacheReadPerMTok: 0.375),
        ],
        // Unknown model → treat like a mid-tier Sonnet-class model rather than $0,
        // so an unrecognised id never silently reports zero cost.
        fallback: ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)
    )

    /// Loads user overrides from `~/.config/tokenscope/pricing.json` if present,
    /// merging them over the defaults. Returns `.default` when the file is absent
    /// or malformed.
    public static func loaded(overridePath: URL? = nil) -> PricingTable {
        let path = overridePath ?? FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".config/tokenscope/pricing.json")
        guard let data = try? Data(contentsOf: path),
              let overrides = try? JSONDecoder().decode([String: ModelPricing].self, from: data),
              !overrides.isEmpty else {
            return .default
        }
        var merged: [String: ModelPricing] = [
            "opus": ModelPricing(inputPerMTok: 15, outputPerMTok: 75, cacheWritePerMTok: 18.75, cacheReadPerMTok: 1.50),
            "sonnet": ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30),
            "haiku-3": ModelPricing(inputPerMTok: 0.80, outputPerMTok: 4, cacheWritePerMTok: 1.00, cacheReadPerMTok: 0.08),
            "haiku": ModelPricing(inputPerMTok: 1.00, outputPerMTok: 5, cacheWritePerMTok: 1.25, cacheReadPerMTok: 0.10),
            "gpt-5-mini": ModelPricing(inputPerMTok: 0.25, outputPerMTok: 2, cacheWritePerMTok: 0.25, cacheReadPerMTok: 0.025),
            "gpt-5": ModelPricing(inputPerMTok: 1.25, outputPerMTok: 10, cacheWritePerMTok: 1.25, cacheReadPerMTok: 0.125),
            "o4-mini": ModelPricing(inputPerMTok: 1.10, outputPerMTok: 4.40, cacheWritePerMTok: 1.10, cacheReadPerMTok: 0.275),
            "codex": ModelPricing(inputPerMTok: 1.50, outputPerMTok: 6, cacheWritePerMTok: 1.50, cacheReadPerMTok: 0.375),
        ]
        for (key, value) in overrides {
            merged[key.lowercased()] = value
        }
        return PricingTable(
            entries: merged,
            fallback: ModelPricing(inputPerMTok: 3, outputPerMTok: 15, cacheWritePerMTok: 3.75, cacheReadPerMTok: 0.30)
        )
    }
}
