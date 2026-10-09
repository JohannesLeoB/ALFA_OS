import SwiftUI
import Tokens

// The raw values of the cases below are token paths of the design contract (`color.akzent`, `space.s4`,
// `text.kopf.familie`). They belong to the contract with the design side and stay as they are.

/// Color token of the UI. Path in the contract: `color.<raw value>`.
public enum ColorToken: String, CaseIterable, Sendable {
    /// Accent of the app. In the contract an alias of `koralle`.
    case accent = "akzent"
    /// Canvas and window ground: white in light mode, black in dark mode.
    case background = "grund"
    /// Resting card, image ground and hover.
    case surface = "flaeche"
    /// Content of cards and fields.
    case surfaceContent = "blatt"
    /// Lines on glass: separators, field edges, card edges at rest.
    case border = "rahmen"
    case text
    case textMuted = "textLeise"
    /// The one signal colour: focus, snapping, lasso, confirm.
    case coral = "koralle"
    case glass = "glas"
    case glassDense = "glas-dicht"
    case glassEdge = "glas-kante"
    /// Grip at the lower right corner of a card.
    case fold = "falz"
    case lasso
    case zoneStone = "zone-stein"
    case zonePlum = "zone-pflaume"
    case zoneNight = "zone-nacht"
    case zoneApricot = "zone-aprikose"
    case zoneRose = "zone-rose"
    case zonePaper = "zone-papier"
    case zoneBlack = "zone-schwarz"
    case synKeyword = "syn-schluessel"
    case synString = "syn-zeichenkette"
    case synComment = "syn-kommentar"
    case synType = "syn-typ"
    case synNumber = "syn-zahl"
    case synTag = "syn-tag"

    /// The colours a blade of the swatch fan paints: the interface colours.
    public static let paintable: [ColorToken] = [.accent, .background, .surface, .border, .text, .textMuted, .coral]
}

/// Spacing token. Path: `space.<name>`. Values in points.
public enum SpaceToken: String, CaseIterable, Sendable {
    case s1, s2, s3, s4, s5, s6, s7, s8
}

/// Radius token. Path: `radius.<name>`. Values in points.
public enum RadiusToken: String, CaseIterable, Sendable {
    case s, m, l
}

/// Text style. Path: `text.<raw value>.familie`, `.groesse`, `.gewicht`, `.zeilenhoehe`, `.laufweite`.
public enum TextToken: String, CaseIterable, Sendable {
    case zone, title = "titel", section = "abschnitt", heading = "kopf", lead
    case reading = "lesen", body = "fliesstext", control = "bedienung", caption = "beschriftung", code = "quelltext"
}

/// Shadow token of the contract. Path: `shadow.<raw value>.aussen` (or `.innen` for glass).
public enum ShadowToken: String, CaseIterable, Sendable {
    case card = "schatten-karte", frame = "schatten-rahmen", glass = "schatten-glas"

    /// The group of the contract that holds the parts of the shadow.
    var side: String { self == .glass ? "innen" : "aussen" }
}

/// A resolved shadow: offset, blur in points, and colour. Zero blur and a clear colour mean no shadow.
public struct ShadowSpec: Sendable, Equatable {
    public var x: CGFloat
    public var y: CGFloat
    public var blur: CGFloat
    public var color: RGB

    public static let none = ShadowSpec(x: 0, y: 0, blur: 0, color: RGB(r: 0, g: 0, b: 0, a: 0))
}

/// A resolved text style. The family "System" selects the system font, "System Display" and "System Text"
/// the system font too, and "Mono" the monospaced system font.
public struct TextStyle: Sendable, Equatable {
    public var families: [String]
    public var size: CGFloat
    public var weight: Int
    /// Line height as a factor of the size. Unitless.
    public var lineHeight: CGFloat
    /// Letter spacing in em.
    public var tracking: CGFloat

    public init(families: [String], size: CGFloat, weight: Int, lineHeight: CGFloat = 1.5, tracking: CGFloat = 0) {
        self.families = families; self.size = size; self.weight = weight
        self.lineHeight = lineHeight; self.tracking = tracking
    }

