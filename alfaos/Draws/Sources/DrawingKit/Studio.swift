import CoreGraphics
import Foundation
import Pages

public extension TemplatePack {
    enum Tier: String, Sendable { case title, value, note, label, dim, mark }

    struct Dim: Sendable, Equatable {
        public var tick: Double
        public var overrun: Double
        public var stub: Double
        public var text: Double
    }

    struct Seal: Sendable, Equatable {
        public var angle: Double
        public var width: Double
        public var height: Double
        public var x: Double
        public var y: Double
    }

    struct Logo: Sendable, Equatable {
        public var file: String
        public var frame: CGRect
        public var x: Double
        public var base: Double
        public var size: Double
        public var anchor: Anchor
        public var cover: Bool
        public var data: Data?
    }

    struct Piece: Sendable, Equatable {
        public var label: String
        public var key: String
        public var literal: String
        public var x: Double
        public var gap: Double
        public var base: Double
        public var mono: Bool
        public var tier: Tier
    }

    struct Slot: Sendable, Equatable {
        public var width: Double
        public var pieces: [Piece]
    }

    struct Band: Sendable, Equatable {
        public var height: Double
        public var heavy: Bool
        public var cut: Bool
        public var slots: [Slot]
    }

    struct Column: Sendable, Equatable {
        public var left: Double
        public var width: Double
        public var inset: Double
        public var blocks: Blocks
        public var notes: Notes
        public var title: Title

        public struct Blocks: Sendable, Equatable {
            public var top: Double
            public var height: Double
            public var rows: Int
            public var row: Double
            public var head: Double
            public var headBase: Double
            public var rowBase: Double
            public var glyph: Double
            public var split: [Int]
            public var materials: String
        }

        public struct Notes: Sendable, Equatable {
            public var top: Double
            public var height: Double
            public var base: Double
            public var step: Double
            public var x: Double
        }

        public struct Title: Sendable, Equatable {
            public var top: Double
            public var height: Double
            public var bands: [Band]
        }
    }

    struct Deck: Sendable, Equatable {
        public var caps: Bool
        public var titleKey: String
        public var titleX: Double
        public var titleTop: Double
        public var titleWidth: Double
        public var titleHeight: Double
        public var titleLeading: Double
        public var headX: Double
        public var headBase: Double
        public var footBase: Double
        public var foot: [Foot]
        public var captionLeading: Double
        public var captionGap: Double

        public struct Foot: Sendable, Equatable {
            public var x: Double
            public var text: String
            public var end: Bool
        }
    }
}

extension Packs {
    static func studio(_ r: Reader, into pack: inout TemplatePack) -> [String] {
        var defects: [String] = []
        pack.ciName = r.text("ci", or: "")
        pack.divider = r.flag("divider", or: false)
        if let o = r.maybe("outer") {
            pack.outer = .init(left: o.number("left"), top: o.number("top"), right: o.number("right"), bottom: o.number("bottom"))
            defects += o.deep
        }
        if let d = r.maybe("dim") {
            pack.dim = .init(tick: d.number("tick"), overrun: d.number("overrun"), stub: d.number("stub"), text: d.number("text"))
            defects += d.deep
        }
        if let s = r.maybe("seal") {
            pack.seal = .init(angle: s.number("angle"), width: s.number("width"), height: s.number("height"),
                              x: s.number("x"), y: s.number("y"))
            defects += s.deep
        }
        if let l = r.maybe("logo") {
            let f = l.numbers("frame", count: 4), t = l.numbers("text", count: 2)
            pack.logo = .init(file: l.text("file"), frame: CGRect(x: f[0], y: f[1], width: f[2], height: f[3]),
                              x: t[0], base: t[1], size: l.number("size", or: 0), anchor: Anchor(rawValue: l.text("anchor", or: "start")) ?? .start,
                              cover: l.flag("cover", or: false), data: nil)
            defects += l.deep
        }
        if let c = r.maybe("column") {
            pack.column = column(c)
            defects += c.deep
        }
        if let d = r.maybe("deck") {
            pack.deck = deck(d)
            defects += d.deep
        }
        return defects
    }

    private static func column(_ c: Reader) -> TemplatePack.Column {
        let b = c.object("blocks"), n = c.object("notes"), t = c.object("title")
        let blocks = TemplatePack.Column.Blocks(
            top: b.number("top"), height: b.number("height"), rows: b.count("rows"), row: b.number("row"),
            head: b.number("head"), headBase: b.number("headBase"), rowBase: b.number("rowBase"),
            glyph: b.number("glyph", or: 0.6), split: b.counts("split"), materials: b.text("materials", or: ""))
        let notes = TemplatePack.Column.Notes(
            top: n.number("top"), height: n.number("height"), base: n.number("base"), step: n.number("step"),
            x: n.number("x", or: c.number("inset")))
        let bands = t.list("bands").map { band in
            TemplatePack.Band(
                height: band.number("h"), heavy: band.flag("heavy", or: false),
                cut: band.flag("cut", or: true),
                slots: band.list("slots").map { slot in
                    TemplatePack.Slot(width: slot.number("w"), pieces: slot.list("pieces").map(piece))
                })
        }
        let title = TemplatePack.Column.Title(top: t.number("top"), height: t.number("height"), bands: bands)
        return TemplatePack.Column(left: c.number("left"), width: c.number("width"), inset: c.number("inset"),
                                   blocks: blocks, notes: notes, title: title)
    }

    private static func piece(_ p: Reader) -> TemplatePack.Piece {
        TemplatePack.Piece(
            label: p.text("label", or: ""), key: p.text("key", or: ""), literal: p.text("text", or: ""),
            x: p.number("x"), gap: p.number("gap", or: 0), base: p.number("base"), mono: p.flag("mono", or: false),
            tier: TemplatePack.Tier(rawValue: p.text("tier", or: "value")) ?? .value)
    }

    private static func deck(_ d: Reader) -> TemplatePack.Deck {
        let t = d.object("title"), h = d.object("head"), f = d.object("foot"), c = d.object("caption")
        let foot = f.list("items").map { TemplatePack.Deck.Foot(x: $0.number("x"), text: $0.text("text"), end: $0.flag("end", or: false)) }
        return TemplatePack.Deck(
            caps: d.flag("caps", or: false), titleKey: t.text("key", or: "title"), titleX: t.number("x"), titleTop: t.number("top"),
            titleWidth: t.number("width"), titleHeight: t.number("height"), titleLeading: t.number("leading"),
            headX: h.number("x"), headBase: h.number("base"), footBase: f.number("base"), foot: foot,
            captionLeading: c.number("leading"), captionGap: c.number("gap"))
    }
}

public extension Packs {
    static func loadTemplate(_ folder: URL, also: [URL]) throws -> Loaded<TemplatePack> {
        var loaded = try loadTemplate(folder)
        if let file = loaded.pack.logo?.file, !file.isEmpty {
            loaded.pack.logo?.data = ([folder] + also).lazy
                .compactMap { try? Data(contentsOf: $0.appendingPathComponent(file)) }.first
        }
        return loaded
    }
}
