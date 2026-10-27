import Foundation

public struct ReportEntry: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    var inlet: Inlet.ID
    var event: ReportEvent
    var capability: Capability?
    var at: Date
    var ok: Bool
    var kind: FailureKind?
    var hint: String?
    var original: Original?

    init(id: UUID = UUID(), inlet: Inlet.ID, event: ReportEvent, capability: Capability? = nil, at: Date,
                ok: Bool, kind: FailureKind? = nil, hint: String? = nil, original: Original? = nil) {
        self.id = id
        self.inlet = inlet
        self.event = event
        self.capability = capability
        self.at = at
        self.ok = ok
        self.kind = kind
        self.hint = hint
        self.original = original
    }
}

public enum ReportEvent: String, Codable, Equatable, Sendable {
    case signIn
    case probe
    case sync
    case renewal
    case write
}