    /// Letter spacing in points, for `Text.tracking`.
    public var trackingPoints: CGFloat { tracking * size }

    /// Extra space between two lines in points, for `lineSpacing`: the line height factor minus one, times the size.
    public var lineSpacingPoints: CGFloat { max(0, (lineHeight - 1) * size) }

    public var font: Font {
        let fontWeight = Theme.fontWeight(weight)
        let name = families.first ?? "System"
        if name == "Mono" {
            return Font.system(size: size, weight: fontWeight, design: .monospaced)
        }
        if name.hasPrefix("System") {
            return Font.system(size: size, weight: fontWeight)
        }
        return Font.custom(name, size: size).weight(fontWeight)
    }
}

/// The values of the UI. Every value comes from the contract or from the placeholder.
/// Colors change with the mode. Spacing, radii and type apply to both.
public struct Theme: Sendable, Equatable {
    public enum Mode: Sendable, Hashable {
        case light, dark
        public init(_ scheme: ColorScheme) { self = scheme == .dark ? .dark : .light }
    }

    /// Where the values come from: "Placeholder" or the name of the contract.
    public let source: String
    /// Paths that the contract lacks or delivers with the wrong type. The placeholder applies to them.
    public let missing: [String]
    private let colors: [Mode: [ColorToken: RGB]]
    private let spacing: [SpaceToken: CGFloat]
    private let radii: [RadiusToken: CGFloat]
    private let texts: [TextToken: TextStyle]
    private let shadows: [Mode: [ShadowToken: ShadowSpec]]

    /// Placeholders only. Without a contract, this set applies. It holds colours only.
    public static let placeholder = Theme(contract: Placeholder.light, dark: Placeholder.dark, source: "Placeholder",
                                          reportMissing: false)

    /// `light` delivers all values. `dark` is optional. A dark contract names only the values that differ in dark mode;
    /// every other value keeps its light value. Without a dark contract, the placeholder colours apply in dark mode.
    public init(contract light: TokenSet, dark: TokenSet? = nil, source: String) {
        self.init(contract: light, dark: dark, source: source, reportMissing: true)
    }

