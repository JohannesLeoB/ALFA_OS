import Calculation
import Core
import Foundation
import Hub
@testable import Storage
import XCTest
@testable import Assistant

private struct KeyText: TextPort {
    func text(_ key: String, _ arguments: [String]) -> String {
        arguments.isEmpty ? key : key + "|" + arguments.joined(separator: "|")
    }
}

private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}

private struct FakeKeys: KeyPort {
    func claudeKey() async -> ClaudeKey? { ClaudeKey(apiKey: "k", model: "m") }
}

private struct FakeHttp: HttpPort {
    let sent: Box<[URLRequest]>
    let streamLines: [String]

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        sent.value.append(request)
        let body = Data(#"{"content":[{"type":"text","text":"hi"}],"stop_reason":"end_turn"}"#.utf8)
        return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        sent.value.append(request)
        let lines = streamLines
        let stream = AsyncThrowingStream<String, any Error> { continuation in
            for line in lines { continuation.yield(line) }
            continuation.finish()
        }
        return (stream, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private final class ScriptedProvider: ConversationPort, @unchecked Sendable {
    private let state: Box<(replies: [Reply], requests: [ChatRequest])>

    init(_ replies: [Reply]) { state = Box((replies, [])) }

    func respond(_ request: ChatRequest) async throws -> Reply {
        var current = state.value
        current.requests.append(request)
        let reply = current.replies.isEmpty ? Reply(text: "done", toolUses: [], stopReason: nil) : current.replies.removeFirst()
        state.value = current
        return reply
    }

    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { $0.finish() }
    }

    var requests: [ChatRequest] { state.value.requests }
    var count: Int { requests.count }
}

private final class FlakyProvider: ConversationPort, @unchecked Sendable {
    private let failures: Box<Int>

    init(failures: Int) { self.failures = Box(failures) }

    func respond(_ request: ChatRequest) async throws -> Reply {
        Reply(text: "ok", toolUses: [], stopReason: nil)
    }

    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, any Error> {
        let fail = failures.value > 0
        if fail { failures.value -= 1 }
        return AsyncThrowingStream { continuation in
            if fail {
                continuation.finish(throwing: ClaudeFailure.overloaded)
            } else {
                continuation.yield("Antwort")
                continuation.finish()
            }
        }
    }
}

private struct HangingProvider: ConversationPort {
    func respond(_ request: ChatRequest) async throws -> Reply {
        try await Task.sleep(for: .seconds(30))
        return Reply(text: "", toolUses: [], stopReason: nil)
    }

    func stream(_ request: ChatRequest) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                try? await Task.sleep(for: .seconds(30))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

@MainActor
private func until(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<400 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}

private func scratch() -> URL {
    let base = ProcessInfo.processInfo.environment["TMPDIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    return (base ?? FileManager.default.temporaryDirectory).appendingPathComponent(UUID().uuidString, isDirectory: true)
}

private func file(_ name: String, _ text: String, in folder: URL) throws -> URL {
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let url = folder.appendingPathComponent(name)
    try Data(text.utf8).write(to: url)
    return url
}

private func stored(_ store: AttachmentStore) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: store.directory.path)) ?? []).sorted()
}

private struct CopyAttachments: AttachmentPort {
    let store: AttachmentStore

    func save(_ url: URL) async throws -> AttachmentRef {
        let data = try Data(contentsOf: url)
        let name = UUID().uuidString + "." + url.pathExtension
        try FileManager.default.createDirectory(at: store.directory, withIntermediateDirectories: true)
        try data.write(to: store.directory.appendingPathComponent(name))
        return AttachmentRef(fileName: url.lastPathComponent, mimeType: AttachmentStore.mimeType(of: url), byteCount: data.count,
                             relativePath: name, sha256: name)
    }

    func sweep(keeping paths: Set<String>) {
        store.sweep(keeping: paths)
    }
}

private func body(_ request: URLRequest) -> String {
    String(decoding: request.httpBody ?? Data(), as: UTF8.self)
}

private final class FakeAlarm: AlarmPort, @unchecked Sendable {
    let scheduled = Box<[Todo]>([])
    let cancelled = Box<[String]>([])
    func reschedule(_ todo: Todo) async { scheduled.value.append(todo) }
    func cancel(todoID: String) async { cancelled.value.append(todoID) }
}

private struct Stub: MailSearchPort, CalendarPort, DrivePort, GoogleContactsPort, TaskBoardPort, CatalogPort, StockPort,
                     SamplePort, TimeEntryPort, ReceiptPort, ShipmentPort, PdfRenderPort {
    var hasTeamCalendars: Bool { false }
    func search(query: String, limit: Int) async throws -> [MailHit] {
        [MailHit(id: "m1", subject: "Angebot", from: "a@b.de", receivedAt: nil, labels: ["INBOX", "UNREAD"], snippet: "s")]
    }
    func body(messageID: String) async throws -> String { "body" }
    func calendars() async throws -> [CalendarRef] { [] }
    func events(calendarID: String?, query: String?, withinDays: Int) async throws -> [CalendarEntry] { [] }
    func list(folderID: String) async throws -> [DriveEntry] { [] }
    func offers(folderID: String) async throws -> OfferListing { OfferListing() }
    func findFile(named name: String, in folderID: String) async throws -> DriveEntry? { nil }
    func text(of file: DriveEntry) async throws -> String? { nil }
    func search(query: String) async throws -> [GoogleContact] { [] }
    func openTasks(listID: String) async throws -> [TaskItem] {
        listID == "L1" ? [TaskItem(id: "t1", name: "Plan", status: "open", isUrgent: true)] : []
    }
    func members(listID: String) async throws -> [TaskMember] { [] }
    func search(term: String, limit: Int) async -> ArticleSearchState { .empty }
    func current() async -> StockListState { .empty }
    func samples(projectNumber: String) async throws -> SampleListing { SampleListing(samples: []) }
    func report(period: TimePeriod) async -> TimeReport { TimeReport(entries: []) }
    func receipts() async -> [ReceiptEntry] { [] }
    func track(number: String) async throws -> ShipmentStatus { ShipmentStatus(number: number, statusLabel: "x") }
    func render(title: String, rows: [[String]]) async throws -> Data { Data("pdf".utf8) }
}

private struct FixedStock: StockPort {
    let state: StockListState
    func current() async -> StockListState { state }
}

private final class FakeEstimation:EstimationPort, @unchecked Sendable {
    let overrides = Box<[EstimateOverride]>([])
    func estimate(projectID: String?, text: String, override: EstimateOverride) async throws -> CostEstimate {
        overrides.value.append(override)
        return CostEstimate(
            estimateID: "e1", projectID: projectID ?? "", minNet: 1000, maxNet: 3000, midNet: 2000, confidence: 0.5,
            evidenceCount: 3, costFloor: 0, costFloorRatio: 0, topEvidence: [],
            lines: [EstimateBreakdownLine(label: Notice("calc.exclude.worktop.label"), amountNet: nil, kind: .open)])
    }
}

final class AssistantTests: XCTestCase {
    private func makeTools(database: SQLiteStore, alarm: FakeAlarm = FakeAlarm()) throws -> [any ToolPort] {
        let stub = Stub()
        let notes = NoteStore(database: database, userID: "u")
        let todos = TodoStore(database: database, userID: "u")
        let journal = JournalStore(database: database)
        let projects = ProjectSearchEngine(entries: [ProjectEntry(projectNumber: "2408-01", title: "Haus", driveFolderID: "f")])
        let lists = [ProjectTaskList(projectNumber: "2408-01", title: "Haus", listID: "L1")]
        let knowledge = try XCTUnwrap(StudioKnowledge(data: Data("{}".utf8)))
        let artifacts = ArtifactStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        return [
            SearchMailTool(mail: stub), ReadMailTool(mail: stub), ProposeMailDraftTool(),
            ListEventsTool(calendar: stub), SuggestEventLinkTool(), ProposeEventTool(),
            ListFolderTool(drive: stub), FindOffersTool(drive: stub, projects: projects), ReadFileTool(drive: stub, projects: projects),
            SearchGoogleContactsTool(contacts: stub), ProposeGoogleContactTool(),
            ListTasksTool(board: stub, lists: lists), ProposeTaskChangeTool(board: stub, lists: lists),
            SearchCatalogTool(catalog: stub), ListStockTool(stock: stub), ProposeCartItemTool(catalog: stub, stock: stub),
            StudioKnowledgeTool(knowledge: knowledge), LookupCustomerTool(customers: CustomerSearchEngine(customers: [])),
            SearchContactsTool(directory: ContactSearchEngine(contacts: [])), ProposeContactTool(directory: ContactSearchEngine(contacts: [])),
            ProposeContactChangeTool(),
            CreateNoteTool(notes: notes), ListNotesTool(notes: notes), UpdateNoteTool(notes: notes), DeleteNoteTool(notes: notes),
            CreateTodoTool(todos: todos, alarm: alarm), ListTodosTool(todos: todos),
            CompleteTodoTool(todos: todos, alarm: alarm), DeleteTodoTool(todos: todos, alarm: alarm),
            JournalTool(journal: journal), CalculationTool(estimation: FakeEstimation()),
            ListProjectsTool(projects: projects), ListSamplesTool(samples: stub), ListTimeEntriesTool(time: stub),
            ListDocumentsTool(receipts: stub), TrackShipmentTool(shipments: stub),
            ProposeFileTool(artifacts: artifacts, projects: projects, pdf: stub),
        ]
    }

