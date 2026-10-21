import Foundation

public struct CIPack: Sendable {
    public var placeholder: Bool
    public var ink: String
    public var muted: String
    public var signal: String
    public var paper: String
    public var lineFrame: Double
    public var lineBlock: Double
    public var lineEdge: Double
    public var lineDimension: Double
    public var lineExtension: Double
    public var lineTick: Double
    public var textDimension: Double
    public var textTitle: Double
    public var textLabel: Double
    public var textValue: Double
    public var textNote: Double
    public var weightTitle: Int
    public var tints: [String: String]
    public var accent: String
    public var iso: IsoStyle
    public var colorDimension = ""
    public var colorRow = ""
    public var colorCell = ""
    public var lineRow = 0.0
    public var lineCell = 0.0
    public var textMark = 0.0
    public var textDeck = 0.0
    public var textCaption = 0.0
}

public struct IsoStyle: Sendable, Equatable {
    public var top: Double
    public var side: Double
    public var front: Double
    public var edge: Double
    public var outline: Double
    public var shadow: Double
    public var spread: Double
    public var accent: String?
    public var faces: [String]?
    public var accentColor: String?

    public init(top: Double, side: Double, front: Double, edge: Double, outline: Double,
                shadow: Double, spread: Double, accent: String?, faces: [String]? = nil, accentColor: String? = nil) {
        self.top = top; self.side = side; self.front = front; self.edge = edge
        self.outline = outline; self.shadow = shadow; self.spread = spread; self.accent = accent
        self.faces = faces; self.accentColor = accentColor
    }
}

public struct TemplatePack: Sendable {
    public var placeholder: Bool
    public var format: String
    public var width: Double
    public var height: Double
    public var frame: Insets
    public var method: ProjectionMethod
    public var band: Double
    public var gap: Double
    public var chainOffset: Double
    public var chainStep: Double
    public var minPaperLength: Double
    public var tick: Double
    public var extensionGap: Double
    public var titleOffset: Double
    public var noScale: String
    public var scales: [Double]
    public var isoScales: [Double]
    public var isoMargin: Insets
    public var viewTitles: [String: String]
    public var titles: [String: String]
    public var block: TitleBlock
    public var presentation: Presentation
    public var ciName = ""
    public var outer: Insets?
    public var divider = false
    public var dim: Dim?
    public var seal: Seal?
    public var logo: Logo?
    public var column: Column?
    public var deck: Deck?

    public struct Presentation: Sendable {
        public var columnGap: Double
        public var titleGap: Double
        public var labelGap: Double
        public var labelStep: Double
        public var blockGap: Double
        public var blockRow: Double
        public var swatch: Double
        public var stamp: String
        public var stampStatuses: [String]
        public var stampSize: Double
        public var totalPad: Double
    }

    public struct Insets: Codable, Sendable {
        public var left: Double
        public var top: Double
        public var right: Double
        public var bottom: Double
    }

    public struct Row: Codable, Sendable {
        public var label: String
        public var key: String
    }

    public struct TitleBlock: Codable, Sendable {
        public var inset: Double
        public var notes: [String]
        public var notesTop: Double
        public var notesStep: Double
        public var rowsTop: Double
        public var rowHeight: Double
        public var labelBaseline: Double
        public var valueBaseline: Double
        public var rows: [Row]
        public var footerHeight: Double
        public var footer: [String]
        public var footerStep: Double
        public var stamp: String
    }
}

public struct Loaded<T: Sendable>: Sendable {
    public var pack: T
    public var defects: [String]
}

public enum Packs {
    public static func loadCI(_ folder: URL) throws -> Loaded<CIPack> {
        try decodeCI(Data(contentsOf: folder.appendingPathComponent("ci.json")))
    }

    public static func loadTemplate(_ folder: URL) throws -> Loaded<TemplatePack> {
        try decodeTemplate(Data(contentsOf: folder.appendingPathComponent("template.json")))
    }

    public static func decodeCI(_ data: Data) throws -> Loaded<CIPack> {
        let r = try Reader(data, prefix: "ci")
        let iso = r.object("iso")
        var pack = CIPack(
            placeholder: r.flag("platzhalter"),
            ink: r.color("ink"), muted: r.color("muted"), signal: r.color("signal"), paper: r.color("paper"),
            lineFrame: r.number("lineFrame"), lineBlock: r.number("lineBlock"), lineEdge: r.number("lineEdge"),
            lineDimension: r.number("lineDimension"), lineExtension: r.number("lineExtension"), lineTick: r.number("lineTick"),
            textDimension: r.number("textDimension"), textTitle: r.number("textTitle"), textLabel: r.number("textLabel"),
            textValue: r.number("textValue"), textNote: r.number("textNote"),
            weightTitle: r.weight("weightTitle"),
            tints: r.colours("tints"), accent: r.color("accent"),
            iso: IsoStyle(top: iso.number("top"), side: iso.number("side"), front: iso.number("front"),
                          edge: iso.number("edge"), outline: iso.number("outline"),
                          shadow: iso.number("shadow"), spread: iso.number("spread"), accent: nil)
        )
        pack.colorDimension = r.color("colorDimension", or: pack.ink)
        pack.colorRow = r.color("colorRow", or: pack.ink)
        pack.colorCell = r.color("colorCell", or: pack.ink)
        pack.lineRow = r.number("lineRow", or: pack.lineDimension)
        pack.lineCell = r.number("lineCell", or: pack.lineDimension)
        pack.textMark = r.number("textMark", or: pack.textTitle)
        pack.textDeck = r.number("textDeck", or: pack.textTitle)
        pack.textCaption = r.number("textCaption", or: pack.textDimension)
        return Loaded(pack: pack, defects: r.defects + iso.defects)
    }

