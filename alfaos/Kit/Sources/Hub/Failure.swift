import Foundation

public enum FailureKind: String, Codable, Equatable, Sendable {
    case transient
    case signIn
    case rejected
}

public struct Original: Equatable, Codable, Sendable {
    public var provider: String
    public var status: Int?
    public var code: String?
    public var text: String?
    public var extra: [String: String]
    public var body: String?

    public init(provider: String, status: Int? = nil, code: String? = nil, text: String? = nil,
                extra: [String: String] = [:], body: String? = nil) {
        self.provider = provider
        self.status = status
        self.code = code
        self.text = text
        self.extra = extra
        self.body = body
    }

    public var label: String {
        var parts = [provider]
        if let status { parts.append(String(status)) }
        if let code { parts.append(code) }
        return parts.joined(separator: ".")
    }
}

public struct Classification: Equatable, Sendable {
    public var kind: FailureKind
    public var original: Original

    public init(kind: FailureKind, original: Original) {
        self.kind = kind
        self.original = original
    }

    public var detail: String? {
        if let text = original.text, !text.isEmpty { return text }
        return original.status.map { "HTTP \($0)" }
    }

    public static func generic(_ error: Error) -> Classification {
        if let url = error as? URLError {
            return Classification(kind: .transient, original: Original(
                provider: "network", code: "URLError." + String(url.code.rawValue), text: url.localizedDescription,
                extra: ["domain": URLError.errorDomain]))
        }
        return Classification(kind: .rejected, original: Original(provider: "unknown", text: String(describing: error)))
    }
}

public enum InletHealth: String, Codable, Equatable, Sendable {
    case online
    case limited
    case failed
}

public enum ReportEvent: String, Codable, Equatable, Sendable {
    case signIn
    case probe
    case sync
    case renewal
    case write
}

public struct ReportEntry: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var inlet: Inlet.ID
    public var event: ReportEvent
    public var capability: Capability?
    public var at: Date
    public var ok: Bool
    public var kind: FailureKind?
    public var hint: String?
    public var original: Original?

    public init(id: UUID = UUID(), inlet: Inlet.ID, event: ReportEvent, capability: Capability? = nil, at: Date,
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
