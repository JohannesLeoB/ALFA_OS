import Foundation
import os.log
import AlfaKit

public protocol AssistantConversing: Sendable {
    func respond(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int
    ) async throws -> ClaudeChatResponse

    func streamText(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int
    ) -> AsyncThrowingStream<String, Error>

    func respond(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int, model: String?
    ) async throws -> ClaudeChatResponse
    func streamText(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int, model: String?
    ) -> AsyncThrowingStream<String, Error>
}

extension AssistantConversing {
    public func respond(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int, model: String?
    ) async throws -> ClaudeChatResponse {
        try await respond(messages: messages, system: system, tools: tools, maxTokens: maxTokens)
    }

    public func streamText(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int, model: String?
    ) -> AsyncThrowingStream<String, Error> {
        streamText(messages: messages, system: system, tools: tools, maxTokens: maxTokens)
    }

    public func streamText(
        messages: [ChatMessage], system: String, tools: [ClaudeToolDefinition], maxTokens: Int
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let r = try await respond(messages: messages, system: system, tools: tools, maxTokens: maxTokens)
                    if r.text.isEmpty == false { continuation.yield(r.text) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

@MainActor
public final class ConversationEngine {
    private let chatStore: ChatStore
    private let provider: any AssistantConversing
    private var registry: AssistantToolRegistry?
    private let dataFlowLogger: DataFlowLogger?

    private let memoryStore: ChatMemoryStore?

    public func updateRegistry(_ newRegistry: AssistantToolRegistry) {
        self.registry = newRegistry
    }

    private static let maxToolRounds = 10

    private let toolTimeoutSeconds: Double
    private let turnDeadlineSeconds: Double

    public private(set) var isResponding = false

    public private(set) var lastRoutedModel: String?

    private var activeTask: Task<Void, Never>?

    public func cancel() {
        activeTask?.cancel()
    }

    public init(
        chatStore: ChatStore,
        provider: any AssistantConversing,
        registry: AssistantToolRegistry? = nil,
        dataFlowLogger: DataFlowLogger? = nil,
        memoryStore: ChatMemoryStore? = nil,
        toolTimeoutSeconds: Double = 15,
        turnDeadlineSeconds: Double = 75
    ) {
        self.chatStore = chatStore
        self.provider = provider
        self.registry = registry
        self.dataFlowLogger = dataFlowLogger
        self.memoryStore = memoryStore
        self.toolTimeoutSeconds = toolTimeoutSeconds
        self.turnDeadlineSeconds = turnDeadlineSeconds
    }

    public func send(
        _ text: String,
        scope: ChatScope,
        focusedProjectID: String?,
        focusedDriveFolderID: String? = nil,
        focusedClickUpListID: String? = nil,
        signals: [WidgetSignal],
        projects: [Project],
        toolsEnabled: Bool = false,
        schaetzModusEnabled: Bool = false,
        now: Date = Date(),
        profile: UserProfile? = nil,

        datenschutzPraeferenzen: DatenschutzPraeferenzen = .standard,

        actorUserID: String = "assistant",
        attachments: [ChatAttachmentRef] = [],
        chatFilesEnabled: Bool = false
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false || attachments.isEmpty == false, isResponding == false else { return }
        isResponding = true
        defer { isResponding = false }

        let attachmentBlocks: [ChatContentBlock] = attachments.map {
            ChatAttachmentStore.kind(forMimeType: $0.mimeType) == .image ? .image($0) : .document($0)
        }
        let user = ChatMessage(
            role: .user,
            blocks: (trimmed.isEmpty ? [] : [.text(trimmed)]) + attachmentBlocks
        )
        let placeholder = ChatMessage(role: .assistant, blocks: [.text("")], status: .streaming)
        do {
            try chatStore.append(user, to: scope)
            try chatStore.append(placeholder, to: scope)
        } catch {
            return
        }

        if datenschutzPraeferenzen.kiKomplettAus {
            try? chatStore.updateAssistantTurn(
                id: placeholder.id,
                blocks: [.text("Der Assistent ist per Datenschutz-Einstellung (KI komplett aus) "
                    + "ausgeschaltet — schalte ihn in den Einstellungen wieder ein, um zu antworten.")],
                status: .complete, in: scope
            )
            return
        }

        let effectiveProjectID = focusedProjectID ?? (schaetzModusEnabled ? "schaetzung" : nil)

        let persistedMessages = chatStore.messages(for: scope).filter { $0.id != placeholder.id }
        let windowed = datenschutzPraeferenzen.teileChatMitAssistent
            ? Self.memoryWindow(persistedMessages, now: now)
            : Array(persistedMessages.suffix(1))

        let (distilledConvo, conversationSummary) = datenschutzPraeferenzen.teileChatMitAssistent
            ? await applyMemoryDistillation(windowed: windowed, scope: scope)
            : (windowed, nil)
        var convo = distilledConvo
        let effectiveToolsEnabled = toolsEnabled || schaetzModusEnabled

        let routedModel = AssistantModelRouter.model(
            latestUserText: trimmed, toolsEnabled: effectiveToolsEnabled, schaetzModus: schaetzModusEnabled
        )
        lastRoutedModel = routedModel

        let disabledToolNames = Self.disabledToolNames(datenschutzPraeferenzen)
        let has: (String) -> Bool = { name in
            effectiveToolsEnabled
            && (self.registry?.toolNames.contains(name) == true)
            && disabledToolNames.contains(name) == false
        }
        let kalkulationsEnabled = has("schaetze_projekt")

        let driveEnabled      = !schaetzModusEnabled && has("list_drive_folder") && (focusedDriveFolderID?.isEmpty == false)
        let clickUpEnabled    = !schaetzModusEnabled && has("list_clickup_tasks") && (focusedClickUpListID?.isEmpty == false)
        let allClickUpEnabled = !schaetzModusEnabled && has("list_all_clickup_tasks")
        let clickUpWriteEnabled = !schaetzModusEnabled && has("propose_clickup_change")
        let contactsEnabled   = !schaetzModusEnabled && has("search_contacts")
        let contactsWriteEnabled = !schaetzModusEnabled && has("create_contact")
        let draftEnabled      = !schaetzModusEnabled && has("create_draft")
        let kontaktVerzeichnisEnabled = !schaetzModusEnabled && has("lookup_kontakt")
        let studioBrainEnabled = !schaetzModusEnabled && has("query_studio_knowledge")
        let katalogEnabled    = !schaetzModusEnabled && has("search_katalog")
        let notesEnabled      = !schaetzModusEnabled && has("create_note")
        let tasksEnabled      = !schaetzModusEnabled && has("create_task")
        let offersEnabled     = !schaetzModusEnabled && has("find_offers")
        let fileReadEnabled   = !schaetzModusEnabled && has("read_drive_file")
        let system = AssistantGrounding.systemPrompt(
            profile: profile, focusedProjectID: effectiveProjectID,
            conversationSummary: conversationSummary,
            signals: signals, projects: projects, now: now, toolsEnabled: effectiveToolsEnabled,
            kalkulationsEnabled: kalkulationsEnabled,
            driveEnabled: driveEnabled, contactsEnabled: contactsEnabled,
            clickUpEnabled: clickUpEnabled, allClickUpEnabled: allClickUpEnabled,
            draftEnabled: draftEnabled,
            contactsWriteEnabled: contactsWriteEnabled,
            kontaktVerzeichnisEnabled: kontaktVerzeichnisEnabled,
            studioBrainEnabled: studioBrainEnabled,
            katalogEnabled: katalogEnabled, notesEnabled: notesEnabled,
            tasksEnabled: tasksEnabled,
            offersEnabled: offersEnabled, fileReadEnabled: fileReadEnabled,
            chatFilesEnabled: chatFilesEnabled,
            clickUpWriteEnabled: clickUpWriteEnabled
        )

        let tools: [ClaudeToolDefinition]
        if schaetzModusEnabled {
            tools = registry?.schaetzDefinitions() ?? []
        } else {
            tools = ((toolsEnabled ? registry?.definitions() : nil) ?? [])
                .filter { disabledToolNames.contains($0.name) == false }
        }

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                var activities: [ChatContentBlock] = []
                let placeholderID = placeholder.id
                let onTextDelta: (String) -> Void = { [chatStore] text in
                    chatStore.updateStreamingText(id: placeholderID, text: text, in: scope)
                }
                let onActivities: ([ChatContentBlock]) -> Void = { [chatStore] laufend in
                    chatStore.updateStreamingActivities(id: placeholderID, activities: laufend, in: scope)
                }
                let finalText = try await self.runLoop(
                    convo: &convo, activities: &activities, system: system, tools: tools, model: routedModel,
                    focusedProjectID: effectiveProjectID, focusedDriveFolderID: focusedDriveFolderID,
                    focusedClickUpListID: focusedClickUpListID, onTextDelta: onTextDelta,
                    onActivities: onActivities,
                    actorUserID: actorUserID
                )

                try chatStore.updateAssistantTurn(
                    id: placeholder.id, blocks: activities + [.text(finalText)], status: .complete, in: scope
                )
            } catch is CancellationError {
                try? chatStore.updateAssistantTurn(
                    id: placeholder.id, blocks: [.text("Abgebrochen.")], status: .complete, in: scope
                )
            } catch {
                let message = Self.describe(error)

                try? chatStore.updateAssistantTurn(
                    id: placeholder.id, blocks: [.text(message)], status: .failed(message), in: scope
                )
            }
        }
        activeTask = task
        await task.value
        activeTask = nil
    }

    static func disabledToolNames(_ p: DatenschutzPraeferenzen) -> Set<String> {
        var disabled: Set<String> = []
        if p.teileMailMitAssistent == false {
            disabled.formUnion(["search_gmail", "read_email", "create_draft"])
        }
        if p.teileKalenderMitAssistent == false {
            disabled.formUnion(["list_calendar_events", "suggest_calendar_event"])
        }
        if p.teileKontakteMitAssistent == false {
            disabled.formUnion([
                "search_contacts", "create_contact", "lookup_kontakt", "lookup_kunde",
                "list_airtable_kontakte", "search_airtable_kontakt",
                "create_airtable_kontakt", "update_airtable_kontakt"
            ])
        }
        if p.teileDriveMitAssistent == false {
            disabled.formUnion(["list_drive_folder", "read_drive_file", "find_offers"])
        }
        if p.teileClickUpMitAssistent == false {
            disabled.formUnion(["list_clickup_tasks", "list_all_clickup_tasks", "propose_clickup_change"])
        }
        if p.teileNotizenMitAssistent == false {
            disabled.formUnion(["create_note", "list_notes", "update_note", "delete_note"])
        }
        if p.teileAufgabenMitAssistent == false {
            disabled.formUnion(["create_task", "list_tasks", "complete_task", "delete_task"])
        }
        if p.teileKatalogKalkulationMitAssistent == false {
            disabled.formUnion(["search_katalog", "schaetze_projekt"])
        }
        if p.teileStudioWissenMitAssistent == false {
            disabled.formUnion(["query_studio_knowledge"])
        }
        if p.teileChatMitAssistent == false {
            disabled.formUnion(["log_friction_point"])
        }
        return disabled
    }

    static let usageLog = Logger(subsystem: MykLog.subsystem, category: "assistent.verbrauch")

    static func report(usage: ClaudeTokenUsage?, model: String?, toolCount: Int) {
        guard let usage else { return }
        usageLog.info("Assistent \(model ?? "Standard", privacy: .public) · neu \(usage.input, privacy: .public) · aus Cache \(usage.cacheRead, privacy: .public) · in Cache \(usage.cacheWrite, privacy: .public) · Antwort \(usage.output, privacy: .public) · Cache \(Int(usage.cacheShare * 100), privacy: .public)% · Werkzeuge \(toolCount, privacy: .public)")
    }

    public static let memoryWindowDays = 28
    public static let antwortMaxTokens = 4096

    static func memoryWindow(_ messages: [ChatMessage], now: Date) -> [ChatMessage] {
        let cutoff = now.addingTimeInterval(-Double(memoryWindowDays) * 24 * 3600)
        var windowed = messages.filter { $0.createdAt >= cutoff }
        if windowed.count > 120 { windowed = Array(windowed.suffix(120)) }
        return trimToUserStart(windowed)
    }

    static func trimToUserStart(_ messages: [ChatMessage]) -> [ChatMessage] {
        var trimmed = messages
        while let first = trimmed.first, first.role != .user { trimmed.removeFirst() }
        return trimmed
    }

    private static let distillationTailSize = 8
    private static let distillationMinBatch = 12

    private static let distillationModel = "claude-haiku-4-5-20251001"

    private func applyMemoryDistillation(
        windowed: [ChatMessage], scope: ChatScope
    ) async -> (convo: [ChatMessage], summary: String?) {
        guard let memoryStore, windowed.count > Self.distillationTailSize else {
            return (windowed, nil)
        }
        let tailStart = windowed.count - Self.distillationTailSize
        do {
            let existing = try memoryStore.summary(for: scope)
            let coveredIndex = existing.flatMap { summary in
                windowed.firstIndex { $0.id.uuidString == summary.coveredThroughMessageID }
            } ?? -1
            let newOldSlice = coveredIndex + 1 < tailStart ? Array(windowed[(coveredIndex + 1)..<tailStart]) : []

            if newOldSlice.count >= Self.distillationMinBatch {
                let newSummaryText = try await distill(existingSummaryText: existing?.summaryText, newMessages: newOldSlice)
                try memoryStore.save(ChatMemorySummary(
                    scopeKey: scope.rawKey,
                    summaryText: newSummaryText,
                    coveredThroughMessageID: newOldSlice.last!.id.uuidString,
                    updatedAt: Date()
                ))
                return (Self.trimToUserStart(Array(windowed[tailStart...])), newSummaryText)
            }
            if let existing {
                return (Self.trimToUserStart(Array(windowed[tailStart...])), existing.summaryText)
            }

            return (windowed, nil)
        } catch {
            return (windowed, nil)
        }
    }

    private func distill(existingSummaryText: String?, newMessages: [ChatMessage]) async throws -> String {
        let transcript = newMessages.map { m in
            "\(m.role == .user ? "Nutzer" : "Assistent"): \(m.text)"
        }.joined(separator: "\n")
        let system = """
        Du fasst einen Chatverlauf kompakt für ein Assistenten-Gedächtnis zusammen. Du bekommst eine \
        bisherige Zusammenfassung (kann isEmpty sein) und neue Nachrichten seit der letzten Zusammenfassung. \
        Verschmelze beides zu EINER neuen, aktuellen Fassung — häufe nicht an. Widersprüche löst du \
        zugunsten der neueren Information auf. Halte Entscheidungen, offene Punkte, Nutzer-Präferenzen/ \
        -Korrekturen und projektrelevante Fakten fest. Antworte NUR mit der neuen Zusammenfassung als \
        Fließtext, maximal 400 Wörter, keine Meta-Kommentare, keine Überschriften.
        """
        let existingPart = (existingSummaryText?.isEmpty == false) ? existingSummaryText! : "(noch keine)"
        let userTurn = ChatMessage.text(
            "BISHERIGE ZUSAMMENFASSUNG:\n\(existingPart)\n\nNEUE NACHRICHTEN SEIT DER LETZTEN ZUSAMMENFASSUNG:\n\(transcript)",
            role: .user
        )
        let response = try await provider.respond(
            messages: [userTurn], system: system, tools: [], maxTokens: 600, model: Self.distillationModel
        )
        return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runLoop(
        convo: inout [ChatMessage],
        activities: inout [ChatContentBlock],
        system: String,
        tools: [ClaudeToolDefinition],
        model: String,
        focusedProjectID: String? = nil,
        focusedDriveFolderID: String? = nil,
        focusedClickUpListID: String? = nil,
        onTextDelta: ((String) -> Void)? = nil,
        onActivities: (([ChatContentBlock]) -> Void)? = nil,
        actorUserID: String = "assistant"
    ) async throws -> String {
        if tools.isEmpty, let onTextDelta {
            return try await streamingFinalAnswer(convo: convo, system: system, model: model, onTextDelta: onTextDelta)
        }

        let deadline = Date().addingTimeInterval(turnDeadlineSeconds)
        var rounds = 0

        var seenToolCalls: Set<String> = []

        var evidenceBelege: [String] = convo.compactMap { $0.role == .user ? $0.text : nil }

        var belegQuellen: [GroundingGate.BelegQuelle] = convo.compactMap {
            $0.role == .user ? GroundingGate.BelegQuelle(source: "Deine Nachricht", text: $0.text) : nil
        }
        while true {
            rounds += 1
            if Date() >= deadline {
                return "Das dauert gerade zu lange — bitte versuche es erneut oder formuliere die Frage einfacher."
            }
            let response = try await provider.respond(messages: convo, system: system, tools: tools, maxTokens: Self.antwortMaxTokens, model: model)
            Self.report(usage: response.usage, model: model, toolCount: tools.count)

            if response.toolUses.isEmpty {
                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? "Ich konnte gerade keine Antwort bilden." : response.text
            }
            if rounds >= Self.maxToolRounds {
                let text = response.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let notice = "\n\n_(Antwort nach \(Self.maxToolRounds) Suchschritten abgebrochen — bitte mit \"weiter\" oder einer präziseren Anfrage nachfassen.)_"
                return text.isEmpty
                    ? "Das dauert gerade zu viele Schritte — bitte formuliere die Frage präziser."
                    : text + notice
            }

            var assistantBlocks: [ChatContentBlock] = response.text.isEmpty ? [] : [.text(response.text)]
            assistantBlocks += response.toolUses.map { .toolUse(id: $0.id, name: $0.name, inputJSON: $0.inputJSON) }
            convo.append(ChatMessage(role: .assistant, blocks: assistantBlocks, status: .complete))

            var resultBlocks: [ChatContentBlock] = []
            var repeatDetected = false
            for toolUse in response.toolUses {
                let callKey = Self.callKey(name: toolUse.name, inputJSON: toolUse.inputJSON)
                let isRepeat = seenToolCalls.contains(callKey)
                seenToolCalls.insert(callKey)
                let result: ToolRunResult
                if isRepeat {
                    repeatDetected = true
                    result = ToolRunResult(
                        text: "Diese Anfrage wurde in diesem Gespräch bereits identisch gestellt — wird nicht wiederholt.",
                        isError: true
                    )
                } else {
                    onActivities?(activities + [.toolActivity(
                        label: Self.activityLabel(name: toolUse.name, inputJSON: toolUse.inputJSON) + " …", isError: false)])
                    result = await runToolWithTimeout(
                        name: toolUse.name, inputJSON: toolUse.inputJSON,
                        projektID: focusedProjectID, driveFolderID: focusedDriveFolderID, clickUpListID: focusedClickUpListID
                    )
                }

                dataFlowLogger?.log(
                    integrationID: AssistantToolManifest.manifestID(forTool: toolUse.name),
                    actorUserID: actorUserID,
                    action: result.isError ? .error : .success,
                    errorMessage: result.isError ? result.text : nil,
                    summary: "Tool-Call: \(toolUse.name)"
                )

                let istSchreibVorschau = result.emailDraft != nil
                    || result.contactDraft != nil
                    || result.airtableContactDraft != nil
                if result.isError == false && istSchreibVorschau == false {
                    evidenceBelege.append(result.text)
                    belegQuellen.append(GroundingGate.BelegQuelle(
                        source: Self.activityLabel(name: toolUse.name, inputJSON: toolUse.inputJSON),
                        text: result.text
                    ))
                }

                let evidence = GroundingGate.Evidence(evidenceBelege)
                var summaryForModel = result.text
                var haltEmailDraft = false
                var haltContactDraft = false
                var haltAirtableDraft = false
                func gate(_ verdict: GroundingGate.Verdict) -> Bool {
                    guard verdict.isGrounded == false else { return false }
                    summaryForModel += GroundingGate.modellHinweis(verdict)
                    activities.append(.toolActivity(label: GroundingGate.warnLabel(verdict), isError: true))
                    return true
                }

                func provenanceSpur(_ hits: [GroundingGate.ProvenanceHit]) {
                    if let label = GroundingGate.provenanceLabel(hits) {
                        activities.append(.toolActivity(label: label, isError: false))
                    }
                }
                if let mailDraft = result.emailDraft {
                    haltEmailDraft = gate(GroundingGate.pruefe(mailDraft, evidence: evidence))
                }
                if let draft = result.contactDraft {
                    haltContactDraft = gate(GroundingGate.pruefe(draft, evidence: evidence))
                }
                if let airtableDraft = result.airtableContactDraft {
                    haltAirtableDraft = gate(GroundingGate.pruefe(airtableDraft, evidence: evidence))
                }

                resultBlocks.append(.toolResult(toolUseID: toolUse.id, summary: summaryForModel, isError: result.isError))
                activities.append(.toolActivity(
                    label: Self.activityLabel(name: toolUse.name, inputJSON: toolUse.inputJSON),
                    isError: result.isError
                ))
                if let url = result.actionURL {
                    activities.append(.calendarAction(url: url, label: "Im Kalender öffnen"))
                }
                if let draft = result.contactDraft, haltContactDraft == false {
                    activities.append(.contactAction(draft: draft))
                    provenanceSpur(GroundingGate.provenance(draft, belege: belegQuellen))
                }
                if let mailDraft = result.emailDraft, haltEmailDraft == false {
                    activities.append(.draftAction(draft: mailDraft))
                    provenanceSpur(GroundingGate.provenance(mailDraft, belege: belegQuellen))
                }
                if result.driveFiles.isEmpty == false {
                    activities.append(.driveFiles(label: "Gefundene Dokumente", files: result.driveFiles))
                }
                if let airtableDraft = result.airtableContactDraft, haltAirtableDraft == false {
                    activities.append(.airtableContactAction(draft: airtableDraft))
                    provenanceSpur(GroundingGate.provenance(airtableDraft, belege: belegQuellen))
                }
                if let terminDraft = result.terminDraft {
                    activities.append(.terminAction(draft: terminDraft))
                }
                if let warenkorbDraft = result.warenkorbDraft {
                    activities.append(.warenkorbAction(draft: warenkorbDraft))
                }
                if let dateiDraft = result.dateiDraft {
                    activities.append(.dateiAction(draft: dateiDraft))
                }
                if let clickUpDraft = result.clickUpDraft {
                    activities.append(.clickUpAction(draft: clickUpDraft))
                }
                if let s = result.schaetzung {
                    activities.append(.kalkulationsSchaetzung(
                        schaetzungsID: s.schaetzungsID,
                        projektID: s.projektID,
                        minNetto: s.minNetto,
                        maxNetto: s.maxNetto,
                        mitteNetto: s.mitteNetto,
                        confidence: s.confidence,
                        evidenceCount: s.evidenceCount
                    ))
                    if s.lines.isEmpty == false || s.excludes.isEmpty == false {
                        activities.append(.estimateBreakdown(
                            schaetzungsID: s.schaetzungsID,
                            lines: s.lines,
                            excludes: s.excludes
                        ))
                    }
                }
            }
            convo.append(ChatMessage(role: .user, blocks: resultBlocks, status: .complete))
            onActivities?(activities)

            if repeatDetected {
                return "Ich konnte dazu keine neuen Daten finden — magst du die Frage anders stellen oder mir mehr Kontext geben?"
            }
        }
    }

    private func runToolWithTimeout(
        name: String, inputJSON: Data, projektID: String?, driveFolderID: String?, clickUpListID: String?
    ) async -> ToolRunResult {
        guard let registry else { return ToolRunResult(text: "Keine Tools verfügbar.", isError: true) }
        let timeout = toolTimeoutSeconds
        return await withTaskGroup(of: ToolRunResult.self) { group in
            group.addTask {
                await registry.run(
                    name: name, inputJSON: inputJSON, projektID: projektID,
                    driveFolderID: driveFolderID, clickUpListID: clickUpListID
                )
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return ToolRunResult(text: "Zeitüberschreitung — das Tool hat nicht rechtzeitig geantwortet.", isError: true)
            }
            let first = await group.next() ?? ToolRunResult(text: "Keine Antwort erhalten.", isError: true)
            group.cancelAll()
            return first
        }
    }

    static func callKey(name: String, inputJSON: Data) -> String {
        "\(name)|\(String(data: inputJSON, encoding: .utf8) ?? "")"
    }

    private func streamingFinalAnswer(
        convo: [ChatMessage], system: String, model: String, onTextDelta: (String) -> Void
    ) async throws -> String {
        let stream = provider.streamText(messages: convo, system: system, tools: [], maxTokens: Self.antwortMaxTokens, model: model)
        var accumulated = ""
        for try await delta in stream {
            accumulated += delta
            onTextDelta(accumulated)
        }
        let trimmed = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ich konnte gerade keine Antwort bilden." : accumulated
    }

    static func activityLabel(name: String, inputJSON: Data) -> String {
        let input = Self.stringDict(from: inputJSON)
        let query = input["query"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: String
        switch name {
        case "search_gmail":              base = "Gmail durchsucht"
        case "read_email":                base = "Mail gelesen"
        case "create_draft":              base = "Mail-Entwurf vorbereitet"
        case "list_calendar_events":      base = "Kalender gelesen"
        case "suggest_calendar_event":    base = "Kalender-Link generiert"
        case "schaetze_projekt":          base = "Kostenschätzung erstellt"
        case "list_drive_folder":         base = "Drive-Ordner gelesen"
        case "search_contacts":           base = "Kontakte durchsucht"
        case "create_contact":            base = "Kontakt-Entwurf erstellt"
        case "list_clickup_tasks":        base = "ClickUp gelesen"
        case "query_studio_knowledge":    base = "Wissensbasis durchsucht"
        case "search_katalog":            base = "Katalog durchsucht"
        case "find_offers":               base = "Angebote im Drive gesucht"
        case "read_drive_file":           base = "Datei gelesen"
        case "list_all_clickup_tasks":    base = "ClickUp über alle Projekte gelesen"
        case "lookup_kunde":              base = "Kunde nachgeschlagen"
        case "propose_clickup_change":    base = "ClickUp-Änderung vorbereitet"
        case "lookup_kontakt", "search_airtable_kontakt", "list_airtable_kontakte": base = "Kontaktverzeichnis gelesen"
        case "create_airtable_kontakt":   base = "Kontakt-Vorschlag erstellt"
        case "update_airtable_kontakt":   base = "Kontakt-Änderung vorgeschlagen"
        case "create_note", "update_note", "delete_note", "list_notes": base = "Notizen"
        case "create_task", "complete_task", "delete_task", "list_tasks": base = "Interne Aufgaben"
        default:                          base = name
        }
        if let query, query.isEmpty == false { return "\(base) · \(query)" }
        return base
    }

    static func stringDict(from data: Data) -> [String: String] {
        guard let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
        return raw.compactMapValues { v in
            if let s = v as? String { return s }
            if let n = v as? NSNumber { return n.stringValue }
            return nil
        }
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case ClaudeClientError.notConnected:
            "Claude ist nicht verbunden — bitte in den Einstellungen einen API-Key hinterlegen."
        case ClaudeClientError.rateLimited:
            "Zu viele Anfragen — bitte kurz warten und erneut versuchen."
        case ClaudeClientError.overloaded:
            "Der Dienst ist gerade überlastet — bitte gleich erneut versuchen."
        case ClaudeClientError.httpError(let code):
            "Die Anfrage ist fehlgeschlagen (Fehler \(code))."
        case ClaudeClientError.streamInterrupted:
            "Die Verbindung wurde unterbrochen — bitte erneut versuchen."
        default:
            "Es ist ein Fehler aufgetreten. Bitte erneut versuchen."
        }
    }
}
