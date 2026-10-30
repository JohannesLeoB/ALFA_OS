struct HTMLToken: Equatable, Sendable {
    enum Kind: Sendable {
        case text
        case raw
        case start
        case end
    }

    var kind: Kind
    var name: String
    var attributes: [String: String]
    var selfClosing: Bool
    var raw: String

    static func text(_ raw: String, kind: Kind = .text) -> HTMLToken {
        HTMLToken(kind: kind, name: "", attributes: [:], selfClosing: false, raw: raw)
    }

    var isVoid: Bool {
        selfClosing || HTMLToken.voidNames.contains(name)
    }

    static let voidNames: Set<String> = [
        "br", "hr", "img", "input", "meta", "link", "wbr", "area", "base", "col", "source", "embed", "track", "param"
    ]
}
