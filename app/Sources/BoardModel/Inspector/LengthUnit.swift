import Foundation

/// The unit of the position and size fields. Points are the unit of the board; millimetres are for print;
/// pixels depend on the pixel scale of the frame (@1x to @3x).
public enum LengthUnit: String, CaseIterable, Sendable {
    case point, millimetre, pixel

    /// The key of the symbol in the string catalog, for example "unit.point".
    public var symbolKey: String { "unit.\(rawValue)" }

    /// Points per unit: one point is 1; one millimetre is 72 / 25.4 points; one pixel is 1 / scale points.
    public func pointsPerUnit(scale: Double = 1) -> Double {
        switch self {
        case .point: 1
        case .millimetre: 72 / 25.4
        case .pixel: 1 / scale
        }
    }

    public func value(points: Double, scale: Double = 1) -> Double { points / pointsPerUnit(scale: scale) }

    public func points(_ value: Double, scale: Double = 1) -> Double { value * pointsPerUnit(scale: scale) }

    /// The text of a value in a field: at most two decimals, written in the number style of `locale`.
    /// A value that rounds to zero is written as zero, never as "-0".
    public func text(points: Double, scale: Double = 1, locale: Locale = .current) -> String {
        let rounded = (value(points: points, scale: scale) * 100).rounded() / 100
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: rounded == 0 ? 0 : rounded)) ?? ""
    }

    /// The points that the text of a field means, or nil when the text is not a finite number.
    /// A dot and a comma both separate the decimals, whatever the locale, so "12.5" and "12,5" are equal.
    /// A unit written after the number ("10 mm", "10pt") wins over the unit of the field.
    public func points(from text: String, scale: Double = 1) -> Double? {
        var rest = text.trimmingCharacters(in: .whitespaces).lowercased()
        var unit = self
        for candidate in LengthUnit.allCases where rest.hasSuffix(candidate.suffix) {
            rest.removeLast(candidate.suffix.count)
            unit = candidate
            break
        }
        let number = rest.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !number.isEmpty, !number.contains(where: { $0.isWhitespace }),
              let value = Double(number), value.isFinite else { return nil }
        return unit.points(value, scale: scale)
    }

    /// The unit as it is written after a number in a field.
    private var suffix: String {
        switch self {
        case .point: "pt"
        case .millimetre: "mm"
        case .pixel: "px"
        }
    }
}
