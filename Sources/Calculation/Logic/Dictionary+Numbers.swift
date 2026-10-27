import Core
import Foundation

public extension Dictionary where Key == String, Value == String {
    func decimal(_ key: String) -> Decimal {
        NumberParser.decimal(string(key)) ?? 0
    }

    func optionalDecimal(_ key: String) -> Decimal? {
        NumberParser.decimal(string(key))
    }

    func double(_ key: String) -> Double {
        let value = string(key)
        if let double = Double(value) { return double }
        return NumberParser.double(value) ?? 0
    }
}
