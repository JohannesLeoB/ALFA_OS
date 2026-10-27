enum ClickUpFailure: Error, Equatable, Sendable {
    case notConnected
    case invalidResponse
    case http(Int)
    case decoding
    case ambiguousAnchor(name: String, count: Int)
    case ambiguousField(name: String, count: Int)
    case ambiguousOption(field: String, label: String, count: Int)

    var detail: String {
        switch self {
        case .notConnected: "notConnected"
        case .invalidResponse: "invalidResponse"
        case .http(let code): "http \(code)"
        case .decoding: "decoding"
        case .ambiguousAnchor(let name, let count): "ambiguousAnchor \(name) \(count)"
        case .ambiguousField(let name, let count): "ambiguousField \(name) \(count)"
        case .ambiguousOption(let field, let label, let count): "ambiguousOption \(field) \(label) \(count)"
        }
    }
}
