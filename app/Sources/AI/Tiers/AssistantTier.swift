import Foundation

/// The four stages of the assistant, from the cheapest to the strongest. A stage sets the model family,
/// the effort, the thinking mode, the answer length, the tool rounds and the web search of each task.
public enum AssistantTier: String, Sendable, Equatable, CaseIterable {
    case minimized
    case eco
    case normal
    case max

    /// The kind of work: code writes a card or a page, names write short text.
    enum Work: Sendable, Equatable {
        case code
        case names
    }

    /// What the stage sets for one kind of work.
    struct Row: Sendable, Equatable {
        let line: ModelLine
        let effort: AIEffort
        let thinking: AIThinking?
        let maxTokens: Int
    }

    func row(for work: Work) -> Row {
        switch (self, work) {
        case (.minimized, .code): Row(line: .haiku, effort: .low, thinking: .disabled, maxTokens: 4096)
        case (.minimized, .names): Row(line: .haiku, effort: .low, thinking: .disabled, maxTokens: 1024)
        case (.eco, .code): Row(line: .sonnet, effort: .medium, thinking: .betweenTools, maxTokens: 8192)
        case (.eco, .names): Row(line: .haiku, effort: .medium, thinking: nil, maxTokens: 2048)
        case (.normal, .code): Row(line: .sonnet, effort: .high, thinking: .adaptive, maxTokens: 16000)
        case (.normal, .names): Row(line: .sonnet, effort: .high, thinking: .adaptive, maxTokens: 4096)
        case (.max, .code): Row(line: .opus, effort: .xhigh, thinking: .adaptive, maxTokens: 64000)
        case (.max, .names): Row(line: .sonnet, effort: .xhigh, thinking: .adaptive, maxTokens: 8192)
        }
    }

    /// The most rounds of tool calls that one message may cause.
    public var toolRounds: Int {
        switch self {
        case .minimized: 2
        case .eco: 4
        case .normal: 8
        case .max: 12
        }
    }

    /// The web search of the chat. The labs never search.
    public var webSearch: WebSearchPlan {
        switch self {
        case .minimized, .eco: .off
        case .normal: .on(maxUses: 3)
        case .max: .on(maxUses: 10)
        }
    }

    /// Whether the names come back in a fixed JSON form.
    public var structuredNames: Bool {
        switch self {
        case .minimized, .eco: false
        case .normal, .max: true
        }
    }
}

/// Whether the web search runs, and how many searches one message may make.
public enum WebSearchPlan: Sendable, Equatable {
    case off
    case on(maxUses: Int)
}

/// The family of a model. The platform names it in the models list; the app never reads it from the id.
public enum ModelLine: String, Sendable, Equatable, CaseIterable {
    case haiku
    case sonnet
    case opus
    case fable

    /// The model that the app uses for the family when the list does not say otherwise.
    public var defaultModel: String {
        switch self {
        case .haiku: ModelID.haiku
        case .sonnet: ModelID.sonnet
        case .opus: ModelID.opus
        case .fable: ModelID.fable
        }
    }

    /// The family of a model: the line that the list gives, otherwise the family name inside the id.
    init?(modelID: String, info: AIModelInfo?) {
        if let named = info?.line, let line = ModelLine(rawValue: named) {
            self = line
            return
        }
        guard let found = ModelLine.allCases.first(where: { modelID.contains($0.rawValue) }) else {
            return nil
        }
        self = found
    }
}

extension AITaskKind {
    /// The kind of work of the task, which decides the stage row it takes.
    var work: AssistantTier.Work {
        switch self {
        case .codeVariant, .htmlForCSS, .codeFromScreenshot: .code
        case .tokenNames, .explain: .names
        }
    }
}
