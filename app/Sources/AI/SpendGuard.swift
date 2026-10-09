import Foundation

/// Estimates the cost of a request before it is sent and compares it with the monthly limit.
public enum SpendGuard {
    /// The side of an image tile in pixels, as the API counts image tokens.
    static let imageTileSide = 28
    /// Characters per estimated input token.
    static let charactersPerToken = 3

    /// Throws `AIError.limitStop` when spent plus the estimate would pass the limit. A missing or zero limit stops every call.
    public static func check(
        _ request: AIRequest,
        spent: Decimal,
        limit: Decimal?,
        prices: PriceTable,
        usdToEur: Decimal
    ) throws {
        guard let limit, limit > 0 else {
            throw AIError.limitStop(spent: spent, limit: 0)
        }
        let estimate = estimatedCost(request, prices: prices, usdToEur: usdToEur)
        if spent + estimate > limit {
            throw AIError.limitStop(spent: spent, limit: limit)
        }
    }

    /// The input tokens of a request: characters divided by three, rounded up, plus the tokens of each image.
    public static func estimatedInputTokens(_ request: AIRequest) -> Int {
        var characters = request.system.count
        var tokens = 0
        for message in request.messages {
            for block in message.blocks {
                switch block {
                case let .text(text):
                    characters += text.count
                case let .image(image):
                    tokens += imageTokens(width: image.width, height: image.height)
                }
            }
        }
        return (characters + charactersPerToken - 1) / charactersPerToken + tokens
    }

    /// The tokens of one image: width and height each rounded up to tiles of 28 pixels, then multiplied.
    public static func imageTokens(width: Int, height: Int) -> Int {
        ((width + imageTileSide - 1) / imageTileSide) * ((height + imageTileSide - 1) / imageTileSide)
    }

    /// The estimated cost in EUR. The output is counted at `maxTokens`, the most the call may return.
    public static func estimatedCost(_ request: AIRequest, prices: PriceTable, usdToEur: Decimal) -> Decimal {
        let usage = AIUsage(inputTokens: estimatedInputTokens(request), outputTokens: request.maxTokens)
        return AICost.compute(usage: usage, model: request.model, prices: prices, usdToEur: usdToEur)
    }
}
