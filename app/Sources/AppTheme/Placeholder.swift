import Tokens

/// PLACEHOLDER. Not design values.
/// These colours apply while there is no contract. They are replaced by gestaltung/vertrag/tokens.json
/// as soon as the design side delivers the contract. Spacing, radii and type have no placeholder: without
/// a contract they take the fixed defaults of `Theme`. A colour without any value is magenta.
/// The accent is magenta on purpose, so that nobody takes a placeholder for a design decision.
/// The token paths (`color.akzent`) are the contract's raw names.
public enum Placeholder {
    /// Light: colours in light mode.
    public static let light = TokenSet(name: "PLACEHOLDER light", tokens: [
        Token(["color", "akzent"], color("#FF00FF")),
        Token(["color", "grund"], color("#F2F2F2")),
        Token(["color", "flaeche"], color("#FFFFFF")),
        Token(["color", "rahmen"], color("#D1D1D6")),
        Token(["color", "text"], color("#1C1C1E")),
        Token(["color", "textLeise"], color("#6E6E73")),
        Token(["color", "koralle"], color("#FF00FF")),
    ])

    /// Dark: colours in dark mode.
    public static let dark = TokenSet(name: "PLACEHOLDER dark", tokens: [
        Token(["color", "akzent"], color("#FF00FF")),
        Token(["color", "grund"], color("#1C1C1E")),
        Token(["color", "flaeche"], color("#2C2C2E")),
        Token(["color", "rahmen"], color("#3A3A3C")),
        Token(["color", "text"], color("#F2F2F7")),
        Token(["color", "textLeise"], color("#98989D")),
        Token(["color", "koralle"], color("#FF00FF")),
    ])

    /// Invalid hex values fall back to magenta, so that they stand out.
    private static func color(_ hex: String) -> TokenValue {
        .color(RGB(hex: hex) ?? RGB(r: 1, g: 0, b: 1))
    }
}
