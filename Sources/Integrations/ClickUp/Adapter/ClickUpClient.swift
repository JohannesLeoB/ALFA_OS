import Assistant
import Foundation

public struct ClickUpClient: ReadPort, WritePort {
    static let endpoint = "https://api.clickup.com/api/v2"
    static let endpointV3 = "https://api.clickup.com/api/v3"
    static let pageSize = 100
    static let maxPages = 20

    private let credentials: any CredentialsPort
    private let http: any HttpPort

    public init(credentials: any CredentialsPort, http: any HttpPort) {
        self.credentials = credentials
        self.http = http
    }

    public func tasks(listID: String, includeClosed: Bool) async throws -> [ClickUpTask] {
        var all: [ClickUpTask] = []
        for page in 0..<Self.maxPages {
            let query = [
                URLQueryItem(name: "archived", value: "false"),
                URLQueryItem(name: "include_closed", value: String(includeClosed)),
                URLQueryItem(name: "subtasks", value: "false"),
                URLQueryItem(name: "page", value: String(page)),
            ]
            let batch = try ResponseParser.tasks(from: try await send("GET", ["list", listID, "task"], query: query))
            all += batch
            if batch.count < Self.pageSize { break }
        }
        return all
    }

    func dependencies(taskID: String) async throws -> TaskDependencies {
        let ids = try ResponseParser.dependencyIDs(from: try await detail(taskID), ownTaskID: taskID)
        guard ids.waitingOn.isEmpty == false || ids.blocking.isEmpty == false else { return .empty }
        async let waitingOn = references(ids.waitingOn)
        async let blocking = references(ids.blocking)
        return await TaskDependencies(waitingOn: waitingOn, blocking: blocking)
    }

    func comments(taskID: String) async throws -> [Comment] {
        try ResponseParser.comments(from: try await send("GET", ["task", taskID, "comment"]))
    }

    func customFields(taskID: String) async throws -> [CustomField] {
        try ResponseParser.customFields(from: try await detail(taskID))
    }

    func subtasks(taskID: String) async throws -> [ClickUpTask] {
        let query = [URLQueryItem(name: "include_subtasks", value: "true")]
        return try ResponseParser.subtasks(from: try await send("GET", ["task", taskID], query: query))
    }

    func taskContent(taskID: String) async throws -> String? {
        try ResponseParser.content(from: try await detail(taskID))
    }

    public func listMembers(listID: String) async throws -> [Member] {
        try ResponseParser.members(from: try await send("GET", ["list", listID, "member"]))
    }

    func fieldCatalog(listID: String) async throws -> [CustomField] {
        try ResponseParser.fieldCatalog(from: try await send("GET", ["list", listID, "field"]))
    }

    func currentUser() async throws -> Member {
        try ResponseParser.user(from: try await send("GET", ["user"]))
    }

    public func createTask(listID: String, name: String, content: String?) async throws -> String {
        var body: [String: Any] = ["name": name]
        if let content, content.isEmpty == false { body["content"] = content }
        return try ResponseParser.createdID(from: try await send("POST", ["list", listID, "task"], body: body))
    }

    public func setStatus(taskID: String, status: String) async throws {
        _ = try await send("PUT", ["task", taskID], body: ["status": status])
    }

    public func updateTask(taskID: String, name: String?, dueDate: Date?, priority: Priority?) async throws {
        var body: [String: Any] = [:]
        if let name, name.isEmpty == false { body["name"] = name }
        if let dueDate { body["due_date"] = Self.milliseconds(dueDate) }
        if let priority { body["priority"] = priority.nativeValue }
        guard body.isEmpty == false else { return }
        _ = try await send("PUT", ["task", taskID], body: body)
    }

    public func assign(taskID: String, memberID: String) async throws {
        try await changeAssignees(taskID, memberID, adding: true)
    }

    func unassign(taskID: String, memberID: String) async throws {
        try await changeAssignees(taskID, memberID, adding: false)
    }

    func deleteTask(taskID: String) async throws {
        _ = try await send("DELETE", ["task", taskID])
    }

    func addDependency(taskID: String, otherTaskID: String, direction: TaskDependencies.Direction) async throws {
        _ = try await send("POST", ["task", taskID, "dependency"], body: [Self.dependencyKey(direction): otherTaskID])
    }

    func removeDependency(taskID: String, otherTaskID: String, direction: TaskDependencies.Direction) async throws {
        let query = [URLQueryItem(name: Self.dependencyKey(direction), value: otherTaskID)]
        _ = try await send("DELETE", ["task", taskID, "dependency"], query: query)
    }

