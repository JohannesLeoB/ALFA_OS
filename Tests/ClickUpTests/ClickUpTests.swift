import Assistant
import Foundation
import Hub
import XCTest
@testable import ClickUp

private final class Script: @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [(Int, String)]
    private var sent: [URLRequest] = []

    init(_ replies: [(Int, String)]) { self.replies = replies }

    func next(_ request: URLRequest) -> (Int, String) {
        lock.lock(); defer { lock.unlock() }
        sent.append(request)
        return replies.isEmpty ? (200, "{}") : replies.removeFirst()
    }

    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return sent
    }
}

private struct FakeHttp: HttpPort {
    let script: Script

    init(_ replies: [(Int, String)] = []) { script = Script(replies) }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (status, body) = script.next(request)
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        throw ClickUpFailure.invalidResponse
    }
}

private struct FakeCredentials: CredentialsPort {
    var value: Credentials? = Credentials(token: "tok")

    func load() throws -> Credentials? { value }
}

private final class FakeKeychain: KeychainPort, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [KeySlot: String] = [:]

    func put(_ value: String, at slot: KeySlot) throws { lock.lock(); items[slot] = value; lock.unlock() }
    func get(_ slot: KeySlot) throws -> String? { lock.lock(); defer { lock.unlock() }; return items[slot] }
    func delete(_ slot: KeySlot) throws { lock.lock(); items[slot] = nil; lock.unlock() }
}

private final class FakeWrite: WritePort, @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String] = []

    var calls: [String] { lock.lock(); defer { lock.unlock() }; return log }

    private func note(_ text: String) { lock.withLock { log.append(text) } }

    func createTask(listID: String, name: String, content: String?) async throws -> String { note("create \(listID) \(name)"); return "new" }
    func setStatus(taskID: String, status: String) async throws { note("status \(taskID) \(status)") }
    func updateTask(taskID: String, name: String?, dueDate: Date?, priority: Priority?) async throws {
        note("update \(taskID) \(dueDate.map { String(Int($0.timeIntervalSince1970)) } ?? "-")")
    }
    func assign(taskID: String, memberID: String) async throws { note("assign \(taskID) \(memberID)") }
    func unassign(taskID: String, memberID: String) async throws {}
    func deleteTask(taskID: String) async throws {}
    func addDependency(taskID: String, otherTaskID: String, direction: TaskDependencies.Direction) async throws {}
    func removeDependency(taskID: String, otherTaskID: String, direction: TaskDependencies.Direction) async throws {}
    func addComment(taskID: String, text: String) async throws -> String { "" }
    func addTag(taskID: String, tagName: String) async throws {}
    func removeTag(taskID: String, tagName: String) async throws {}
    func setCustomFieldValue(taskID: String, fieldID: String, value: String) async throws {}
    func setCustomFieldBoolValue(taskID: String, fieldID: String, value: Bool) async throws {}
    func setCustomFieldDateValue(taskID: String, fieldID: String, value: Date) async throws {}
    func setCustomFieldDropdownValue(taskID: String, fieldID: String, optionID: String) async throws {}
    func setCustomFieldLabelsValue(taskID: String, fieldID: String, optionIDs: [String]) async throws {}
    func createSubtask(listID: String, parentTaskID: String, name: String) async throws -> String { "" }
    func moveTask(taskID: String, toListID: String) async throws {}
    func findOrCreateList(folderID: String, name: String, content: String?) async throws -> String { "" }
}

private struct FakeRead: ReadPort {
    var tasksResult: Result<[ClickUpTask], ClickUpFailure> = .success([])
    var membersResult: Result<[Member], ClickUpFailure> = .success([])

    func tasks(listID: String, includeClosed: Bool) async throws -> [ClickUpTask] { try tasksResult.get() }
    func dependencies(taskID: String) async throws -> TaskDependencies { .empty }
    func comments(taskID: String) async throws -> [Comment] { [] }
    func customFields(taskID: String) async throws -> [CustomField] { [] }
    func subtasks(taskID: String) async throws -> [ClickUpTask] { [] }
    func taskContent(taskID: String) async throws -> String? { nil }
    func listMembers(listID: String) async throws -> [Member] { try membersResult.get() }
    func fieldCatalog(listID: String) async throws -> [CustomField] { [] }
    func currentUser() async throws -> Member { Member(id: "1", username: "u") }
}

