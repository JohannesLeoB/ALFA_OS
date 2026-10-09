import Foundation
import ALFAcolorCore
import Tokens

/// Where a colour is used in a space: the swatches and shapes that carry it as a colour.
public enum ColorUse {
    /// The items of the space whose swatch, fill or stroke is this colour. Other kinds of items never count.
    public static func items(using color: RGB, in space: Space?) -> Set<ItemID> {
        guard let space else { return [] }
        let target = key(of: color)
        return Set(space.items.filter { uses($0.content, target) }.map(\.id))
    }

    static func uses(_ content: Content, _ key: String) -> Bool {
        switch content {
        case .swatch(let hex, _):
            return self.key(of: hex) == key
        case .shape(_, let style):
            return [style.fill, style.stroke].contains { text in
                guard let text else { return false }
                return self.key(of: text) == key
            }
        default:
            return false
        }
    }

    /// The colour as the comparison key: opaque, upper case "#RRGGBB".
    static func key(of color: RGB) -> String {
        var opaque = color
        opaque.a = 1
        return opaque.hex
    }

    /// The key of a hex text, nil when the text is not a colour.
    static func key(of text: String) -> String? {
        RGB(hex: text).map { key(of: $0) }
    }
}
