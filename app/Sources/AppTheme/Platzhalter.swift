import Tokens

/// PLATZHALTER. Keine Gestaltungswerte.
/// Diese Werte gelten, solange kein Vertrag da ist. Ersetzt durch gestaltung/vertrag/tokens.json,
/// sobald Konto B den Vertrag liefert. Der Akzent ist absichtlich Magenta, damit niemand einen
/// Platzhalter für eine Gestaltungsentscheidung hält.
public enum Platzhalter {
    /// Hell: Farben im hellen Modus, dazu Abstände, Radien und Schrift (gelten für beide Modi).
    public static let hell = TokenSet(name: "PLATZHALTER hell", tokens: [
        Token(["color", "akzent"], farbe("#FF00FF")),
        Token(["color", "grund"], farbe("#F2F2F2")),
        Token(["color", "flaeche"], farbe("#FFFFFF")),
        Token(["color", "rahmen"], farbe("#D1D1D6")),
        Token(["color", "text"], farbe("#1C1C1E")),
        Token(["color", "textLeise"], farbe("#6E6E73")),
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

    /// Dunkel: nur die Farben. Maße und Schrift kommen aus `hell`.
    public static let dunkel = TokenSet(name: "PLATZHALTER dunkel", tokens: [
        Token(["color", "akzent"], farbe("#FF00FF")),
        Token(["color", "grund"], farbe("#1C1C1E")),
        Token(["color", "flaeche"], farbe("#2C2C2E")),
        Token(["color", "rahmen"], farbe("#3A3A3C")),
        Token(["color", "text"], farbe("#F2F2F7")),
        Token(["color", "textLeise"], farbe("#98989D")),
    ])

    /// Ungültige Hex-Angaben fallen auf Magenta zurück, damit sie auffallen.
    private static func farbe(_ hex: String) -> TokenValue {
        .color(RGB(hex: hex) ?? RGB(r: 1, g: 0, b: 1))
    }
}
