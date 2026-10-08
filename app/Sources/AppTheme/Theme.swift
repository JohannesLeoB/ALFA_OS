import SwiftUI
import Tokens

/// Farbtoken der Oberfläche. Pfad im Vertrag: `color.<name>`.
public enum ColorToken: String, CaseIterable, Sendable {
    case akzent, grund, flaeche, rahmen, text, textLeise
}

/// Abstandstoken. Pfad: `space.<name>`. Werte in Punkten.
public enum SpaceToken: String, CaseIterable, Sendable {
    case s1, s2, s3, s4, s5, s6, s8
}

/// Radiustoken. Pfad: `radius.<name>`. Werte in Punkten.
public enum RadiusToken: String, CaseIterable, Sendable {
    case s, m, l
}

/// Textstil. Pfad: `text.<name>.familie`, `.groesse`, `.gewicht`.
public enum TextToken: String, CaseIterable, Sendable {
    case kopf, fliesstext, beschriftung
}

/// Ein aufgelöster Textstil. Die Schrift "System" wählt die Systemschrift.
public struct TextStyle: Sendable, Equatable {
    public var families: [String]
    public var size: CGFloat
    public var weight: Int

    public init(families: [String], size: CGFloat, weight: Int) {
        self.families = families; self.size = size; self.weight = weight
    }

    public var font: Font {
        let gewicht = TextStyle.fontWeight(weight)
        if let name = families.first, name != "System" {
            return Font.custom(name, size: size).weight(gewicht)
        }
        return Font.system(size: size, weight: gewicht)
    }

    static func fontWeight(_ w: Int) -> Font.Weight {
        switch w {
        case ..<150: .ultraLight
        case ..<250: .thin
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        case ..<750: .bold
        case ..<850: .heavy
        default: .black
        }
    }
}

/// Die Werte der Oberfläche. Jeder Wert kommt aus dem Vertrag oder aus dem Platzhalter.
/// Farben wechseln mit dem Modus; Abstände, Radien und Schrift gelten für beide.
public struct Theme: Sendable, Equatable {
    public enum Modus: Sendable, Hashable {
        case hell, dunkel
        public init(_ scheme: ColorScheme) { self = scheme == .dark ? .dunkel : .hell }
    }

    /// Herkunft der Werte: "Platzhalter" oder der Name des Vertrags.
    public let quelle: String
    /// Pfade, die der Vertrag fehlt oder mit falschem Typ liefert. Für sie gilt der Platzhalter.
    public let fehlend: [String]
    private let farben: [Modus: [ColorToken: RGB]]
    private let abstaende: [SpaceToken: CGFloat]
    private let radien: [RadiusToken: CGFloat]
    private let texte: [TextToken: TextStyle]

    /// Nur Platzhalter. Ohne Vertrag gilt dieser Satz.
    public static let platzhalter = Theme(vertrag: Platzhalter.hell, dunkel: Platzhalter.dunkel, quelle: "Platzhalter")

    /// `hell` liefert alle Werte. `dunkel` ist optional und ersetzt nur die Farben im dunklen Modus.
    public init(vertrag hell: TokenSet, dunkel: TokenSet? = nil, quelle: String) {
        var fehlend: [String] = []
        let hellIndex = Theme.index(hell)
        let dunkelIndex = dunkel.map(Theme.index) ?? [:]
        let phHell = Theme.index(Platzhalter.hell)
        let phDunkel = Theme.index(Platzhalter.dunkel)
        let dunkelMeldung: String? = dunkel == nil ? nil : "dunkel: "

        var hellFarben: [ColorToken: RGB] = [:]
        var dunkelFarben: [ColorToken: RGB] = [:]
        for c in ColorToken.allCases {
            let pfad = "color.\(c.rawValue)"
            hellFarben[c] = Theme.wert(pfad, aus: hellIndex, sonst: phHell, melden: "", &fehlend,
                                       lesen: Theme.lesenFarbe, notfall: RGB(r: 0, g: 0, b: 0))
            dunkelFarben[c] = Theme.wert(pfad, aus: dunkelIndex, sonst: phDunkel, melden: dunkelMeldung, &fehlend,
                                         lesen: Theme.lesenFarbe, notfall: RGB(r: 0, g: 0, b: 0))
        }

        var abstaende: [SpaceToken: CGFloat] = [:]
        for s in SpaceToken.allCases {
            abstaende[s] = Theme.wert("space.\(s.rawValue)", aus: hellIndex, sonst: phHell, melden: "", &fehlend,
                                      lesen: Theme.lesenPunkte, notfall: 0)
        }

        var radien: [RadiusToken: CGFloat] = [:]
        for r in RadiusToken.allCases {
            radien[r] = Theme.wert("radius.\(r.rawValue)", aus: hellIndex, sonst: phHell, melden: "", &fehlend,
                                   lesen: Theme.lesenPunkte, notfall: 0)
        }

        var texte: [TextToken: TextStyle] = [:]
        for t in TextToken.allCases {
            let pfad = "text.\(t.rawValue)"
            let familie = Theme.wert(pfad + ".familie", aus: hellIndex, sonst: phHell, melden: "", &fehlend,
                                     lesen: Theme.lesenFamilie, notfall: ["System"])
            let groesse = Theme.wert(pfad + ".groesse", aus: hellIndex, sonst: phHell, melden: "", &fehlend,
                                     lesen: Theme.lesenPunkte, notfall: 13)
            let gewicht = Theme.wert(pfad + ".gewicht", aus: hellIndex, sonst: phHell, melden: "", &fehlend,
                                     lesen: Theme.lesenGewicht, notfall: 400)
            texte[t] = TextStyle(families: familie, size: groesse, weight: gewicht)
        }

        self.quelle = quelle
        self.fehlend = fehlend
        self.farben = [.hell: hellFarben, .dunkel: dunkelFarben]
        self.abstaende = abstaende
        self.radien = radien
        self.texte = texte
    }

