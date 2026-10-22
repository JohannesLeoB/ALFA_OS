import Foundation

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

final class Zip {
    static let cap = 64 << 20
    private static let tool = URL(fileURLWithPath: "/usr/bin/unzip")

    private let url: URL
    let names: Set<String>

    private init(url: URL, names: Set<String>) {
        self.url = url; self.names = names
    }

    deinit { try? FileManager.default.removeItem(at: url) }

    static func open(_ data: Data) -> Zip? {
        let url = FileManager.default.temporaryDirectory.appending(path: "zip-\(UUID().uuidString)")
        guard (try? data.write(to: url)) != nil else { return nil }
        guard let listing = run(["-Z1", url.path], limit: cap), let text = String(data: listing, encoding: .utf8) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return Zip(url: url, names: Set(text.split(whereSeparator: \.isNewline).map(String.init)))
    }

    static func file(_ zip: Zip, _ path: String) -> Data? {
        guard zip.names.contains(path) else { return nil }
        let pattern = path.reduce(into: "") { $0 += "\\[]*?".contains($1) ? "\\\($1)" : String($1) }
        return run(["-p", zip.url.path, pattern], limit: cap)
    }

    private static func run(_ arguments: [String], limit: Int) -> Data? {
        let process = Process(), pipe = Pipe()
        process.executableURL = tool
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        var out = Data(), over = false
        while true {
            let chunk = pipe.fileHandleForReading.availableData
            if chunk.isEmpty { break }
            if out.count + chunk.count > limit { over = true; process.terminate(); break }
            out.append(chunk)
        }
        process.waitUntilExit()
        return !over && process.terminationStatus == 0 ? out : nil
    }
}