    public static func decodeTemplate(_ data: Data) throws -> Loaded<TemplatePack> {
        let r = try Reader(data, prefix: "template")
        let frame = r.object("frame"), iso = r.object("isoMargin"), b = r.object("block"), pr = r.object("presentation")
        func insets(_ o: Reader) -> TemplatePack.Insets {
            .init(left: o.number("left"), top: o.number("top"), right: o.number("right"), bottom: o.number("bottom"))
        }
        let rows = b.list("rows").map { TemplatePack.Row(label: $0.text("label"), key: $0.text("key")) }
        let block = TemplatePack.TitleBlock(
            inset: b.number("inset"), notes: b.strings("notes"), notesTop: b.number("notesTop"), notesStep: b.number("notesStep"),
            rowsTop: b.number("rowsTop"), rowHeight: b.number("rowHeight"),
            labelBaseline: b.number("labelBaseline"), valueBaseline: b.number("valueBaseline"), rows: rows,
            footerHeight: b.number("footerHeight"), footer: b.strings("footer"), footerStep: b.number("footerStep"),
            stamp: b.text("stamp")
        )
        let method = ProjectionMethod(rawValue: r.text("method"))
        var pack = TemplatePack(
            placeholder: r.flag("platzhalter"), format: r.text("format"),
            width: r.number("width"), height: r.number("height"), frame: insets(frame),
            method: method ?? .first,
            band: r.number("band"), gap: r.number("gap"), chainOffset: r.number("chainOffset"), chainStep: r.number("chainStep"),
            minPaperLength: r.number("minPaperLength"), tick: r.number("tick"), extensionGap: r.number("extensionGap"),
            titleOffset: r.number("titleOffset"), noScale: r.text("noScale"),
            scales: r.ratios("scales"), isoScales: r.ratios("isoScales"), isoMargin: insets(iso),
            viewTitles: r.table("viewTitles"), titles: r.table("titles"), block: block,
            presentation: TemplatePack.Presentation(
                columnGap: pr.number("columnGap"), titleGap: pr.number("titleGap"), labelGap: pr.number("labelGap"),
                labelStep: pr.number("labelStep"), blockGap: pr.number("blockGap"), blockRow: pr.number("blockRow"),
                swatch: pr.number("swatch"), stamp: pr.text("stamp"), stampStatuses: pr.strings("stampStatuses"),
                stampSize: pr.number("stampSize"), totalPad: pr.number("totalPad"))
        )
        var defects = r.defects + frame.defects + iso.defects + b.defects + pr.defects
        if method == nil, !defects.contains("template.method") { defects.append("template.method") }
        if pack.chainOffset + pack.chainStep >= pack.band, !defects.contains("template.band") { defects.append("template.band") }
        defects += studio(r, into: &pack)
        return Loaded(pack: pack, defects: defects)
    }
}

final class Reader {
    let root: [String: Any]
    let prefix: String
    private(set) var defects: [String] = []
    private var kids: [Reader] = []

    var deep: [String] { defects + kids.flatMap(\.deep) }