    func testToolInventoryDeclaresAccessAndPrivacy() throws {
        let tools = try makeTools(database: SQLiteStore.inMemory())
        XCTAssertEqual(Set(tools.map(\.name)).count, tools.count)
        let expected: [String: (ToolAccess, PrivacyCategory)] = [
            "search_gmail": (.read, .mail), "read_email": (.read, .mail), "create_draft": (.propose, .mail),
            "list_calendar_events": (.read, .calendar), "suggest_calendar_event": (.propose, .calendar),
            "propose_termin": (.propose, .calendar), "list_drive_folder": (.read, .drive), "find_offers": (.read, .drive),
            "read_drive_file": (.read, .drive), "search_contacts": (.read, .contacts), "create_contact": (.propose, .contacts),
            "list_clickup_tasks": (.read, .clickUp), "propose_clickup_change": (.propose, .clickUp),
            "search_katalog": (.read, .catalogCalculation), "list_lager": (.read, .catalogCalculation),
            "propose_warenkorb": (.propose, .catalogCalculation), "query_studio_knowledge": (.read, .studioKnowledge),
            "lookup_kunde": (.read, .contacts), "lookup_kontakt": (.read, .contacts),
            "create_airtable_kontakt": (.propose, .contacts), "update_airtable_kontakt": (.propose, .contacts),
            "create_note": (.write, .notes), "list_notes": (.read, .notes), "update_note": (.write, .notes),
            "delete_note": (.write, .notes), "create_task": (.write, .tasks), "list_tasks": (.read, .tasks),
            "complete_task": (.write, .tasks), "delete_task": (.write, .tasks), "log_friction_point": (.write, .chat),
            "schaetze_projekt": (.write, .catalogCalculation), "list_projects": (.read, .studioKnowledge),
            "list_bemusterung": (.read, .studioKnowledge), "list_zeiten": (.read, .time), "list_belege": (.read, .drive),
            "verfolge_sendung": (.read, .catalogCalculation), "erzeuge_datei": (.write, .drive),
        ]
        XCTAssertEqual(Set(tools.map(\.name)), Set(expected.keys))
        for tool in tools {
            XCTAssertEqual(tool.access, expected[tool.name]?.0, tool.name)
            XCTAssertEqual(tool.privacy, expected[tool.name]?.1, tool.name)
        }
    }

    func testEveryPrivacyCategoryRemovesItsToolsAndNothingElse() throws {
        let tools = try makeTools(database: SQLiteStore.inMemory())
        for category in PrivacyCategory.allCases {
            let snapshot = PrivacySnapshot(settings: PrivacySettings(disabled: [category]))
            let allowed = ToolAccessEngine.allowed(tools, privacy: snapshot)
            XCTAssertEqual(allowed.count, tools.filter { $0.privacy != category }.count)
            XCTAssertTrue(allowed.allSatisfy { $0.privacy != category })
        }
        let none = ToolAccessEngine.allowed(tools, privacy: PrivacySnapshot(settings: PrivacySettings(disabled: Set(PrivacyCategory.allCases))))
        XCTAssertTrue(none.isEmpty)
    }

    func testUnreadablePrivacyClosesEveryCategory() throws {
        struct Unreadable: PrivacyPort {
            func load() throws -> PrivacySettings { throw CocoaError(.fileReadCorruptFile) }
        }
        let reading = Unreadable().current()
        XCTAssertFalse(reading.readable)
        XCTAssertTrue(PrivacyCategory.allCases.allSatisfy { reading.settings.shares($0) == false })
        let tools = try makeTools(database: SQLiteStore.inMemory())
        XCTAssertTrue(ToolAccessEngine.allowed(tools, privacy: PrivacySnapshot(settings: reading.settings)).isEmpty)
        let stored = PrivacyStore(database: try SQLiteStore.inMemory()).current()
        XCTAssertTrue(stored.readable)
        XCTAssertEqual(stored.settings, PrivacySettings())
    }

