enum SyncEngine {
    enum Resolution {
        case restore
        case fail
    }

    static func key(_ inlet: Inlet.ID, _ capability: Capability) -> String {
        inlet + "|" + capability.rawValue
    }

    static func isRunning<Keys: Sequence>(_ inlet: Inlet.ID, in running: Keys) -> Bool where Keys.Element == String {
        running.contains { $0.hasPrefix(inlet + "|") }
    }

    static func resolution(capability: Capability, kind: FailureKind) -> Resolution {
        capability == .files || kind == .transient ? .restore : .fail
    }

    static func failureHint(for classification: Classification, inlet: Inlet.ID, current: InletState?) -> Hint {
        if case .failed(let existing)? = current, existing.text == Hint.signInExpiredText { return existing }
        return HintEngine.hint(classification, fixIn: .inlet(inlet))
    }

    static func kinds(of capability: Capability) -> [DataKind] {
        DataKind.allCases.filter { $0.capability == capability }
    }
}
