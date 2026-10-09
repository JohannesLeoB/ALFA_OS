import Foundation
import ALFAcolorCore
import Tokens

/// Commands for text styles. Each one is one undo step, named by its key in the string catalog.
extension BoardStore {
    /// Adds a text style. Returns false when nothing changed.
    @discardableResult
    public func addTextStyle(name: String, style: Typography) throws -> Bool {
        try changeTokenSets(nameKey: "undo.type.add") { try TypographyStyles.add(name: name, style: style, to: &$0) }
    }

    /// Changes the values of a text style.
    public func changeTextStyle(_ name: String, to style: Typography) throws {
        _ = try changeTokenSets(nameKey: "undo.type.change") { try TypographyStyles.change(name, to: style, in: &$0) }
    }

    /// Removes a text style.
    public func removeTextStyle(_ name: String) throws {
        _ = try changeTokenSets(nameKey: "undo.type.remove") { try TypographyStyles.remove(name, from: &$0) }
    }

    /// Creates the type ramp from a base and a factor.
    public func makeTypeRamp(_ spec: TypeRampSpec) throws {
        _ = try changeTokenSets(nameKey: "undo.type.ramp") { try TypographyStyles.makeRamp(spec, in: &$0) }
    }

    /// Calculates the ramp again from a new base and factor. Typed sizes stay.
    public func recalculateTypeRamp(base: Double, factor: Double) throws {
        _ = try changeTokenSets(nameKey: "undo.type.recalculate") { try TypographyStyles.recalculate(base: base, factor: factor, in: &$0) }
    }
}
