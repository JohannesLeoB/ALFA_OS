import Assistant
import Core
import Foundation
import Hub

public struct ClockodoClient: MasterDataPort, BookingPort, TimeEntryPort {
    static let root = "https://my.clockodo.com/api/v2"

    private let credentials: any CredentialsPort
    private let http: any HttpPort
    private let userID: Int?
    private let clock: @Sendable () -> Date

    public init(
        credentials: any CredentialsPort, http: any HttpPort, userID: Int? = nil,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.credentials = credentials
        self.http = http
        self.userID = userID
        self.clock = clock
    }

    public func check(userID: Int?, now: Date) async throws {
        let span = Period.today.span(now: now)
        let query = Self.entryQuery(since: span.since, until: span.until, userID: userID, page: 1)
        let _: (items: [EntryParser], pageCount: Int) = try await page(path: "entries", key: "entries", query: query)
    }

    public func customers() async throws -> [TimeCustomer] {
        let items: [EntryParser.Customer] = try await all(path: "customers", key: "customers")
        return EntryParser.customers(items)
    }

    public func projects() async throws -> [TimeProject] {
        let items: [EntryParser.Project] = try await all(path: "projects", key: "projects")
        return EntryParser.projects(items)
    }

    public func activities() async throws -> [TimeActivity] {
        let items: [EntryParser.Activity] = try await all(path: "services", key: "services")
        return EntryParser.activities(items)
    }

    public func entries(since: Date, until: Date, userID: Int? = nil) async throws -> [TimeEntry] {
        let items: [EntryParser] = try await all(path: "entries", key: "entries") { page in
            Self.entryQuery(since: since, until: until, userID: userID, page: page)
        }
        return EntryParser.entries(items)
    }

    func createEntry(
        customerID: Int, activityID: Int, projectID: Int?, since: Date, until: Date, billable: Bool, text: String?,
        confirmed: Bool
    ) async throws -> String {
        try Self.assertConfirmed(confirmed)
        let body = EntryParser.createBody(
            customerID: customerID, activityID: activityID, projectID: projectID, since: since, until: until,
            billable: billable, text: text)
        return try EntryParser.createdID(from: try await send("POST", path: "entries", body: body))
    }

    func deleteEntry(id: Int, confirmed: Bool) async throws {
        try Self.assertConfirmed(confirmed)
        _ = try await send("DELETE", path: "entries/\(id)")
    }

    func updateText(id: Int, text: String, confirmed: Bool) async throws {
        try await update(id: id, fields: ["text": text], confirmed: confirmed)
    }

    func setBillable(id: Int, billable: Bool, confirmed: Bool) async throws {
        try await update(id: id, fields: ["billable": billable ? 1 : 0], confirmed: confirmed)
    }

    public func report(period: TimePeriod) async -> TimeReport {
        var failure: String?
        var customers: [TimeCustomer] = []
        var activities: [TimeActivity] = []
        do {
            async let loadedCustomers = self.customers()
            async let loadedActivities = self.activities()
            customers = try await loadedCustomers.filter(\.isActive)
            activities = try await loadedActivities.filter(\.isActive)
        } catch {
            failure = Self.detail(error)
        }
        let span = Period(period).span(now: clock())
        let entries: [TimeEntry]
        do {
            entries = try await self.entries(since: span.since, until: span.until, userID: userID).sorted { $0.start > $1.start }
        } catch {
            return TimeReport(entries: [], error: Self.detail(error))
        }
        let rows = entries.map { entry in
            TimeReport.Entry(
                start: entry.start,
                customer: customers.first { $0.id == entry.customerID }?.name ?? String(entry.customerID),
                service: activities.first { $0.id == entry.activityID }?.name ?? String(entry.activityID),
                seconds: entry.seconds,
                note: entry.text)
        }
        return TimeReport(entries: rows, error: rows.isEmpty ? failure : nil)
    }

