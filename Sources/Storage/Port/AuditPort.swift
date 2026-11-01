@MainActor
public protocol AuditPort: Sendable {
    func append(_ entry: AuditEntry) throws
}
