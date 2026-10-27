public struct ToolResult: Sendable, Equatable {
    var lines: [Phrase]
    var isError: Bool
    var cards: [ContentBlock]

    init(lines: [Phrase], isError: Bool = false, cards: [ContentBlock] = []) {
        self.lines = lines
        self.isError = isError
        self.cards = cards
    }

    init(_ line: Phrase, isError: Bool = false, cards: [ContentBlock] = []) {
        self.init(lines: [line], isError: isError, cards: cards)
    }

    static func failure(_ key: String, _ arguments: String...) -> ToolResult {
        ToolResult(.key(key, arguments), isError: true)
    }

    func render(_ text: any TextPort) -> String {
        lines.map { $0.render(text) }.joined(separator: "\n")
    }
}
