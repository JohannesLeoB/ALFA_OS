import Foundation

/// The unit of the position and size fields. Points are the unit of the board; millimetres are for print.
public enum LengthUnit: String, CaseIterable, Sendable {
    case point, millimetre

    /// The key of the symbol in the string catalog, for example "unit.point".
    public var symbolKey: String { "unit.\(rawValue)" }

    /// Points per unit: one point is 1; one millimetre is 72 / 25.4 points.
    public var pointsPerUnit: Double {
        switch self {
        case .point: 1
        case .millimetre: 72 / 25.4
        }
    }

    public func value(points: Double) -> Double { points / pointsPerUnit }

    public func points(_ value: Double) -> Double { value * pointsPerUnit }

    /// The text of a value in a field: at most two decimals, written in the number style of `locale`.
    public func text(points: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value(points: points))) ?? ""
    }

    /// The points that the text of a field means, or nil when the text is not a finite number.
    public func points(from text: String, locale: Locale = .current) -> Double? {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        guard let number = formatter.number(from: text.trimmingCharacters(in: .whitespaces)),
              number.doubleValue.isFinite else { return nil }
        return points(number.doubleValue)
    }
}
