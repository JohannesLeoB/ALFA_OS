import SwiftUI
import Tokens

// The raw values of the cases below are token paths of the design contract (`color.akzent`, `space.s4`,
// `text.kopf.familie`). They belong to the contract with the design side and stay as they are.

/// Color token of the UI. Path in the contract: `color.<raw value>`.
public enum ColorToken: String, CaseIterable, Sendable {
    case accent = "akzent"
    case background = "grund"
    case surface = "flaeche"
    case border = "rahmen"
    case text
    case textMuted = "textLeise"
}

/// Spacing token. Path: `space.<name>`. Values in points.
public enum SpaceToken: String, CaseIterable, Sendable {
    case s1, s2, s3, s4, s5, s6, s8
}

/// Radius token. Path: `radius.<name>`. Values in points.
public enum RadiusToken: String, CaseIterable, Sendable {
    case s, m, l
}

/// Text style. Path: `text.<raw value>.familie`, `.groesse`, `.gewicht`.
public enum TextToken: String, CaseIterable, Sendable {
    case heading = "kopf"
    case body = "fliesstext"
    case caption = "beschriftung"
}

/// A resolved text style. The font "System" selects the system font.
public struct TextStyle: Sendable, Equatable {
    public var families: [String]
    public var size: CGFloat
    public var weight: Int

    public init(families: [String], size: CGFloat, weight: Int) {
        self.families = families; self.size = size; self.weight = weight
    }

    public var font: Font {
        let fontWeight = TextStyle.fontWeight(weight)
        if let name = families.first, name != "System" {
            return Font.custom(name, size: size).weight(fontWeight)
        }
        return Font.system(size: size, weight: fontWeight)
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

    /// Placeholders only. Without a contract, this set applies.
    public static let placeholder = Theme(contract: Placeholder.light, dark: Placeholder.dark, source: "Placeholder")

    /// `light` delivers all values. `dark` is optional and replaces only the colors in dark mode.
    public init(contract light: TokenSet, dark: TokenSet? = nil, source: String) {
        var missing: [String] = []
        let lightIndex = Theme.index(light)
        let darkIndex = dark.map(Theme.index) ?? [:]
        let placeholderLight = Theme.index(Placeholder.light)
        let placeholderDark = Theme.index(Placeholder.dark)
        let darkReport: String? = dark == nil ? nil : "dark: "

        var lightColors: [ColorToken: RGB] = [:]
        var darkColors: [ColorToken: RGB] = [:]
        for c in ColorToken.allCases {
            let path = "color.\(c.rawValue)"
            lightColors[c] = Theme.value(path, from: lightIndex, fallback: placeholderLight, report: "", &missing,
                                         read: Theme.readColor, last: RGB(r: 0, g: 0, b: 0))
            darkColors[c] = Theme.value(path, from: darkIndex, fallback: placeholderDark, report: darkReport, &missing,
                                        read: Theme.readColor, last: RGB(r: 0, g: 0, b: 0))
        }

        var spacing: [SpaceToken: CGFloat] = [:]
        for s in SpaceToken.allCases {
            spacing[s] = Theme.value("space.\(s.rawValue)", from: lightIndex, fallback: placeholderLight, report: "", &missing,
                                     read: Theme.readPoints, last: 0)
        }

        var radii: [RadiusToken: CGFloat] = [:]
        for r in RadiusToken.allCases {
            radii[r] = Theme.value("radius.\(r.rawValue)", from: lightIndex, fallback: placeholderLight, report: "", &missing,
                                   read: Theme.readPoints, last: 0)
        }

        var texts: [TextToken: TextStyle] = [:]
        for t in TextToken.allCases {
            let path = "text.\(t.rawValue)"
            let family = Theme.value(path + ".familie", from: lightIndex, fallback: placeholderLight, report: "", &missing,
                                     read: Theme.readFamily, last: ["System"])
            let size = Theme.value(path + ".groesse", from: lightIndex, fallback: placeholderLight, report: "", &missing,
                                   read: Theme.readPoints, last: 13)
            let weight = Theme.value(path + ".gewicht", from: lightIndex, fallback: placeholderLight, report: "", &missing,
                                     read: Theme.readWeight, last: 400)
            texts[t] = TextStyle(families: family, size: size, weight: weight)
        }

        self.source = source
        self.missing = missing
        self.colors = [.light: lightColors, .dark: darkColors]
        self.spacing = spacing
        self.radii = radii
        self.texts = texts
    }

    // MARK: - Access

    public func rgb(_ color: ColorToken, _ mode: Mode) -> RGB {
        colors[mode]?[color] ?? RGB(r: 0, g: 0, b: 0)
    }

    /// Color for SwiftUI. The mode comes from the ColorScheme of the environment.
    public func color(_ color: ColorToken, _ scheme: ColorScheme) -> Color {
        let c = rgb(color, Mode(scheme))
        return Color(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    public func space(_ s: SpaceToken) -> CGFloat { spacing[s] ?? 0 }

    public func radius(_ r: RadiusToken) -> CGFloat { radii[r] ?? 0 }

    public func text(_ t: TextToken) -> TextStyle {
        texts[t] ?? TextStyle(families: ["System"], size: 13, weight: 400)
    }

    // MARK: - Resolving

    private static func index(_ set: TokenSet) -> [String: TokenValue] {
        Dictionary(set.tokens.map { ($0.id, $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    /// Value from the contract, otherwise from the placeholder. If it is missing or has the wrong type,
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

    /// The contract file in the app bundle, if the build copied it. nil means the placeholder applies.
    static func contractFile(in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: "tokens", withExtension: "json")
    }
}

public extension EnvironmentValues {
    /// The values of the UI. Default: the placeholder.
    @Entry var theme: Theme = .placeholder
}