    func addComment(taskID: String, text: String) async throws -> String {
        let body: [String: Any] = ["comment_text": text, "notify_all": false]
        return try ResponseParser.createdID(from: try await send("POST", ["task", taskID, "comment"], body: body))
    }

    func addTag(taskID: String, tagName: String) async throws {
        _ = try await send("POST", ["task", taskID, "tag", try Self.tag(tagName)])
    }

    func removeTag(taskID: String, tagName: String) async throws {
        _ = try await send("DELETE", ["task", taskID, "tag", try Self.tag(tagName)])
    }

    func setCustomFieldValue(taskID: String, fieldID: String, value: String) async throws {
        try await setField(taskID, fieldID, value)
    }

    func setCustomFieldBoolValue(taskID: String, fieldID: String, value: Bool) async throws {
        try await setField(taskID, fieldID, value)
    }

    func setCustomFieldDateValue(taskID: String, fieldID: String, value: Date) async throws {
        try await setField(taskID, fieldID, Self.milliseconds(value))
    }

    func setCustomFieldDropdownValue(taskID: String, fieldID: String, optionID: String) async throws {
        try await setField(taskID, fieldID, optionID)
    }

    func setCustomFieldLabelsValue(taskID: String, fieldID: String, optionIDs: [String]) async throws {
        try await setField(taskID, fieldID, optionIDs)
    }

    func createSubtask(listID: String, parentTaskID: String, name: String) async throws -> String {
        let body: [String: Any] = ["name": name, "parent": parentTaskID]
        return try ResponseParser.createdID(from: try await send("POST", ["list", listID, "task"], body: body))
    }

    func moveTask(taskID: String, toListID: String) async throws {
        let workspace = try ResponseParser.firstTeamID(from: try await send("GET", ["team"]))
        _ = try await send("PUT", ["workspaces", workspace, "tasks", taskID, "home_list", toListID], version3: true)
    }

    func findOrCreateList(folderID: String, name: String, content: String?) async throws -> String {
        let existing = try await send("GET", ["folder", folderID, "list"])
        if let id = try ResponseParser.listID(named: name, from: existing) { return id }
        var body: [String: Any] = ["name": name]
        if let content, content.isEmpty == false { body["content"] = content }
        return try ResponseParser.createdID(from: try await send("POST", ["folder", folderID, "list"], body: body))
    }

    private func detail(_ taskID: String) async throws -> Data {
        try await send("GET", ["task", taskID])
    }

    private func references(_ ids: [String]) async -> [TaskDependencies.Reference] {
        await withTaskGroup(of: TaskDependencies.Reference.self) { group in
            for id in ids {
                group.addTask {
                    let data = try? await self.detail(id)
                    return data.map { ResponseParser.reference(id: id, from: $0) }
                        ?? TaskDependencies.Reference(id: id, name: id, status: "")
                }
            }
            var result: [TaskDependencies.Reference] = []
            for await reference in group { result.append(reference) }
            return result.sorted { $0.name < $1.name }
        }
    }

    private func changeAssignees(_ taskID: String, _ memberID: String, adding: Bool) async throws {
        guard let member = Int(memberID) else { throw ClickUpFailure.invalidResponse }
        let assignees: [String: [Int]] = adding ? ["add": [member], "rem": []] : ["add": [], "rem": [member]]
        _ = try await send("PUT", ["task", taskID], body: ["assignees": assignees])
    }

    private func setField(_ taskID: String, _ fieldID: String, _ value: Any) async throws {
        _ = try await send("POST", ["task", taskID, "field", fieldID], body: ["value": value])
    }

    private func send(_ method: String, _ path: [String], query: [URLQueryItem] = [], body: [String: Any]? = nil,
                      version3: Bool = false) async throws -> Data {
        guard let held = try? credentials.load() else { throw ClickUpFailure.notConnected }
        let root = version3 ? Self.endpointV3 : Self.endpoint
        let encoded = path.map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
        guard var components = URLComponents(string: root + "/" + encoded.joined(separator: "/")) else {
            throw ClickUpFailure.invalidResponse
        }
        if query.isEmpty == false { components.queryItems = query }
        guard let url = components.url else { throw ClickUpFailure.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(held.token, forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await http.data(for: request)
        guard let status = response as? HTTPURLResponse else { throw ClickUpFailure.invalidResponse }
        guard (200...299).contains(status.statusCode) else { throw ClickUpFailure.http(status.statusCode) }
        return data
    }

    private static func tag(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { throw ClickUpFailure.invalidResponse }
        return trimmed
    }

    private static func dependencyKey(_ direction: TaskDependencies.Direction) -> String {
        direction == .waitingOn ? "depends_on" : "dependency_of"
    }

    private static func milliseconds(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 * 1000)
    }
}
