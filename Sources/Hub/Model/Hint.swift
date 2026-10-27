public struct Hint: Equatable, Codable, Sendable {
    public static let signInExpiredText = "hint.signin.expired"

    public let text: String
    public let detail: String?
    public let fixIn: SettingsTarget?
    public let kind: FailureKind?
    public let original: Original?

    public init(text: String, detail: String? = nil, fixIn: SettingsTarget? = nil, kind: FailureKind? = nil,
                original: Original? = nil) {
        self.text = text
        self.detail = detail
        self.fixIn = fixIn
        self.kind = kind
        self.original = original
    }

    public init(text: String, classification: Classification, fixIn: SettingsTarget? = nil) {
        self.init(text: text, detail: classification.detail, fixIn: fixIn, kind: classification.kind,
                  original: classification.original)
    }

    public static func failed(_ error: Error) -> Hint {
        Hint(text: HintEngine.failedText, detail: String(describing: error))
    }

    public var code: String? { original?.label }

    public var codeKey: String? { code.map { "hint.code." + $0 } }
}

public struct ProbeResult: Equatable, Sendable {
    public var account: String
    public var rejection: Hint?

    public init(account: String, rejection: Hint? = nil) {
        self.account = account
        self.rejection = rejection
    }
}