    static func entryQuery(since: Date, until: Date, userID: Int?, page: Int) -> [URLQueryItem] {
        var query = [
            URLQueryItem(name: "time_since", value: EntryParser.timestamp(since)),
            URLQueryItem(name: "time_until", value: EntryParser.timestamp(until)),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if let userID { query.append(URLQueryItem(name: "filter[users_id]", value: String(userID))) }
        return query
    }

    static func detail(_ error: any Error) -> String {
        (error as? RequestFailure)?.detail ?? error.localizedDescription
    }

    private static func assertConfirmed(_ confirmed: Bool) throws {
        guard confirmed else { throw WriteFailure.unconfirmed }
    }

    private func update(id: Int, fields: [String: Any], confirmed: Bool) async throws {
        try Self.assertConfirmed(confirmed)
        let body = try? JSONSerialization.data(withJSONObject: fields)
        _ = try await send("PUT", path: "entries/\(id)", body: body)
    }

    private func all<T: Decodable>(
        path: String, key: String, query: (Int) -> [URLQueryItem] = { [URLQueryItem(name: "page", value: String($0))] }
    ) async throws -> [T] {
        var page = 1
        var collected: [T] = []
        while true {
            let (items, pageCount): ([T], Int) = try await self.page(path: path, key: key, query: query(page))
            collected += items
            if page >= pageCount { return collected }
            page += 1
        }
    }

    private func page<T: Decodable>(path: String, key: String, query: [URLQueryItem]) async throws -> (items: [T], pageCount: Int) {
        try EntryParser.page(from: try await send("GET", path: path, query: query), key: key)
    }

    private func send(_ method: String, path: String, query: [URLQueryItem] = [], body: Data? = nil) async throws -> Data {
        guard let held = try? credentials.load() else { throw RequestFailure.notConnected }
        guard var components = URLComponents(string: Self.root + "/" + path) else { throw RequestFailure.invalidResponse }
        if query.isEmpty == false { components.queryItems = query }
        guard let url = components.url else { throw RequestFailure.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(held.email, forHTTPHeaderField: "X-ClockodoApiUser")
        request.setValue(held.key, forHTTPHeaderField: "X-ClockodoApiKey")
        request.setValue("\(AppIdentity.name);\(held.email)", forHTTPHeaderField: "X-Clockodo-External-Application")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        let (data, response) = try await http.data(for: request)
        guard let status = response as? HTTPURLResponse else { throw RequestFailure.invalidResponse }
        guard (200...299).contains(status.statusCode) else { throw RequestFailure.http(status.statusCode) }
        return data
    }
}

public struct ConnectionCheck: ConnectionCheckPort {
    private let http: any HttpPort
    private let clock: @Sendable () -> Date

    public init(http: any HttpPort, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.http = http
        self.clock = clock
    }

    public var integration: String { "clockodo" }

    public func check(_ values: KeyValues) async throws -> String? {
        var user: Int?
        if values["user"].isEmpty == false {
            guard let number = Int(values["user"]) else { throw KeyFieldFailure(field: "user") }
            user = number
        }
        let client = ClockodoClient(
            credentials: HeldCredentials(credentials: Credentials(email: values["email"], key: values["key"])), http: http)
        do {
            try await client.check(userID: user, now: clock())
        } catch let failure as RequestFailure {
            throw Self.translate(failure)
        }
        return values["email"]
    }

    static func translate(_ failure: RequestFailure) -> any Error {
        switch failure {
        case .http(let code): StatusFailure(status: code)
        case .invalidResponse, .decoding: ShapeFailure()
        case .notConnected: failure
        }
    }

    private struct HeldCredentials: CredentialsPort {
        let credentials: Credentials

        func load() throws -> Credentials? { credentials }
    }

    private struct StatusFailure: StatusErrorPort {
        let status: Int
    }

    private struct ShapeFailure: ShapeErrorPort {}
}
