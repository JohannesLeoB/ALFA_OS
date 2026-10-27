import Calculation

indirect enum Phrase: Codable, Sendable, Equatable {
    case key(String, [String])
    case raw(String)
    case notice(Notice)
    case join([Phrase], String)

    static func make(_ key: String, _ arguments: String...) -> Phrase {
        .key(key, arguments)
    }

    func render(_ text: any TextPort) -> String {
        switch self {
        case .key(let key, let arguments): text.text(key, arguments)
        case .raw(let value): value
        case .notice(let notice): text.text(notice.key, notice.arguments)
        case .join(let parts, let separator): parts.map { $0.render(text) }.joined(separator: separator)
        }
    }
}