    func testLocalizationFileCoversEveryKeyInSourceAndEveryTool() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/assistant.localizable.json"))
        let keys = try XCTUnwrap((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["keys"] as? [String: Any])
        let ignored: Set<String> = ["assistant.alarm.enabled", "assistant.alarm.sound", "assistant.usage"]
        let regex = try NSRegularExpression(pattern: #""(assistant\.[A-Za-z0-9_.]+[A-Za-z0-9_])""#)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root.appendingPathComponent("Sources/Assistant"), includingPropertiesForKeys: nil))
        var missing: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                let key = String(source[Range(match.range(at: 1), in: source)!])
                if ignored.contains(key) { continue }
                let dynamicPrefix = key.hasSuffix(".") == false && ["assistant.activity", "assistant.field", "assistant.studio.total", "assistant.time.header", "assistant.tool"].contains(key)
                if keys[key] == nil && dynamicPrefix == false { missing.append(key) }
            }
        }
        XCTAssertEqual(missing, [])
        let tools = try makeTools(database: SQLiteStore.inMemory())
        for tool in tools {
            XCTAssertNotNil(keys[tool.descriptionKey], tool.name)
            XCTAssertNotNil(keys[tool.activityKey], tool.name)
            for parameter in tool.parameters { XCTAssertNotNil(keys[tool.parameterKey(parameter.name)], tool.name + "." + parameter.name) }
            if tool.documented { for key in tool.promptKeys(available: Set(tools.map(\.name))) { XCTAssertNotNil(keys[key], key) } }
        }
        for key in ["assistant.field.to", "assistant.field.cc", "assistant.field.bcc", "assistant.field.email", "assistant.field.phone",
                    "assistant.time.header.today", "assistant.time.header.week", "assistant.time.header.month"] {
            XCTAssertNotNil(keys[key], key)
        }
        for key in StudioKnowledge.totalKeys { XCTAssertNotNil(keys["assistant.studio.total." + key]) }
        let json = String(decoding: data, as: UTF8.self).lowercased()
        XCTAssertFalse(json.contains("m" + "yk"))
    }

    func testRouterKeepsKeywordRulesAndModelIds() {
        XCTAssertEqual(ModelRouter.haiku, "claude-haiku-4-5-20251001")
        XCTAssertEqual(ModelRouter.sonnet, "claude-sonnet-4-6")
        XCTAssertEqual(ModelRouter.opus, "claude-opus-4-8")
        XCTAssertEqual(ClaudeModelChoice.allCases.map(\.id), [nil, ModelRouter.sonnet, ModelRouter.haiku, ModelRouter.opus])
        XCTAssertEqual(ClaudeModelChoice.stored(nil), .standard)
        XCTAssertEqual(ClaudeModelChoice.stored("unknown"), .standard)
        XCTAssertEqual(ClaudeModelChoice.stored(ModelRouter.opus), .opus)
        XCTAssertEqual(ClaudeModelChoice.allCases.map(\.key),
                       ["settings.value.default", "settings.model.sonnet", "settings.model.haiku", "settings.model.opus"])
        XCTAssertEqual(ModelRouter.model(latestUserText: "Was kostet das? 5 \u{20AC}", toolsEnabled: true), ModelRouter.opus)
        XCTAssertEqual(ModelRouter.model(latestUserText: "mein BUDGET", toolsEnabled: false), ModelRouter.opus)
        XCTAssertEqual(ModelRouter.model(latestUserText: "ein euro", toolsEnabled: false), ModelRouter.opus)
        XCTAssertEqual(ModelRouter.model(latestUserText: "hallo", toolsEnabled: true), ModelRouter.sonnet)
        XCTAssertEqual(ModelRouter.model(latestUserText: "hallo", toolsEnabled: false), ModelRouter.haiku)
        XCTAssertEqual(ModelRouter.model(latestUserText: "erkl\u{E4}re mir das", toolsEnabled: false), ModelRouter.sonnet)
        XCTAssertEqual(ModelRouter.model(latestUserText: Array(repeating: "wort", count: 41).joined(separator: " "), toolsEnabled: false), ModelRouter.sonnet)
    }

    func testNumericToolInputIsReplayedNotEmptied() async throws {
        let sent = Box<[URLRequest]>([])
        let client = ClaudeClient(keys: FakeKeys(), http: FakeHttp(sent: sent, streamLines: []))
        let input = Data(#"{"korpusanzahl":12,"entfernung_km":2.5,"x":"y"}"#.utf8)
        let messages = [
            Message.text("hi", role: .user),
            Message(role: .assistant, blocks: [.toolUse(id: "1", name: "schaetze_projekt", inputJSON: input)]),
            Message(role: .user, blocks: [.toolResult(toolUseID: "1", summary: "ok", isError: false)]),
        ]
        _ = try await client.respond(ChatRequest(messages: messages, system: "s", maxTokens: 10))
        let body = String(decoding: try XCTUnwrap(sent.value.first?.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains(#""korpusanzahl":12"#), body)
        XCTAssertTrue(body.contains(#""entfernung_km":2.5"#), body)
        XCTAssertEqual(sent.value.first?.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
    }

    func testStreamingGoesThroughInjectedHttpAndSurfacesErrors() async throws {
        let sent = Box<[URLRequest]>([])
        let good = [
            #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"ab"}}"#,
            #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"cd"}}"#, "data: [DONE]",
        ]
        let client = ClaudeClient(keys: FakeKeys(), http: FakeHttp(sent: sent, streamLines: good))
        var text = ""
        for try await part in client.stream(ChatRequest(messages: [.text("x", role: .user)], system: "s", maxTokens: 5)) { text += part }
        XCTAssertEqual(text, "abcd")
        XCTAssertEqual(sent.value.count, 1)
        let bad = ClaudeClient(keys: FakeKeys(), http: FakeHttp(sent: sent, streamLines: [#"data: {"type":"error"}"#]))
        do {
            for try await _ in bad.stream(ChatRequest(messages: [.text("x", role: .user)], system: "s", maxTokens: 5)) {}
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? ClaudeFailure, .streamInterrupted)
        }
    }

    func testRequestMarksOnlyLastToolForCaching() throws {
        let client = ClaudeClient(keys: FakeKeys(), http: FakeHttp(sent: Box([]), streamLines: []))
        let tools: [any ToolPort] = [ProposeMailDraftTool(), SuggestEventLinkTool()]
        let definitions = tools.map { ToolDefinition(tool: $0, text: KeyText()) }
        let request = try client.build(ChatRequest(messages: [.text("x", role: .user)], system: "s", tools: definitions, maxTokens: 5),
                                       key: ClaudeKey(apiKey: "k"), stream: false)
        let body = String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
        XCTAssertEqual(body.components(separatedBy: "cache_control").count - 1, 2)
        XCTAssertEqual(request.timeoutInterval, 30)
    }

    func testToolInputStringifiesNumbersAndBooleans() {
        let input = ToolInput(json: Data(#"{"a":12,"b":2.5,"c":true,"d":"x ","e":null,"f":[1]}"#.utf8))
        XCTAssertEqual(input.integer("a"), 12)
        XCTAssertEqual(input.number("b"), 2.5)
        XCTAssertTrue(input.flag("c"))
        XCTAssertEqual(input.text("d"), "x")
        XCTAssertNil(input.optionalText("e"))
        XCTAssertNil(input.optionalText("f"))
    }

    func testSystemPromptKeepsNoInventedNumbersRuleAndMarker() throws {
        let tools = try makeTools(database: SQLiteStore.inMemory())
        let prompt = Grounding.systemPrompt(Grounding.Input(tools: tools, toolsEnabled: true, hasDriveFocus: true), text: KeyText())
        XCTAssertTrue(prompt.contains("assistant.tool.schaetze_projekt.prompt"))
        XCTAssertTrue(prompt.contains("assistant.tool.schaetze_projekt.prompt.catalog"))
        XCTAssertTrue(prompt.contains("assistant.tool.list_drive_folder.prompt"))
        XCTAssertFalse(prompt.contains("assistant.tool.list_zeiten.prompt"))
        XCTAssertTrue(prompt.contains(Grounding.volatileMarker))
        let blocks = ClaudeClient.systemBlocks(from: prompt)
        XCTAssertEqual(blocks.count, 2)
        XCTAssertNotNil(blocks[0].cacheControl)
        XCTAssertNil(blocks[1].cacheControl)
        let json = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/assistant.localizable.json"))
        let text = String(decoding: json, as: UTF8.self)
        XCTAssertTrue(text.contains("erfinde NIEMALS einen Preis"))
        XCTAssertTrue(text.contains("Nenne nie einen Endkunden- oder Verkaufspreis"))
    }

    func testCalculationToolPassesOverridesDeclaresWriteAndCards() async throws {
        let estimation = FakeEstimation()
        let tool = CalculationTool(estimation: estimation)
        let result = await tool.run(ToolInput(json: Data(#"{"beschreibung":"K\#u{FC}che","korpusanzahl":12,"entfernung_km":7.5,"fronten":"lack"}"#.utf8)),
                                    scope: ToolScope(projectID: "P1"))
        XCTAssertFalse(result.isError)
        XCTAssertEqual(estimation.overrides.value.first, EstimateOverride(carcassCount: 12, frontExecution: "lack", distanceKm: 7.5))
        XCTAssertEqual(tool.access, .write)
        XCTAssertEqual(result.cards.count, 2)
        let text = result.render(KeyText())
        XCTAssertTrue(text.contains("assistant.estimate.header|1.000|2.000|3.000|50|3"), text)
        XCTAssertTrue(text.contains("calc.exclude.worktop.label"))
        let missing = await tool.run(ToolInput(), scope: ToolScope())
        XCTAssertTrue(missing.isError)
    }

    func testMergedContactAndTaskToolsKeepBothModes() async throws {
        let contacts = ContactSearchEngine(contacts: [
            Contact(id: "rec1", name: "Anna Muster", organization: "Firma", email: "a@x.de", category: "Lieferant"),
            Contact(id: "rec2", name: "Bernd", category: "Handwerker"),
        ])
        let lookup = SearchContactsTool(directory: contacts)
        let search = await lookup.run(ToolInput(["query": "anna"]), scope: ToolScope()).render(KeyText())
        XCTAssertTrue(search.contains("ID: rec1"))
        let list = await lookup.run(ToolInput(["kategorie": "hand"]), scope: ToolScope()).render(KeyText())
        XCTAssertTrue(list.contains("Bernd"))
        XCTAssertFalse(list.contains("Anna"))

        let tasks = ListTasksTool(board: Stub(), lists: [ProjectTaskList(projectNumber: "1", title: "Haus", listID: "L1")])
        let focused = await tasks.run(ToolInput(), scope: ToolScope(taskListID: "L1")).render(KeyText())
        XCTAssertTrue(focused.contains("Plan [open]"))
        let overview = await tasks.run(ToolInput(["alle": "true"]), scope: ToolScope()).render(KeyText())
        XCTAssertTrue(overview.contains("assistant.tasks.overviewHeader|1|1"), overview)
        let none = await tasks.run(ToolInput(), scope: ToolScope()).render(KeyText())
        XCTAssertEqual(none, "assistant.tasks.noList")
    }

    func testScopeCannotBeSetByTheModel() async throws {
        let database = try SQLiteStore.inMemory()
        let notes = NoteStore(database: database, userID: "u")
        let tool = CreateNoteTool(notes: notes)
        _ = await tool.run(ToolInput(["text": "hello world", "_projektID": "evil"]), scope: ToolScope())
        let stored = try await notes.all()
        XCTAssertNil(stored.first?.projectID)
    }

    func testStoresRoundTripAndPrivacyIsStoredAsCategories() async throws {
        let database = try SQLiteStore.inMemory()
        let todos = TodoStore(database: database, userID: "u")
        let first = try await todos.create("Zuerst", dueDate: Date(timeIntervalSince1970: 2_000_000_000), projectID: "p", alarmActive: true)
        _ = try await todos.create("Sp\u{E4}ter", dueDate: nil)
        let all = try await todos.all()
        XCTAssertEqual(all.first?.id, first.id)
        let done = try await todos.setDone(matching: String(first.id.prefix(6)))
        XCTAssertEqual(done?.done, true)
        let scoped = try await todos.scoped(to: "other")
        XCTAssertEqual(scoped.count, 1)
        let store = PrivacyStore(database: database)
        XCTAssertEqual(try store.load(), PrivacySettings())
        try store.save(PrivacySettings(disabled: [.mail, .time]))
        XCTAssertEqual(try store.load().disabled, [.mail, .time])
        let journal = JournalStore(database: database)
        try await journal.append(JournalEntry(kind: .missingInfo, text: "t"))
        let entries = try await journal.entries()
        XCTAssertEqual(entries.first?.kind, .missingInfo)
    }

    func testArtifactStoreWritesAtomicallyWithSafeName() throws {
        let artifact = ArtifactStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let url = try artifact.write(Data("x".utf8), name: "../a..b/c.txt")
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertFalse(url.lastPathComponent.contains(".."))
        XCTAssertEqual(try Data(contentsOf: url), Data("x".utf8))
    }

    func testArtifactStoreNameSanitising() {
        let name = ArtifactStore.safeName("../a..b/c.txt", at: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(name.contains("/"))
        XCTAssertFalse(name.contains(".."))
        XCTAssertTrue(ArtifactStore.safeName("~~~", at: Date()).hasSuffix("_file"))
    }

    func testProposeFileWritesThroughArtifactStoreAtomically() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let tool = ProposeFileTool(artifacts: ArtifactStore(root: root), projects: ProjectSearchEngine(entries: []))
        let result = await tool.run(ToolInput(["dateiname": "Liste", "format": "csv", "inhalt": "a;b\n1;2"]), scope: ToolScope())
        XCTAssertFalse(result.isError)
        guard case .fileDraft(let draft)? = result.cards.first, let path = draft.savedPath else { return XCTFail("no card") }
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "a;b\n1;2")
        XCTAssertEqual(draft.fullName, "Liste.csv")
        let pdf = await tool.run(ToolInput(["dateiname": "Liste", "format": "pdf", "inhalt": "a"]), scope: ToolScope())
        XCTAssertTrue(pdf.isError)
    }

    func testAlarmDecisionRules() {
        let now = Date(timeIntervalSince1970: 1000)
        let due = Todo(title: "t", dueDate: Date(timeIntervalSince1970: 2000), alarmActive: true)
        XCTAssertTrue(TodoAlarmClient.shouldAlarm(due, enabled: true, now: now))
        XCTAssertFalse(TodoAlarmClient.shouldAlarm(due, enabled: false, now: now))
        var done = due
        done.done = true
        XCTAssertFalse(TodoAlarmClient.shouldAlarm(done, enabled: true, now: now))
        XCTAssertFalse(TodoAlarmClient.shouldAlarm(due, enabled: true, now: Date(timeIntervalSince1970: 3000)))
        XCTAssertFalse(TodoAlarmClient.identifier("x").lowercased().contains("m" + "yk"))
    }

    func testMemoryPlanDistillsOnlyBeyondTailAndBatch() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        func messages(_ count: Int) -> [Message] {
            (0..<count).map { index in
                Message(role: index.isMultiple(of: 2) ? .user : .assistant, blocks: [.text("m\(index)")], createdAt: base.addingTimeInterval(Double(index)))
            }
        }
        XCTAssertEqual(MemoryEngine.plan(windowed: messages(8), existing: nil), .passthrough)
        XCTAssertEqual(MemoryEngine.plan(windowed: messages(15), existing: nil), .passthrough)
        guard case .distill(let tail, let batch, _, _) = MemoryEngine.plan(windowed: messages(22), existing: nil) else { return XCTFail() }
        XCTAssertEqual(batch.count, 14)
        XCTAssertEqual(tail.first?.role, .user)
        let window = MemoryEngine.window(messages(3), now: base.addingTimeInterval(29 * 24 * 3600))
        XCTAssertTrue(window.isEmpty)
    }

    func testEngineRunsToolWithAlarmAuditAndPersistsTurn() async throws {
        let database = try SQLiteStore.inMemory()
        let alarm = FakeAlarm()
        let tools = try makeTools(database: database, alarm: alarm)
        let call = ToolUse(id: "u1", name: "create_task", inputJSON: Data(#"{"titel":"Anruf","faellig":"2031-01-02"}"#.utf8))
        let provider = ScriptedProvider([
            Reply(text: "", toolUses: [call], stopReason: "tool_use"),
            Reply(text: "Erledigt", toolUses: [], stopReason: "end_turn"),
        ])
        let (chat, log, engine) = await MainActor.run {
            let chat = ChatStore(database: database, userID: "u")
            let log = IntegrationLogStore(database: database)
            let engine = ConversationEngine(chat: chat, provider: provider, registry: ToolRegistry(tools: tools), text: KeyText(), log: log)
            return (chat, log, engine)
        }
        await engine.send("Bitte Aufgabe", scope: .home, context: ConversationContext(focusedProjectID: "2408-01"))
        let outcome: (Message?, [String], String?) = await MainActor.run {
            (chat.messages(for: .home).last, log.entries.map(\.integrationID), engine.lastRoutedModel)
        }
        XCTAssertEqual(outcome.0?.text, "Erledigt")
        XCTAssertEqual(outcome.0?.status, .complete)
        XCTAssertEqual(outcome.1, ["ASSISTANT_TASKS"])
        XCTAssertEqual(outcome.2, ModelRouter.sonnet)
        XCTAssertEqual(alarm.scheduled.value.count, 1)
        XCTAssertEqual(alarm.scheduled.value.first?.alarmActive, true)
        XCTAssertEqual(alarm.scheduled.value.first?.projectID, "2408-01")
        let offered = provider.requests.first?.tools.map(\.name) ?? []
        XCTAssertTrue(offered.contains("create_task"))
    }

    func testEngineEnforcesPrivacyOnOfferAndOnRun() async throws {
        let database = try SQLiteStore.inMemory()
        let alarm = FakeAlarm()
        let tools = try makeTools(database: database, alarm: alarm)
        let call = ToolUse(id: "u1", name: "create_task", inputJSON: Data(#"{"titel":"x"}"#.utf8))
        let provider = ScriptedProvider([
            Reply(text: "", toolUses: [call], stopReason: "tool_use"),
            Reply(text: "ok", toolUses: [], stopReason: "end_turn"),
        ])
        let chat = await MainActor.run { ChatStore(database: database, userID: "u") }
        let engine = await MainActor.run { ConversationEngine(chat: chat, provider: provider, registry: ToolRegistry(tools: tools), text: KeyText()) }
        let privacy = PrivacySnapshot(settings: PrivacySettings(disabled: [.tasks, .time, .drive]))
        await engine.send("hallo", scope: .home, privacy: privacy)
        let offered = Set(provider.requests.first?.tools.map(\.name) ?? [])
        XCTAssertFalse(offered.contains("create_task"))
        XCTAssertFalse(offered.contains("list_zeiten"))
        XCTAssertFalse(offered.contains("erzeuge_datei"))
        XCTAssertTrue(alarm.scheduled.value.isEmpty)
        let todos = try await TodoStore(database: database, userID: "u").all()
        XCTAssertTrue(todos.isEmpty)
        let denied = await ToolRegistry(tools: tools).run(name: "create_task", inputJSON: Data(), scope: ToolScope(), allowed: [])
        XCTAssertTrue(denied.isError)
    }

    func testEngineAssistantOffMakesNoProviderCall() async throws {
        let database = try SQLiteStore.inMemory()
        let provider = ScriptedProvider([])
        let chat = await MainActor.run { ChatStore(database: database, userID: "u") }
        let engine = await MainActor.run { ConversationEngine(chat: chat, provider: provider, registry: ToolRegistry(tools: []), text: KeyText()) }
        await engine.send("hallo", scope: .home, privacy: PrivacySnapshot(choices: PrivacyChoices(assistantOff: true)))
        XCTAssertEqual(provider.count, 0)
        let last = await MainActor.run { chat.messages(for: .home).last?.text }
        XCTAssertEqual(last, "assistant.engine.assistantOff")
    }

    func testEngineWithholdsUngroundedDraftAndShowsGroundedOne() async throws {
        let database = try SQLiteStore.inMemory()
        let tools: [any ToolPort] = [ProposeMailDraftTool()]
        func run(address: String) async -> [ContentBlock] {
            let args = #"{"betreff":"S","text":"T","an":"\#(address)"}"#
            let provider = ScriptedProvider([
                Reply(text: "", toolUses: [ToolUse(id: "1", name: "create_draft", inputJSON: Data(args.utf8))], stopReason: nil),
                Reply(text: "fertig", toolUses: [], stopReason: nil),
            ])
            let chat = await MainActor.run { ChatStore(database: database, userID: UUID().uuidString) }
            let engine = await MainActor.run { ConversationEngine(chat: chat, provider: provider, registry: ToolRegistry(tools: tools), text: KeyText()) }
            await engine.send("schreib an bekannt@firma.de", scope: .home)
            return await MainActor.run { chat.messages(for: .home).last?.blocks ?? [] }
        }
        let grounded = await run(address: "bekannt@firma.de")
        XCTAssertTrue(grounded.contains { if case .mailDraft = $0 { true } else { false } })
        let ungrounded = await run(address: "erfunden@nirgends.de")
        XCTAssertFalse(ungrounded.contains { if case .mailDraft = $0 { true } else { false } })
        XCTAssertTrue(ungrounded.contains { if case .toolActivity(let label, true) = $0 { label.hasPrefix("assistant.gate.warn") } else { false } })
    }

    func testContentBlockPersistsEveryCardKind() throws {
        let blocks: [ContentBlock] = [
            .text("a"), .toolUse(id: "1", name: "n", inputJSON: Data("{}".utf8)), .calendarLink(url: "u"),
            .mailDraft(MailDraft(subject: "s", body: "b")), .contactDraft(ContactDraft(givenName: "g")),
            .cartDraft(CartDraft(label: "l", articleNumber: "1", source: .stock)),
            .estimate(estimateID: "e", projectID: "p", minNet: 1, maxNet: 2, midNet: 1.5, confidence: 0.4, evidenceCount: 1),
            .driveFiles([DriveLink(id: "d", name: "n", mimeType: "m", subtitle: .make("k", "a"))]), .unreadable,
        ]
        let data = try JSONEncoder().encode(blocks)
        XCTAssertEqual(try JSONDecoder().decode([ContentBlock].self, from: data), blocks)
    }

    func testThreadEngineMapsTurnStatesAndBlocks() {
        let ref = AttachmentRef(fileName: "plan.pdf", mimeType: "application/pdf", byteCount: 1, relativePath: "x", sha256: "s")
        let question = Message(role: .user, blocks: [.text("Frage"), .document(ref)])
        let answer = Message(role: .assistant, blocks: [
            .toolActivity(label: "Mail gelesen", isError: false), .toolUse(id: "1", name: "n", inputJSON: Data()),
            .mailDraft(MailDraft(to: "vogt@example.com", subject: "Aufmass", body: "b")), .text("Fertig"), .unreadable,
        ])
        let streaming = Message(role: .assistant, blocks: [.text("")], status: .streaming)
        let failed = Message(role: .assistant, blocks: [.text("kaputt")], status: .failed("kaputt"))
        let turns = ThreadEngine.turns([question, answer, streaming, failed])
        XCTAssertEqual(turns.map(\.kind), [.user, .assistant, .streaming, .failed])
        XCTAssertEqual(turns[0].blocks, [.file("plan.pdf"), .text("Frage")])
        XCTAssertEqual(turns[1].blocks, [
            .activity(label: "Mail gelesen", failed: false),
            .draft(DraftSummary(kind: .mail, title: "Aufmass", line: "vogt@example.com")), .text("Fertig"), .unreadable,
        ])
        XCTAssertTrue(turns[2].blocks.isEmpty)
        XCTAssertTrue(turns[3].blocks.isEmpty)
        XCTAssertEqual(ThreadEngine.attachments(question), [ref])
        XCTAssertEqual(ThreadEngine.blocks(.estimate(estimateID: "e", projectID: "p", minNet: 1, maxNet: 2, midNet: 1.5,
                                                     confidence: 0.4, evidenceCount: 1)), [.estimate(minNet: 1, maxNet: 2)])
        XCTAssertEqual(ThreadEngine.blocks(.driveFiles([DriveLink(id: "d", name: "a.pdf", mimeType: "m")])), [.file("a.pdf")])
    }

    func testChatStoreRemoveKeepsOrderAfterReload() async throws {
        let database = try SQLiteStore.inMemory()
        let order: [String] = try await MainActor.run {
            let chat = ChatStore(database: database, userID: "u")
            let messages = ["a", "b", "c", "d"].map { Message.text($0, role: .user) }
            for message in messages { try chat.append(message, to: .home) }
            try chat.remove([messages[1].id], from: .home)
            try chat.append(Message.text("e", role: .user), to: .home)
            let reloaded = ChatStore(database: database, userID: "u")
            try reloaded.loadIfNeeded(.home)
            return reloaded.messages(for: .home).map(\.text)
        }
        XCTAssertEqual(order, ["a", "c", "d", "e"])
    }

    func testChatStateRetriesFailedTurnAndClearsWithUndo() async throws {
        let database = try SQLiteStore.inMemory()
        let state = await MainActor.run {
            let chat = ChatStore(database: database, userID: "u")
            let engine = ConversationEngine(chat: chat, provider: FlakyProvider(failures: 1), registry: ToolRegistry(tools: []), text: KeyText())
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            return ChatState(chat: chat, engine: engine, attachments: AttachmentStore(root: root), privacy: PrivacyStore(database: database))
        }
        await MainActor.run { state.draft = "Frage" }
        let firstDone = await state.send(choices: PrivacyChoices())
        XCTAssertFalse(firstDone)
        let failedKinds = await MainActor.run { state.turns.map(\.kind) }
        XCTAssertEqual(failedKinds, [.user, .failed])
        let retried = await state.retry(choices: PrivacyChoices())
        XCTAssertTrue(retried)
        let after: ([ChatTurn.Kind], [TurnBlock]) = await MainActor.run { (state.turns.map(\.kind), state.turns.last?.blocks ?? []) }
        XCTAssertEqual(after.0, [.user, .assistant])
        XCTAssertEqual(after.1, [.text("Antwort")])
        let cleared: (Int, ChatState.Note?) = await MainActor.run {
            state.clear()
            return (state.turns.count, state.note)
        }
        XCTAssertEqual(cleared.0, 0)
        XCTAssertEqual(cleared.1, .cleared)
        let restored = await MainActor.run {
            state.undo()
            return (state.turns.map(\.kind), state.note)
        }
        XCTAssertEqual(restored.0, [.user, .assistant])
        XCTAssertNil(restored.1)
    }

    @MainActor
    func testAttachRejectsUnsupportedAndOversizedFilesFromDisk() async throws {
        let database = try SQLiteStore.inMemory()
        let folder = scratch()
        let store = AttachmentStore(root: scratch())
        let big = Attachment(filename: "lang.txt", mimeType: "text/plain",
                             data: Data(String(repeating: "a", count: AttachmentStore.textCharacterLimit + 1).utf8))
        XCTAssertThrowsError(try store.save(big)) { error in
            XCTAssertEqual(error as? AttachmentFailure, .tooLarge("lang.txt"))
        }
        let chat = ChatStore(database: database, userID: "u")
        let engine = ConversationEngine(chat: chat, provider: ScriptedProvider([]), registry: ToolRegistry(tools: []), text: KeyText())
        let state = ChatState(chat: chat, engine: engine, attachments: store, privacy: PrivacyStore(database: database))
        await state.attach([try file("x.bin", "1", in: folder)])
        XCTAssertEqual(state.note, .rejected(.unsupported("x.bin")))
        await state.attach([try file("lang.txt", String(repeating: "a", count: AttachmentStore.textCharacterLimit + 1), in: folder)])
        XCTAssertEqual(state.note, .rejected(.tooLarge("lang.txt")))
        await state.attach([folder.appendingPathComponent("fehlt.txt")])
        XCTAssertEqual(state.note, .rejected(.unreadable("fehlt.txt")))
        XCTAssertTrue(state.pending.isEmpty)
        XCTAssertFalse(state.canSend)
        XCTAssertEqual(stored(store), [])
    }

    @MainActor
    func testChatFilesOffSendsNoFileDataAndDropsThePendingFile() async throws {
        let database = try SQLiteStore.inMemory()
        let store = AttachmentStore(root: scratch())
        let sent = Box<[URLRequest]>([])
        let client = ClaudeClient(keys: FakeKeys(), http: FakeHttp(sent: sent, streamLines: [
            #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"ok"}}"#,
        ]), attachments: store)
        let chat = ChatStore(database: database, userID: "u")
        let engine = ConversationEngine(chat: chat, provider: client, registry: ToolRegistry(tools: []), text: KeyText())
        let state = ChatState(chat: chat, engine: engine, attachments: CopyAttachments(store: store), privacy: PrivacyStore(database: database))
        await state.attach([try file("plan.txt", "GEHEIM", in: scratch())])
        XCTAssertEqual(state.pending.map(\.file.fileName), ["plan.txt"])
        state.draft = "Lies das"
        let answered = await state.send(choices: PrivacyChoices(chatFiles: false))
        XCTAssertTrue(answered)
        XCTAssertTrue(state.pending.isEmpty)
        XCTAssertEqual(state.turns.first?.blocks, [.text("Lies das")])
        XCTAssertEqual(sent.value.count, 1)
        XCTAssertFalse(body(try XCTUnwrap(sent.value.first)).contains("GEHEIM"))
        XCTAssertEqual(stored(store), [])

        let ref = try await CopyAttachments(store: store).save(try file("plan.txt", "GEHEIM", in: scratch()))
        let question = Message(role: .user, blocks: [.text("Nochmal"), .document(ref)])
        let retried = try client.build(ChatRequest(messages: [question], system: "s", maxTokens: 5, sharesFiles: false),
                                       key: ClaudeKey(apiKey: "k"), stream: true)
        XCTAssertFalse(body(retried).contains("GEHEIM"))
        XCTAssertTrue(body(retried).contains("[attachment: plan.txt]"))
        XCTAssertEqual(retried.timeoutInterval, ClaudeClient.plainTimeout)
    }

    func testOnlyTheCurrentQuestionCarriesFileData() async throws {
        let store = AttachmentStore(root: scratch())
        let client = ClaudeClient(keys: FakeKeys(), http: FakeHttp(sent: Box([]), streamLines: []), attachments: store)
        let ref = try await CopyAttachments(store: store).save(try file("plan.txt", "GEHEIM", in: scratch()))
        let question = Message(role: .user, blocks: [.text("Lies"), .document(ref)])
        func request(_ messages: [Message]) throws -> URLRequest {
            try client.build(ChatRequest(messages: messages, system: "s", maxTokens: 5, sharesFiles: true),
                             key: ClaudeKey(apiKey: "k"), stream: false)
        }
        let current = try request([question])
        XCTAssertTrue(body(current).contains("GEHEIM"))
        XCTAssertEqual(current.timeoutInterval, ClaudeClient.attachmentTimeout)
        let toolRound = try request([
            question,
            Message(role: .assistant, blocks: [.toolUse(id: "1", name: "n", inputJSON: Data("{}".utf8))]),
            Message(role: .user, blocks: [.toolResult(toolUseID: "1", summary: "ok", isError: false)]),
        ])
        XCTAssertTrue(body(toolRound).contains("GEHEIM"))
        let later = try request([question, .text("Gelesen", role: .assistant), .text("Und jetzt?", role: .user)])
        XCTAssertFalse(body(later).contains("GEHEIM"))
        XCTAssertTrue(body(later).contains("[attachment: plan.txt]"))
        XCTAssertEqual(later.timeoutInterval, ClaudeClient.plainTimeout)
    }

    @MainActor
    func testClearedFilesLeaveTheDiskOnlyWhenTheUndoWindowCloses() async throws {
        let database = try SQLiteStore.inMemory()
        let folder = scratch()
        let store = AttachmentStore(root: scratch())
        let chat = ChatStore(database: database, userID: "u")
        let engine = ConversationEngine(chat: chat, provider: FlakyProvider(failures: 0), registry: ToolRegistry(tools: []), text: KeyText())
        let state = ChatState(chat: chat, engine: engine, attachments: CopyAttachments(store: store), privacy: PrivacyStore(database: database))
        await state.attach([try file("a.txt", "eins", in: folder)])
        state.draft = "Lies"
        let answered = await state.send(choices: PrivacyChoices())
        XCTAssertTrue(answered)
        XCTAssertEqual(stored(store).count, 1)
        await state.attach([try file("b.txt", "zwei", in: folder)])
        XCTAssertEqual(stored(store).count, 2)
        state.clear()
        XCTAssertTrue(state.pending.isEmpty)
        XCTAssertEqual(stored(store).count, 2)
        state.undo()
        XCTAssertEqual(state.turns.map(\.kind), [.user, .assistant])
        XCTAssertEqual(state.turns.first?.blocks, [.file("a.txt"), .text("Lies")])
        XCTAssertEqual(stored(store).count, 1)
        state.clear()
        state.dismiss()
        XCTAssertTrue(state.turns.isEmpty)
        XCTAssertEqual(stored(store), [])
    }

    @MainActor
    func testUndoAfterANewMessageKeepsTheNewThread() async throws {
        let database = try SQLiteStore.inMemory()
        let chat = ChatStore(database: database, userID: "u")
        let engine = ConversationEngine(chat: chat, provider: FlakyProvider(failures: 0), registry: ToolRegistry(tools: []), text: KeyText())
        let state = ChatState(chat: chat, engine: engine, attachments: AttachmentStore(root: scratch()), privacy: PrivacyStore(database: database))
        state.draft = "alt"
        _ = await state.send(choices: PrivacyChoices())
        state.clear()
        XCTAssertEqual(state.note, .cleared)
        state.draft = "neu"
        _ = await state.send(choices: PrivacyChoices())
        XCTAssertNil(state.note)
        state.undo()
        let texts = chat.messages(for: .home).map(\.text)
        XCTAssertEqual(texts, ["neu", "Antwort"])
        let reloaded = ChatStore(database: database, userID: "u")
        try reloaded.loadIfNeeded(.home)
        XCTAssertEqual(reloaded.messages(for: .home).map(\.text), ["neu", "Antwort"])
    }

    @MainActor
    func testARejectedFileEndsTheUndoWindow() async throws {
        let database = try SQLiteStore.inMemory()
        let chat = ChatStore(database: database, userID: "u")
        let engine = ConversationEngine(chat: chat, provider: FlakyProvider(failures: 0), registry: ToolRegistry(tools: []), text: KeyText())
        let state = ChatState(chat: chat, engine: engine, attachments: AttachmentStore(root: scratch()), privacy: PrivacyStore(database: database))
        state.draft = "alt"
        _ = await state.send(choices: PrivacyChoices())
        state.clear()
        await state.attach([try file("x.bin", "1", in: scratch())])
        XCTAssertEqual(state.note, .rejected(.unsupported("x.bin")))
        state.undo()
        XCTAssertTrue(state.turns.isEmpty)
    }

    @MainActor
    func testClearDuringAStreamLeavesTheRestoredTurnSettled() async throws {
        let database = try SQLiteStore.inMemory()
        let chat = ChatStore(database: database, userID: "u")
        let engine = ConversationEngine(chat: chat, provider: HangingProvider(), registry: ToolRegistry(tools: []), text: KeyText())
        let state = ChatState(chat: chat, engine: engine, attachments: AttachmentStore(root: scratch()), privacy: PrivacyStore(database: database))
        state.draft = "Frage"
        let turn = Task { await state.send(choices: PrivacyChoices()) }
        let streaming = await until { state.turns.last?.kind == .streaming }
        XCTAssertTrue(streaming)
        state.clear()
        state.undo()
        let answered = await turn.value
        XCTAssertFalse(answered)
        XCTAssertEqual(state.turns.map(\.kind), [.user, .failed])
        let reloaded = ChatStore(database: database, userID: "u")
        try reloaded.loadIfNeeded(.home)
        XCTAssertEqual(reloaded.messages(for: .home).map(\.status), [.complete, .failed("")])
    }

    @MainActor
    func testStopEndsARunningTurnAsCancelled() async throws {
        let database = try SQLiteStore.inMemory()
        let chat = ChatStore(database: database, userID: "u")
        let engine = ConversationEngine(chat: chat, provider: HangingProvider(), registry: ToolRegistry(tools: []), text: KeyText())
        let state = ChatState(chat: chat, engine: engine, attachments: AttachmentStore(root: scratch()), privacy: PrivacyStore(database: database))
        state.draft = "Frage"
        let turn = Task { await state.send(choices: PrivacyChoices()) }
        let streaming = await until { state.turns.last?.kind == .streaming }
        XCTAssertTrue(streaming)
        state.stop()
        _ = await turn.value
        XCTAssertEqual(chat.messages(for: .home).last?.text, "assistant.engine.cancelled")
        XCTAssertFalse(state.busy)
    }

    func testPrivacyCategoryKeysExistInTheCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("Resources/Localizable.xcstrings"))
        let strings = try XCTUnwrap((try JSONSerialization.jsonObject(with: data) as? [String: Any])?["strings"] as? [String: Any])
        for category in PrivacyCategory.allCases {
            XCTAssertNotNil(strings[category.key], category.key)
            XCTAssertTrue(category.key.hasSuffix("." + category.rawValue), category.key)
        }
    }

    func testEngineLabelsADisabledCategoryAsOff() async throws {
        let database = try SQLiteStore.inMemory()
        let tools = try makeTools(database: database)
        let call = ToolUse(id: "u1", name: "create_task", inputJSON: Data(#"{"titel":"x"}"#.utf8))
        let provider = ScriptedProvider([
            Reply(text: "", toolUses: [call], stopReason: "tool_use"),
            Reply(text: "ok", toolUses: [], stopReason: "end_turn"),
        ])
        let chat = await MainActor.run { ChatStore(database: database, userID: "u") }
        let engine = await MainActor.run { ConversationEngine(chat: chat, provider: provider, registry: ToolRegistry(tools: tools), text: KeyText()) }
        await engine.send("hallo", scope: .home, privacy: PrivacySnapshot(settings: PrivacySettings(disabled: [.tasks])))
        let blocks = await MainActor.run { chat.messages(for: .home).last?.blocks ?? [] }
        XCTAssertTrue(blocks.contains(.toolActivity(label: "assistant.activity.categoryOff|settings.privacy.category.tasks", isError: true)))
    }

    func testEngineGroundsADraftOnASuccessfulToolResult() async throws {
        let database = try SQLiteStore.inMemory()
        let tools: [any ToolPort] = [SearchMailTool(mail: Stub()), ProposeMailDraftTool()]
        let search = ToolUse(id: "1", name: "search_gmail", inputJSON: Data(#"{"query":"Angebot"}"#.utf8))
        let draft = ToolUse(id: "2", name: "create_draft", inputJSON: Data(#"{"betreff":"S","text":"T","an":"a@b.de"}"#.utf8))
        let provider = ScriptedProvider([
            Reply(text: "", toolUses: [search], stopReason: nil),
            Reply(text: "", toolUses: [draft], stopReason: nil),
            Reply(text: "fertig", toolUses: [], stopReason: nil),
        ])
        let chat = await MainActor.run { ChatStore(database: database, userID: "u") }
        let engine = await MainActor.run { ConversationEngine(chat: chat, provider: provider, registry: ToolRegistry(tools: tools), text: KeyText()) }
        await engine.send("schreib dem Absender", scope: .home)
        let blocks = await MainActor.run { chat.messages(for: .home).last?.blocks ?? [] }
        XCTAssertTrue(blocks.contains { if case .mailDraft = $0 { true } else { false } })
        XCTAssertFalse(blocks.contains { if case .toolActivity(let label, true) = $0 { label.hasPrefix("assistant.gate.warn") } else { false } })
    }

    func testEngineStopsAtTheToolRoundLimit() async throws {
        let database = try SQLiteStore.inMemory()
        let tools: [any ToolPort] = [SearchMailTool(mail: Stub())]
        let limit = await MainActor.run { ConversationEngine.maxToolRounds }
        let replies = (0...limit).map { round in
            Reply(text: "", toolUses: [ToolUse(id: "u\(round)", name: "search_gmail", inputJSON: Data(#"{"query":"q\#(round)"}"#.utf8))],
                  stopReason: "tool_use")
        }
        let provider = ScriptedProvider(replies)
        let chat = await MainActor.run { ChatStore(database: database, userID: "u") }
        let engine = await MainActor.run { ConversationEngine(chat: chat, provider: provider, registry: ToolRegistry(tools: tools), text: KeyText()) }
        await engine.send("hallo", scope: .home)
        XCTAssertEqual(provider.count, limit)
        let last = await MainActor.run { chat.messages(for: .home).last?.text }
        XCTAssertEqual(last, "assistant.engine.tooManySteps")
    }

    @MainActor
    func testStreamingTextReplacesTheTextBlockAndKeepsActivities() throws {
        let chat = ChatStore(database: try SQLiteStore.inMemory(), userID: "u")
        let placeholder = Message(role: .assistant, blocks: [.text("")], status: .streaming)
        try chat.append(placeholder, to: .home)
        chat.updateStreamingActivities(id: placeholder.id, activities: [.toolActivity(label: "a", isError: false)], in: .home)
        chat.updateStreamingText(id: placeholder.id, text: "x", in: .home)
        XCTAssertEqual(chat.messages(for: .home).last?.blocks, [.toolActivity(label: "a", isError: false), .text("x")])
    }

    func testCacheSplitsTheSystemPromptAtTheVolatileMarker() {
        let split = ClaudeClient.systemBlocks(from: "a" + Grounding.volatileMarker + "b")
        XCTAssertEqual(split.map(\.text), ["a", "b"])
        XCTAssertEqual(split.map { $0.cacheControl != nil }, [true, false])
    }

    func testSystemBlocksStayWholeWithoutASecondPart() {
        let whole = ClaudeClient.systemBlocks(from: "ab")
        XCTAssertEqual(whole.map(\.text), ["ab"])
        XCTAssertNotNil(whole[0].cacheControl)
        let trailing = ClaudeClient.systemBlocks(from: "a" + Grounding.volatileMarker)
        XCTAssertEqual(trailing.count, 1)
    }

    func testCustomerRowCountsProjectsInSingularAndPlural() {
        let engine = CustomerSearchEngine(customers: [], projectCounts: ["K1": 1, "K2": 3])
        let one = engine.describe(CustomerEntry(number: "K1", name: "Anna")).render(KeyText())
        let many = engine.describe(CustomerEntry(number: "K2", name: "Bernd")).render(KeyText())
        let none = engine.describe(CustomerEntry(number: "K3", name: "Cora")).render(KeyText())
        XCTAssertTrue(one.contains("assistant.customers.projectOne|1"), one)
        XCTAssertTrue(many.contains("assistant.customers.projectMany|3"), many)
        XCTAssertEqual(none, "assistant.customers.row|Cora|K3")
    }

    func testContactListOmitsIDsThatTheSearchShows() async {
        let tool = SearchContactsTool(directory: ContactSearchEngine(contacts: [Contact(id: "rec1", name: "Anna Muster", project: "P1")]))
        let list = await tool.run(ToolInput(), scope: ToolScope()).render(KeyText())
        XCTAssertTrue(list.contains("Anna Muster"), list)
        XCTAssertFalse(list.contains("ID:"), list)
        XCTAssertFalse(list.contains("assistant.contacts.project"), list)
    }

    func testStockRowsShowOnlyNonEmptyArticleNumbers() async {
        let stock = FixedStock(state: .items([
            StockItem(id: "1", label: "Griff", articleNumber: "A-1"), StockItem(id: "2", label: "Leiste", articleNumber: ""),
        ]))
        let text = await ListStockTool(stock: stock).run(ToolInput(), scope: ToolScope()).render(KeyText())
        XCTAssertTrue(text.contains("assistant.catalog.article|A-1"), text)
        XCTAssertEqual(text.components(separatedBy: "assistant.catalog.article").count - 1, 1, text)
    }

    func testOffersListIncomingSection() {
        let offer = OfferListing.Offer(file: DriveEntry(id: "i1", name: "Eingang.pdf"), typeLabel: "PDF")
        let result = FindOffersTool.result(OfferListing(incoming: [offer]), label: nil)
        let text = result.render(KeyText())
        XCTAssertTrue(text.contains("assistant.offers.incomingHeader|1"), text)
        XCTAssertTrue(text.contains("Eingang.pdf [PDF]"), text)
        XCTAssertFalse(text.contains("assistant.offers.outgoingHeader"), text)
        XCTAssertEqual(result.cards.count, 1)
    }

    func testTaskOverviewNamesNoMoreListsWhenAllFit() async {
        let tasks = ListTasksTool(board: Stub(), lists: [ProjectTaskList(projectNumber: "1", title: "Haus", listID: "L1")])
        let overview = await tasks.run(ToolInput(["alle": "true"]), scope: ToolScope()).render(KeyText())
        XCTAssertFalse(overview.contains("assistant.tasks.moreLists"), overview)
    }

    func testCreateNoteSchemaRequiresText() throws {
        let tool = CreateNoteTool(notes: NoteStore(database: try SQLiteStore.inMemory(), userID: "u"))
        XCTAssertEqual(ToolDefinition(tool: tool, text: KeyText()).inputSchema.required, ["text"])
    }

    func testEventLinkDatesNeedEightDigits() {
        XCTAssertEqual(SuggestEventLinkTool.dates(from: "2031-01-02"), "20310102/20310102")
        XCTAssertEqual(SuggestEventLinkTool.dates(from: "2031-01-02 10:30"), "20310102T103000/20310102T103000")
        XCTAssertNil(SuggestEventLinkTool.dates(from: "2031-01-0"))
    }

    func testListingClipAddsMoreOnlyBeyondTheRows() {
        let rows: [Phrase] = [.raw("a"), .raw("b")]
        XCTAssertEqual(ListingEngine.clip(rows, total: 2).map { $0.render(KeyText()) }, ["a", "b"])
        XCTAssertEqual(ListingEngine.clip(rows, total: 5).map { $0.render(KeyText()) }, ["a", "b", "assistant.list.more|3"])
    }

    func testAirtableContactDraftWarnsOnlyAboutDuplicates() async {
        let tool = ProposeContactTool(directory: ContactSearchEngine(contacts: [Contact(id: "rec1", name: "Anna Muster")]))
        let duplicate = await tool.run(ToolInput(["name": "Anna Muster"]), scope: ToolScope()).render(KeyText())
        XCTAssertTrue(duplicate.contains("assistant.duplicate.name|Anna Muster"), duplicate)
        XCTAssertTrue(duplicate.contains("assistant.contactDraft.duplicateAsk"), duplicate)
        let fresh = await tool.run(ToolInput(["name": "Zora Neu"]), scope: ToolScope()).render(KeyText())
        XCTAssertFalse(fresh.contains("assistant.contactDraft.duplicate"), fresh)
        XCTAssertTrue(fresh.contains("assistant.contactDraft.airtableReady"), fresh)
    }
}

private struct UsageKeys: KeyPort {
    func claudeKey() async -> ClaudeKey? { ClaudeKey(apiKey: "k", model: "m") }
}

private struct UsageHttp: HttpPort {
    let body: String
    let streamLines: [String]

    private func ok(_ request: URLRequest) -> URLResponse {
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) { (Data(body.utf8), ok(request)) }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        let lines = streamLines
        let stream = AsyncThrowingStream<String, any Error> { continuation in
            for line in lines { continuation.yield(line) }
            continuation.finish()
        }
        return (stream, ok(request))
    }
}

extension AssistantTests {
    private func usageRequest() -> ChatRequest { ChatRequest(messages: [.text("x", role: .user)], system: "s", maxTokens: 5, model: "claude-x") }

    func testAnswerUsageIsBookedWithModelAndMonthTotalsAddUp() async throws {
        let store = ClaudeUsageStore(database: try SQLiteStore.inMemory())
        let body = #"{"content":[{"type":"text","text":"hi"}],"usage":{"input_tokens":100,"output_tokens":40,"cache_read_input_tokens":10,"cache_creation_input_tokens":5}}"#
        let client = ClaudeClient(keys: UsageKeys(), http: UsageHttp(body: body, streamLines: []), usage: store)
        _ = try await client.respond(usageRequest())
        _ = try await client.respond(usageRequest())
        let totals = store.totals(from: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(totals, UsageTotals(input: 230, output: 80, calls: 2, since: totals.since))
        XCTAssertNotNil(totals.since)
    }

    func testStreamedAnswerBooksStartAndEndCounts() async throws {
        let store = ClaudeUsageStore(database: try SQLiteStore.inMemory())
        let lines = [
            #"data: {"type":"message_start","message":{"usage":{"input_tokens":70,"output_tokens":1}}}"#,
            #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"ab"}}"#,
            #"data: {"type":"message_delta","usage":{"output_tokens":25}}"#,
        ]
        let client = ClaudeClient(keys: UsageKeys(), http: UsageHttp(body: "", streamLines: lines), usage: store)
        for try await _ in client.stream(usageRequest()) {}
        let totals = store.totals(from: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(totals.input, 70)
        XCTAssertEqual(totals.output, 25)
        XCTAssertEqual(totals.calls, 1)
    }

    func testAnswerWithoutUsageBooksNothing() async throws {
        let store = ClaudeUsageStore(database: try SQLiteStore.inMemory())
        let client = ClaudeClient(keys: UsageKeys(), http: UsageHttp(body: #"{"content":[]}"#, streamLines: []), usage: store)
        _ = try await client.respond(usageRequest())
        XCTAssertEqual(store.totals(from: Date(timeIntervalSince1970: 0)), UsageTotals())
    }

    func testTotalsStartAtTheGivenDayAndResetEmptiesTheCounter() throws {
        let store = ClaudeUsageStore(database: try SQLiteStore.inMemory())
        let old = Date(timeIntervalSince1970: 86_400 * 10)
        let recent = Date(timeIntervalSince1970: 86_400 * 40)
        store.book(TokenUsage(input: 1000, output: 500, cacheRead: 0, cacheWrite: 0), model: "a", at: old)
        store.book(TokenUsage(input: 20, output: 10, cacheRead: 0, cacheWrite: 0), model: "b", at: recent)
        let month = store.totals(from: Date(timeIntervalSince1970: 86_400 * 30))
        XCTAssertEqual(month.input, 20)
        XCTAssertEqual(month.output, 10)
        XCTAssertEqual(month.since, Date(timeIntervalSince1970: 86_400 * 40))
        store.reset()
        XCTAssertEqual(store.totals(from: Date(timeIntervalSince1970: 0)), UsageTotals())
    }

    func testPricesPersistPerKind() throws {
        let store = ClaudeUsageStore(database: try SQLiteStore.inMemory())
        XCTAssertEqual(store.price(.input), "")
        store.setPrice("3,00", for: .input)
        store.setPrice("15,00", for: .output)
        store.setPrice("4,00", for: .input)
        XCTAssertEqual(store.price(.input), "4,00")
        XCTAssertEqual(store.price(.output), "15,00")
    }

    func testEstimateNeedsBothPricesAndRoundsToHalfEuro() {
        let totals = UsageTotals(input: 1_200_000, output: 310_000, calls: 3)
        XCTAssertEqual(UsageEngine.estimate(totals, input: "3,00", output: "15,00"), 8.5)
        XCTAssertNil(UsageEngine.estimate(totals, input: "3,00", output: ""))
        XCTAssertNil(UsageEngine.estimate(totals, input: "0", output: "15"))
        XCTAssertEqual(UsageEngine.price(" 2.5 "), 2.5)
    }

    func testScaledAndDays() {
        XCTAssertEqual(UsageEngine.scaled(1_200_000).amount, "1,2")
        XCTAssertTrue(UsageEngine.scaled(1_200_000).millions)
        XCTAssertEqual(UsageEngine.scaled(310_400).amount, "310")
        XCTAssertFalse(UsageEngine.scaled(310_400).millions)
        let now = Date(timeIntervalSince1970: 86_400 * 12)
        XCTAssertEqual(UsageEngine.days(since: Date(timeIntervalSince1970: 86_400 * 3), now: now), 9)
        XCTAssertEqual(UsageEngine.days(since: now, now: now), 0)
    }
}
