import Foundation
import ZIPFoundation

final class Node {
    let name: String
    let attrs: [String: String]
    var kids: [Node] = []
    var text = ""

    init(_ name: String, _ attrs: [String: String]) {
        self.name = name; self.attrs = attrs
    }

    func first(_ tag: String) -> Node? { kids.first { $0.name == tag } }

    func all(_ tag: String) -> [Node] {
        kids.flatMap { ($0.name == tag ? [$0] : []) + $0.all(tag) }
    }

    var flat: String { text + kids.map(\.flat).joined() }
}

final class Dom: NSObject, XMLParserDelegate {
    private var stack: [Node] = []
    private var top: Node?

    static func parse(_ data: Data?) -> Node? {
        guard let data else { return nil }
        let dom = Dom()
        let parser = XMLParser(data: data)
        parser.delegate = dom
        parser.shouldResolveExternalEntities = false
        return parser.parse() ? dom.top : nil
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        let node = Node(name, attributes)
        stack.last?.kids.append(node)
        if top == nil { top = node }
        stack.append(node)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        _ = stack.popLast()
    }

    func parser(_ parser: XMLParser, foundCharacters text: String) {
        stack.last?.text += text
    }
}

enum Zip {
    static let cap: UInt64 = 64 << 20

    static func open(_ data: Data) -> Archive? { try? Archive(data: data, accessMode: .read, pathEncoding: nil) }

    static func file(_ archive: Archive, _ path: String) -> Data? {
        guard let entry = archive[path], entry.uncompressedSize <= cap else { return nil }
        var out = Data()
        guard (try? archive.extract(entry, consumer: { out.append($0) })) != nil else { return nil }
        return out
    }
}
