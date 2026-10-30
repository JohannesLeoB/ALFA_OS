import Foundation

public enum UsageEngine {
    static let million = 1_000_000.0
    static let secondsPerDay = 86_400.0

    public static func price(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    public static func estimate(_ totals: UsageTotals, input: String, output: String) -> Double? {
        guard let inputPrice = price(input), let outputPrice = price(output) else { return nil }
        let cost = Double(totals.input) / million * inputPrice + Double(totals.output) / million * outputPrice
        return (cost * 2).rounded() / 2
    }

    public static func days(since: Date, now: Date) -> Int {
        max(0, Int((now.timeIntervalSince(since) / secondsPerDay).rounded(.down)))
    }

    public static func scaled(_ tokens: Int) -> (amount: String, millions: Bool) {
        let value = Double(tokens)
        if value >= million { return (String(format: "%.1f", locale: Locale(identifier: "de"), value / million), true) }
        return (String(Int((value / 1000).rounded())), false)
    }

    public static func money(_ amount: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "de"), amount)
    }
}
