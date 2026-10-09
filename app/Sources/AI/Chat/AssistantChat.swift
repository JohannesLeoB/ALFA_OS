import Foundation

/// One conversation with the assistant about one document. It runs the loop: message, stream, tool calls,
/// proposals, decision, results. It keeps the messages that go to the API and the entries that the view shows.
///
/// Nothing changes the document here. A change waits as a proposal group until the user accepts or discards it.
public actor AssistantChat {
    public private(set) var phase: ChatPhase = .idle
    /// What the view shows, in order.
    public private(set) var entries: [ChatEntry] = []
    /// The messages that go to the API, in order. A failed or cancelled turn is removed again.
    public private(set) var messages: [AIMessage] = []

    private let client: any AIClient
    /// The model and settings of the chat: the settings of the code task of the stage.
    private let plan: TaskPlan
    /// The most rounds of tool calls that one message may cause.
    private let toolRounds: Int
    private let design: any DesignSource
    private var document: DocumentSnapshot
    private var tools: [AITool]
    private var system = ContextBuilder.systemText(directory: nil)
    /// The number of messages before the current turn. A failed turn is cut back to it.
    private var turnStart = 0
    private var rounds = 0
    /// The tool calls that wait for a decision, with the answers of the read tools of the same round.
    private var pending: PendingRound?
    private var deciding = false
    /// The index of the answer entry that the stream is writing.
    private var answerIndex: Int?
    /// True after a paused turn: the next answer continues the same assistant message.
    private var continuingPause = false
    private var work: Task<Void, Never>?

    private struct PendingRound {
        let calls: [AIToolCall]
        let answers: [String: ToolAnswer]
        let groupID: String
    }

    private struct ToolAnswer {
        let text: String
        let isError: Bool
    }

    /// - Parameters:
    ///   - plan: the model and settings of the chat, such as the code task of the stage.
    ///   - toolRounds: the most rounds of tool calls that one message may cause.
    ///   - platformTools: the tools that the platform runs itself, such as web search. They go after the client tools.
    ///   - messages: the messages of an earlier conversation, read from the saved chat. They go before the next message.
    public init(
        client: any AIClient,
        plan: TaskPlan,
        toolRounds: Int,
        document: DocumentSnapshot,
        design: any DesignSource,
        platformTools: [AITool] = [],
        messages: [AIMessage] = []
    ) {
        self.client = client
        self.plan = plan
        self.toolRounds = toolRounds
        self.document = document
        self.design = design
        self.tools = AssistantTools.definitions + platformTools
        self.messages = messages
    }

    /// The messages that a saved chat keeps: all of them between turns, and only the finished turns while one runs or waits.
    public var savedMessages: [AIMessage] {
        switch phase {
        case .streaming, .awaitingDecision:
            return Array(messages.prefix(turnStart))
        case .idle, .failed, .cancelled:
            return messages
        }
    }

    /// The IDs of the document as they are now. The app calls it after each change of the document.
    public func updateDocument(_ snapshot: DocumentSnapshot) {
        document = snapshot
    }

    /// Sends one message and runs the turn until it ends or waits for a decision.
    /// Nothing happens while a turn runs or waits for a decision, or with an empty message.
    public func send(_ input: ContextInput) async {
        guard canStart else { return }
        guard !input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !input.attachments.isEmpty else {
            return
        }
        await inWork { @Sendable in await self.begin(input) }
    }

    /// Accepts the chosen proposals of the waiting group. The applier gets them in one call.
    public func accept(applier: any ProposalApplier) async {
        guard let round = pending, !deciding, let group = currentGroup(round.groupID) else { return }
        deciding = true
        let decided = await group.accepting(current: document, applier: applier)
        deciding = false
        await finish(decided: decided, round: round)
    }

    /// Discards the waiting group. Nothing is applied; the model is told that the user did not accept it.
    public func reject() async {
        guard let round = pending, !deciding, var group = currentGroup(round.groupID) else { return }
        group.discard()
        await finish(decided: group, round: round)
    }

    /// Stops the running answer. The turn is rolled back.
    public func cancel() {
        work?.cancel()
    }

    // MARK: turn

    private var canStart: Bool {
        switch phase {
        case .idle, .failed, .cancelled:
            return true
        case .streaming, .awaitingDecision:
            return false
        }
    }

    private func begin(_ input: ContextInput) async {
        turnStart = messages.count
        rounds = 0
        continuingPause = false
        do {
            let request = try ContextBuilder.request(for: input, plan: plan, tools: tools, history: messages)
            system = request.system
            if let last = request.messages.last {
                messages.append(last)
            }
        } catch let error as AIError {
            stop(error)
            return
        } catch {
            stop(.decoding)
            return
        }
        entries.append(.user(text: input.text))
        await run()
    }

    /// Streams answers until the turn ends or waits for a decision.
    private func run() async {
        while true {
            phase = .streaming
            let response: AIResponse
            do {
                let request = try ContextBuilder.request(plan: plan, system: system, messages: messages, tools: tools)
                response = try await stream(request)
            } catch let error as AIError {
                stop(error)
                return
            } catch {
                stop(Task.isCancelled ? .cancelled : .network("the stream failed"))
                return
            }

            append(response.blocks)
            switch response.stopReason {
            case .toolUse?:
                guard rounds < toolRounds else {
                    stop(.unusableAnswer("too many rounds of tool calls"))
                    return
                }
                rounds += 1
                let calls = response.toolCalls
                guard !calls.isEmpty else {
                    phase = .idle
                    return
                }
                if let groupID = handle(calls) {
                    phase = .awaitingDecision(groupID: groupID)
                    return
                }
            case .pauseTurn?:
                continuingPause = true
            default:
                phase = .idle
                return
            }
        }
    }

    /// Adds the blocks of an answer to the history. After a paused turn they join the paused message.
    private func append(_ blocks: [AIBlock]) {
        let merge = continuingPause
        continuingPause = false
        if merge, let last = messages.indices.last, messages[last].role == .assistant {
            messages[last].blocks += blocks
        } else {
            messages.append(AIMessage(role: .assistant, blocks: blocks))
        }
    }

    /// Checks the calls of one answer. Read tools are answered at once and their results go back with the round.
    /// Change tools form one proposal group, which waits for the decision; the ID of that group is returned.
    private func handle(_ calls: [AIToolCall]) -> String? {
        var answers: [String: ToolAnswer] = [:]
        var proposals: [(String, ProposedChange)] = []
        for call in calls {
            switch AssistantTools.handle(call, document: document, design: design) {
            case let .answer(text, isError):
                answers[call.id] = ToolAnswer(text: text, isError: isError)
            case let .proposal(change):
                proposals.append((call.id, change))
            }
        }
        guard !proposals.isEmpty else {
            messages.append(AIMessage(role: .user, blocks: results(for: calls, answers: answers, group: nil)))
            return nil
        }
        let group = ProposalGroup.make(id: "group-" + proposals[0].0, proposals: proposals)
        pending = PendingRound(calls: calls, answers: answers, groupID: group.id)
        entries.append(.proposals(group))
        return group.id
    }

    /// Sends the results of a decided round back to the model and runs the turn on.
    private func finish(decided: ProposalGroup, round: PendingRound) async {
        replaceGroup(decided)
        guard decided.state != .open else { return }
        pending = nil
        messages.append(AIMessage(role: .user, blocks: results(for: round.calls, answers: round.answers, group: decided)))
        await inWork { @Sendable in await self.run() }
    }

    private func stop(_ error: AIError) {
        if messages.count > turnStart {
            messages.removeSubrange(turnStart..<messages.count)
        }
        pending = nil
        continuingPause = false
        if error == .cancelled {
            phase = .cancelled
        } else {
            phase = .failed(error)
            entries.append(.notice(AssistantMessages.notice(for: error)))
        }
    }

    // MARK: stream

    /// Reads one streamed answer. Text is shown while it arrives; the answer is returned as the API wrote it.
    private func stream(_ request: AIRequest) async throws -> AIResponse {
        var assembler = AIStreamAssembler()
        entries.append(.answer(text: ""))
        answerIndex = entries.count - 1
        defer { dropEmptyAnswer() }
        for try await event in client.stream(request) {
            try assembler.apply(event)
            if case let .textDelta(_, text) = event {
                appendText(text)
            }
            if Task.isCancelled {
                throw AIError.cancelled
            }
        }
        if Task.isCancelled {
            throw AIError.cancelled
        }
        return assembler.response
    }

    private func appendText(_ text: String) {
        guard let index = answerIndex, case let .answer(existing) = entries[index] else { return }
        entries[index] = .answer(text: existing + text)
    }

    /// An answer without text, such as a turn of tool calls only, leaves no line in the view.
    private func dropEmptyAnswer() {
        guard let index = answerIndex, index < entries.count, case let .answer(text) = entries[index], text.isEmpty else {
            answerIndex = nil
            return
        }
        entries.remove(at: index)
        answerIndex = nil
    }

    // MARK: groups

    private func currentGroup(_ id: String) -> ProposalGroup? {
        for entry in entries {
            if case let .proposals(group) = entry, group.id == id {
                return group
            }
        }
        return nil
    }

    private func replaceGroup(_ group: ProposalGroup) {
        guard let index = entries.firstIndex(where: {
            if case let .proposals(existing) = $0 { return existing.id == group.id }
            return false
        }) else {
            return
        }
        entries[index] = .proposals(group)
    }

    /// The result blocks of a round, in the order of the calls. A change gets the outcome the user gave it.
    private func results(for calls: [AIToolCall], answers: [String: ToolAnswer], group: ProposalGroup?) -> [AIBlock] {
        calls.map { call -> AIBlock in
            if let answer = answers[call.id] {
                return .toolResult(toolUseID: call.id, content: answer.text, isError: answer.isError)
            }
            let entry = group?.entries.first { $0.id == call.id }
            return .toolResult(toolUseID: call.id, content: Self.outcomeText(entry), isError: Self.isFailure(entry))
        }
    }

    static func outcomeText(_ entry: ProposalEntry?) -> String {
        guard let entry else { return "The change was not found." }
        switch entry.state {
        case .applied:
            return "The change was applied."
        case let .failed(reason):
            return "The change was not applied: \(reason)"
        case .stale:
            return "The items of this change are no longer in the document."
        case .open, .rejected:
            return "The user did not accept this change."
        }
    }

    static func isFailure(_ entry: ProposalEntry?) -> Bool {
        if case .failed? = entry?.state {
            return true
        }
        return entry == nil
    }

    // MARK: work

    /// Runs the body in its own task, so that `cancel()` can stop it.
    private func inWork(_ body: @escaping @Sendable () async -> Void) async {
        let task = Task { await body() }
        work = task
        await task.value
        work = nil
    }
}
