import Foundation

/// The settings of one task, as the request takes them.
public struct TaskPlan: Sendable, Equatable {
    public var model: String
    /// The family of the model, when it is known.
    public var line: ModelLine?
    public var effort: AIEffort
    /// Nil leaves the thinking mode to the platform.
    public var thinking: AIThinking?
    public var maxTokens: Int
    /// Whether the answer comes back in a fixed JSON form.
    public var structuredOutput: Bool
    public var cache: AICachePolicy

    public init(
        model: String,
        line: ModelLine?,
        effort: AIEffort,
        thinking: AIThinking?,
        maxTokens: Int,
        structuredOutput: Bool,
        cache: AICachePolicy
    ) {
        self.model = model
        self.line = line
        self.effort = effort
        self.thinking = thinking
        self.maxTokens = maxTokens
        self.structuredOutput = structuredOutput
        self.cache = cache
    }
}

/// The settings of the assistant for every task, the tool rounds and the web search.
public struct AssistantPlan: Sendable, Equatable {
    public var tasks: [AITaskKind: TaskPlan]
    public var toolRounds: Int
    public var webSearch: WebSearchPlan

    public init(tasks: [AITaskKind: TaskPlan], toolRounds: Int, webSearch: WebSearchPlan) {
        self.tasks = tasks
        self.toolRounds = toolRounds
        self.webSearch = webSearch
    }

    /// The plan of one task. Every kind has a plan, so the lookup does not fail.
    public func task(_ kind: AITaskKind) -> TaskPlan {
        guard let plan = tasks[kind] else {
            preconditionFailure("every task kind has a plan")
        }
        return plan
    }

    /// The plan of a stage, before any setting changes it. The models come from the models list; without
    /// the list, or without a model of the family, the app's default model of the family is used.
    public static func stage(_ tier: AssistantTier, models: [AIModelInfo] = []) -> AssistantPlan {
        var tasks: [AITaskKind: TaskPlan] = [:]
        for kind in AITaskKind.allCases {
            tasks[kind] = taskPlan(kind, tier: tier, models: models)
        }
        return AssistantPlan(tasks: tasks, toolRounds: tier.toolRounds, webSearch: tier.webSearch)
    }

    private static func taskPlan(_ kind: AITaskKind, tier: AssistantTier, models: [AIModelInfo]) -> TaskPlan {
        let row = tier.row(for: kind.work)
        let model = modelID(for: row.line, models: models)
        let info = models.first { $0.id == model }
        let line = ModelLine(modelID: model, info: info)
        let effort = AssistantRules.effort(row.effort, for: line)
        var thinking = row.thinking
        if let wanted = thinking, !fits(wanted, line: line, effort: effort, info: info) {
            thinking = nil
        }
        let limit = info?.maxTokens ?? row.maxTokens
        return TaskPlan(
            model: model,
            line: line,
            effort: effort,
            thinking: thinking,
            maxTokens: min(row.maxTokens, limit),
            structuredOutput: kind == .tokenNames && tier.structuredNames,
            cache: .automatic(ttl: .fiveMinutes)
        )
    }

    /// Whether the thinking mode fits the model, the effort, and what the list says about thinking off.
    static func fits(_ thinking: AIThinking, line: ModelLine?, effort: AIEffort, info: AIModelInfo?) -> Bool {
        guard AssistantRules.allows(thinking, line: line, effort: effort) else { return false }
        if thinking == .disabled, info?.disabledThinkingSupported == false {
            return false
        }
        return true
    }

    /// The model of a family: the app's default when the list has it, otherwise the first listed model of the family.
    static func modelID(for line: ModelLine, models: [AIModelInfo]) -> String {
        if models.contains(where: { $0.id == line.defaultModel }) {
            return line.defaultModel
        }
        return models.first { $0.line == line.rawValue }?.id ?? line.defaultModel
    }
}