    init(contract light: TokenSet, dark: TokenSet?, source: String, reportMissing: Bool) {
        var missing: [String] = []
        let lightIndex = Theme.index(light)
        let darkIndex = dark.map { Theme.index($0).merging(lightIndex) { fromDark, _ in fromDark } } ?? [:]
        let placeholderLight = Theme.index(Placeholder.light)
        let placeholderDark = Theme.index(Placeholder.dark)
        let lightReport: String? = reportMissing ? "" : nil
        let darkReport: String? = reportMissing && dark != nil ? "dark: " : nil

        var lightColors: [ColorToken: RGB] = [:]
        var darkColors: [ColorToken: RGB] = [:]
        for c in ColorToken.allCases {
            let path = "color.\(c.rawValue)"
            lightColors[c] = Theme.value(path, from: lightIndex, fallback: placeholderLight, report: lightReport, &missing,
                                         read: Theme.readColor, last: Theme.magenta)
            darkColors[c] = Theme.value(path, from: darkIndex, fallback: placeholderDark, report: darkReport, &missing,
                                        read: Theme.readColor, last: Theme.magenta)
        }

        var spacing: [SpaceToken: CGFloat] = [:]
        for s in SpaceToken.allCases {
            spacing[s] = Theme.value("space.\(s.rawValue)", from: lightIndex, fallback: placeholderLight,
                                     report: lightReport, &missing, read: Theme.readPoints, last: 0)
        }

        var radii: [RadiusToken: CGFloat] = [:]
        for r in RadiusToken.allCases {
            radii[r] = Theme.value("radius.\(r.rawValue)", from: lightIndex, fallback: placeholderLight,
                                   report: lightReport, &missing, read: Theme.readPoints, last: 0)
        }

        var texts: [TextToken: TextStyle] = [:]
        for t in TextToken.allCases {
            let path = "text.\(t.rawValue)"
            let family = Theme.value(path + ".familie", from: lightIndex, fallback: placeholderLight,
                                     report: lightReport, &missing, read: Theme.readFamily, last: ["System"])
            let size = Theme.value(path + ".groesse", from: lightIndex, fallback: placeholderLight,
                                   report: lightReport, &missing, read: Theme.readPoints, last: 13)
            let weight = Theme.value(path + ".gewicht", from: lightIndex, fallback: placeholderLight,
                                     report: lightReport, &missing, read: Theme.readWeight, last: 400)
            let line = Theme.value(path + ".zeilenhoehe", from: lightIndex, fallback: placeholderLight,
                                   report: nil, &missing, read: Theme.readNumber, last: 1.5)
            let tracking = Theme.value(path + ".laufweite", from: lightIndex, fallback: placeholderLight,
                                       report: nil, &missing, read: Theme.readNumber, last: 0)
            texts[t] = TextStyle(families: family, size: size, weight: weight, lineHeight: line, tracking: tracking)
        }

        var shadowsLight: [ShadowToken: ShadowSpec] = [:]
        var shadowsDark: [ShadowToken: ShadowSpec] = [:]
        for s in ShadowToken.allCases {
            let base = "shadow.\(s.rawValue).\(s.side)"
            func spec(_ index: [String: TokenValue], _ fallback: [String: TokenValue], _ report: String?) -> ShadowSpec {
                var none: [String] = []
                let x = Theme.value(base + ".versatzX", from: index, fallback: fallback, report: nil, &none, read: Theme.readPoints, last: 0)
                let y = Theme.value(base + ".versatzY", from: index, fallback: fallback, report: nil, &none, read: Theme.readPoints, last: 0)
                let blur = Theme.value(base + ".unschaerfe", from: index, fallback: fallback, report: nil, &none, read: Theme.readPoints, last: 0)
                let color = Theme.value(base + ".farbe", from: index, fallback: fallback, report: nil, &none, read: Theme.readColor,
                                        last: ShadowSpec.none.color)
                return ShadowSpec(x: x, y: y, blur: blur, color: color)
            }
            shadowsLight[s] = spec(lightIndex, placeholderLight, lightReport)
            shadowsDark[s] = spec(darkIndex, placeholderDark, darkReport)
        }

        self.source = source
        self.missing = missing
        self.colors = [.light: lightColors, .dark: darkColors]
        self.spacing = spacing
        self.radii = radii
        self.texts = texts
        self.shadows = [.light: shadowsLight, .dark: shadowsDark]
    }

    // MARK: - Access

    public func rgb(_ color: ColorToken, _ mode: Mode) -> RGB {
        colors[mode]?[color] ?? Theme.magenta
    }

    /// Color for SwiftUI. The mode comes from the ColorScheme of the environment.
    public func color(_ color: ColorToken, _ scheme: ColorScheme) -> Color {
        Color(rgb(color, Mode(scheme)))
    }

    public func space(_ s: SpaceToken) -> CGFloat { spacing[s] ?? 0 }

    /// A size of a building block: a number of basic steps (s2), so that sizes stay on the 8-point grid.
    public func grid(_ steps: Int) -> CGFloat { space(.s2) * CGFloat(steps) }

    public func radius(_ r: RadiusToken) -> CGFloat { radii[r] ?? 0 }

    /// The shadow of the contract for the mode. Without a value it is `ShadowSpec.none`.
    public func shadow(_ s: ShadowToken, _ scheme: ColorScheme) -> ShadowSpec {
        shadows[Mode(scheme)]?[s] ?? ShadowSpec.none
    }

    public func text(_ t: TextToken) -> TextStyle {
        texts[t] ?? TextStyle(families: ["System"], size: 13, weight: 400)
    }

    /// The SwiftUI weight for a numeric weight of the contract, following the DTCG names:
    /// 100 thin, 200 extra-light (ultraLight), 300 light, 400 regular, 500 medium, 600 semi-bold, 700 bold, 800 extra-bold, 900 black.
    public static func fontWeight(_ w: Int) -> Font.Weight {
        switch w {
        case ..<150: .thin
        case ..<250: .ultraLight
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        case ..<750: .bold
        case ..<850: .heavy
        default: .black
        }
    }

