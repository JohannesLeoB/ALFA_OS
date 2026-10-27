enum AirtableFailure: Error, Equatable, Sendable {
    case notConnected
    case invalidResponse
    case http(Int)
    case rejected(Int, String)
    case decoding
    case writeNotAllowed(baseID: String, table: String)
    case deleteNotAllowed(baseID: String, table: String)
    case unmapped(Int)

    var detail: String {
        switch self {
        case .notConnected: "notConnected"
        case .invalidResponse: "invalidResponse"
        case .http(let code): "http \(code)"
        case .rejected(let code, let message): "http \(code): \(message)"
        case .decoding: "decoding"
        case .writeNotAllowed(let baseID, let table): "writeNotAllowed \(table)@\(baseID)"
        case .deleteNotAllowed(let baseID, let table): "deleteNotAllowed \(table)@\(baseID)"
        case .unmapped(let count): "unmapped \(count)"
        }
    }
}
