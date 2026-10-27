import Foundation

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

public struct Original: Equatable, Codable, Sendable {
    public var provider: String
    public var status: Int?
    public var code: String?
    public var text: String?
    public var extra: [String: String]

    public init(provider: String, status: Int? = nil, code: String? = nil, text: String? = nil,
                extra: [String: String] = [:]) {
        self.provider = provider
        self.status = status
        self.code = code
        self.text = text
        self.extra = extra
    }

    public var label: String {
        var parts = [provider]
        if let status { parts.append(String(status)) }
        if let code { parts.append(code) }
        return parts.joined(separator: ".")
    }
}

public enum FailureKind: String, Codable, Equatable, Sendable {
    case transient
    case signIn
    case rejected
}
