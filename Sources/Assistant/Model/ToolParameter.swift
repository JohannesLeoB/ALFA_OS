public struct ToolParameter: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case string
        case integer
        case number
    }

    let name: String
    let kind: Kind
    let required: Bool

    init(_ name: String, kind: Kind = .string, required: Bool = false) {
        self.name = name
        self.kind = kind
        self.required = required
    }
}
