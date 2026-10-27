import Foundation

extension Decimal {
    init(finite value: Double) {
        self = value.isFinite ? Decimal(value) : Decimal(0)
    }

    var double: Double { NSDecimalNumber(decimal: self).doubleValue }
}
