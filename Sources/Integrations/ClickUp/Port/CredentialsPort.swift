public protocol CredentialsPort: Sendable {
    func load() throws -> Credentials?
}
