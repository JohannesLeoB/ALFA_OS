import CoreGraphics
import Foundation

public enum Kind: String, Sendable, CaseIterable {
    case pdf, png, jpeg, heic, gif, webp, svg, html, mustache, csv, xlsx, idml, dwg, dxf, json, text, unknown

    public var isImage: Bool { [.png, .jpeg, .heic, .gif, .webp].contains(self) }

    public static func detect(_ data: Data, name: String) -> Kind { Sniff.kind(data, name) }
}

public enum Failure: Error, Sendable, Equatable {
    case empty
    case damaged(Kind)
}

public struct Span: Sendable, Equatable {
    public var text: String
    public var rect: CGRect
}

public struct Leaf: Sendable, Equatable {
    public var index: Int
    public var size: CGSize
    public var text: String
    public var runs: [Span]
}

public struct Rows: Sendable, Equatable {
    public var name: String
    public var rows: [[String]]
}

public enum FrameKind: String, Sendable { case text, rect, image }

public struct Frame: Sendable, Equatable {
    public var id: String
    public var kind: FrameKind
    public var rect: CGRect
    public var text: String
    public var paragraph: String?
    public var character: String?
    public var link: String?
}

public struct Folio: Sendable, Equatable {
    public var name: String
    public var size: CGSize
    public var master: String?
    public var frames: [Frame]
}

public struct Spread: Sendable, Equatable {
    public var id: String
    public var name: String
    public var pages: [Folio]
    public var loose: [Frame]
}

public struct Book: Sendable, Equatable {
    public var spreads: [Spread]
    public var masters: [Spread]
    public var paragraphStyles: [String]
    public var characterStyles: [String]
}

public struct Segment: Sendable, Equatable {
    public var layer: String
    public var from: CGPoint
    public var to: CGPoint
}

public struct Polyline: Sendable, Equatable {
    public var layer: String
    public var points: [CGPoint]
    public var closed: Bool
}

public struct Round: Sendable, Equatable {
    public var layer: String
    public var center: CGPoint
    public var radius: Double
    public var start: Double?
    public var end: Double?
}

public struct Caption: Sendable, Equatable {
    public var layer: String
    public var text: String
    public var at: CGPoint
    public var height: Double
}

public struct Drawing: Sendable, Equatable {
    public var units: String
    public var layers: [String]
    public var segments: [Segment]
    public var polylines: [Polyline]
    public var rounds: [Round]
    public var captions: [Caption]
}

public struct Template: Sendable, Equatable {
    public var source: String
    public var variables: [String]
}

public struct Raster: Sendable, Equatable {
    public var data: Data
    public var width: Int
    public var height: Int
}

public struct Ingested: Sendable, Equatable {
    public var kind: Kind
    public var name: String
    public var size: Int
    public var pages: [Leaf] = []
    public var text = ""
    public var tables: [Rows] = []
    public var layout: Book?
    public var drawing: Drawing?
    public var template: Template?
    public var images: [Raster] = []
    public var notes: [String] = []

    mutating func note(_ key: String) {
        if !notes.contains(key) { notes.append(key) }
    }
}

public enum Destination: Sendable, Equatable {
    case files(folder: String)
    case mail(draft: String?)
    case canvas(template: String)
    case assistant

    public var key: String {
        switch self {
        case let .files(folder): return "files:\(folder)"
        case let .mail(draft): return "mail:\(draft ?? "new")"
        case let .canvas(template): return "canvas:\(template)"
        case .assistant: return "assistant"
        }
    }
}

public struct Route: Sendable, Equatable {
    public var name: String
    public var kind: Kind
    public var destination: Destination

    public init(_ item: Ingested, to destination: Destination) {
        self.name = item.name; self.kind = item.kind; self.destination = destination
    }

    public var key: String { "\(kind.rawValue)>\(destination.key)" }
}

extension Ingested {
    public var digest: String {
        func r(_ v: CGFloat) -> String { String(Int(v.rounded())) }
        func box(_ q: CGRect) -> String { "\(r(q.minX)),\(r(q.minY)),\(r(q.width)),\(r(q.height))" }
        func flat(_ s: String) -> String { s.replacingOccurrences(of: "\n", with: "|") }
        var parts = [kind.rawValue]
        if !pages.isEmpty {
            parts.append("pages " + pages.map { p in
                "\(p.index)/\(r(p.size.width))x\(r(p.size.height))/" + p.runs.map { "\($0.text)@\(box($0.rect))" }.joined(separator: ";")
            }.joined(separator: " "))
        }
        if !text.isEmpty { parts.append("text " + flat(text)) }
        parts += tables.map { "table \($0.name) \($0.rows.count) " + flat($0.rows.map { $0.joined(separator: ",") }.joined(separator: "\n")) }
        if let layout {
            parts.append("styles \(layout.paragraphStyles) \(layout.characterStyles)")
            for (tag, list) in [("spread", layout.spreads), ("master", layout.masters)] {
                for s in list {
                    parts.append("\(tag) \(s.id) " + s.pages.map { p in
                        "\(p.name) \(r(p.size.width))x\(r(p.size.height)) \(p.master ?? "-") "
                            + p.frames.map { "\($0.kind.rawValue):\(box($0.rect)):\(flat($0.text)):\($0.paragraph ?? "-"):\($0.character ?? "-"):\($0.link ?? "-")" }.joined(separator: ";")
                    }.joined(separator: " ") + " loose \(s.loose.count)")
                }
            }
        }
        if let drawing {
            parts.append("units \(drawing.units) layers \(drawing.layers)")
            parts.append("lines " + drawing.segments.map { "\($0.layer):\(r($0.from.x)),\(r($0.from.y))-\(r($0.to.x)),\(r($0.to.y))" }.joined(separator: ";"))
            parts.append("polys " + drawing.polylines.map { "\($0.layer):\($0.points.count):\($0.closed)" }.joined(separator: ";"))
            parts.append("rounds " + drawing.rounds.map { "\($0.layer):\(r($0.center.x)),\(r($0.center.y)):\($0.radius):\($0.start ?? -1):\($0.end ?? -1)" }.joined(separator: ";"))
            parts.append("captions " + drawing.captions.map { "\($0.layer):\($0.text):\(r($0.at.x)),\(r($0.at.y)):\($0.height)" }.joined(separator: ";"))
        }
        if let template { parts.append("vars \(template.variables) \(template.source.count)") }
        if !images.isEmpty { parts.append("images " + images.map { "\($0.width)x\($0.height)" }.joined(separator: ",")) }
        if !notes.isEmpty { parts.append("notes \(notes)") }
        return parts.joined(separator: " / ")
    }
}
