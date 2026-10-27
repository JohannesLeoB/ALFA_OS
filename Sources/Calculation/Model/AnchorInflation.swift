import Foundation

enum AnchorInflation {
    static let annualRate = 0.04
    static let maxYears = 6

    static func year(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let digits = Array(raw)
        for start in 0...(max(0, digits.count - 4)) where start + 4 <= digits.count {
            let window = digits[start..<start + 4]
            guard window.allSatisfy(\.isNumber) else { continue }
            let value = Int(String(window)) ?? 0
            if value >= 1900 && value <= 2100 { return value }
        }
        return nil
    }

    static func factor(offerYear: Int?, referenceYear: Int) -> Decimal {
        guard let offerYear, offerYear < referenceYear else { return 1 }
        let years = min(referenceYear - offerYear, maxYears)
        let grown = pow(1 + annualRate, Double(years))
        return Decimal(grown)
    }

    static func confidenceFactor(offerYear: Int?, referenceYear: Int) -> Double {
        guard let offerYear else { return 0.7 }
        let years = max(0, min(referenceYear - offerYear, maxYears))
        return max(0.55, 1 - Double(years) * 0.06)
    }
}
