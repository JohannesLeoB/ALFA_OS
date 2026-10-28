public protocol PrivacyPort: Sendable {
    func load() throws -> PrivacySettings
}
