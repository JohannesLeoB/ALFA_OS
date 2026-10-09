/// The model of each task. The defaults are fixed here; the settings may replace them per task.
public struct AIModelChoice: Sendable, Equatable {
    /// The default model of each task kind.
    public static let defaults: [AITaskKind: String] = [
        .codeVariant: ModelID.sonnet,
        .htmlForCSS: ModelID.sonnet,
        .codeFromScreenshot: ModelID.sonnet,
        .tokenNames: ModelID.haiku,
        .explain: ModelID.haiku,
    ]

    /// Models set by the user, by task kind. An empty name counts as not set.
    public var overrides: [AITaskKind: String]

    public init(overrides: [AITaskKind: String] = [:]) {
        self.overrides = overrides
    }

    /// The model for a task kind: the override when it is set, otherwise the default.
    public func model(for kind: AITaskKind) -> String {
        if let chosen = overrides[kind], !chosen.isEmpty {
            return chosen
        }
        return Self.defaults[kind] ?? ModelID.haiku
    }
}