    init(_ data: Data, prefix: String) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DrawingError.pack(["\(prefix): no object"])
        }
        self.root = root
        self.prefix = prefix
    }

    init(_ root: [String: Any]?, prefix: String, missing: Bool) {
        self.root = root ?? [:]
        self.prefix = prefix
        if missing { defects.append(prefix) }
    }

    private func miss(_ key: String) { defects.append("\(prefix).\(key)") }

    func text(_ key: String) -> String {
        guard let v = root[key] as? String else { miss(key); return "" }
        return v
    }

    func number(_ key: String) -> Double {
        guard let v = root[key] as? Double, v.isFinite else { miss(key); return 0 }
        return v
    }

    func flag(_ key: String) -> Bool { root[key] as? Bool ?? false }

    func flag(_ key: String, or fallback: Bool) -> Bool { root[key] as? Bool ?? fallback }

    func number(_ key: String, or fallback: Double) -> Double {
        guard let raw = root[key] else { return fallback }
        guard let v = raw as? Double, v.isFinite else { miss(key); return fallback }
        return v
    }

    func text(_ key: String, or fallback: String) -> String {
        guard let raw = root[key] else { return fallback }
        guard let v = raw as? String else { miss(key); return fallback }
        return v
    }

    func color(_ key: String, or fallback: String) -> String {
        guard let raw = root[key] else { return fallback }
        guard let v = raw as? String, Reader.isColour(v) else { miss(key); return fallback }
        return v
    }

    func numbers(_ key: String, count: Int) -> [Double] {
        guard let v = root[key] as? [Double], v.count == count, v.allSatisfy(\.isFinite) else {
            miss(key)
            return Array(repeating: 0, count: count)
        }
        return v
    }

    func counts(_ key: String) -> [Int] {
        guard let raw = root[key] else { return [] }
        guard let v = raw as? [Double] else { miss(key); return [] }
        let ints = v.compactMap { Int(exactly: $0) }
        guard ints.count == v.count else { miss(key); return [] }
        return ints
    }

    func count(_ key: String) -> Int {
        guard let v = root[key] as? Double, let n = Int(exactly: v), n >= 0 else { miss(key); return 0 }
        return n
    }

    func maybe(_ key: String) -> Reader? {
        guard let o = root[key] as? [String: Any] else { return nil }
        let kid = Reader(o, prefix: "\(prefix).\(key)", missing: false)
        kids.append(kid)
        return kid
    }

    func color(_ key: String) -> String {
        guard let v = root[key] as? String, Reader.isColour(v) else { miss(key); return "" }
        return v
    }

    func colours(_ key: String) -> [String: String] {
        var values = table(key)
        for (name, value) in values where !Reader.isColour(value) {
            defects.append("\(prefix).\(key).\(name)")
            values[name] = ""
        }
        return values
    }

    func weight(_ key: String) -> Int {
        guard let v = root[key] as? Double, let w = Int(exactly: v), (100...900).contains(w) else { miss(key); return 400 }
        return w
    }

    func ratios(_ key: String) -> [Double] {
        guard let v = root[key] as? [Any] else { miss(key); return [] }
        let valid = v.compactMap { $0 as? Double }.filter { $0.isFinite && $0 >= 1 && $0 <= 10000 }
        if valid.isEmpty || valid.count != v.count { miss(key) }
        return valid
    }

    static func isColour(_ s: String) -> Bool {
        s.count == 7 && s.hasPrefix("#") && s.dropFirst().allSatisfy { $0.isHexDigit }
    }

    func strings(_ key: String) -> [String] {
        guard let v = root[key] as? [String] else { miss(key); return [] }
        return v
    }

    func table(_ key: String) -> [String: String] {
        guard let v = root[key] as? [String: String] else { miss(key); return [:] }
        return v
    }

    func object(_ key: String) -> Reader {
        let o = root[key] as? [String: Any]
        let kid = Reader(o, prefix: "\(prefix).\(key)", missing: o == nil)
        kids.append(kid)
        return kid
    }

    func list(_ key: String) -> [Reader] {
        guard let v = root[key] as? [[String: Any]] else { miss(key); return [] }
        let made = v.enumerated().map { Reader($0.element, prefix: "\(prefix).\(key)[\($0.offset)]", missing: false) }
        kids += made
        return made
    }
}

public struct Material: Sendable, Equatable, Codable {
    public var code: String
    public var name: String
    public var tone: String
    public var status: String

    public init(code: String, name: String, tone: String, status: String) {
        self.code = code; self.name = name; self.tone = tone; self.status = status
    }
}

public struct MaterialPack: Sendable {
    public var placeholder: Bool
    public var materials: [Material]
    public var slots: [String: String]

    public func material(_ code: String) -> Material? { materials.first { $0.code == code } }
}

public extension Packs {
    static func loadMaterial(_ folder: URL) throws -> Loaded<MaterialPack> {
        try decodeMaterial(Data(contentsOf: folder.appendingPathComponent("material.json")))
    }

    static func decodeMaterial(_ data: Data) throws -> Loaded<MaterialPack> {
        let r = try Reader(data, prefix: "material")
        var defects: [String] = []
        var materials: [Material] = []
        for item in r.list("materials") {
            let tone = item.object("tone")
            materials.append(Material(
                code: item.text("code"), name: item.text("name"),
                tone: tone.color("srgb"), status: item.text("status")
            ))
            defects += item.defects + tone.defects
        }
        let slots = r.table("slots")
        let codes = Set(materials.map(\.code))
        for (key, code) in slots.sorted(by: { $0.key < $1.key }) where !codes.contains(code) {
            defects.append("material.slots.\(key)")
        }
        var seen = Set<String>()
        var repeated = Set<String>()
        for code in materials.map(\.code) where !seen.insert(code).inserted {
            repeated.insert(code)
        }
        defects += repeated.sorted().map { "material.materials.\($0)" }
        let pack = MaterialPack(placeholder: r.flag("platzhalter"), materials: materials, slots: slots)
        return Loaded(pack: pack, defects: r.defects + defects)
    }
}
