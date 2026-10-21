import Foundation
import Intake

public enum Value: Sendable, Equatable, ExpressibleByStringLiteral {
    case text(String)
    case list([Value])
    case map([String: Value])

    public init(stringLiteral value: String) { self = .text(value) }

    var truthy: Bool {
        switch self {
        case let .text(s): return !s.isEmpty
        case let .list(l): return !l.isEmpty
        case .map: return true
        }
    }
}

public struct Rendered: Sendable, Equatable {
    public var text: String
    public var unknown: [String]
}

enum Node: Sendable {
    case text(String)
    case name(String, raw: Bool)
    case block(String, inverted: Bool, [Node])
    case part(String)
}

enum Tag {
    case text(String)
    case tag(Character, String)
}

enum Parse {
    static let sigils: Set<Character> = ["#", "^", "/", "&", ">", "!"]

    static func tags(_ source: String, _ faults: inout [String]) -> [Tag] {
        var out: [Tag] = []
        var rest = Substring(source)
        while let open = rest.range(of: "{{") {
            if open.lowerBound > rest.startIndex { out.append(.text(String(rest[rest.startIndex..<open.lowerBound]))) }
            let after = rest[open.upperBound...]
            let triple = after.hasPrefix("{")
            guard let close = after.range(of: triple ? "}}}" : "}}") else {
                faults.append("open")
                rest = Substring()
                break
            }
            let body = (triple ? after.dropFirst() : after)[..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            if triple {
                out.append(.tag("&", body))
            } else if let first = body.first, sigils.contains(first) {
                out.append(.tag(first, String(body.dropFirst()).trimmingCharacters(in: .whitespaces)))
            } else {
                out.append(.tag(" ", body))
            }
            rest = after[close.upperBound...]
        }
        if !rest.isEmpty { out.append(.text(String(rest))) }
        return out
    }

    static func build(_ tags: [Tag], _ at: inout Int, closing: String?, _ faults: inout [String]) -> [Node] {
        var nodes: [Node] = []
        while at < tags.count {
            let tag = tags[at]
            at += 1
            switch tag {
            case let .text(s): nodes.append(.text(s))
            case let .tag(sigil, name):
                switch sigil {
                case "#", "^": nodes.append(.block(name, inverted: sigil == "^", build(tags, &at, closing: name, &faults)))
                case "/":
                    if name != closing { faults.append("/\(name)") }
                    return nodes
                case ">": nodes.append(.part(name))
                case "!": break
                case "&": nodes.append(.name(name, raw: true))
                default: nodes.append(.name(name, raw: false))
                }
            }
        }
        if let closing { faults.append("#\(closing)") }
        return nodes
    }

    static func run(_ source: String, _ faults: inout [String]) -> [Node] {
        var at = 0
        let found = tags(source, &faults)
        var nodes: [Node] = []
        while at < found.count { nodes += build(found, &at, closing: nil, &faults) }
        return nodes
    }
}

public struct TextTemplate: Sendable {
    static let depth = 16

    let nodes: [Node]
    let parts: [String: [Node]]
    let faults: [String]

    public init(_ source: String, partials: [String: String] = [:]) {
        var faults: [String] = []
        nodes = Parse.run(source, &faults)
        parts = partials.mapValues { Parse.run($0, &faults) }
        self.faults = faults
    }

    public init?(_ item: Ingested, partials: [String: String] = [:]) {
        guard let source = item.template?.source else { return nil }
        self.init(source, partials: partials)
    }

    public func render(_ context: Value) -> Rendered {
        var out = ""
        var unknown: [String] = []
        walk(nodes, [context], 0, &out, &unknown)
        for fault in faults { TextTemplate.note(fault, &unknown) }
        return Rendered(text: out, unknown: unknown)
    }

    static func note(_ name: String, _ unknown: inout [String]) {
        if !unknown.contains(name) { unknown.append(name) }
    }

    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func find(_ name: String, _ scopes: [Value]) -> Value? {
        if name == "." { return scopes.last }
        let path = name.split(separator: ".").map(String.init)
        guard let head = path.first else { return nil }
        for scope in scopes.reversed() {
            guard case let .map(map) = scope, var value = map[head] else { continue }
            for step in path.dropFirst() {
                guard case let .map(inner) = value, let next = inner[step] else { return nil }
                value = next
            }
            return value
        }
        return nil
    }

    func walk(_ nodes: [Node], _ scopes: [Value], _ level: Int, _ out: inout String, _ unknown: inout [String]) {
        for node in nodes {
            switch node {
            case let .text(s): out += s
            case let .name(name, raw):
                guard case let .text(s)? = TextTemplate.find(name, scopes) else { TextTemplate.note(name, &unknown); continue }
                out += raw ? s : TextTemplate.escape(s)
            case let .part(name):
                guard level < TextTemplate.depth, let inner = parts[name] else { TextTemplate.note(">\(name)", &unknown); continue }
                walk(inner, scopes, level + 1, &out, &unknown)
            case let .block(name, inverted, kids):
                let value = TextTemplate.find(name, scopes)
                if value == nil { TextTemplate.note(name, &unknown) }
                if inverted {
                    if !(value?.truthy ?? false) { walk(kids, scopes, level, &out, &unknown) }
                } else if let value, value.truthy {
                    if case let .list(items) = value {
                        for item in items { walk(kids, scopes + [item], level, &out, &unknown) }
                    } else {
                        walk(kids, scopes + [value], level, &out, &unknown)
                    }
                }
            }
        }
    }
}
