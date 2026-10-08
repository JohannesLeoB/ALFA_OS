import Tokens

/// PLACEHOLDER. Not design values.
/// These values apply while there is no contract. They are replaced by gestaltung/vertrag/tokens.json
/// as soon as the design side delivers the contract. The accent is magenta on purpose, so that nobody
/// takes a placeholder for a design decision.
/// The token paths (`color.akzent`, `space.s4`, `text.kopf.familie`) are the contract's raw names.
public enum Placeholder {
    /// Light: colors in light mode, plus spacing, radii and type (they apply to both modes).
    public static let light = TokenSet(name: "PLACEHOLDER light", tokens: [
        Token(["color", "akzent"], color("#FF00FF")),
        Token(["color", "grund"], color("#F2F2F2")),
        Token(["color", "flaeche"], color("#FFFFFF")),
        Token(["color", "rahmen"], color("#D1D1D6")),
        Token(["color", "text"], color("#1C1C1E")),
        Token(["color", "textLeise"], color("#6E6E73")),
        Token(["color", "koralle"], color("#FF00FF")),
        Token(["space", "s1"], .dimension(4, unit: "px")),
        Token(["space", "s2"], .dimension(8, unit: "px")),
        Token(["space", "s3"], .dimension(12, unit: "px")),
        Token(["space", "s4"], .dimension(16, unit: "px")),
        Token(["space", "s5"], .dimension(24, unit: "px")),
        Token(["space", "s6"], .dimension(32, unit: "px")),
        Token(["space", "s8"], .dimension(48, unit: "px")),
        Token(["radius", "s"], .dimension(6, unit: "px")),
        Token(["radius", "m"], .dimension(10, unit: "px")),
        Token(["radius", "l"], .dimension(16, unit: "px")),
        Token(["text", "kopf", "familie"], .fontFamily(["System"])),
        Token(["text", "kopf", "groesse"], .dimension(22, unit: "px")),
        Token(["text", "kopf", "gewicht"], .fontWeight(700)),
        Token(["text", "fliesstext", "familie"], .fontFamily(["System"])),
        Token(["text", "fliesstext", "groesse"], .dimension(13, unit: "px")),
        Token(["text", "fliesstext", "gewicht"], .fontWeight(400)),
        Token(["text", "beschriftung", "familie"], .fontFamily(["System"])),
        Token(["text", "beschriftung", "groesse"], .dimension(11, unit: "px")),
        Token(["text", "beschriftung", "gewicht"], .fontWeight(500)),
    ])

    /// Dark: colors only. Dimensions and type come from `light`.
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
