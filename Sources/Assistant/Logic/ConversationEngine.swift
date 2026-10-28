import Core
import Foundation
import Storage
import os

@MainActor
public final class ConversationEngine {
    static let maxToolRounds = 10
    static let answerTokens = 4096
    static let distillTokens = 600
    static let usageLog = Logger(subsystem: Log.subsystem, category: "assistant.usage")

    private let chat: ChatStore
    private let provider: any ConversationPort
    private let text: any TextPort
    private let memory: MemoryStore?
    private let log: IntegrationLogStore?
    private let toolTimeout: Duration
    private let turnDeadline: TimeInterval
    private var registry: ToolRegistry
    private var activeTask: Task<Void, Never>?

    private(set) var isResponding = false
    private(set) var lastRoutedModel: String?

    public init(chat: ChatStore, provider: any ConversationPort, registry: ToolRegistry, text: any TextPort,
                memory: MemoryStore? = nil, log: IntegrationLogStore? = nil,
                toolTimeout: Duration = .seconds(15), turnDeadline: TimeInterval = 75) {
        self.chat = chat
        self.provider = provider
        self.registry = registry
        self.text = text
        self.memory = memory
        self.log = log
        self.toolTimeout = toolTimeout
        self.turnDeadline = turnDeadline
    }

    public func update(registry: ToolRegistry) {
        self.registry = registry
    }

    func cancel() {
        activeTask?.cancel()
    }