    // MARK: - Zugriff

    public func rgb(_ farbe: ColorToken, _ modus: Modus) -> RGB {
        farben[modus]?[farbe] ?? RGB(r: 0, g: 0, b: 0)
    }

    /// Farbe für SwiftUI. Der Modus kommt aus dem ColorScheme der Umgebung.
    public func color(_ farbe: ColorToken, _ scheme: ColorScheme) -> Color {
        let c = rgb(farbe, Modus(scheme))
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    public func space(_ s: SpaceToken) -> CGFloat { abstaende[s] ?? 0 }

    public func radius(_ r: RadiusToken) -> CGFloat { radien[r] ?? 0 }

    public func text(_ t: TextToken) -> TextStyle {
        texte[t] ?? TextStyle(families: ["System"], size: 13, weight: 400)
    }

    // MARK: - Auflösen

    private static func index(_ set: TokenSet) -> [String: TokenValue] {
        Dictionary(set.tokens.map { ($0.id, $0.value) }, uniquingKeysWith: { erster, _ in erster })
    }

    /// Wert aus dem Vertrag, sonst aus dem Platzhalter. Fehlt oder stimmt der Typ nicht, wird es in `fehlend` vermerkt,
    /// sofern `melden` gesetzt ist.
    private static func wert<T>(_ pfad: String,
                                aus vertrag: [String: TokenValue],
                                sonst fallback: [String: TokenValue],
                                melden praefix: String?,
                                _ fehlend: inout [String],
                                lesen: (TokenValue) -> T?,
                                notfall: T) -> T {
        if let v = vertrag[pfad] {
            if let x = lesen(v) { return x }
            if let p = praefix { fehlend.append("\(p)\(pfad): falscher Typ") }
        } else if let p = praefix {
            fehlend.append("\(p)\(pfad): fehlt")
        }
        if let v = fallback[pfad], let x = lesen(v) { return x }
        return notfall
    }

    private static func lesenFarbe(_ v: TokenValue) -> RGB? {
        if case .color(let c) = v { return c }
        return nil
    }

    /// Maße in Punkten. rem zählt mit 16 Punkten, wie in TokenExport.swiftUI.
    private static func lesenPunkte(_ v: TokenValue) -> CGFloat? {
        guard case .dimension(let x, let einheit) = v else { return nil }
        return CGFloat(einheit == "rem" ? x * 16 : x)
    }

    private static func lesenFamilie(_ v: TokenValue) -> [String]? {
        if case .fontFamily(let f) = v { return f }
        return nil
    }

    private static func lesenGewicht(_ v: TokenValue) -> Int? {
        if case .fontWeight(let w) = v { return w }
        return nil
    }
}

// MARK: - Laden

public extension Theme {
    /// Liest den Vertrag aus DTCG-Daten. Ungültige Daten werfen einen DTCGImportError mit Pfad im JSON.
    static func laden(vertrag daten: Data, quelle: String) throws -> Theme {
        let set = try DTCGImport.tokens(from: daten, name: quelle)
        return Theme(vertrag: set, quelle: quelle)
    }

    /// Liest den Vertrag aus einer Datei.
    static func laden(aus url: URL) throws -> Theme {
        try laden(vertrag: Data(contentsOf: url), quelle: url.lastPathComponent)
    }

    /// Die Vertragsdatei im App-Paket, falls der Bau sie kopiert hat. nil heißt: Platzhalter gelten.
    static func vertragsdatei(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "tokens", withExtension: "json")
    }
}

public extension EnvironmentValues {
    /// Die Werte der Oberfläche. Standard: Platzhalter.
    @Entry var theme: Theme = .platzhalter
}
