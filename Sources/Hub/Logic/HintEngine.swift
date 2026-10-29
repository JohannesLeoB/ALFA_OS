enum HintEngine {
    static let transientText = "hint.provider.transient"
    static let failedText = "hint.provider.failed"
    static let timeoutText = "hint.probe.timeout"
    static let signInTimeoutText = "hint.signin.timeout"
    static let unknownProviderText = "hint.provider.unknown"
    static let unknownInletText = "hint.inlet.unknown"
    static let unknownPortText = "hint.port.unknown"
    static let unreadableText = "hint.keychain.unreadable"
    static let unwritableText = "hint.keychain.unwritable"
    static let keyFieldsInvalidText = "hint.key.fields.invalid"
    static let keyRejectedText = "hint.key.rejected"
    static let keyFailedText = "hint.key.failed"
    static let accountMismatchText = "hint.account.mismatch"

    static func hint(_ classification: Classification, fixIn: SettingsTarget? = nil) -> Hint {
        let text: String
        switch classification.kind {
        case .transient: text = transientText
        case .signIn: text = Hint.signInExpiredText
        case .rejected: text = failedText
        }
        return Hint(text: text, classification: classification, fixIn: fixIn)
    }
}