    func send(_ message: String, scope: ConversationScope, context: ConversationContext = ConversationContext(),
                     privacy: PrivacySnapshot = PrivacySnapshot(), attachments: [AttachmentRef] = [],
                     toolsEnabled: Bool = true, now: Date = Date()) async {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false || attachments.isEmpty == false, isResponding == false else { return }
        isResponding = true
        defer { isResponding = false }

        let attachmentBlocks: [ContentBlock] = attachments.map {
            AttachmentStore.kind(forMimeType: $0.mimeType) == .image ? .image($0) : .document($0)
        }
        let user = Message(role: .user, blocks: (trimmed.isEmpty ? [] : [.text(trimmed)]) + attachmentBlocks)
        let placeholder = Message(role: .assistant, blocks: [.text("")], status: .streaming)
        do {
            try chat.append(user, to: scope)
            try chat.append(placeholder, to: scope)
        } catch {
            return
        }
        if privacy.assistantOff {
            try? chat.updateAssistantTurn(id: placeholder.id, blocks: [.text(say("assistant.engine.assistantOff"))],
                                          status: .complete, in: scope)
            return
        }

        let persisted = chat.messages(for: scope).filter { $0.id != placeholder.id }
        let shareChat = privacy.shares(.chat)
        let windowed = shareChat ? MemoryEngine.window(persisted, now: now) : Array(persisted.suffix(1))
        let prepared = shareChat ? await prepareMemory(windowed, scope: scope) : (convo: windowed, summary: nil as String?)

        let allowedTools = toolsEnabled ? ToolAccessEngine.allowed(registry.tools, privacy: privacy) : []
        let model = ModelRouter.model(latestUserText: trimmed, toolsEnabled: toolsEnabled)
        lastRoutedModel = model
        let system = Grounding.systemPrompt(
            Grounding.Input(
                profile: context.profile, focusedProjectID: context.focusedProjectID,
                conversationSummary: prepared.summary, signals: context.signals, projects: context.projects, now: now,
                tools: allowedTools, toolsEnabled: toolsEnabled, chatFilesEnabled: privacy.chatFiles,
                hasDriveFocus: context.focusedDriveFolderID?.isEmpty == false,
                hasTaskListFocus: context.focusedTaskListID?.isEmpty == false),
            text: text)
        let definitions = allowedTools.map { ToolDefinition(tool: $0, text: text) }
        let turn = Turn(
            convo: prepared.convo, system: system, definitions: definitions, allowed: Set(allowedTools.map(\.name)),
            model: model, scope: context.scope, actor: context.actorUserID, placeholderID: placeholder.id,
            conversation: scope, disabled: privacy.settings.disabled, sharesFiles: privacy.chatFiles)

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let outcome = try await self.run(turn)
                try self.chat.updateAssistantTurn(id: placeholder.id, blocks: outcome.activities + [.text(outcome.answer)],
                                                  status: .complete, in: scope)
            } catch is CancellationError {
                try? self.chat.updateAssistantTurn(id: placeholder.id, blocks: [.text(self.say("assistant.engine.cancelled"))],
                                                   status: .complete, in: scope)
            } catch {
                let failure = self.describe(error)
                try? self.chat.updateAssistantTurn(id: placeholder.id, blocks: [.text(failure)],
                                                   status: .failed(failure), in: scope)
            }
        }
        activeTask = task
        await task.value
        activeTask = nil
    }

    struct Turn {
        var convo: [Message]
        let system: String
        let definitions: [ToolDefinition]
        let allowed: Set<String>
        let model: String
        let scope: ToolScope
        let actor: String
        let placeholderID: UUID
        let conversation: ConversationScope
        let disabled: Set<PrivacyCategory>
        let sharesFiles: Bool
    }

    struct Outcome {
        let answer: String
        let activities: [ContentBlock]
    }

    func say(_ key: String, _ arguments: String...) -> String {
        text.text(key, arguments)
    }

    private func prepareMemory(_ windowed: [Message], scope: ConversationScope) async -> (convo: [Message], summary: String?) {
        guard let memory else { return (windowed, nil) }
        do {
            let existing = try memory.summary(for: scope)
            switch MemoryEngine.plan(windowed: windowed, existing: existing) {
            case .passthrough:
                return (windowed, nil)
            case .reuse(let tail, let summary):
                return (tail, summary)
            case .distill(let tail, let batch, let previous, let covered):
                let merged = try await distill(previous: previous, batch: batch)
                try memory.save(MemorySummary(scopeKey: scope.rawKey, summaryText: merged,
                                              coveredThroughMessageID: covered, updatedAt: Date()))
                return (tail, merged)
            }
        } catch {
            return (windowed, nil)
        }
    }

    private func distill(previous: String?, batch: [Message]) async throws -> String {
        let transcript = MemoryEngine.transcript(batch, text: text)
        let existing = previous.flatMap { $0.isEmpty ? nil : $0 } ?? say("assistant.memory.none")
        let turn = Message.text(say("assistant.memory.turn", existing, transcript), role: .user)
        let reply = try await provider.respond(ChatRequest(
            messages: [turn], system: say("assistant.memory.system"), tools: [], maxTokens: Self.distillTokens,
            model: ModelRouter.haiku))
        return reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func run(_ turn: Turn) async throws -> Outcome {
        if turn.definitions.isEmpty {
            let answer = try await streamingAnswer(turn)
            return Outcome(answer: answer, activities: [])
        }
        var convo = turn.convo
        var activities: [ContentBlock] = []
        let deadline = Date().addingTimeInterval(turnDeadline)
        var rounds = 0
        var seen: Set<String> = []
        var proofs: [String] = convo.compactMap { $0.role == .user ? $0.text : nil }
        var sources: [ProvenanceEngine.Source] = convo.compactMap {
            $0.role == .user ? ProvenanceEngine.Source(label: say("assistant.source.userMessage"), text: $0.text) : nil
        }
        while true {
            rounds += 1
            if Date() >= deadline { return Outcome(answer: say("assistant.engine.deadline"), activities: activities) }
            let reply = try await provider.respond(ChatRequest(
                messages: convo, system: turn.system, tools: turn.definitions, maxTokens: Self.answerTokens, model: turn.model,
                sharesFiles: turn.sharesFiles))
            report(reply.usage, model: turn.model, toolCount: turn.definitions.count)

            if reply.toolUses.isEmpty {
                let trimmed = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return Outcome(answer: trimmed.isEmpty ? say("assistant.engine.noAnswer") : reply.text, activities: activities)
            }
            if rounds >= Self.maxToolRounds {
                let trimmed = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let answer = trimmed.isEmpty
                    ? say("assistant.engine.tooManySteps")
                    : reply.text + say("assistant.engine.roundCut", String(Self.maxToolRounds))
                return Outcome(answer: answer, activities: activities)
            }

            var assistantBlocks: [ContentBlock] = reply.text.isEmpty ? [] : [.text(reply.text)]
            assistantBlocks += reply.toolUses.map { .toolUse(id: $0.id, name: $0.name, inputJSON: $0.inputJSON) }
            convo.append(Message(role: .assistant, blocks: assistantBlocks))

            var resultBlocks: [ContentBlock] = []
            var repeated = false
            for use in reply.toolUses {
                let key = Self.callKey(name: use.name, inputJSON: use.inputJSON)
                let isRepeat = seen.contains(key)
                seen.insert(key)
                let label = blockedLabel(name: use.name, turn: turn) ?? activityLabel(name: use.name, inputJSON: use.inputJSON)
                let result: ToolResult
                if isRepeat {
                    repeated = true
                    result = .failure("assistant.engine.repeated")
                } else {
                    chat.updateStreamingActivities(
                        id: turn.placeholderID, activities: activities + [.toolActivity(label: label + " \u{2026}", isError: false)],
                        in: turn.conversation)
                    result = await runWithTimeout(use, turn: turn)
                }
                let rendered = result.render(text)
                audit(use.name, actor: turn.actor, result: result, rendered: rendered)

                let isDraftPreview = result.cards.contains(where: Self.isGatedDraft)
                if result.isError == false && isDraftPreview == false {
                    proofs.append(rendered)
                    sources.append(ProvenanceEngine.Source(label: label, text: rendered))
                }
                let evidence = ProvenanceEngine.Evidence(proofs)
                var summary = rendered
                var withheld: [Int] = []
                for (index, card) in result.cards.enumerated() {
                    guard let subject = Self.subject(of: card) else { continue }
                    let verdict = ProvenanceEngine.check(subject, evidence: evidence)
                    guard verdict.isGrounded == false else { continue }
                    summary += ProvenanceEngine.modelHint(verdict, text: text)
                    activities.append(.toolActivity(label: ProvenanceEngine.warnLabel(verdict, text: text), isError: true))
                    withheld.append(index)
                }
                resultBlocks.append(.toolResult(toolUseID: use.id, summary: summary, isError: result.isError))
                activities.append(.toolActivity(label: label, isError: result.isError))
                for (index, card) in result.cards.enumerated() where withheld.contains(index) == false {
                    activities.append(card)
                    if let subject = Self.subject(of: card),
                       let proof = ProvenanceEngine.provenanceLabel(ProvenanceEngine.provenance(subject, sources: sources), text: text) {
                        activities.append(.toolActivity(label: proof, isError: false))
                    }
                }
            }
            convo.append(Message(role: .user, blocks: resultBlocks))
            chat.updateStreamingActivities(id: turn.placeholderID, activities: activities, in: turn.conversation)
            if repeated { return Outcome(answer: say("assistant.engine.noNewData"), activities: activities) }
        }
    }

    private func runWithTimeout(_ use: ToolUse, turn: Turn) async -> ToolResult {
        let registry = registry
        let timeout = toolTimeout
        let scope = turn.scope
        let allowed = turn.allowed
        return await withTaskGroup(of: ToolResult.self) { group in
            group.addTask {
                await registry.run(name: use.name, inputJSON: use.inputJSON, scope: scope, allowed: allowed)
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return .failure("assistant.engine.toolTimeout")
            }
            let first = await group.next() ?? .failure("assistant.engine.noResponse")
            group.cancelAll()
            return first
        }
    }

    private func streamingAnswer(_ turn: Turn) async throws -> String {
        let stream = provider.stream(ChatRequest(
            messages: turn.convo, system: turn.system, tools: [], maxTokens: Self.answerTokens, model: turn.model,
            sharesFiles: turn.sharesFiles))
        var accumulated = ""
        for try await delta in stream {
            accumulated += delta
            chat.updateStreamingText(id: turn.placeholderID, text: accumulated, in: turn.conversation)
        }
        try Task.checkCancellation()
        let trimmed = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? say("assistant.engine.noAnswer") : accumulated
    }

    private func audit(_ name: String, actor: String, result: ToolResult, rendered: String) {
        log?.log(integrationID: registry.manifest.identifier(forTool: name), actorUserID: actor,
                 action: result.isError ? .error : .success, errorMessage: result.isError ? rendered : nil,
                 summary: "tool-call:\(name):v\(ToolManifest.version)")
    }

    private func report(_ usage: TokenUsage?, model: String, toolCount: Int) {
        guard let usage else { return }
        Self.usageLog.info("usage model=\(model, privacy: .public) input=\(usage.input, privacy: .public) cacheRead=\(usage.cacheRead, privacy: .public) cacheWrite=\(usage.cacheWrite, privacy: .public) output=\(usage.output, privacy: .public) cachePercent=\(Int(usage.cacheShare * 100), privacy: .public) tools=\(toolCount, privacy: .public)")
    }

    static func callKey(name: String, inputJSON: Data) -> String {
        "\(name)|\(String(data: inputJSON, encoding: .utf8) ?? "")"
    }

    static func isGatedDraft(_ card: ContentBlock) -> Bool {
        switch card {
        case .mailDraft, .contactDraft, .airtableContactDraft: true
        default: false
        }
    }

    static func subject(of card: ContentBlock) -> ProvenanceEngine.Subject? {
        switch card {
        case .mailDraft(let draft): ProvenanceEngine.subject(draft)
        case .contactDraft(let draft): ProvenanceEngine.subject(draft)
        case .airtableContactDraft(let draft): ProvenanceEngine.subject(draft)
        default: nil
        }
    }

    func activityLabel(name: String, inputJSON: Data) -> String {
        let query = ToolInput(json: inputJSON).text("query")
        let base = registry.tool(named: name).map { text.text($0.activityKey, []) } ?? name
        return query.isEmpty ? base : "\(base) \u{00B7} \(query)"
    }

    func blockedLabel(name: String, turn: Turn) -> String? {
        guard turn.allowed.contains(name) == false, let tool = registry.tool(named: name),
              turn.disabled.contains(tool.privacy) else { return nil }
        return say("assistant.activity.categoryOff", say(tool.privacy.key))
    }

    func describe(_ error: any Error) -> String {
        switch error {
        case ClaudeFailure.notConnected: say("assistant.failure.notConnected")
        case ClaudeFailure.rateLimited: say("assistant.failure.rateLimited")
        case ClaudeFailure.overloaded: say("assistant.failure.overloaded")
        case ClaudeFailure.httpError(let code): say("assistant.failure.http", String(code))
        case ClaudeFailure.streamInterrupted: say("assistant.failure.interrupted")
        default: say("assistant.failure.generic")
        }
    }
}

enum ToolAccessEngine {
    static func allowed(_ tools: [any ToolPort], privacy: PrivacySnapshot) -> [any ToolPort] {
        tools.filter { privacy.shares($0.privacy) }
    }

    static func names(_ tools: [any ToolPort], privacy: PrivacySnapshot) -> Set<String> {
        Set(allowed(tools, privacy: privacy).map(\.name))
    }
}
