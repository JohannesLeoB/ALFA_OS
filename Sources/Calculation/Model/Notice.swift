import Foundation

public struct Notice: Codable, Equatable, Sendable {
    public let key: String
    public let arguments: [String]

    public init(_ key: String, _ arguments: [String] = []) {
        self.key = key
        self.arguments = arguments
    }

    public init?(json: String) {
        guard let notice = try? JSONDecoder().decode(Notice.self, from: Data(json.utf8)) else { return nil }
        self = notice
    }

    public var json: String {
        guard let data = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static let sizeEstimated = Notice("size_estimated")
    static let sizeImplausible = Notice("size_implausible")

    static func amount(_ value: Decimal) -> String {
        let handler = NSDecimalNumberHandler(
            roundingMode: .bankers, scale: 0, raiseOnExactness: false,
            raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        return NSDecimalNumber(decimal: value).rounding(accordingToBehavior: handler).stringValue
    }

    static func fixed(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }

    static func measure(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }
}
