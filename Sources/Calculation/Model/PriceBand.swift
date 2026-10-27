import Foundation

struct PriceBand: Equatable, Sendable {
    let low: Decimal
    let expected: Decimal
    let high: Decimal
    let currency: String
}
