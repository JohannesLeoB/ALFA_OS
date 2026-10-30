enum MailCredential: Equatable, Sendable {
    case password(String)
    case accessToken(String)

    var isEmpty: Bool {
        switch self {
        case .password(let value), .accessToken(let value): value.isEmpty
        }
    }
}
