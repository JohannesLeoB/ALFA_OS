public enum ShippingFailure: Error, Equatable, Sendable {
    case noKey
    case noCredentials
    case unsupported
    case incomplete([LabelOrderIssue])
    case http(Int)
    case transport(String)
    case parse(String)

    var detail: String {
        switch self {
        case .noKey: "noKey"
        case .noCredentials: "noCredentials"
        case .unsupported: "unsupported"
        case .incomplete(let issues): "incomplete " + issues.map(\.rawValue).joined(separator: ",")
        case .http(let code): "http \(code)"
        case .transport(let reason): "transport \(reason)"
        case .parse(let reason): "parse \(reason)"
        }
    }
}
