import Foundation

/// A property of a React component that the lab shows as a control: a slider, segments, a text field or a switch.
public struct LabProp: Equatable, Sendable, Identifiable {
    /// What the control takes.
    public enum Kind: Equatable, Sendable {
        /// A slider over `range`, moved in steps of `step`.
        case number(range: ClosedRange<Double>, step: Double)
        /// Texts to choose from, shown as segments.
        case choice([String])
        /// Any text.
        case text
        /// On or off.
        case flag
    }

    /// The value of a property.
    public enum Value: Equatable, Sendable {
        case number(Double)
        case text(String)
        case flag(Bool)
    }

    public var id: String { name }
    /// The name of the property, as the component destructures it.
    public let name: String
    public let kind: Kind
    /// The default value in the code.
    public let initial: Value
    /// The value that the control shows now.
    public private(set) var value: Value

    public init(name: String, kind: Kind, initial: Value) {
        self.name = name
        self.kind = kind
        self.initial = initial
        self.value = initial
    }

    /// Whether the value differs from the code.
    public var isChanged: Bool { value != initial }

    /// Sets the value when it fits the kind. A number is kept inside the range, and a text must be one of the choices.
    public mutating func set(_ new: Value) {
        switch (kind, new) {
        case (.number(let range, _), .number(let number)):
            value = .number(min(max(number, range.lowerBound), range.upperBound))
        case (.choice(let options), .text(let text)) where options.contains(text):
            value = new
        case (.text, .text), (.flag, .flag):
            value = new
        default:
            break
        }
    }
}
