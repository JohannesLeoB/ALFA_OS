import Foundation
import Pages

public enum DocFile {
    public static let namespace = "https://alfa.app/draws"
    static let tag = "doc"

    public static func json(_ doc: DrawsDoc) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let raw = try? encoder.encode(doc), let text = String(data: raw, encoding: .utf8) else { throw DocError.encode }
        return Data(text.replacingOccurrences(of: "]]>", with: "]]\\u003E").utf8)
    }

    public static func write(_ doc: DrawsDoc, sheet: Sheet) throws -> Data {
        let body = try json(doc)
        guard let text = String(data: body, encoding: .utf8) else { throw DocError.encode }
        let svg = SVGRenderer().svg(sheet.page, fonts: sheet.faces)
        guard let cut = svg.firstIndex(of: "\n") else { throw DocError.encode }
        let meta = "<metadata><draws:\(tag) xmlns:draws=\"\(namespace)\"><![CDATA[\(text)]]></draws:\(tag)></metadata>"
        return Data((svg[..<cut] + "\n" + meta + svg[cut...]).utf8)
    }

    public static func read(_ data: Data) throws -> DrawsDoc? {
        let found = Finder()
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.delegate = found
        parser.parse()
        guard let body = found.body else { return nil }
        struct Head: Decodable { var schema: Int? }
        guard let head = try? JSONDecoder().decode(Head.self, from: body) else { throw DocError.corrupt }
        if let schema = head.schema, schema > DrawsDoc.schema { throw DocError.newer(schema) }
        guard let doc = try? JSONDecoder().decode(DrawsDoc.self, from: body) else { throw DocError.corrupt }
        return doc
    }

    public static func svg(_ doc: DrawsDoc, shelf: PackShelf, fonts: SheetFonts) throws -> Data {
        let sheets = try shelf.sheets(doc, fonts: fonts)
        guard sheets.indices.contains(doc.render.page) else { throw DocError.missing("page") }
        return try write(doc, sheet: sheets[doc.render.page])
    }
}

private final class Finder: NSObject, XMLParserDelegate {
    var body: Data?
    private var inside = false
    private var buffer = Data()

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        if body == nil, namespaceURI == DocFile.namespace, name == DocFile.tag {
            inside = true
            buffer = Data()
        }
    }

    func parser(_ parser: XMLParser, foundCDATA block: Data) {
        if inside { buffer.append(block) }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if inside, namespaceURI == DocFile.namespace, name == DocFile.tag {
            inside = false
            body = buffer
            parser.abortParsing()
        }
    }
}
