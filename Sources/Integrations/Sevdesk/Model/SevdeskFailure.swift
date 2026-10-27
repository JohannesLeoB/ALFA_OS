enum SevdeskFailure: Error, Equatable, Sendable {
    case notConnected
    case invalidResponse
    case http(Int)
    case decoding

    var detail: String {
        switch self {
        case .notConnected: "notConnected"
        case .invalidResponse: "invalidResponse"
        case .http(let code): "http \(code)"
        case .decoding: "decoding"
        }
    }
}
