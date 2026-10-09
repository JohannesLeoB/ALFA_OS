import ALFAcolorCore
import Tokens

/// The fill of a new shape. A shape without fill is drawn in the text colour of the theme, so it stays visible.
public enum ShapeFill {
    /// The first colour field of the token sets, or nil when there is none: then the text colour applies.
    public static func standard(in sets: [TokenSet]) -> RGB? {
        ColorFields.fields(in: sets).first?.color
    }
}
