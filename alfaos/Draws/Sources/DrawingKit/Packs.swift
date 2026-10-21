import Foundation

public struct CIPack: Sendable {
    public var placeholder: Bool
    public var font: String
    public var pdfFont: String
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

    public init(top: Double, side: Double, front: Double, edge: Double, outline: Double,
                shadow: Double, spread: Double, accent: String?) {
        self.top = top; self.side = side; self.front = front; self.edge = edge
        self.outline = outline; self.shadow = shadow; self.spread = spread; self.accent = accent
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
    public var scales: [Double]
    public var isoScales: [Double]
    public var isoMargin: Insets
    public var viewTitles: [String: String]
    public var titles: [String: String]
    public var block: TitleBlock

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
        let pack = CIPack(
            placeholder: r.flag("platzhalter"),
            font: r.text("font"), pdfFont: r.text("pdfFont"),
            ink: r.text("ink"), muted: r.text("muted"), signal: r.text("signal"), paper: r.text("paper"),
            lineFrame: r.number("lineFrame"), lineBlock: r.number("lineBlock"), lineEdge: r.number("lineEdge"),
            lineDimension: r.number("lineDimension"), lineExtension: r.number("lineExtension"), lineTick: r.number("lineTick"),
            textDimension: r.number("textDimension"), textTitle: r.number("textTitle"), textLabel: r.number("textLabel"),
            textValue: r.number("textValue"), textNote: r.number("textNote"),
            weightTitle: Int(r.number("weightTitle")),
            tints: r.table("tints"), accent: r.text("accent"),
            iso: IsoStyle(top: iso.number("top"), side: iso.number("side"), front: iso.number("front"),
                          edge: iso.number("edge"), outline: iso.number("outline"),
                          shadow: iso.number("shadow"), spread: iso.number("spread"), accent: nil)
        )
        return Loaded(pack: pack, defects: r.defects + iso.defects)
    }

    public static func decodeTemplate(_ data: Data) throws -> Loaded<TemplatePack> {
        let r = try Reader(data, prefix: "template")
        let frame = r.object("frame"), iso = r.object("isoMargin"), b = r.object("block")
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
        let pack = TemplatePack(
            placeholder: r.flag("platzhalter"), format: r.text("format"),
            width: r.number("width"), height: r.number("height"), frame: insets(frame),
            method: method ?? .first,
            band: r.number("band"), gap: r.number("gap"), chainOffset: r.number("chainOffset"), chainStep: r.number("chainStep"),
            minPaperLength: r.number("minPaperLength"), tick: r.number("tick"), extensionGap: r.number("extensionGap"),
            titleOffset: r.number("titleOffset"),
            scales: r.numbers("scales"), isoScales: r.numbers("isoScales"), isoMargin: insets(iso),
            viewTitles: r.table("viewTitles"), titles: r.table("titles"), block: block
        )
        var defects = r.defects + frame.defects + iso.defects + b.defects
        if method == nil, !defects.contains("template.method") { defects.append("template.method") }
        return Loaded(pack: pack, defects: defects)
    }
}

final class Reader {
    let root: [String: Any]
    let prefix: String
    private(set) var defects: [String] = []

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

    func numbers(_ key: String) -> [Double] {
        guard let v = root[key] as? [Double], !v.isEmpty, v.allSatisfy({ $0.isFinite && $0 > 0 }) else { miss(key); return [] }
        return v
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
        return Reader(o, prefix: "\(prefix).\(key)", missing: o == nil)
    }

    func list(_ key: String) -> [Reader] {
        guard let v = root[key] as? [[String: Any]] else { miss(key); return [] }
        return v.enumerated().map { Reader($0.element, prefix: "\(prefix).\(key)[\($0.offset)]", missing: false) }
    }
}
