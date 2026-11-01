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

    private let chat: any ChatPort
    private let provider: any ConversationPort
    private let text: any TextPort
    private let memory: (any MemoryPort)?
    private let log: (any ToolAuditPort)?
    private let toolTimeout: Duration
    private let turnDeadline: TimeInterval
    private var registry: ToolRegistry
    private var categoryObserver: (@MainActor (Set<PrivacyCategory>) -> Void)?
    private var activeTask: Task<Void, Never>?

    private(set) var isResponding = false
    private(set) var lastRoutedModel: String?

    public init(chat: any ChatPort, provider: any ConversationPort, registry: ToolRegistry, text: any TextPort,
                memory: (any MemoryPort)? = nil, log: (any ToolAuditPort)? = nil,
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
        categoryObserver?(registry.categories)
    }

    func observeCategories(_ observer: @escaping @MainActor (Set<PrivacyCategory>) -> Void) {
        categoryObserver = observer
        observer(registry.categories)
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
            AttachmentKind(mimeType: $0.mimeType) == .image ? .image($0) : .document($0)
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
                self.settle(placeholder.id, blocks: [.text(self.say("assistant.engine.cancelled"))], status: .complete, in: scope)
            } catch {
                let failure = self.describe(error)
                self.settle(placeholder.id, blocks: [.text(failure)], status: .failed(failure), in: scope)
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

    private func settle(_ id: UUID, blocks: [ContentBlock], status: TurnStatus, in scope: ConversationScope) {
        do {
            try chat.updateAssistantTurn(id: id, blocks: blocks, status: status, in: scope)
        } catch {
            Log.failure("ChatUnsaved", detail: String(describing: error))
        }
    }

    private func runWithTimeout(_ use: ToolUse, turn: Turn) async -> ToolResult {
        let registry = registry
        let timeout = toolTimeout
        let scope = turn.scope
        let allowed = turn.allowed
        do {
            return try await Deadline.run(timeout) {
                await registry.run(name: use.name, inputJSON: use.inputJSON, scope: scope, allowed: allowed)
            }
        } catch is CancellationError {
            return .failure("assistant.engine.cancelled")
        } catch {
            return .failure("assistant.engine.toolTimeout")
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

enum MemoryEngine {
    static let windowDays = 28
    static let maxMessages = 120
    static let tailSize = 8
    static let minBatch = 12

    enum Plan: Equatable {
        case passthrough
        case reuse(tail: [Message], summary: String)
        case distill(tail: [Message], batch: [Message], existing: String?, coveredThrough: String)
    }

    static func window(_ messages: [Message], now: Date) -> [Message] {
        let cutoff = now.addingTimeInterval(-Double(windowDays) * 24 * 3600)
        var windowed = messages.filter { $0.createdAt >= cutoff }
        if windowed.count > maxMessages { windowed = Array(windowed.suffix(maxMessages)) }
        return trimToUserStart(windowed)
    }

    static func trimToUserStart(_ messages: [Message]) -> [Message] {
        var trimmed = messages
        while let first = trimmed.first, first.role != .user { trimmed.removeFirst() }
        return trimmed
    }

    static func plan(windowed: [Message], existing: MemorySummary?) -> Plan {
        guard windowed.count > tailSize else { return .passthrough }
        let tailStart = windowed.count - tailSize
        let coveredIndex = existing.flatMap { summary in
            windowed.firstIndex { $0.id.uuidString == summary.coveredThroughMessageID }
        } ?? -1
        let batch = coveredIndex + 1 < tailStart ? Array(windowed[(coveredIndex + 1)..<tailStart]) : []
        let tail = trimToUserStart(Array(windowed[tailStart...]))
        if batch.count >= minBatch, let last = batch.last {
            return .distill(tail: tail, batch: batch, existing: existing?.summaryText, coveredThrough: last.id.uuidString)
        }
        if let existing { return .reuse(tail: tail, summary: existing.summaryText) }
        return .passthrough
    }

    static func transcript(_ batch: [Message], text: any TextPort) -> String {
        batch.map { message in
            let role = text.text(message.role == .user ? "assistant.memory.roleUser" : "assistant.memory.roleAssistant", [])
            return "\(role): \(message.text)"
        }.joined(separator: "\n")
    }
}

enum ModelRouter {
    static let haiku = "claude-haiku-4-5-20251001"
    static let sonnet = "claude-sonnet-4-6"
    static let opus = "claude-opus-4-8"

    static let estimationKeywords = [
        "sch\u{E4}tz", "schaetz", "kalkul", "budget", "marge", "kostenvoranschlag",
        "was kostet", "wieviel kostet", "kosten f\u{FC}r", "preis pro", "\u{20AC}", "euro",
    ]

    static let complexKeywords = [
        "warum", "erkl\u{E4}re", "erkl\u{E4}r", "vergleich", "analys",
        "strategie", "begr\u{FC}nd", "schritt f\u{FC}r schritt", "plane ",
    ]

    static let complexWordLimit = 40

    static func model(latestUserText: String, toolsEnabled: Bool) -> String {
        let text = latestUserText.lowercased()
        if mentionsEstimation(text) { return opus }
        if toolsEnabled { return sonnet }
        if isComplex(text) { return sonnet }
        return haiku
    }

    static func mentionsEstimation(_ text: String) -> Bool {
        estimationKeywords.contains { text.contains($0) }
    }

    static func isComplex(_ text: String) -> Bool {
        if text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count > complexWordLimit { return true }
        return complexKeywords.contains { text.contains($0) }
    }
}

enum ThreadEngine {
    static func turns(_ messages: [Message]) -> [ChatTurn] {
        messages.map(turn)
    }

    static func turn(_ message: Message) -> ChatTurn {
        let failure: String? = if case .failed(let reason) = message.status { reason } else { nil }
        var blocks = message.blocks.flatMap(blocks).filter { block in
            guard case .text(let value) = block else { return true }
            return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && value != failure
        }
        if message.role == .user {
            blocks = blocks.filter(\.isFile) + blocks.filter { $0.isFile == false }
        }
        return ChatTurn(id: message.id, kind: kind(message, failed: failure != nil), blocks: blocks)
    }

    static func kind(_ message: Message, failed: Bool) -> ChatTurn.Kind {
        if failed { return .failed }
        if message.status == .streaming { return .streaming }
        return message.role == .user ? .user : .assistant
    }

    static func blocks(_ block: ContentBlock) -> [TurnBlock] {
        switch block {
        case .text(let value): [.text(value)]
        case .toolUse, .toolResult: []
        case .toolActivity(let label, let isError): [.activity(label: label, failed: isError)]
        case .calendarLink(let url): [.draft(DraftSummary(kind: .calendar, title: url))]
        case .contactDraft(let draft): [.draft(DraftSummary(kind: .contact, title: draft.displayName, line: draft.organization ?? draft.email))]
        case .mailDraft(let draft): [.draft(DraftSummary(kind: .mail, title: draft.subject, line: draft.to))]
        case .driveFiles(let links): links.map { .file($0.name) }
        case .estimate(_, _, let minNet, let maxNet, _, _, _): [.estimate(minNet: minNet, maxNet: maxNet)]
        case .estimateBreakdown(_, let lines, _): [.breakdown(lines: lines.count)]
        case .airtableContactDraft(let draft): [.draft(DraftSummary(kind: .contact, title: draft.name, line: draft.organization ?? draft.email))]
        case .taskChangeDraft(let draft): [.draft(DraftSummary(kind: .task, title: draft.taskName, line: draft.projectNumber))]
        case .appointmentDraft(let draft): [.draft(DraftSummary(kind: .appointment, title: draft.title, line: draft.location))]
        case .cartDraft(let draft): [.draft(DraftSummary(kind: .cart, title: draft.label, line: draft.articleNumber))]
        case .fileDraft(let draft): [.draft(DraftSummary(kind: .file, title: draft.fileName, line: draft.projectNumber))]
        case .image(let ref), .document(let ref): [.file(ref.fileName)]
        case .unreadable: [.unreadable]
        }
    }

    static func attachments(_ message: Message) -> [AttachmentRef] {
        message.blocks.compactMap { block in
            switch block {
            case .image(let ref), .document(let ref): ref
            default: nil
            }
        }
    }
}

public enum UsageEngine {
    static let million = 1_000_000.0
    static let secondsPerDay = 86_400.0

    static func price(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    public static func estimate(_ totals: UsageTotals, input: String, output: String) -> Double? {
        guard let inputPrice = price(input), let outputPrice = price(output) else { return nil }
        let cost = Double(totals.input) / million * inputPrice + Double(totals.output) / million * outputPrice
        return (cost * 2).rounded() / 2
    }

    public static func days(since: Date, now: Date) -> Int {
        max(0, Int((now.timeIntervalSince(since) / secondsPerDay).rounded(.down)))
    }

    public static func scaled(_ tokens: Int) -> (amount: String, millions: Bool) {
        let value = Double(tokens)
        if value >= million { return (String(format: "%.1f", locale: Locale(identifier: "de"), value / million), true) }
        return (String(Int((value / 1000).rounded())), false)
    }

    public static func money(_ amount: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "de"), amount)
    }
}
