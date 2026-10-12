import Foundation
import MykilosKit

public struct ClickUpTask: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var status: String
    public var dueDate: Date?

    public var startDate: Date?
    public var assignee: String?

    public var assigneeID: String?

    public var assigneeIDs: [String]

    public var assigneeNamen: [String: String]
    public var isUrgent: Bool

    public var priority: ClickUpPriority?

    public var projectPhase: ClickUpProjectPhase?

    public var hasCustomFields: Bool

    public var isMilestone: Bool

    public var tags: [String]

    public var statusType: String?

    public var dueDateHatUhrzeit: Bool?

    public init(id: String, name: String, status: String,
                dueDate: Date? = nil, startDate: Date? = nil, assignee: String? = nil, assigneeID: String? = nil,
                assigneeIDs: [String] = [], assigneeNamen: [String: String] = [:],
                isUrgent: Bool = false, priority: ClickUpPriority? = nil,
                projectPhase: ClickUpProjectPhase? = nil, hasCustomFields: Bool = false,
                isMilestone: Bool = false, statusType: String? = nil, tags: [String] = []) {
        self.id = id
        self.name = name
        self.status = status
        self.dueDate = dueDate
        self.startDate = startDate
        self.assignee = assignee
        self.assigneeID = assigneeID
        self.assigneeIDs = assigneeIDs.isEmpty ? Array([assigneeID].compactMap { $0 }) : assigneeIDs
        self.assigneeNamen = assigneeNamen
        self.isUrgent = isUrgent
        self.priority = priority
        self.projectPhase = projectPhase
        self.hasCustomFields = hasCustomFields
        self.isMilestone = isMilestone
        self.statusType = statusType
        self.tags = tags
    }

    public func faelligkeitZeigtUhrzeit(kalender: Calendar = .current) -> Bool {
        guard let dueDate else { return false }
        if let dueDateHatUhrzeit { return dueDateHatUhrzeit }
        let teile = kalender.dateComponents([.hour, .minute], from: dueDate)
        return (teile.hour == 4 && teile.minute == 0) == false
    }

    public var istErledigt: Bool {
        if let typ = statusType?.lowercased(), typ.isEmpty == false {
            return typ == "done" || typ == "closed"
        }
        return status.lowercased() == "complete"
    }
}

public enum ClickUpPriority: String, CaseIterable, Sendable, Equatable {
    case urgent, high, normal, low

    public var label: String {
        switch self {
        case .urgent: "Dringend"
        case .high: "Hoch"
        case .normal: "Normal"
        case .low: "Niedrig"
        }
    }
}

public enum ClickUpError: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed
}

public enum ClickUpMehrdeutigFehler: Error, Sendable, Equatable, LocalizedError {
    case ankerTask(name: String, count: Int)
    case feld(name: String, count: Int)
    case dropdownLabel(feld: String, label: String, count: Int)

    public var errorDescription: String? {
        switch self {
        case .ankerTask(let name, let count):
            return "🔀 \(count) Tasks heißen \"\(name)\" in dieser ClickUp-Liste — der Anker ist mehrdeutig, kein stilles Raten. Doppelten Task in ClickUp entfernen."
        case .feld(let name, let count):
            return "🔀 \(count) Custom Fields heißen \"\(name)\" auf dem Anker-Task — mehrdeutig, es wird nicht ins falsche Feld geschrieben."
        case .dropdownLabel(let feld, let label, let count):
            return "🔀 Feld \"\(feld)\" hat \(count) Optionen namens \"\(label)\" — mehrdeutig, keine Auswahl ins Ungewisse."
        }
    }
}

public struct ClickUpTaskDependencies: Equatable, Sendable {
    public var waitingOn: [ClickUpDependencyRef]

    public var blocking: [ClickUpDependencyRef]

    public static let empty = ClickUpTaskDependencies(waitingOn: [], blocking: [])

    public init(waitingOn: [ClickUpDependencyRef] = [], blocking: [ClickUpDependencyRef] = []) {
        self.waitingOn = waitingOn
        self.blocking = blocking
    }
}

public struct ClickUpDependencyRef: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var status: String

    public init(id: String, name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
    }
}

public enum ClickUpDependencyDirection: String, Sendable, Equatable {
    case waitingOn

    case blocking
}

public struct ClickUpComment: Identifiable, Equatable, Sendable {
    public var id: String
    public var text: String
    public var authorName: String?
    public var authorID: String?
    public var postedAt: Date?
    public var resolved: Bool

    public init(
        id: String, text: String, authorName: String? = nil, authorID: String? = nil,
        postedAt: Date? = nil, resolved: Bool = false
    ) {
        self.id = id
        self.text = text
        self.authorName = authorName
        self.authorID = authorID
        self.postedAt = postedAt
        self.resolved = resolved
    }
}

public struct ClickUpFieldOption: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var orderindex: Int?

    public init(id: String, name: String, orderindex: Int? = nil) {
        self.id = id
        self.name = name
        self.orderindex = orderindex
    }
}