    // MARK: - Resolving

    /// Colour of a token that neither the contract nor the placeholder names. Visible on purpose.
    private static let magenta = RGB(r: 1, g: 0, b: 1)

    private static func index(_ set: TokenSet) -> [String: TokenValue] {
        Dictionary(set.tokens.map { ($0.id, $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    /// Value from the contract, otherwise from the placeholder, otherwise `last`. If it is missing or has the wrong type,
    /// it is noted in `missing`, provided that `report` is set.
    private static func value<T>(_ path: String,
                                 from contract: [String: TokenValue],
                                 fallback: [String: TokenValue],
                                 report prefix: String?,
                                 _ missing: inout [String],
                                 read: (TokenValue) -> T?,
                                 last: T) -> T {
        if let v = contract[path] {
            if let x = read(v) { return x }
            if let p = prefix { missing.append("\(p)\(path): wrong type") }
        } else if let p = prefix {
            missing.append("\(p)\(path): missing")
        }
        if let v = fallback[path], let x = read(v) { return x }
        return last
    }

    private static func readColor(_ v: TokenValue) -> RGB? {
        if case .color(let c) = v { return c }
        return nil
    }

    /// Dimensions in points. A rem counts as 16 points, as in TokenExport.swiftUI.
    private static func readPoints(_ v: TokenValue) -> CGFloat? {
        guard case .dimension(let x, let unit) = v else { return nil }
        return CGFloat(unit == "rem" ? x * 16 : x)
    }

    private static func readNumber(_ v: TokenValue) -> CGFloat? {
        if case .number(let x) = v { return CGFloat(x) }
        return nil
    }

    private static func readFamily(_ v: TokenValue) -> [String]? {
        if case .fontFamily(let f) = v { return f }
        return nil
    }

    private static func readWeight(_ v: TokenValue) -> Int? {
        if case .fontWeight(let w) = v { return w }
        return nil
    }
}

// MARK: - Loading

public extension Theme {
    /// Reads the contract from DTCG data. Invalid data throws a DTCGImportError with the path in the JSON.
    static func load(contract data: Data, source: String) throws -> Theme {
        let set = try DTCGImport.tokens(from: data, name: source)
        return Theme(contract: set, source: source)
    }

    /// Reads the contract from a file.
    static func load(from url: URL) throws -> Theme {
        try load(contract: Data(contentsOf: url), source: url.lastPathComponent)
    }

    /// Reads the light contract and the dark contract from two files. A missing or invalid light file gives
    /// the placeholder. A missing or invalid dark file gives the placeholder colors in dark mode only.
    static func load(light: URL?, dark: URL?) -> Theme {
        guard let light, let lightSet = tokenSet(at: light) else { return .placeholder }
        return Theme(contract: lightSet, dark: dark.flatMap(tokenSet(at:)), source: light.lastPathComponent)
    }

    /// The contract from the app bundle: `tokens.json` for light and `tokens.dunkel.json` for dark.
    /// Without a valid light file the placeholder applies.
    static func bundled(in bundle: Bundle = .main) -> Theme {
        load(light: contractFile(in: bundle), dark: darkContractFile(in: bundle))
    }

    /// The light contract file in the app bundle, if the build copied it. nil means the placeholder applies.
    static func contractFile(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "tokens", withExtension: "json")
    }

    /// The dark contract file in the app bundle, if the build copied it.
    static func darkContractFile(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "tokens.dunkel", withExtension: "json")
    }

    private static func tokenSet(at url: URL) -> TokenSet? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? DTCGImport.tokens(from: data, name: url.lastPathComponent)
    }
}

public extension EnvironmentValues {
    /// The values of the UI. Default: the placeholder.
    @Entry var theme: Theme = .placeholder
}

public extension Color {
    /// The one converter from an RGB value (a token or a value of an item) to a color. Features use it and build no colors themselves.
    init(_ rgb: RGB) {
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: rgb.a)
    }
}
