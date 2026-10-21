import CoreGraphics
import Foundation

struct Matrix {
    var a = 1.0, b = 0.0, c = 0.0, d = 1.0, tx = 0.0, ty = 0.0

    init() {}

    init(_ text: String?) {
        let v = (text ?? "").split(separator: " ").compactMap { Double($0) }
        guard v.count == 6 else { return }
        a = v[0]; b = v[1]; c = v[2]; d = v[3]; tx = v[4]; ty = v[5]
    }

    func apply(_ p: CGPoint) -> CGPoint {
        CGPoint(x: a * p.x + c * p.y + tx, y: b * p.x + d * p.y + ty)
    }

    func then(_ o: Matrix) -> Matrix {
        var m = Matrix()
        m.a = a * o.a + b * o.c; m.b = a * o.b + b * o.d
        m.c = c * o.a + d * o.c; m.d = c * o.b + d * o.d
        m.tx = tx * o.a + ty * o.c + o.tx; m.ty = tx * o.b + ty * o.d + o.ty
        return m
    }

    func box(_ points: [CGPoint]) -> CGRect? {
        let q = points.map(apply)
        guard let x0 = q.map(\.x).min(), let x1 = q.map(\.x).max(), let y0 = q.map(\.y).min(), let y1 = q.map(\.y).max() else { return nil }
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}

enum Idml {
    static let mm = 25.4 / 72
    static let shapes: Set<String> = ["TextFrame", "Rectangle", "Oval", "Polygon", "GraphicLine"]
    static let placed: Set<String> = ["Image", "EPS", "PDF", "ImportedPage", "WMF", "PICT"]

    struct Hit {
        var node: Node
        var box: CGRect
    }

    static func read(_ data: Data, _ r: inout Ingested) throws {
        guard let zip = Zip.open(data), let map = Dom.parse(Zip.file(zip, "designmap.xml")) else { throw Failure.damaged(.idml) }
        let src = { (tag: String) in map.all(tag).compactMap { $0.attrs["src"] } }
        var stories: [String: Node] = [:]
        for path in src("idPkg:Story") {
            if let story = Dom.parse(Zip.file(zip, path))?.first("Story") { stories[story.attrs["Self"] ?? path] = story }
        }
        let styles = Dom.parse(Zip.file(zip, "Resources/Styles.xml"))
        var book = Book(spreads: [], masters: [], paragraphStyles: names(styles, "ParagraphStyle"), characterStyles: names(styles, "CharacterStyle"))
        for path in src("idPkg:MasterSpread") {
            if let node = Dom.parse(Zip.file(zip, path))?.first("MasterSpread") { book.masters.append(spread(node, stories, &r)) }
        }
        for path in src("idPkg:Spread") {
            if let node = Dom.parse(Zip.file(zip, path))?.first("Spread") { book.spreads.append(spread(node, stories, &r)) }
        }
        r.layout = book
        let frames = book.spreads.flatMap { $0.pages.flatMap(\.frames) + $0.loose }
        r.text = frames.filter { $0.kind == .text && !$0.text.isEmpty }.map(\.text).joined(separator: "\n")
        if book.spreads.isEmpty { r.note("idml.empty") }
    }

    static func names(_ root: Node?, _ tag: String) -> [String] {
        var seen: [String] = []
        for name in (root?.all(tag) ?? []).compactMap({ $0.attrs["Name"] }) where !seen.contains(name) { seen.append(name) }
        return seen
    }

    static func spread(_ node: Node, _ stories: [String: Node], _ r: inout Ingested) -> Spread {
        var pages: [(Folio, CGRect)] = []
        for page in node.kids where page.name == "Page" {
            let b = (page.attrs["GeometricBounds"] ?? "").split(separator: " ").compactMap { Double($0) }
            guard b.count == 4 else { r.note("idml.page"); continue }
            let corners = [CGPoint(x: b[1], y: b[0]), CGPoint(x: b[3], y: b[2])]
            guard let area = Matrix(page.attrs["ItemTransform"]).box(corners) else { continue }
            let master = page.attrs["AppliedMaster"].flatMap { $0 == "n" ? nil : $0 }
            let folio = Folio(name: page.attrs["Name"] ?? page.attrs["Self"] ?? "", size: CGSize(width: area.width * mm, height: area.height * mm), master: master, frames: [])
            pages.append((folio, area))
        }
        var loose: [Frame] = []
        let origin = pages.first?.1.origin ?? .zero
        for hit in items(node, Matrix(), &r) {
            let frame = frame(hit, stories)
            let center = CGPoint(x: hit.box.midX, y: hit.box.midY)
            if let at = pages.firstIndex(where: { $0.1.contains(center) }) {
                pages[at].0.frames.append(place(frame, hit.box, pages[at].1.origin))
            } else {
                loose.append(place(frame, hit.box, origin))
            }
        }
        return Spread(id: node.attrs["Self"] ?? "", name: node.attrs["Name"] ?? "", pages: pages.map(\.0), loose: loose)
    }

    static func place(_ frame: Frame, _ box: CGRect, _ origin: CGPoint) -> Frame {
        var out = frame
        out.rect = CGRect(x: (box.minX - origin.x) * mm, y: (box.minY - origin.y) * mm, width: box.width * mm, height: box.height * mm)
        return out
    }

    static func items(_ parent: Node, _ outer: Matrix, _ r: inout Ingested) -> [Hit] {
        var hits: [Hit] = []
        for node in parent.kids {
            let matrix = Matrix(node.attrs["ItemTransform"]).then(outer)
            if node.name == "Group" {
                hits += items(node, matrix, &r)
            } else if shapes.contains(node.name) {
                let points = node.all("PathPointType").compactMap { p -> CGPoint? in
                    let v = (p.attrs["Anchor"] ?? "").split(separator: " ").compactMap { Double($0) }
                    return v.count == 2 ? CGPoint(x: v[0], y: v[1]) : nil
                }
                if let box = matrix.box(points) { hits.append(Hit(node: node, box: box)) } else { r.note("idml.geometry") }
            }
        }
        return hits
    }

    static func frame(_ hit: Hit, _ stories: [String: Node]) -> Frame {
        let node = hit.node
        let link = node.all("Link").first?.attrs["LinkResourceURI"]
        let isImage = node.kids.contains { placed.contains($0.name) }
        var frame = Frame(id: node.attrs["Self"] ?? "", kind: isImage ? .image : .rect, rect: .zero, text: "", paragraph: nil, character: nil, link: link)
        guard node.name == "TextFrame" else { return frame }
        frame.kind = .text
        guard let story = stories[node.attrs["ParentStory"] ?? ""] else { return frame }
        frame.text = text(story).trimmingCharacters(in: .newlines)
        frame.paragraph = story.all("ParagraphStyleRange").first.flatMap { style($0.attrs["AppliedParagraphStyle"]) }
        frame.character = story.all("CharacterStyleRange").first.flatMap { style($0.attrs["AppliedCharacterStyle"]) }
        return frame
    }

    static func text(_ node: Node) -> String {
        node.kids.map { $0.name == "Content" ? $0.text : ($0.name == "Br" ? "\n" : text($0)) }.joined()
    }

    static func style(_ applied: String?) -> String? {
        applied.flatMap { $0.split(separator: "/").last }.flatMap { String($0).removingPercentEncoding }
    }
}