private func client(_ replies: [(Int, String)] = [], credentials: FakeCredentials = FakeCredentials()) -> (ClickUpClient, Script) {
    let http = FakeHttp(replies)
    return (ClickUpClient(credentials: credentials, http: http), http.script)
}

private func json(_ request: URLRequest) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
}

private let taskJSON = """
{"id":"t1","name":"Planen","status":{"status":"open","type":"open"},"due_date":"1700000000000","due_date_time":true,
"start_date":"1690000000000","priority":{"priority":"Urgent"},
"assignees":[{"id":11,"username":"ann"},{"id":12,"username":"bob"}],
"custom_fields":[{"name":"project_phase","value":2},{"name":"other","value":"x"}],
"custom_item_id":1,"tags":[{"name":"a"},{"name":"b"}]}
"""

final class ClickUpTests: XCTestCase {
    func testTasksMapEveryField() async throws {
        let (api, script) = client([(200, #"{"tasks":[\#(taskJSON)]}"#)])
        let tasks = try await api.tasks(listID: "L 1")
        XCTAssertEqual(tasks.count, 1)
        let task = tasks[0]
        XCTAssertEqual(task.id, "t1")
        XCTAssertEqual(task.status, "open")
        XCTAssertEqual(task.dueDate, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(task.startDate, Date(timeIntervalSince1970: 1_690_000_000))
        XCTAssertEqual(task.assignee, "ann")
        XCTAssertEqual(task.assigneeID, "11")
        XCTAssertEqual(task.assigneeIDs, ["11", "12"])
        XCTAssertEqual(task.assigneeNames, ["11": "ann", "12": "bob"])
        XCTAssertTrue(task.isUrgent)
        XCTAssertEqual(task.priority, .urgent)
        XCTAssertEqual(task.projectPhase, .planning)
        XCTAssertTrue(task.hasCustomFields)
        XCTAssertTrue(task.isMilestone)
        XCTAssertEqual(task.tags, ["a", "b"])
        XCTAssertEqual(task.dueHasTime, true)
        XCTAssertFalse(task.isDone)
        let request = script.requests[0]
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "tok")
        let url = request.url!.absoluteString
        XCTAssertTrue(url.hasPrefix("https://api.clickup.com/api/v2/list/L%201/task?"))
        XCTAssertTrue(url.contains("archived=false"))
        XCTAssertTrue(url.contains("include_closed=false"))
        XCTAssertTrue(url.contains("subtasks=false"))
        XCTAssertTrue(url.contains("page=0"))
    }

    func testTasksPageUntilShortPage() async throws {
        let full = (0..<100).map { #"{"id":"t\#($0)","name":"n"}"# }.joined(separator: ",")
        let (api, script) = client([(200, #"{"tasks":[\#(full)]}"#), (200, #"{"tasks":[{"id":"last","name":"n"}]}"#)])
        let tasks = try await api.tasks(listID: "L", includeClosed: true)
        XCTAssertEqual(tasks.count, 101)
        XCTAssertEqual(script.requests.count, 2)
        XCTAssertTrue(script.requests[0].url!.absoluteString.contains("include_closed=true"))
        XCTAssertTrue(script.requests[1].url!.absoluteString.contains("page=1"))
    }

    func testFailuresAreTyped() async {
        let cases: [(ClickUpClient, ClickUpFailure)] = [
            (client(credentials: FakeCredentials(value: nil)).0, .notConnected),
            (client([(401, "")]).0, .http(401)),
            (client([(200, "[]")]).0, .decoding),
        ]
        for (api, expected) in cases {
            do {
                _ = try await api.tasks(listID: "L")
                XCTFail("expected failure")
            } catch { XCTAssertEqual(error as? ClickUpFailure, expected) }
        }
    }

    func testWritesBuildTheRightRequests() async throws {
        let (api, script) = client([(200, #"{"id":"new1"}"#)])
        let id = try await api.createTask(listID: "L", name: "Neu", content: "text")
        XCTAssertEqual(id, "new1")
        try await api.setStatus(taskID: "T", status: "done")
        try await api.updateTask(taskID: "T", name: "x", dueDate: Date(timeIntervalSince1970: 1000), priority: .high)
        try await api.updateTask(taskID: "T", name: "", dueDate: nil, priority: nil)
        try await api.assign(taskID: "T", memberID: "42")
        try await api.unassign(taskID: "T", memberID: "42")
        try await api.deleteTask(taskID: "T")
        let sent = script.requests
        XCTAssertEqual(sent.map(\.httpMethod), ["POST", "PUT", "PUT", "PUT", "PUT", "DELETE"])
        XCTAssertEqual(sent[0].url?.absoluteString, "https://api.clickup.com/api/v2/list/L/task")
        XCTAssertEqual(sent[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(json(sent[0])["name"] as? String, "Neu")
        XCTAssertEqual(json(sent[0])["content"] as? String, "text")
        XCTAssertEqual(json(sent[1])["status"] as? String, "done")
        XCTAssertEqual(json(sent[2])["due_date"] as? Int, 1_000_000)
        XCTAssertEqual(json(sent[2])["priority"] as? Int, 2)
        XCTAssertEqual(json(sent[2])["name"] as? String, "x")
        let add = json(sent[3])["assignees"] as? [String: [Int]]
        XCTAssertEqual(add?["add"], [42])
        XCTAssertEqual(add?["rem"], [])
        let remove = json(sent[4])["assignees"] as? [String: [Int]]
        XCTAssertEqual(remove?["rem"], [42])
        XCTAssertEqual(sent[5].url?.absoluteString, "https://api.clickup.com/api/v2/task/T")
        XCTAssertNil(sent[5].httpBody)
    }

    func testEmptyUpdateAndBadMemberSendNothing() async {
        let (api, script) = client()
        try? await api.updateTask(taskID: "T", name: nil, dueDate: nil, priority: nil)
        do {
            try await api.assign(taskID: "T", memberID: "abc")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? ClickUpFailure, .invalidResponse) }
        XCTAssertTrue(script.requests.isEmpty)
    }

    func testTagsDependenciesAndFields() async throws {
        let (api, script) = client(Array(repeating: (200, "{}"), count: 5) + [(200, #"{"id":"c9"}"#)])
        try await api.addTag(taskID: "T", tagName: " rot ")
        try await api.removeTag(taskID: "T", tagName: "rot")
        do {
            try await api.addTag(taskID: "T", tagName: "  ")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? ClickUpFailure, .invalidResponse) }
        try await api.addDependency(taskID: "T", otherTaskID: "O", direction: .waitingOn)
        try await api.addDependency(taskID: "T", otherTaskID: "O", direction: .blocking)
        try await api.removeDependency(taskID: "T", otherTaskID: "O", direction: .blocking)
        let comment = try await api.addComment(taskID: "T", text: "hi")
        XCTAssertEqual(comment, "c9")
        try await api.setCustomFieldValue(taskID: "T", fieldID: "F", value: "v")
        try await api.setCustomFieldBoolValue(taskID: "T", fieldID: "F", value: true)
        try await api.setCustomFieldDateValue(taskID: "T", fieldID: "F", value: Date(timeIntervalSince1970: 2))
        try await api.setCustomFieldDropdownValue(taskID: "T", fieldID: "F", optionID: "o")
        try await api.setCustomFieldLabelsValue(taskID: "T", fieldID: "F", optionIDs: ["a", "b"])
        let sent = script.requests
        XCTAssertEqual(sent.count, 11)
        XCTAssertEqual(sent[0].url?.absoluteString, "https://api.clickup.com/api/v2/task/T/tag/rot")
        XCTAssertEqual(sent[0].httpMethod, "POST")
        XCTAssertEqual(sent[1].httpMethod, "DELETE")
        XCTAssertEqual(json(sent[2])["depends_on"] as? String, "O")
        XCTAssertEqual(json(sent[3])["dependency_of"] as? String, "O")
        XCTAssertEqual(sent[4].url?.absoluteString, "https://api.clickup.com/api/v2/task/T/dependency?dependency_of=O")
        XCTAssertEqual(sent[4].httpMethod, "DELETE")
        XCTAssertEqual(json(sent[5])["comment_text"] as? String, "hi")
        XCTAssertEqual(json(sent[5])["notify_all"] as? Bool, false)
        XCTAssertEqual(sent[6].url?.absoluteString, "https://api.clickup.com/api/v2/task/T/field/F")
        XCTAssertEqual(json(sent[6])["value"] as? String, "v")
        XCTAssertEqual(json(sent[7])["value"] as? Bool, true)
        XCTAssertEqual(json(sent[8])["value"] as? Int, 2000)
        XCTAssertEqual(json(sent[9])["value"] as? String, "o")
        XCTAssertEqual(json(sent[10])["value"] as? [String], ["a", "b"])
    }

    func testReadsDecodeDetailMembersCommentsAndCatalog() async throws {
        let detail = """
        {"name":"T","status":{"status":"open"},"text_content":"Inhalt",
        "custom_fields":[{"id":"f1","name":"Phase","type":"drop_down","value":2,"type_config":{"options":[{"id":"o1","name":"A","orderindex":0},{"id":"o2","label":"B"}]}},
        {"id":"f2","name":"Note","type":"text","value":"abc"},{"id":"f3","name":"Tags","type":"labels","value":["x","y"]}],
        "subtasks":[{"id":"s1","name":"Sub"}]}
        """
        let (api, script) = client([
            (200, detail), (200, detail), (200, detail),
            (200, #"{"members":[{"id":5,"username":"ann"},{"id":6}]}"#),
            (200, #"{"comments":[{"id":"c1","comment_text":"x","user":{"id":3,"username":"zed"},"date":"1700000000000","resolved":true}]}"#),
            (200, #"{"fields":[{"id":"f1","name":"Phase","type":"drop_down","type_config":{"options":[{"id":"o1","name":"A"}]}}]}"#),
            (200, #"{"user":{"id":7,"username":"me","email":"me@example.com"}}"#),
        ])
        let fields = try await api.customFields(taskID: "T")
        XCTAssertEqual(fields.map(\.rawValue), ["2", "abc", "x, y"])
        XCTAssertEqual(fields[0].options, [FieldOption(id: "o1", name: "A", orderIndex: 0), FieldOption(id: "o2", name: "B")])
        let value1 = try await api.taskContent(taskID: "T")
        XCTAssertEqual(value1, "Inhalt")
        let value2 = try await api.subtasks(taskID: "T").map(\.id)
        XCTAssertEqual(value2, ["s1"])
        let value3 = try await api.listMembers(listID: "L")
        XCTAssertEqual(value3, [Member(id: "5", username: "ann"), Member(id: "6", username: "")])
        let comments = try await api.comments(taskID: "T")
        XCTAssertEqual(comments, [Comment(id: "c1", text: "x", authorName: "zed", authorID: "3",
                                          postedAt: Date(timeIntervalSince1970: 1_700_000_000), resolved: true)])
        let catalog = try await api.fieldCatalog(listID: "L")
        XCTAssertEqual(catalog.first?.options.first?.id, "o1")
        XCTAssertEqual(catalog.first?.rawValue, "")
        let value4 = try await api.currentUser()
        XCTAssertEqual(value4, Member(id: "7", username: "me", email: "me@example.com"))
        let urls = script.requests.map { $0.url!.absoluteString }
        XCTAssertTrue(urls[2].hasSuffix("/task/T?include_subtasks=true"))
        XCTAssertTrue(urls[3].hasSuffix("/list/L/member"))
        XCTAssertTrue(urls[4].hasSuffix("/task/T/comment"))
        XCTAssertTrue(urls[5].hasSuffix("/list/L/field"))
        XCTAssertTrue(urls[6].hasSuffix("/user"))
    }

    func testDependenciesResolveBothDirectionsSorted() async throws {
        let own = #"{"name":"Own","dependencies":[{"task_id":"T","depends_on":"A"},{"task_id":"B","depends_on":"T"},{"task_id":"X","depends_on":"Y"}]}"#
        let (api, _) = client([(200, own), (200, #"{"name":"Alpha","status":{"status":"done"}}"#), (200, #"{"name":"Beta","status":{"status":"open"}}"#)])
        let result = try await api.dependencies(taskID: "T")
        XCTAssertEqual(result.waitingOn.map(\.id), ["A"])
        XCTAssertEqual(result.blocking.map(\.id), ["B"])
        XCTAssertEqual(Set((result.waitingOn + result.blocking).map(\.name)), ["Alpha", "Beta"])
        let (quiet, script) = client([(200, #"{"name":"Own"}"#)])
        let none = try await quiet.dependencies(taskID: "T")
        XCTAssertEqual(none, .empty)
        XCTAssertEqual(script.requests.count, 1)
    }

    func testDependencyFallsBackToIdWhenLookupFails() async throws {
        let own = #"{"name":"Own","dependencies":[{"task_id":"T","depends_on":"A"}]}"#
        let (api, _) = client([(200, own), (404, "")])
        let result = try await api.dependencies(taskID: "T")
        XCTAssertEqual(result.waitingOn, [TaskDependencies.Reference(id: "A", name: "A", status: "")])
    }

    func testMoveUsesTeamThenVersion3() async throws {
        let (api, script) = client([(200, #"{"teams":[{"id":"W1"}]}"#), (200, "{}")])
        try await api.moveTask(taskID: "T", toListID: "L2")
        XCTAssertEqual(script.requests[0].url?.absoluteString, "https://api.clickup.com/api/v2/team")
        XCTAssertEqual(script.requests[1].url?.absoluteString, "https://api.clickup.com/api/v3/workspaces/W1/tasks/T/home_list/L2")
        XCTAssertEqual(script.requests[1].httpMethod, "PUT")
        let (empty, _) = client([(200, #"{"teams":[]}"#)])
        do {
            try await empty.moveTask(taskID: "T", toListID: "L2")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? ClickUpFailure, .decoding) }
    }

    func testFindOrCreateListReusesExistingByName() async throws {
        let lists = #"{"lists":[{"id":"l1","name":"Alpha"},{"id":"l2","name":"Beta"}]}"#
        let (reuse, reused) = client([(200, lists)])
        let value5 = try await reuse.findOrCreateList(folderID: "F", name: "Beta", content: nil)
        XCTAssertEqual(value5, "l2")
        XCTAssertEqual(reused.requests.count, 1)
        let (create, created) = client([(200, lists), (200, #"{"id":"l9"}"#)])
        let value6 = try await create.findOrCreateList(folderID: "F", name: "Gamma", content: "info")
        XCTAssertEqual(value6, "l9")
        XCTAssertEqual(created.requests[1].httpMethod, "POST")
        XCTAssertEqual(created.requests[1].url?.absoluteString, "https://api.clickup.com/api/v2/folder/F/list")
        XCTAssertEqual(json(created.requests[1])["content"] as? String, "info")
    }

    func testCreateSubtaskCarriesParent() async throws {
        let (api, script) = client([(200, #"{"id":"sub"}"#)])
        let value7 = try await api.createSubtask(listID: "L", parentTaskID: "P", name: "n")
        XCTAssertEqual(value7, "sub")
        XCTAssertEqual(json(script.requests[0])["parent"] as? String, "P")
        let (broken, _) = client([(200, "{}")])
        do {
            _ = try await broken.createSubtask(listID: "L", parentTaskID: "P", name: "n")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? ClickUpFailure, .decoding) }
    }

    func testConnectionCheckReturnsUsernameAndTranslatesFailures() async throws {
        let ok = FakeHttp([(200, #"{"user":{"id":1,"username":"ann"}}"#)])
        let check = ConnectionCheck(http: ok)
        XCTAssertEqual(check.integration, "clickup")
        let account = try await check.check(KeyValues(values: ["token": "tok"]))
        XCTAssertEqual(account, "ann")
        XCTAssertEqual(ok.script.requests[0].value(forHTTPHeaderField: "Authorization"), "tok")
        do {
            _ = try await ConnectionCheck(http: FakeHttp([(401, "")])).check(KeyValues(values: ["token": "x"]))
            XCTFail("expected failure")
        } catch { XCTAssertEqual((error as? any StatusErrorPort)?.status, 401) }
        do {
            _ = try await ConnectionCheck(http: FakeHttp([(200, "[]")])).check(KeyValues(values: ["token": "x"]))
            XCTFail("expected failure")
        } catch { XCTAssertTrue(error is any ShapeErrorPort) }
    }

    func testCredentialsStoreReadsTokenFromKeychain() throws {
        let keychain = FakeKeychain()
        let store = CredentialsStore(keychain: keychain, inlet: "i1")
        XCTAssertNil(try store.load())
        try keychain.put("tok", at: KeySlot(inlet: "i1", name: "token"))
        XCTAssertEqual(try store.load(), Credentials(token: "tok"))
        try keychain.put("", at: KeySlot(inlet: "i1", name: "token"))
        XCTAssertNil(try store.load())
    }

    func testTaskBoardMapsTasksAndMembers() async throws {
        let due = Date(timeIntervalSince1970: 100)
        let tasks = [ClickUpTask(id: "1", name: "A", status: "open", dueDate: due, assignee: "ann", isUrgent: true)]
        let board = TaskBoardClient(read: FakeRead(tasksResult: .success(tasks), membersResult: .success([Member(id: "5", username: "ann")])),
                                    write: FakeWrite())
        let value8 = try await board.openTasks(listID: "L")
        XCTAssertEqual(value8, [TaskItem(id: "1", name: "A", status: "open", isUrgent: true, dueDate: due, assignee: "ann")])
        let value9 = try await board.members(listID: "L")
        XCTAssertEqual(value9, [TaskMember(id: "5", username: "ann")])
    }

    func testTaskBoardTranslatesFailures() async {
        let offline = TaskBoardClient(read: FakeRead(tasksResult: .failure(.notConnected), membersResult: .failure(.http(500))),
                                      write: FakeWrite())
        do {
            _ = try await offline.openTasks(listID: "L")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? PortFailure, .notConnected) }
        do {
            _ = try await offline.members(listID: "L")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? PortFailure, .failed("http 500")) }
    }

    func testTaskBoardAppliesEveryProposalKind() async throws {
        let write = FakeWrite()
        let board = TaskBoardClient(read: FakeRead(), write: write)
        let due = Date(timeIntervalSince1970: 500)
        let created = try await board.apply(ClickUpChangeDraft(intent: .create, listID: "L", projectNumber: "P1", taskName: "Neu", dueDate: due))
        XCTAssertEqual(created, "new")
        try await board.apply(ClickUpChangeDraft(intent: .status, listID: "L", projectNumber: "P1", taskID: "T", taskName: "x", status: "done"))
        try await board.apply(ClickUpChangeDraft(intent: .dueDate, listID: "L", projectNumber: "P1", taskID: "T", taskName: "x", dueDate: due))
        try await board.apply(ClickUpChangeDraft(intent: .assign, listID: "L", projectNumber: "P1", taskID: "T", taskName: "x", memberID: "9"))
        XCTAssertEqual(write.calls, ["create L Neu", "update new 500", "status T done", "update T 500", "assign T 9"])
        do {
            _ = try await board.apply(ClickUpChangeDraft(intent: .status, listID: "L", projectNumber: "P1", taskName: "x", status: "done"))
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? PortFailure, .failed("invalidResponse")) }
    }

    func testProjectTemplateAnchorIsExplicitAboutAmbiguity() throws {
        let plain = ClickUpTask(id: "1", name: "Anker", status: "open")
        let other = ClickUpTask(id: "2", name: "Andere", status: "open", projectPhase: .execution, hasCustomFields: true)
        let named = ClickUpTask(id: "3", name: "Anker", status: "open", projectPhase: .offer, hasCustomFields: true)
        XCTAssertEqual(try ProjectTemplate.anchor(in: [other, named], named: "Anker")?.id, "3")
        XCTAssertEqual(try ProjectTemplate.anchor(in: [plain, other], named: "Fehlt")?.id, "2")
        XCTAssertNil(try ProjectTemplate.anchor(in: [plain], named: "Fehlt"))
        XCTAssertThrowsError(try ProjectTemplate.anchor(in: [plain, named], named: "Anker")) {
            XCTAssertEqual($0 as? ClickUpFailure, .ambiguousAnchor(name: "Anker", count: 2))
        }
        XCTAssertEqual(ProjectTemplate.phase(in: [other, named], anchorName: "Anker"), .offer)
        XCTAssertNil(ProjectTemplate.phase(in: [plain, named], anchorName: "Anker"))
        XCTAssertEqual(ProjectTemplate.taskKeys.count, 8)
        XCTAssertEqual(ProjectTemplate.anchorKey, ProjectTemplate.taskKeys[0])
        XCTAssertEqual(Set(ProjectTemplate.taskKeys).count, 8)
    }

    func testCustomFieldWriteKindsAndStrictLookups() throws {
        let options = [FieldOption(id: "o1", name: "Rot"), FieldOption(id: "o2", name: "rot"), FieldOption(id: "o3", name: "Blau")]
        XCTAssertEqual(CustomField(id: "1", name: "n", type: "short_text", rawValue: "").writeKind, .text)
        XCTAssertEqual(CustomField(id: "1", name: "n", type: "checkbox", rawValue: "").writeKind, .checkbox)
        XCTAssertEqual(CustomField(id: "1", name: "n", type: "date", rawValue: "").writeKind, .date)
        XCTAssertEqual(CustomField(id: "1", name: "n", type: "drop_down", rawValue: "", options: options).writeKind, .dropdown)
        XCTAssertEqual(CustomField(id: "1", name: "n", type: "drop_down", rawValue: "").writeKind, WriteKindNone.value)
        XCTAssertEqual(CustomField(id: "1", name: "n", type: "labels", rawValue: "", options: options).writeKind, .labels)
        XCTAssertEqual(CustomField(id: "1", name: "n", type: "formula", rawValue: "").writeKind, WriteKindNone.value)
        let field = CustomField(id: "1", name: "Farbe", type: "drop_down", rawValue: "", options: options)
        XCTAssertEqual(try field.optionID(forLabel: "BLAU"), "o3")
        XCTAssertNil(try field.optionID(forLabel: "Gelb"))
        XCTAssertThrowsError(try field.optionID(forLabel: "rot")) {
            XCTAssertEqual($0 as? ClickUpFailure, .ambiguousOption(field: "Farbe", label: "rot", count: 2))
        }
        let twin = CustomField(id: "2", name: "Farbe", type: "text", rawValue: "")
        XCTAssertEqual(try CustomField.unique(named: "Farbe", in: [field])?.id, "1")
        XCTAssertNil(try CustomField.unique(named: "Nix", in: [field]))
        XCTAssertThrowsError(try CustomField.unique(named: "Farbe", in: [field, twin])) {
            XCTAssertEqual($0 as? ClickUpFailure, .ambiguousField(name: "Farbe", count: 2))
        }
    }

    func testTaskHelpers() {
        var task = ClickUpTask(id: "1", name: "n", status: "Complete")
        XCTAssertTrue(task.isDone)
        task.statusType = "open"
        XCTAssertFalse(task.isDone)
        task.statusType = "closed"
        XCTAssertTrue(task.isDone)
        XCTAssertFalse(task.showsDueTime())
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        task.dueDate = Date(timeIntervalSince1970: 4 * 3600)
        XCTAssertFalse(task.showsDueTime(calendar: calendar))
        task.dueDate = Date(timeIntervalSince1970: 9 * 3600)
        XCTAssertTrue(task.showsDueTime(calendar: calendar))
        task.dueHasTime = false
        XCTAssertFalse(task.showsDueTime(calendar: calendar))
        XCTAssertEqual(ClickUpTask(id: "1", name: "n", status: "s", assigneeID: "7").assigneeIDs, ["7"])
        XCTAssertEqual(Priority.allCases.map(\.nativeValue), [1, 2, 3, 4])
        XCTAssertEqual(Priority.urgent.labelKey, "clickup.priority.urgent")
        XCTAssertEqual(ProjectPhase.allCases.map(\.rawValue), Array(0...6))
        XCTAssertEqual(ProjectPhase.execution.labelKey, "clickup.phase.execution")
    }
}

private enum WriteKindNone {
    static let value = CustomField.WriteKind.none
}
