import Foundation
import ALFAcolorCore
import Tokens

/// A colour that follows a colour field. While the field exists its colour is used; the stored hex is the
/// last known value and takes over when the field is gone. The functions here change nothing.
public enum ColorBinding {
    /// The colour to draw, and whether a bound field is missing.
    public struct Resolved: Equatable, Sendable {
        public var color: RGB?
        public var isMissing: Bool
    }

    /// Resolves a colour. `hex` is the stored value, `token` the name of the bound field or nil when unbound.
    public static func resolve(hex: String?, token: String?, in sets: [TokenSet]) -> Resolved {
        let stored = hex.flatMap { RGB(hex: $0) }
        guard let token else { return Resolved(color: stored, isMissing: false) }
        guard let field = ColorFields.fields(in: sets).first(where: { $0.name == token }) else {
            return Resolved(color: stored, isMissing: true)
        }
        return Resolved(color: field.color, isMissing: false)
    }

    /// The slots of an item that can hold a binding.
    public enum Slot: Sendable, CaseIterable {
        case fill, stroke, swatch
    }

    /// The item with `slot` bound to the field `name` and the stored value set to the colour of the field.
    /// nil when the slot does not exist on the item.
    static func bound(_ item: Item, slot: Slot, name: String, color: RGB) -> Item? {
        var out = item
        let hex = color.hex
        switch (item.content, slot) {
        case (.shape(let kind, var style), .fill):
            style.fill = hex; style.fillToken = name
            out.content = .shape(kind: kind, style: style)
        case (.shape(let kind, var style), .stroke):
            style.stroke = hex; style.strokeToken = name
            out.content = .shape(kind: kind, style: style)
        case (.swatch(_, let label), .swatch):
            out.content = .swatch(hex: hex, name: label)
            out.colorToken = name
        default:
            return nil
        }
        return out
    }

    /// The item with `slot` released. The stored value stays. nil when the slot does not exist on the item.
    static func released(_ item: Item, slot: Slot) -> Item? {
        var out = item
        switch (item.content, slot) {
        case (.shape(let kind, var style), .fill):
            guard style.fillToken != nil else { return nil }
            style.fillToken = nil
            out.content = .shape(kind: kind, style: style)
        case (.shape(let kind, var style), .stroke):
            guard style.strokeToken != nil else { return nil }
            style.strokeToken = nil
            out.content = .shape(kind: kind, style: style)
        case (.swatch, .swatch):
            guard item.colorToken != nil else { return nil }
            out.colorToken = nil
        default:
            return nil
        }
        return out
    }

    /// The item with every binding to the field `old` moved to `new`. nil when the item has no such binding.
    static func renamed(_ item: Item, from old: String, to new: String) -> Item? {
        var out = item
        switch item.content {
        case .shape(let kind, var style):
            let fill = style.fillToken == old, stroke = style.strokeToken == old
            guard fill || stroke else { break }
            if fill { style.fillToken = new }
            if stroke { style.strokeToken = new }
            out.content = .shape(kind: kind, style: style)
        default:
            break
        }
        if item.colorToken == old { out.colorToken = new }
        return out == item ? nil : out
    }

    /// True when the item has a binding to the field `name` in any slot.
    static func isBound(_ item: Item, to name: String) -> Bool {
        if item.colorToken == name { return true }
        guard case .shape(_, let style) = item.content else { return false }
        return style.fillToken == name || style.strokeToken == name
    }
}
