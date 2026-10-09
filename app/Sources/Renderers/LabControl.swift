import Foundation

/// The value of a control: a colour as CSS writes it, or a number with its unit.
public enum LabValue: Equatable, Sendable {
    case colour(String)
    case number(Double, unit: String)

    /// The value as CSS writes it. Numbers drop trailing zeros.
    public var css: String {
        switch self {
        case .colour(let hex): hex
        case .number(let value, let unit): LabNumber.text(value) + unit
        }
    }

    /// The colour with six digits in lower case, as a colour well takes it. nil for a number.
    public var pickerHex: String? {
        guard case .colour(let hex) = self else { return nil }
        let digits = Array(hex.dropFirst())
        let six = digits.count == 3 ? digits.flatMap { [$0, $0] } : digits
        return "#" + String(six).lowercased()
    }
}

/// A control for one CSS variable of the code: a slider for a number, a colour well for a colour.
public struct LabControl: Equatable, Sendable, Identifiable {
    public var id: String { name }
    /// The name with its dashes, for example "--accent".
    public let name: String
    /// The value that the code had when the lab read it.
    public let initial: LabValue
    /// The value that the control shows now.
    public private(set) var value: LabValue
    /// The range of a slider. nil for a colour.
    public let range: ClosedRange<Double>?
    /// The step of a slider.
    public let step: Double

    public init(name: String, value: LabValue) {
        self.name = name
        self.initial = value
        self.value = value
        switch value {
        case .colour:
            range = nil
            step = 0
        case .number(let number, let unit):
            (range, step) = LabControls.slider(for: number, unit: unit)
        }
    }

    /// Whether the value differs from the code.
    public var isChanged: Bool { value.css != initial.css }

    /// Sets a number. Nothing changes for a colour control.
    public mutating func setNumber(_ number: Double) {
        guard case .number(_, let unit) = value else { return }
        value = .number(number, unit: unit)
    }

    /// Sets a colour. Nothing changes for a number control.
    public mutating func setColour(_ hex: String) {
        guard case .colour = value else { return }
        value = .colour(hex)
    }

    /// The same control with the value of `earlier`, when the code still declares the same initial value.
    func carrying(_ earlier: LabControl) -> LabControl {
        guard earlier.initial.css == initial.css else { return self }
        var copy = self
        copy.value = earlier.value
        return copy
    }
}

/// Reads the CSS variables of a draft as controls.
public enum LabControls {
    /// Most controls per draft. The first declarations win.
    public static let limit = 24

    /// The controls of the draft, in the order the code declares them. A name counts once, with its first value.
    /// Values that use var() are not controls.
    public static func read(_ draft: LabDraft) -> [LabControl] {
        let markup = draft.art == .react ? "" : draft.html
        let source = [draft.css, markup, draft.script].joined(separator: "\n")
        var result: [LabControl] = []
        // A declaration: the name with its dashes, then the value up to the end of the declaration.
        for match in source.matches(of: /(--[A-Za-z0-9_-]+)\s*:\s*([^;{}"'`\n]+)/) {
            guard result.count < limit else { break }
            let name = String(match.output.1)
            let raw = String(match.output.2).trimmingCharacters(in: .whitespaces)
            guard !result.contains(where: { $0.name == name }), !raw.contains("var(") else { continue }
            guard let value = value(of: raw) else { continue }
            result.append(LabControl(name: name, value: value))
        }
        return result
    }

    /// The value of one declaration: a three or six digit hex colour, or a number with an optional unit.
    static func value(of raw: String) -> LabValue? {
        if raw.wholeMatch(of: /#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})/) != nil { return .colour(raw) }
        if let match = raw.wholeMatch(of: /(-?\d*\.?\d+)(px|rem|em|%|s|ms|deg|vh|vw|fr)?/),
           let number = Double(String(match.output.1)) {
            return .number(number, unit: match.output.2.map(String.init) ?? "")
        }
        return nil
    }

    /// The range and the step of a slider for a number. The range holds the number, and the step is finer for fractions.
    static func slider(for number: Double, unit: String) -> (ClosedRange<Double>, Double) {
        let size = abs(number)
        let top: Double
        switch unit {
        case "%": top = 100
        case "deg": top = 360
        case "" where size <= 1: top = 1
        default: top = max(size * 3, fallbackTop(unit))
        }
        let bottom = number < 0 ? -max(top, size) : 0
        let fine = (unit.isEmpty && size <= 1) || ["rem", "em", "s"].contains(unit)
        return (bottom...max(top, size), fine ? 0.01 : 1)
    }

    private static func fallbackTop(_ unit: String) -> Double {
        switch unit {
        case "rem", "em": 4
        case "s": 3
        case "ms": 2000
        default: 64
        }
    }
}

/// Formats numbers as CSS shows them: whole numbers without a point, fractions with at most two digits.
enum LabNumber {
    static func text(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int(value))
        }
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}
