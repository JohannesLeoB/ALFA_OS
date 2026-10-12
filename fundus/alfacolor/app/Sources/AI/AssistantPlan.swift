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

/// The settings of the assistant for every task, the tool rounds, the web search and the notices of the
/// values that were changed to fit the rules.
public struct AssistantPlan: Sendable, Equatable {
    public var tasks: [AITaskKind: TaskPlan]
    public var toolRounds: Int
    public var webSearch: WebSearchPlan
    public var allowedDomains: [String]
    public var blockedDomains: [String]
    public var userCountry: String?
    public var userTimeZone: String?
    public var notices: [SettingNotice]

    public init(
        tasks: [AITaskKind: TaskPlan],
        toolRounds: Int,
        webSearch: WebSearchPlan,
        allowedDomains: [String] = [],
        blockedDomains: [String] = [],
        userCountry: String? = nil,
        userTimeZone: String? = nil,
        notices: [SettingNotice] = []
    ) {
        self.tasks = tasks
        self.toolRounds = toolRounds
        self.webSearch = webSearch
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
        self.userCountry = userCountry
        self.userTimeZone = userTimeZone
        self.notices = notices
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
        resolve(AssistantOverrides(tier: tier), models: models)
    }

    /// The plan of the stage with the user's overrides. Each value is bounded by the rules of the platform;
    /// a value that had to change is reported in `notices`.
    public static func resolve(_ overrides: AssistantOverrides, models: [AIModelInfo] = []) -> AssistantPlan {
        var notices: [SettingNotice] = []
        var tasks: [AITaskKind: TaskPlan] = [:]
        for kind in AITaskKind.allCases {
            tasks[kind] = taskPlan(kind, overrides: overrides, models: models, notices: &notices)
        }

        let tier = overrides.tier
        var rounds = tier.toolRounds
        if let wanted = overrides.toolRounds {
            rounds = min(max(wanted, AssistantOverrides.toolRoundsRange.lowerBound), AssistantOverrides.toolRoundsRange.upperBound)
            Self.note(.toolRoundsLimited(to: rounds), when: rounds != wanted, in: &notices)
        }

        var search = tier.webSearch
        let enabled = overrides.webSearch ?? { if case .on = tier.webSearch { return true } else { return false } }()
        var uses = overrides.searchesPerMessage ?? { if case let .on(count) = tier.webSearch { return count } else { return 3 } }()
        uses = min(max(uses, AssistantOverrides.searchRange.lowerBound), AssistantOverrides.searchRange.upperBound)
        if let wanted = overrides.searchesPerMessage {
            Self.note(.searchesLimited(to: uses), when: uses != wanted, in: &notices)
        }
        search = enabled ? .on(maxUses: uses) : .off

        var allowed = overrides.allowedDomains.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        var blocked = overrides.blockedDomains.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !allowed.isEmpty, !blocked.isEmpty {
            blocked = []
            Self.note(.blockedDomainsDropped, when: true, in: &notices)
        }
        allowed = Array(allowed.prefix(AssistantOverrides.domainLimit))
        blocked = Array(blocked.prefix(AssistantOverrides.domainLimit))

        var country: String? = nil
        if let code = overrides.countryCode {
            if isCountryCode(code) {
                country = code
            } else {
                Self.note(.countryDropped, when: true, in: &notices)
            }
        }

        let zone = overrides.timeZone?.trimmingCharacters(in: .whitespaces)

        return AssistantPlan(
            tasks: tasks,
            toolRounds: rounds,
            webSearch: search,
            allowedDomains: allowed,
            blockedDomains: blocked,
            userCountry: country,
            userTimeZone: (zone?.isEmpty ?? true) ? nil : zone,
            notices: notices
        )
    }

    /// The plan of one task: model, effort, thinking, answer length, structured names and cache.
    private static func taskPlan(
        _ kind: AITaskKind,
        overrides: AssistantOverrides,
        models: [AIModelInfo],
        notices: inout [SettingNotice]
    ) -> TaskPlan {
        let tier = overrides.tier
        let row = tier.row(for: kind.work)
        let chosen = overrides.models[kind] ?? ""
        let model = chosen.isEmpty ? modelID(for: row.line, models: models) : chosen
        let info = models.first { $0.id == model }
        let line = ModelLine(modelID: model, info: info)

        let effort = AssistantRules.effort(overrides.effort ?? row.effort, for: line)
        if let wanted = overrides.effort {
            note(.effortLowered(model: model, to: effort), when: effort != wanted, in: &notices)
        }

        var thinking = overrides.thinking ?? row.thinking
        if let wanted = thinking, !fits(wanted, line: line, effort: effort, info: info) {
            if overrides.thinking != nil {
                note(.thinkingLeftToPlatform(model: model), when: true, in: &notices)
            }
            thinking = nil
        }

        let limit = info?.maxTokens ?? AssistantOverrides.maxTokensCeiling
        var maxTokens = min(row.maxTokens, limit)
        if let wanted = overrides.maxTokens {
            maxTokens = min(max(wanted, AssistantOverrides.maxTokensFloor), limit)
            note(.maxTokensLimited(model: model, to: maxTokens), when: maxTokens != wanted, in: &notices)
            if maxTokens < AssistantOverrides.thinkingAnswerFloor, thinking != .disabled {
                note(.shortAnswerWithThinking(model: model), when: true, in: &notices)
            }
        }

        return TaskPlan(
            model: model,
            line: line,
            effort: effort,
            thinking: thinking,
            maxTokens: maxTokens,
            structuredOutput: kind == .tokenNames && (overrides.structuredNames ?? tier.structuredNames),
            cache: overrides.cache ?? .automatic(ttl: .fiveMinutes)
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

    /// A country is two capital ASCII letters, as ISO 3166-1 alpha-2 writes it.
    static func isCountryCode(_ code: String) -> Bool {
        code.count == 2 && code.allSatisfy { ("A"..."Z").contains($0) }
    }

    /// Adds a notice once, in the order it happened.
    private static func note(_ notice: SettingNotice, when condition: Bool, in notices: inout [SettingNotice]) {
        guard condition, !notices.contains(notice) else { return }
        notices.append(notice)
    }
}
