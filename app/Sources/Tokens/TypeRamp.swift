import Foundation

/// The six steps of a type ramp, from title to mono. Each step is a `typography` token at ["type", step].
/// Sizes: base × factor^exponent, rounded to whole points. Mono sits one step above the text size, so all six sizes differ.
public enum TypeStep: String, Codable, CaseIterable, Sendable {
    case title, heading, subheading, mono, text, small

    /// The power of the factor for the size of this step.
    public var exponent: Int {
        switch self {
        case .title: 4
        case .heading: 3
        case .subheading: 2
        case .mono: 1
        case .text: 0
        case .small: -1
        }
    }

    public var isMono: Bool { self == .mono }

    /// Defaults for weight and line height. Placeholders until the design contract gives the values.
    var weight: Int {
        switch self {
        case .title, .heading: 700
        case .subheading: 600
        case .mono, .text, .small: 400
        }
    }

    var lineHeight: Double {
        switch self {
        case .title: 1.2
        case .heading: 1.25
        case .subheading: 1.3
        case .small: 1.4
        case .mono, .text: 1.5
        }
    }
}

/// Where a ramp token comes from: its step, the base and factor it was made with, and whether its size was set by hand.
public struct RampMark: Codable, Hashable, Sendable {
    public var step: TypeStep
    public var base: Double
    public var factor: Double
    public var overridden: Bool

    public init(step: TypeStep, base: Double, factor: Double, overridden: Bool) {
        self.step = step; self.base = base; self.factor = factor; self.overridden = overridden
    }
}

/// The inputs of a ramp: base size and factor in px, and the families of the text and mono steps.
public struct TypeRampSpec: Equatable, Sendable {
    public var base: Double
    public var factor: Double
    public var textFamilies: [String]
    public var monoFamilies: [String]

    public init(base: Double = 16, factor: Double = 1.25, textFamilies: [String] = ["sans-serif"], monoFamilies: [String] = ["monospace"]) {
        self.base = base; self.factor = factor; self.textFamilies = textFamilies; self.monoFamilies = monoFamilies
    }
}

/// Builds and recalculates the type ramp. Pure functions; the caller keeps the token set and the undo step.
public enum TypeRamp {
    /// The token set that holds the ramp.
    public static let setName = "text"
    /// The first part of the path of a text style.
    public static let group = "type"

    /// Size of one step in whole points.
    public static func size(_ step: TypeStep, base: Double, factor: Double) -> Double {
        (base * pow(factor, Double(step.exponent))).rounded()
    }

    /// The six text styles for a spec. A size in `overrides` is kept as given; the other steps are calculated.
    public static func tokens(_ spec: TypeRampSpec, overrides: [TypeStep: Double] = [:]) -> [Token] {
        TypeStep.allCases.map { step in
            let typed = overrides[step]
            return token(step, spec: spec, size: typed ?? size(step, base: spec.base, factor: spec.factor), overridden: typed != nil)
        }
    }

    /// Changes base and factor. Steps whose size was set by hand keep it; the others follow the new ramp.
    public static func recalculate(_ tokens: [Token], base: Double, factor: Double) -> [Token] {
        tokens.map { token in
            guard let mark = token.ramp, case .typography(var style) = token.value else { return token }
            if !mark.overridden { style.fontSize = size(mark.step, base: base, factor: factor) }
            var result = token
            result.value = .typography(style)
            result.ramp = RampMark(step: mark.step, base: base, factor: factor, overridden: mark.overridden)
            return result
        }
    }

    /// Sets the size of one step by hand. Later recalculations keep that size.
    /// Returns the tokens unchanged when the step is not in the ramp.
    public static func setSize(_ points: Double, for step: TypeStep, in tokens: [Token]) -> [Token] {
        tokens.map { token in
            guard var mark = token.ramp, mark.step == step, case .typography(var style) = token.value else { return token }
            style.fontSize = points
            mark.overridden = true
            var result = token
            result.value = .typography(style)
            result.ramp = mark
            return result
        }
    }

    private static func token(_ step: TypeStep, spec: TypeRampSpec, size points: Double, overridden: Bool) -> Token {
        let style = Typography(fontFamily: step.isMono ? spec.monoFamilies : spec.textFamilies,
                               fontSize: points, fontWeight: step.weight, letterSpacing: 0, lineHeight: step.lineHeight)
        return Token([group, step.rawValue], .typography(style),
                     ramp: RampMark(step: step, base: spec.base, factor: spec.factor, overridden: overridden))
    }
}