public struct ClickUpCustomFieldRef: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var type: String
    public var rawValue: String

    public var options: [ClickUpFieldOption]

    public init(
        id: String, name: String, type: String, rawValue: String,
        options: [ClickUpFieldOption] = []
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.rawValue = rawValue
        self.options = options
    }

    public var unterstuetztSchreiben: Bool {
        ["text", "short_text", "number", "url", "email", "phone"].contains(type)
    }

    public enum TypisierterSchreibPfad: Equatable, Sendable {
        case text
        case checkbox
        case date
        case dropdown
        case labels
        case keiner
    }

    public var typisierterSchreibPfad: TypisierterSchreibPfad {
        if unterstuetztSchreiben { return .text }
        switch type {
        case "checkbox": return .checkbox
        case "date": return .date
        case "drop_down": return options.isEmpty ? .keiner : .dropdown
        case "labels": return options.isEmpty ? .keiner : .labels
        default: return .keiner
        }
    }

    public func optionID(forLabel label: String) -> String? {
        options.first { $0.name.caseInsensitiveCompare(label) == .orderedSame }?.id
    }

    public func optionIDStreng(forLabel label: String) throws -> String? {
        let match = options.filter { $0.name.caseInsensitiveCompare(label) == .orderedSame }
        guard match.count <= 1 else {
            throw ClickUpMehrdeutigFehler.dropdownLabel(feld: name, label: label, count: match.count)
        }
        return match.first?.id
    }

    public static func eindeutig(in fields: [ClickUpCustomFieldRef], name: String) throws -> ClickUpCustomFieldRef? {
        let match = fields.filter { $0.name == name }
        guard match.count <= 1 else {
            throw ClickUpMehrdeutigFehler.feld(name: name, count: match.count)
        }
        return match.first
    }

    public var aktiveOptionIDs: [String] {
        let gueltige = Set(options.map(\.id))
        return rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { gueltige.contains($0) }
    }
}

public struct ClickUpMember: Identifiable, Equatable, Sendable {
    public var id: String
    public var username: String

    public init(id: String, username: String) {
        self.id = id
        self.username = username
    }
}

public protocol ClickUpFetching: Sendable {
    func tasks(listID: String) async throws -> [ClickUpTask]

    func tasks(listID: String, includeClosed: Bool) async throws -> [ClickUpTask]

    func projektMeta(listID: String) async throws -> ClickUpProjektMeta

    func dependencies(taskID: String) async throws -> ClickUpTaskDependencies

    func comments(taskID: String) async throws -> [ClickUpComment]

    func customFields(taskID: String) async throws -> [ClickUpCustomFieldRef]

    func subtasks(taskID: String) async throws -> [ClickUpTask]

    func taskContent(taskID: String) async throws -> String?

    func listMembers(listID: String) async throws -> [ClickUpMember]

    func fieldCatalog(listID: String) async throws -> [ClickUpCustomFieldRef]

    func taskSignale(listID: String) async throws -> [ClickUpTaskSignale]
}

public extension ClickUpFetching {
    func tasks(listID: String, includeClosed: Bool) async throws -> [ClickUpTask] {
        try await tasks(listID: listID)
    }
    func projektMeta(listID: String) async throws -> ClickUpProjektMeta { .empty }
    func dependencies(taskID: String) async throws -> ClickUpTaskDependencies { .empty }
    func comments(taskID: String) async throws -> [ClickUpComment] { [] }
    func customFields(taskID: String) async throws -> [ClickUpCustomFieldRef] { [] }
    func subtasks(taskID: String) async throws -> [ClickUpTask] { [] }
    func taskContent(taskID: String) async throws -> String? { nil }
    func listMembers(listID: String) async throws -> [ClickUpMember] { [] }
    func fieldCatalog(listID: String) async throws -> [ClickUpCustomFieldRef] { [] }
    func taskSignale(listID: String) async throws -> [ClickUpTaskSignale] { [] }
}

public protocol ClickUpUserIdentifying: Sendable {
    func currentUser() async throws -> ClickUpUserInfo
}

public struct ClickUpUserInfo: Equatable, Sendable {
    public var id: String
    public var username: String
    public var email: String?

    public init(id: String, username: String, email: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
    }
}

public protocol ClickUpTaskWriting: Sendable {
    func createTask(listID: String, name: String, content: String?) async throws -> String

    func setStatus(taskID: String, status: String) async throws

    func updateTask(taskID: String, name: String?, dueDate: Date?, priority: ClickUpPriority?) async throws

    func assign(taskID: String, memberID: String) async throws

    func unassign(taskID: String, memberID: String) async throws

    func deleteTask(taskID: String) async throws

    func addDependency(taskID: String, otherTaskID: String, direction: ClickUpDependencyDirection) async throws

    func removeDependency(taskID: String, otherTaskID: String, direction: ClickUpDependencyDirection) async throws

    @discardableResult
    func addComment(taskID: String, text: String) async throws -> String

    func addTag(taskID: String, tagName: String) async throws

    func removeTag(taskID: String, tagName: String) async throws

    func setCustomFieldValue(taskID: String, fieldID: String, value: String) async throws

