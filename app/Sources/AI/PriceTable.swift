import Foundation

/// Prices of one model in USD per million tokens, for input and for output.
public struct PriceRates: Sendable, Equatable {
    public var input: Decimal
    public var output: Decimal

    public init(input: Decimal, output: Decimal) {
        self.input = input
        self.output = output
    }
}

/// The price of one model. Cache reads and writes are multiples of the input price.
public struct ModelPrice: Sendable, Equatable {
    /// The standard prices.
    public var rates: PriceRates
    /// The prices for prompts above `PriceTable.longPromptThreshold` input tokens, when they differ.
    public var longPrompt: PriceRates?
    /// The multiple of the input price for reading the cache.
    public var cacheReadMultiplier: Decimal
    /// The multiple of the input price for writing the cache.
    public var cacheWriteMultiplier: Decimal

    public init(
        rates: PriceRates,
        longPrompt: PriceRates? = nil,
        cacheReadMultiplier: Decimal = Decimal(string: "0.1") ?? 0,
        cacheWriteMultiplier: Decimal = Decimal(string: "1.25") ?? 1
    ) {
        self.rates = rates
        self.longPrompt = longPrompt
        self.cacheReadMultiplier = cacheReadMultiplier
        self.cacheWriteMultiplier = cacheWriteMultiplier
    }
}

/// The table of prices by model name. It can be replaced, because the prices come from a research note of 2026-10-08.
public struct PriceTable: Sendable, Equatable {
    /// Prompts with more input tokens than this use the long-prompt prices, when a model has them.
    public static let longPromptThreshold = 100_000

    public var prices: [String: ModelPrice]

    public init(prices: [String: ModelPrice]) {
        self.prices = prices
    }

    /// The prices of the research note. The cache multiples of Fable and the write multiple are not in that note.
    public static let standard = PriceTable(prices: [
        ModelID.fable: ModelPrice(rates: PriceRates(input: money("10"), output: money("50"))),
        ModelID.opus: ModelPrice(
            rates: PriceRates(input: money("4"), output: money("20")),
            cacheReadMultiplier: money("0.05")
        ),
        ModelID.sonnet: ModelPrice(
            rates: PriceRates(input: money("2"), output: money("10")),
            cacheReadMultiplier: money("0.05")
        ),
        ModelID.haiku: ModelPrice(
            rates: PriceRates(input: money("0.10"), output: money("0.50")),
            longPrompt: PriceRates(input: money("0.50"), output: money("2.50"))
        ),
    ])

    /// The price of a model. An unknown model costs the highest price of the table, so the estimate errs high.
    public func price(for model: String) -> ModelPrice {
        prices[model] ?? fallback
    }

    private var fallback: ModelPrice {
        var input = Decimal(0)
        var output = Decimal(0)
        var writeMultiplier = Decimal(0)
        for price in prices.values {
            input = max(input, price.rates.input, price.longPrompt?.input ?? 0)
            output = max(output, price.rates.output, price.longPrompt?.output ?? 0)
            writeMultiplier = max(writeMultiplier, price.cacheWriteMultiplier)
        }
        return ModelPrice(
            rates: PriceRates(input: input, output: output),
            cacheReadMultiplier: 1,
            cacheWriteMultiplier: writeMultiplier
        )
    }
}

/// The cost of one call. All arithmetic is in `Decimal`.
public enum AICost {
    /// The cost in EUR of one call with this usage.
    public static func compute(usage: AIUsage, model: String, prices: PriceTable, usdToEur: Decimal) -> Decimal {
        let price = prices.price(for: model)
        let promptTokens = usage.inputTokens + usage.cacheReadTokens + usage.cacheWriteTokens
        let rates: PriceRates
        if promptTokens > PriceTable.longPromptThreshold, let long = price.longPrompt {
            rates = long
        } else {
            rates = price.rates
        }

        let input = Decimal(usage.inputTokens) * rates.input
        let read = Decimal(usage.cacheReadTokens) * rates.input * price.cacheReadMultiplier
        let write = Decimal(usage.cacheWriteTokens) * rates.input * price.cacheWriteMultiplier
        let output = Decimal(usage.outputTokens) * rates.output
        let usd = (input + read + write + output) / Decimal(1_000_000)
        return usd * usdToEur
    }
}

/// A decimal price from its text. The text is always a valid number here.
func money(_ text: String) -> Decimal {
    Decimal(string: text) ?? 0
}