    func setCustomFieldBoolValue(taskID: String, fieldID: String, value: Bool) async throws

    func setCustomFieldDateValue(taskID: String, fieldID: String, value: Date) async throws

    func setCustomFieldDropdownValue(taskID: String, fieldID: String, optionID: String) async throws

    func setCustomFieldLabelsValue(taskID: String, fieldID: String, optionIDs: [String]) async throws

    @discardableResult
    func createSubtask(listID: String, parentTaskID: String, name: String) async throws -> String

    func moveTask(taskID: String, toListID: String) async throws
}

public protocol ClickUpListWriting: Sendable {
    func renameList(listID: String, name: String) async throws
}

public protocol ClickUpProjectProvisioning: Sendable {
    func findOrCreateList(folderID: String, name: String, content: String?) async throws -> String

    func createTask(listID: String, name: String) async throws -> String
}

public struct ClickUpClient: ClickUpFetching, ClickUpProjectProvisioning, ClickUpTaskWriting,
                              ClickUpListWriting, ClickUpUserIdentifying {
    private let credentialsStore: ClickUpCredentialsStoring
    private let session: URLSession
    private let baseURL = "https://api.clickup.com/api/v2"

    private let baseURLv3 = "https://api.clickup.com/api/v3"

    public init(
        credentialsStore: ClickUpCredentialsStoring = KeychainClickUpCredentialsStore(),
        session: URLSession = .shared
    ) {
        self.credentialsStore = credentialsStore
        self.session = session
    }

    public func tasks(listID: String) async throws -> [ClickUpTask] {
        try await tasks(listID: listID, includeClosed: false)
    }

    public func tasks(listID: String, includeClosed: Bool) async throws -> [ClickUpTask] {
        guard let credentials = try? credentialsStore.load() else {
            throw ClickUpError.notConnected
        }

        var alle: [ClickUpTask] = []
        for page in 0..<20 {
            guard let url = Self.buildTasksURL(baseURL: baseURL, listID: listID, page: page,
                                               includeClosed: includeClosed) else {
                throw ClickUpError.invalidResponse
            }
            var request = URLRequest(url: url)
            request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
            guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }

            let page = try Self.parseTasks(from: data)
            alle.append(contentsOf: page)
            if page.count < 100 { break }
        }
        return alle
    }

    private func tasksSeiteRoh(listID: String, page: Int) async throws -> (data: Data, count: Int) {
        guard let credentials = try? credentialsStore.load() else {
            throw ClickUpError.notConnected
        }
        guard let url = Self.buildTasksURL(baseURL: baseURL, listID: listID, page: page) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        return (data, (try Self.parseTasks(from: data)).count)
    }

    public func projektMeta(listID: String) async throws -> ClickUpProjektMeta {
        for page in 0..<20 {
            let page = try await tasksSeiteRoh(listID: listID, page: page)
            let meta = try ClickUpProjektCustomFieldMapper.parse(from: page.data)
            if meta.isEmpty == false { return meta }
            if page.count < 100 { break }
        }
        return .empty
    }

    public func taskSignale(listID: String) async throws -> [ClickUpTaskSignale] {
        var alle: [ClickUpTaskSignale] = []
        for page in 0..<20 {
            let page = try await tasksSeiteRoh(listID: listID, page: page)
            alle.append(contentsOf: try ClickUpTaskSignaleMapper.parse(from: page.data, listID: listID))
            if page.count < 100 { break }
        }
        return alle
    }

    public func findOrCreateList(folderID: String, name: String, content: String? = nil) async throws -> String {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }

        guard let listsURL = Self.buildFolderListsURL(baseURL: baseURL, folderID: folderID) else {
            throw ClickUpError.invalidResponse
        }
        var listRequest = URLRequest(url: listsURL)
        listRequest.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (listData, listResponse) = try await session.data(for: listRequest)
        guard let listHTTP = listResponse as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(listHTTP.statusCode) else { throw ClickUpError.httpError(listHTTP.statusCode) }
        if let existingID = try Self.parseListID(from: listData, matchingName: name) {
            return existingID
        }

        guard let createURL = Self.buildCreateListURL(baseURL: baseURL, folderID: folderID) else {
            throw ClickUpError.invalidResponse
        }
        var createRequest = URLRequest(url: createURL)
        createRequest.httpMethod = "POST"
        createRequest.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["name": name]
        if let content, content.isEmpty == false { body["content"] = content }
        createRequest.httpBody = try JSONEncoder().encode(body)
        let (createData, createResponse) = try await session.data(for: createRequest)
        guard let createHTTP = createResponse as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(createHTTP.statusCode) else { throw ClickUpError.httpError(createHTTP.statusCode) }
        guard let newID = try Self.parseCreatedID(from: createData) else { throw ClickUpError.decodingFailed }
        return newID
    }

    public func createTask(listID: String, name: String) async throws -> String {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildCreateTaskURL(baseURL: baseURL, listID: listID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["name": name])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        guard let newID = try Self.parseCreatedID(from: data) else { throw ClickUpError.decodingFailed }
        return newID
    }

    public func createTask(listID: String, name: String, content: String? = nil) async throws -> String {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildCreateTaskURL(baseURL: baseURL, listID: listID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["name": name]
        if let content, content.isEmpty == false { body["content"] = content }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        guard let newID = try Self.parseCreatedID(from: data) else { throw ClickUpError.decodingFailed }
        return newID
    }

    public func setStatus(taskID: String, status: String) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildUpdateTaskURL(baseURL: baseURL, taskID: taskID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["status": status])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    public func updateTask(taskID: String, name: String?, dueDate: Date?, priority: ClickUpPriority?) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildUpdateTaskURL(baseURL: baseURL, taskID: taskID) else {
            throw ClickUpError.invalidResponse
        }

        var body: [String: Any] = [:]
        if let name, name.isEmpty == false { body["name"] = name }
        if let dueDate { body["due_date"] = Int(dueDate.timeIntervalSince1970 * 1000) }
        if let priority { body["priority"] = Self.nativePriority(priority) }
        guard body.isEmpty == false else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    public func assign(taskID: String, memberID: String) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildUpdateTaskURL(baseURL: baseURL, taskID: taskID),
              let memberIDInt = Int(memberID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "assignees": ["add": [memberIDInt], "rem": []]
        ])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    public func unassign(taskID: String, memberID: String) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildUpdateTaskURL(baseURL: baseURL, taskID: taskID),
              let memberIDInt = Int(memberID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "assignees": ["add": [], "rem": [memberIDInt]]
        ])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    public func addTag(taskID: String, tagName: String) async throws {
        try await tagRequest(taskID: taskID, tagName: tagName, methode: "POST")
    }
    public func removeTag(taskID: String, tagName: String) async throws {
        try await tagRequest(taskID: taskID, tagName: tagName, methode: "DELETE")
    }
    private func tagRequest(taskID: String, tagName: String, methode: String) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildTagURL(baseURL: baseURL, taskID: taskID, tagName: tagName) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = methode
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    public func deleteTask(taskID: String) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildUpdateTaskURL(baseURL: baseURL, taskID: taskID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    public func dependencies(taskID: String) async throws -> ClickUpTaskDependencies {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        let refs = try await Self.parseDependencyRefs(from: fetchTaskDetailData(taskID: taskID, credentials: credentials), ownTaskID: taskID)
        guard refs.waitingOnIDs.isEmpty == false || refs.blockingIDs.isEmpty == false else { return .empty }

        async let waitingOn = resolveDependencyRefs(ids: refs.waitingOnIDs, credentials: credentials)
        async let blocking = resolveDependencyRefs(ids: refs.blockingIDs, credentials: credentials)
        return try await ClickUpTaskDependencies(waitingOn: waitingOn, blocking: blocking)
    }

    private func fetchTaskDetailData(taskID: String, credentials: ClickUpCredentials, includeSubtasks: Bool = false) async throws -> Data {
        guard let base = Self.buildUpdateTaskURL(baseURL: baseURL, taskID: taskID) else {
            throw ClickUpError.invalidResponse
        }
        var url = base
        if includeSubtasks {
            var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "include_subtasks", value: "true")]
            guard let withQuery = components?.url else { throw ClickUpError.invalidResponse }
            url = withQuery
        }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        return data
    }

    private func resolveDependencyRefs(ids: [String], credentials: ClickUpCredentials) async -> [ClickUpDependencyRef] {
        await withTaskGroup(of: ClickUpDependencyRef.self) { group in
            for id in ids {
                group.addTask {
                    guard let data = try? await self.fetchTaskDetailData(taskID: id, credentials: credentials),
                          let entity = try? JSONDecoder().decode(ClickUpTaskDetailEntity.self, from: data) else {
                        return ClickUpDependencyRef(id: id, name: id, status: "")
                    }
                    return ClickUpDependencyRef(id: id, name: entity.name, status: entity.status?.status ?? "")
                }
            }
            var out: [ClickUpDependencyRef] = []
            for await ref in group { out.append(ref) }
            return out.sorted { $0.name < $1.name }
        }
    }

    public func addDependency(taskID: String, otherTaskID: String, direction: ClickUpDependencyDirection) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildDependencyURL(baseURL: baseURL, taskID: taskID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let bodyKey = direction == .waitingOn ? "depends_on" : "dependency_of"
        request.httpBody = try JSONEncoder().encode([bodyKey: otherTaskID])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    public func removeDependency(taskID: String, otherTaskID: String, direction: ClickUpDependencyDirection) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let baseURL = Self.buildDependencyURL(baseURL: baseURL, taskID: taskID) else {
            throw ClickUpError.invalidResponse
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let queryKey = direction == .waitingOn ? "depends_on" : "dependency_of"
        components?.queryItems = [URLQueryItem(name: queryKey, value: otherTaskID)]
        guard let url = components?.url else { throw ClickUpError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    static func buildDependencyURL(baseURL: String, taskID: String) -> URL? {
        let encoded = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskID
        return URL(string: "\(baseURL)/task/\(encoded)/dependency")
    }

    public func comments(taskID: String) async throws -> [ClickUpComment] {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildCommentURL(baseURL: baseURL, taskID: taskID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        return try Self.parseComments(from: data)
    }

    @discardableResult
    public func addComment(taskID: String, text: String) async throws -> String {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildCommentURL(baseURL: baseURL, taskID: taskID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["comment_text": text, "notify_all": false])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        guard let newID = try Self.parseCreatedID(from: data) else { throw ClickUpError.decodingFailed }
        return newID
    }

    static func buildCommentURL(baseURL: String, taskID: String) -> URL? {
        let encoded = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskID
        return URL(string: "\(baseURL)/task/\(encoded)/comment")
    }

    public func customFields(taskID: String) async throws -> [ClickUpCustomFieldRef] {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        return try Self.parseCustomFields(from: try await fetchTaskDetailData(taskID: taskID, credentials: credentials))
    }

    public func taskContent(taskID: String) async throws -> String? {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        return try Self.parseTaskContent(from: try await fetchTaskDetailData(taskID: taskID, credentials: credentials))
    }

    static func parseTaskContent(from data: Data) throws -> String? {
        do {
            return try JSONDecoder().decode(ClickUpTaskDetailEntity.self, from: data).textContent
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    public func setCustomFieldValue(taskID: String, fieldID: String, value: String) async throws {
        try await postCustomFieldValue(taskID: taskID, fieldID: fieldID, body: JSONEncoder().encode(["value": value]))
    }

    public func setCustomFieldNumberValue(taskID: String, fieldID: String, value: Double) async throws {
        try await postCustomFieldValue(taskID: taskID, fieldID: fieldID, body: JSONEncoder().encode(["value": value]))
    }

    public func setCustomFieldBoolValue(taskID: String, fieldID: String, value: Bool) async throws {
        try await postCustomFieldValue(taskID: taskID, fieldID: fieldID, body: JSONEncoder().encode(["value": value]))
    }

    public func setCustomFieldDateValue(taskID: String, fieldID: String, value: Date) async throws {
        let epochMillis = Int(value.timeIntervalSince1970 * 1000)
        try await postCustomFieldValue(taskID: taskID, fieldID: fieldID, body: JSONEncoder().encode(["value": epochMillis]))
    }

    public func setCustomFieldDropdownValue(taskID: String, fieldID: String, optionID: String) async throws {
        try await postCustomFieldValue(taskID: taskID, fieldID: fieldID, body: JSONEncoder().encode(["value": optionID]))
    }

    public func setCustomFieldLabelsValue(taskID: String, fieldID: String, optionIDs: [String]) async throws {
        try await postCustomFieldValue(taskID: taskID, fieldID: fieldID, body: JSONEncoder().encode(["value": optionIDs]))
    }

    private func postCustomFieldValue(taskID: String, fieldID: String, body: Data) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildCustomFieldURL(baseURL: baseURL, taskID: taskID, fieldID: fieldID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    static func buildCustomFieldURL(baseURL: String, taskID: String, fieldID: String) -> URL? {
        let encodedTask = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskID
        let encodedField = fieldID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fieldID
        return URL(string: "\(baseURL)/task/\(encodedTask)/field/\(encodedField)")
    }

    static func parseCustomFields(from data: Data) throws -> [ClickUpCustomFieldRef] {
        do {
            let entity = try JSONDecoder().decode(ClickUpTaskDetailEntity.self, from: data)
            return (entity.customFields ?? []).map { field in
                ClickUpCustomFieldRef(
                    id: field.id ?? "", name: field.name ?? "", type: field.type ?? "",
                    rawValue: field.value?.displayString ?? "",
                    options: field.typeConfig?.mappedOptions ?? [])
            }
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    public func subtasks(taskID: String) async throws -> [ClickUpTask] {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        return try Self.parseSubtasks(from: try await fetchTaskDetailData(taskID: taskID, credentials: credentials, includeSubtasks: true))
    }

    @discardableResult
    public func createSubtask(listID: String, parentTaskID: String, name: String) async throws -> String {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildCreateTaskURL(baseURL: baseURL, listID: listID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["name": name, "parent": parentTaskID])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        guard let newID = try Self.parseCreatedID(from: data) else { throw ClickUpError.decodingFailed }
        return newID
    }

    static func parseSubtasks(from data: Data) throws -> [ClickUpTask] {
        do {
            let entity = try JSONDecoder().decode(ClickUpTaskDetailEntity.self, from: data)
            return (entity.subtasks ?? []).map(Self.task(from:))
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    public func moveTask(taskID: String, toListID: String) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        let workspaceID = try await resolveWorkspaceID(credentials: credentials)
        guard let url = Self.buildMoveTaskURL(baseURLv3: baseURLv3, workspaceID: workspaceID, taskID: taskID, listID: toListID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }

        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    public func listenPermalink(listID: String) async throws -> URL {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        let workspaceID = try await resolveWorkspaceID(credentials: credentials)
        guard let url = Self.buildListPermalink(workspaceID: workspaceID, listID: listID) else {
            throw ClickUpError.invalidResponse
        }
        return url
    }

    static func buildListPermalink(workspaceID: String, listID: String) -> URL? {
        let ws = workspaceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? workspaceID
        let li = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        guard ws.isEmpty == false, li.isEmpty == false else { return nil }
        return URL(string: "https://app.clickup.com/\(ws)/v/li/\(li)")
    }

    private func resolveWorkspaceID(credentials: ClickUpCredentials) async throws -> String {
        guard let url = URL(string: "\(baseURL)/team") else { throw ClickUpError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        guard let teamID = try Self.parseFirstTeamID(from: data) else { throw ClickUpError.decodingFailed }
        return teamID
    }

    static func buildMoveTaskURL(baseURLv3: String, workspaceID: String, taskID: String, listID: String) -> URL? {
        let encodedTask = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskID
        let encodedList = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        let encodedWorkspace = workspaceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? workspaceID
        return URL(string: "\(baseURLv3)/workspaces/\(encodedWorkspace)/tasks/\(encodedTask)/home_list/\(encodedList)")
    }

    static func parseFirstTeamID(from data: Data) throws -> String? {
        do {
            return try JSONDecoder().decode(ClickUpTeamsResponse.self, from: data).teams.first?.id
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    static func parseComments(from data: Data) throws -> [ClickUpComment] {
        do {
            let decoded = try JSONDecoder().decode(ClickUpCommentsResponse.self, from: data)
            return decoded.comments.map { entity in
                ClickUpComment(
                    id: entity.id ?? "",
                    text: entity.commentText ?? "",
                    authorName: entity.user?.username,
                    authorID: entity.user?.id.map(String.init),
                    postedAt: Self.date(fromEpochMillis: entity.date),
                    resolved: entity.resolved ?? false
                )
            }
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    static func parseDependencyRefs(from data: Data, ownTaskID: String) throws -> (waitingOnIDs: [String], blockingIDs: [String]) {
        do {
            let entity = try JSONDecoder().decode(ClickUpTaskDetailEntity.self, from: data)
            var waitingOnIDs: [String] = []
            var blockingIDs: [String] = []
            for dep in entity.dependencies ?? [] {
                guard let taskID = dep.taskID, let dependsOn = dep.dependsOn else { continue }
                if taskID == ownTaskID { waitingOnIDs.append(dependsOn) } else if dependsOn == ownTaskID { blockingIDs.append(taskID) }
            }
            return (waitingOnIDs, blockingIDs)
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    static func buildUpdateTaskURL(baseURL: String, taskID: String) -> URL? {
        let encoded = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskID
        return URL(string: "\(baseURL)/task/\(encoded)")
    }

    static func buildTagURL(baseURL: String, taskID: String, tagName: String) -> URL? {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let encTask = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? taskID
        guard let encTag = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "\(baseURL)/task/\(encTask)/tag/\(encTag)")
    }

    static func buildUpdateListURL(baseURL: String, listID: String) -> URL? {
        let encoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        return URL(string: "\(baseURL)/list/\(encoded)")
    }

    public func renameList(listID: String, name: String) async throws {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildUpdateListURL(baseURL: baseURL, listID: listID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["name": name])
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
    }

    static func nativePriority(_ priority: ClickUpPriority) -> Int {
        switch priority {
        case .urgent: 1
        case .high: 2
        case .normal: 3
        case .low: 4
        }
    }

    public func currentUser() async throws -> ClickUpUserInfo {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = URL(string: "\(baseURL)/user") else { throw ClickUpError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        return try Self.parseCurrentUser(from: data)
    }

    static func parseCurrentUser(from data: Data) throws -> ClickUpUserInfo {
        do {
            let decoded = try JSONDecoder().decode(CurrentUserResponse.self, from: data)
            return ClickUpUserInfo(id: String(decoded.user.id), username: decoded.user.username, email: decoded.user.email)
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    public func listMembers(listID: String) async throws -> [ClickUpMember] {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildListMembersURL(baseURL: baseURL, listID: listID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        return try Self.parseMembers(from: data)
    }

    static func buildListMembersURL(baseURL: String, listID: String) -> URL? {
        let encoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        return URL(string: "\(baseURL)/list/\(encoded)/member")
    }

    static func parseMembers(from data: Data) throws -> [ClickUpMember] {
        do {
            let decoded = try JSONDecoder().decode(ClickUpMembersResponse.self, from: data)
            return decoded.members.map { ClickUpMember(id: String($0.id), username: $0.username ?? "") }
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    public func fieldCatalog(listID: String) async throws -> [ClickUpCustomFieldRef] {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildFieldCatalogURL(baseURL: baseURL, listID: listID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        return try Self.parseFieldCatalog(from: data)
    }

    static func buildFieldCatalogURL(baseURL: String, listID: String) -> URL? {
        let encoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        return URL(string: "\(baseURL)/list/\(encoded)/field")
    }

    static func parseFieldCatalog(from data: Data) throws -> [ClickUpCustomFieldRef] {
        do {
            let decoded = try JSONDecoder().decode(ClickUpFieldCatalogResponse.self, from: data)
            return decoded.fields.map { field in
                ClickUpCustomFieldRef(
                    id: field.id ?? "", name: field.name ?? "", type: field.type ?? "", rawValue: "",
                    options: field.typeConfig?.mappedOptions ?? [])
            }
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    public func listName(forListID listID: String) async throws -> String? {
        guard let credentials = try? credentialsStore.load() else { throw ClickUpError.notConnected }
        guard let url = Self.buildListDetailURL(baseURL: baseURL, listID: listID) else {
            throw ClickUpError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClickUpError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw ClickUpError.httpError(http.statusCode) }
        return try Self.parseListName(from: data)
    }

    static func parseListName(from data: Data) throws -> String? {
        do {
            return try JSONDecoder().decode(ListDetailResponse.self, from: data).name
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    static func buildListDetailURL(baseURL: String, listID: String) -> URL? {
        let encoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        return URL(string: "\(baseURL)/list/\(encoded)")
    }

    static func buildTasksURL(baseURL: String, listID: String, page: Int = 0,
                              includeClosed: Bool = false) -> URL? {
        let encodedList = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        var components = URLComponents(string: "\(baseURL)/list/\(encodedList)/task")
        components?.queryItems = [
            URLQueryItem(name: "archived", value: "false"),

            URLQueryItem(name: "include_closed", value: String(includeClosed)),
            URLQueryItem(name: "subtasks", value: "false"),

            URLQueryItem(name: "page", value: String(page))
        ]
        return components?.url
    }

    static func parseTasks(from data: Data) throws -> [ClickUpTask] {
        do {
            let decoded = try JSONDecoder().decode(ClickUpTasksResponse.self, from: data)
            return decoded.tasks.map(Self.task(from:))
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    fileprivate static func task(from entity: ClickUpTaskEntity) -> ClickUpTask {
        let phaseIndex = entity.customFields?.first(where: { $0.name == "project_phase" })?.value
        var task = ClickUpTask(
            id: entity.id,
            name: entity.name,
            status: entity.status?.status ?? "",
            dueDate: Self.date(fromEpochMillis: entity.dueDate),
            startDate: Self.date(fromEpochMillis: entity.startDate),
            assignee: entity.assignees?.first?.username,
            assigneeID: entity.assignees?.first?.id.map(String.init),
            assigneeIDs: (entity.assignees ?? []).compactMap { $0.id.map(String.init) },
            assigneeNamen: Dictionary(
                (entity.assignees ?? []).compactMap { a in a.id.map { (String($0), a.username ?? "") } },
                uniquingKeysWith: { first, _ in first }),
            isUrgent: entity.priority?.priority?.lowercased() == "urgent",
            priority: ClickUpPriority(rawValue: entity.priority?.priority?.lowercased() ?? ""),
            projectPhase: phaseIndex.flatMap(ClickUpProjectPhase.init(rawValue:)),
            hasCustomFields: entity.customFields?.isEmpty == false,
            isMilestone: entity.customItemID == 1,
            statusType: entity.status?.type,
            tags: (entity.tags ?? []).compactMap { $0.name }
        )
        task.dueDateHatUhrzeit = entity.dueDateTime
        return task
    }

    public static func ankerTask(in tasks: [ClickUpTask]) throws -> ClickUpTask? {
        let benannte = tasks.filter { $0.name == ClickUpProjectTemplate.standardKundenprojekt[0] }
        guard benannte.count <= 1 else {
            throw ClickUpMehrdeutigFehler.ankerTask(
                name: ClickUpProjectTemplate.standardKundenprojekt[0], count: benannte.count)
        }
        if let benannt = benannte.first { return benannt }
        return tasks.first(where: \.hasCustomFields)
    }

    public static func projectPhase(from tasks: [ClickUpTask]) -> ClickUpProjectPhase? {
        (try? ankerTask(in: tasks))?.projectPhase
    }

    static func date(fromEpochMillis millis: String?) -> Date? {
        guard let millis, let value = Double(millis) else { return nil }
        return Date(timeIntervalSince1970: value / 1000.0)
    }

    static func buildFolderListsURL(baseURL: String, folderID: String) -> URL? {
        let encoded = folderID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? folderID
        return URL(string: "\(baseURL)/folder/\(encoded)/list")
    }

    static func buildCreateListURL(baseURL: String, folderID: String) -> URL? {
        let encoded = folderID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? folderID
        return URL(string: "\(baseURL)/folder/\(encoded)/list")
    }

    static func buildCreateTaskURL(baseURL: String, listID: String) -> URL? {
        let encoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        return URL(string: "\(baseURL)/list/\(encoded)/task")
    }

    static func parseListID(from data: Data, matchingName: String) throws -> String? {
        do {
            let decoded = try JSONDecoder().decode(ClickUpListsResponse.self, from: data)
            return decoded.lists.first { $0.name == matchingName }?.id
        } catch {
            throw ClickUpError.decodingFailed
        }
    }

    static func parseCreatedID(from data: Data) throws -> String? {
        do {
            return try JSONDecoder().decode(ClickUpCreatedEntity.self, from: data).id
        } catch {
            throw ClickUpError.decodingFailed
        }
    }
}

private struct ClickUpListsResponse: Decodable {
    var lists: [ClickUpListEntity]
    struct ClickUpListEntity: Decodable { var id: String; var name: String }
}

private struct ClickUpCreatedEntity: Decodable { var id: String }

private struct ListDetailResponse: Decodable {
    var name: String?
}

private struct ClickUpMembersResponse: Decodable {
    var members: [MemberEntity]
    struct MemberEntity: Decodable { var id: Int; var username: String? }
}

private struct ClickUpFieldCatalogResponse: Decodable {
    var fields: [FieldEntity]
    struct FieldEntity: Decodable {
        var id: String?
        var name: String?
        var type: String?
        var typeConfig: TypeConfigEntity?
        enum CodingKeys: String, CodingKey { case id, name, type; case typeConfig = "type_config" }
    }
}

private struct CurrentUserResponse: Decodable {
    var user: UserEntity
    struct UserEntity: Decodable { var id: Int; var username: String; var email: String? }
}

private struct ClickUpTeamsResponse: Decodable {
    var teams: [TeamEntity]
    struct TeamEntity: Decodable { var id: String }
}

private struct ClickUpTasksResponse: Decodable {
    var tasks: [ClickUpTaskEntity]
}

private struct ClickUpTaskEntity: Decodable {
    var id: String
    var name: String
    var status: StatusEntity?
    var dueDate: String?
    var dueDateTime: Bool?
    var startDate: String?
    var priority: PriorityEntity?
    var assignees: [AssigneeEntity]?
    var customFields: [CustomFieldEntity]?
    var customItemID: Int?
    var tags: [TagEntity]?

    enum CodingKeys: String, CodingKey {
        case id, name, status, priority, assignees, tags
        case dueDate = "due_date"
        case dueDateTime = "due_date_time"
        case startDate = "start_date"
        case customFields = "custom_fields"
        case customItemID = "custom_item_id"
    }

    struct StatusEntity: Decodable { var status: String?; var type: String? }
    struct PriorityEntity: Decodable { var priority: String? }
    struct AssigneeEntity: Decodable { var id: Int?; var username: String? }
    struct TagEntity: Decodable { var name: String? }

    struct CustomFieldEntity: Decodable {
        var name: String
        var value: Int?

        private enum CodingKeys: String, CodingKey { case name, value }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            value = try? container.decode(Int.self, forKey: .value)
        }
    }
}

private struct ClickUpTaskDetailEntity: Decodable {
    var name: String
    var status: StatusEntity?
    var dependencies: [DependencyEntity]?
    var customFields: [CustomFieldDetailEntity]?
    var subtasks: [ClickUpTaskEntity]?

    var textContent: String?

    enum CodingKeys: String, CodingKey {
        case name, status, dependencies, subtasks
        case customFields = "custom_fields"
        case textContent = "text_content"
    }

    struct StatusEntity: Decodable { var status: String? }

    struct DependencyEntity: Decodable {
        var taskID: String?
        var dependsOn: String?

        enum CodingKeys: String, CodingKey {
            case taskID = "task_id"
            case dependsOn = "depends_on"
        }
    }

    struct CustomFieldDetailEntity: Decodable {
        var id: String?
        var name: String?
        var type: String?
        var value: ClickUpAnyValue?
        var typeConfig: TypeConfigEntity?
        enum CodingKeys: String, CodingKey { case id, name, type, value; case typeConfig = "type_config" }
    }
}

struct TypeConfigEntity: Decodable {
    var options: [OptionEntity]?

    struct OptionEntity: Decodable {
        var id: String?
        var name: String?
        var label: String?
        var orderindex: Int?

        enum CodingKeys: String, CodingKey { case id, name, label, orderindex }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try? c.decode(String.self, forKey: .id)
            name = try? c.decode(String.self, forKey: .name)
            label = try? c.decode(String.self, forKey: .label)
            orderindex = try? c.decode(Int.self, forKey: .orderindex)
        }
    }

    var mappedOptions: [ClickUpFieldOption] {
        (options ?? []).compactMap { opt in
            guard let id = opt.id else { return nil }
            return ClickUpFieldOption(id: id, name: opt.name ?? opt.label ?? "", orderindex: opt.orderindex)
        }
    }
}

struct ClickUpAnyValue: Decodable {
    let displayString: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) { displayString = s; return }
        if let n = try? container.decode(Double.self) {
            displayString = n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
            return
        }
        if let b = try? container.decode(Bool.self) { displayString = b ? "true" : "false"; return }
        if let arr = try? container.decode([String].self) { displayString = arr.joined(separator: ", "); return }
        displayString = ""
    }
}

private struct ClickUpCommentsResponse: Decodable {
    var comments: [ClickUpCommentEntity]
}

private struct ClickUpCommentEntity: Decodable {
    var id: String?
    var commentText: String?
    var user: UserEntity?
    var date: String?
    var resolved: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case commentText = "comment_text"
        case user, date, resolved
    }

    struct UserEntity: Decodable { var id: Int?; var username: String? }
}
