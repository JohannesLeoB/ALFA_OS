import Assistant
import Foundation
import Hub
import Storage
import XCTest
@testable import Clockodo

private final class Script: @unchecked Sendable {
    private let lock = NSLock()
    private var replies: [(path: String?, status: Int, body: String)]
    private var sent: [URLRequest] = []

    init(_ replies: [(Int, String)]) { self.replies = replies.map { (nil, $0.0, $0.1) } }

    init(routes: [(String, Int, String)]) { replies = routes.map { ($0.0, $0.1, $0.2) } }

    func next(_ request: URLRequest) -> (Int, String) {
        lock.lock(); defer { lock.unlock() }
        sent.append(request)
        let path = request.url?.lastPathComponent
        guard let index = replies.firstIndex(where: { $0.path == nil || $0.path == path }) else { return (200, "{}") }
        let reply = replies.remove(at: index)
        return (reply.status, reply.body)
    }

    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return sent
    }
}

private struct FakeHttp: HttpPort {
    let script: Script

    init(_ replies: [(Int, String)] = []) { script = Script(replies) }

    init(routes: [(String, Int, String)]) { script = Script(routes: routes) }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (status, body) = script.next(request)
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse) {
        throw RequestFailure.invalidResponse
    }
}

private struct FakeCredentials: CredentialsPort {
    var value: Credentials? = Credentials(email: "a@x", key: "k1")

    func load() throws -> Credentials? { value }
}

private final class FakeKeychain: KeychainPort, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [KeySlot: String] = [:]

    func put(_ value: String, at slot: KeySlot) throws { lock.lock(); items[slot] = value; lock.unlock() }
    func get(_ slot: KeySlot) throws -> String? { lock.lock(); defer { lock.unlock() }; return items[slot] }
    func delete(_ slot: KeySlot) throws { lock.lock(); items[slot] = nil; lock.unlock() }
}

private final class FakeBooking: BookingPort, @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String] = []

    var calls: [String] { lock.withLock { log } }

    func createEntry(
        customerID: Int, activityID: Int, projectID: Int?, since: Date, until: Date, billable: Bool, text: String?,
        confirmed: Bool
    ) async throws -> String {
        lock.withLock { log.append("create \(customerID) \(activityID) \(projectID.map(String.init) ?? "-") \(text ?? "-")") }
        guard confirmed else { throw WriteFailure.unconfirmed }
        return "e1"
    }

    func deleteEntry(id: Int, confirmed: Bool) async throws {
        lock.withLock { log.append("delete \(id)") }
        guard confirmed else { throw WriteFailure.unconfirmed }
    }

    func updateText(id: Int, text: String, confirmed: Bool) async throws {
        lock.withLock { log.append("text \(id) \(text)") }
    }

    func setBillable(id: Int, billable: Bool, confirmed: Bool) async throws {
        lock.withLock { log.append("billable \(id) \(billable)") }
    }
}

private struct FakeMasterData: MasterDataPort {
    var customersResult: [TimeCustomer] = [TimeCustomer(id: 1, name: "Zed"), TimeCustomer(id: 2, name: "Ann")]
    var projectsResult: [TimeProject] = [TimeProject(id: 5, customerID: 1, name: "P")]
    var activitiesResult: [TimeActivity] = [TimeActivity(id: 9, name: "Plan")]
    var entriesResult: [TimeEntry] = []

    func customers() async throws -> [TimeCustomer] { customersResult }
    func projects() async throws -> [TimeProject] { projectsResult }
    func activities() async throws -> [TimeActivity] { activitiesResult }
    func entries(since: Date, until: Date, userID: Int?) async throws -> [TimeEntry] { entriesResult }
}

private let now = Date(timeIntervalSince1970: 1_700_000_000)

private func client(
    _ replies: [(Int, String)] = [], routes: [(String, Int, String)] = [], userID: Int? = nil,
    credentials: FakeCredentials = FakeCredentials()
) -> (ClockodoClient, Script) {
    let http = routes.isEmpty ? FakeHttp(replies) : FakeHttp(routes: routes)
    return (ClockodoClient(credentials: credentials, http: http, userID: userID, clock: { now }), http.script)
}

private func entryJSON(_ id: Int, customer: Int = 1, activity: Int = 9, since: String = "2023-11-14T10:00:00Z",
                       duration: Int? = 3600, billable: Int? = 1, text: String? = nil) -> String {
    var fields = [#""id":\#(id)"#, #""customers_id":\#(customer)"#, #""services_id":\#(activity)"#, #""time_since":"\#(since)""#]
    if let duration { fields.append(#""duration":\#(duration)"#) }
    if let billable { fields.append(#""billable":\#(billable)"#) }
    if let text { fields.append(#""text":"\#(text)""#) }
    return "{" + fields.joined(separator: ",") + "}"
}

private func page(_ key: String, _ items: [String], pages: Int = 1) -> String {
    #"{"\#(key)":[\#(items.joined(separator: ","))],"paging":{"count_pages":\#(pages)}}"#
}

final class ClockodoTests: XCTestCase {
    func testRequestsCarryTheThreeHeaders() async throws {
        let (api, script) = client([(200, page("customers", [#"{"id":1,"name":"Ann","active":false}"#, #"{"id":2,"name":"Bob"}"#]))])
        let customers = try await api.customers()
        XCTAssertEqual(customers, [TimeCustomer(id: 1, name: "Ann", isActive: false), TimeCustomer(id: 2, name: "Bob")])
        let request = script.requests[0]
        XCTAssertEqual(request.url?.absoluteString, "https://my.clockodo.com/api/v2/customers?page=1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-ClockodoApiUser"), "a@x")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-ClockodoApiKey"), "k1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Clockodo-External-Application"), "ALFA_OS;a@x")
    }

    func testOnePaginationLoopServesEveryList() async throws {
        let (api, script) = client([
            (200, page("projects", [#"{"id":1,"name":"A","customers_id":7}"#], pages: 2)),
            (200, page("projects", [#"{"id":2,"name":"B","customers_id":8,"active":false}"#], pages: 2)),
            (200, page("services", [#"{"id":3,"name":"S"}"#])),
        ])
        let projects = try await api.projects()
        XCTAssertEqual(projects, [TimeProject(id: 1, customerID: 7, name: "A"), TimeProject(id: 2, customerID: 8, name: "B", isActive: false)])
        XCTAssertEqual(script.requests.map { $0.url?.query }, ["page=1", "page=2"])
        let activities = try await api.activities()
        XCTAssertEqual(activities, [TimeActivity(id: 3, name: "S")])
    }

    func testEntriesQueryAndMapping() async throws {
        let (api, script) = client([(200, page("entries", [entryJSON(4, billable: 0, text: "hi"), entryJSON(5, duration: nil, billable: nil)]))])
        let entries = try await api.entries(since: Date(timeIntervalSince1970: 0), until: now, userID: 77)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0], TimeEntry(
            id: 4, customerID: 1, projectID: nil, activityID: 9, text: "hi", start: Date(timeIntervalSince1970: 1_699_956_000),
            seconds: 3600, billable: false))
        XCTAssertEqual(entries[1].seconds, 0)
        XCTAssertTrue(entries[1].billable)
        let query = script.requests[0].url!.absoluteString
        XCTAssertTrue(query.contains("time_since=1970-01-01T00:00:00Z"))
        XCTAssertTrue(query.contains("time_until=2023-11-14T22:13:20Z"))
        XCTAssertTrue(query.contains("filter%5Busers_id%5D=77") || query.contains("filter[users_id]=77"))
    }

    func testFailuresAreTyped() async {
        let cases: [(ClockodoClient, RequestFailure)] = [
            (client(credentials: FakeCredentials(value: nil)).0, .notConnected),
            (client([(401, "")]).0, .http(401)),
            (client([(200, "[1]")]).0, .decoding),
            (client([(200, #"{"data":[{"id":"x"}]}"#)]).0, .decoding),
        ]
        for (api, expected) in cases {
            do {
                _ = try await api.customers()
                XCTFail("expected failure")
            } catch { XCTAssertEqual(error as? RequestFailure, expected) }
        }
    }

    func testWritesNeedConfirmationAndSendNothingWithout() async throws {
        let (api, script) = client([(200, #"{"entry":{"id":321}}"#), (200, "{}"), (200, "{}"), (200, "{}")])
        do {
            _ = try await api.createEntry(
                customerID: 1, activityID: 2, projectID: nil, since: now, until: now, billable: true, text: nil, confirmed: false)
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? WriteFailure, .unconfirmed) }
        for call in [
            { try await api.deleteEntry(id: 1, confirmed: false) },
            { try await api.updateText(id: 1, text: "t", confirmed: false) },
            { try await api.setBillable(id: 1, billable: true, confirmed: false) },
        ] {
            do {
                try await call()
                XCTFail("expected failure")
            } catch { XCTAssertEqual(error as? WriteFailure, .unconfirmed) }
        }
        XCTAssertTrue(script.requests.isEmpty)
        XCTAssertEqual(WriteFailure.unconfirmed.key, "clockodo.write.unconfirmed")

        let id = try await api.createEntry(
            customerID: 1, activityID: 2, projectID: 3, since: now, until: now, billable: false, text: " x ", confirmed: true)
        XCTAssertEqual(id, "321")
        try await api.deleteEntry(id: 5, confirmed: true)
        try await api.updateText(id: 5, text: "new", confirmed: true)
        try await api.setBillable(id: 5, billable: true, confirmed: true)
        let sent = script.requests
        XCTAssertEqual(sent.map(\.httpMethod), ["POST", "DELETE", "PUT", "PUT"])
        XCTAssertEqual(sent[0].url?.absoluteString, "https://my.clockodo.com/api/v2/entries")
        let body = try JSONSerialization.jsonObject(with: sent[0].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(body?["customers_id"] as? Int, 1)
        XCTAssertEqual(body?["services_id"] as? Int, 2)
        XCTAssertEqual(body?["projects_id"] as? Int, 3)
        XCTAssertEqual(body?["billable"] as? Int, 0)
        XCTAssertEqual(body?["text"] as? String, " x ")
        XCTAssertEqual(sent[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(sent[1].url?.path, "/api/v2/entries/5")
        let text = try JSONSerialization.jsonObject(with: sent[2].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(text?["text"] as? String, "new")
        let billable = try JSONSerialization.jsonObject(with: sent[3].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(billable?["billable"] as? Int, 1)
    }

    func testCreateBodyOmitsBlankTextAndProject() throws {
        let data = EntryParser.createBody(customerID: 1, activityID: 2, projectID: nil, since: now, until: now, billable: true, text: "  ")
        let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNil(body?["text"])
        XCTAssertNil(body?["projects_id"])
        XCTAssertThrowsError(try EntryParser.createdID(from: Data("{}".utf8)))
    }

    func testReportNamesCustomersAndSortsNewestFirst() async {
        let (api, script) = client(routes: [
            ("customers", 200, page("customers", [#"{"id":1,"name":"Ann"}"#, #"{"id":2,"name":"Off","active":false}"#])),
            ("services", 200, page("services", [#"{"id":9,"name":"Plan"}"#])),
            ("entries", 200, page("entries", [
                entryJSON(1, since: "2023-11-14T08:00:00Z", duration: 1800),
                entryJSON(2, customer: 2, activity: 77, since: "2023-11-14T12:00:00Z", duration: 600, text: "n"),
            ])),
        ], userID: 5)
        let report = await api.report(period: .week)
        XCTAssertNil(report.error)
        XCTAssertEqual(report.entries.map(\.seconds), [600, 1800])
        XCTAssertEqual(report.entries[0].customer, "2")
        XCTAssertEqual(report.entries[0].service, "77")
        XCTAssertEqual(report.entries[0].note, "n")
        XCTAssertEqual(report.entries[1].customer, "Ann")
        XCTAssertEqual(report.entries[1].service, "Plan")
        XCTAssertTrue(script.requests.contains { $0.url!.absoluteString.contains("users_id") })
    }

    func testReportFailureOnlyShowsWhenNothingToList() async {
        let failing = await client(routes: [("customers", 500, ""), ("services", 500, ""), ("entries", 500, "")]).0
            .report(period: .today)
        XCTAssertEqual(failing.entries, [])
        XCTAssertEqual(failing.error, "http 500")

        let masterOnly = await client(routes: [("customers", 500, ""), ("services", 500, ""), ("entries", 200, page("entries", []))]).0
            .report(period: .today)
        XCTAssertEqual(masterOnly.error, "http 500")

        let withEntries = await client(
            routes: [("customers", 500, ""), ("services", 500, ""), ("entries", 200, page("entries", [entryJSON(1)]))]
        ).0.report(period: .today)
        XCTAssertNil(withEntries.error)
        XCTAssertEqual(withEntries.entries.count, 1)
    }

    func testPeriodSpans() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let wednesday = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(Period.today.span(now: wednesday, calendar: calendar).since, Date(timeIntervalSince1970: 1_699_920_000))
        XCTAssertEqual(Period.week.span(now: wednesday, calendar: calendar).since, Date(timeIntervalSince1970: 1_699_833_600))
        XCTAssertEqual(Period.month.span(now: wednesday, calendar: calendar).since, Date(timeIntervalSince1970: 1_698_796_800))
        XCTAssertEqual(Period.month.span(now: wednesday, calendar: calendar).until, wednesday)
        XCTAssertEqual(Period(.today), .today)
        XCTAssertEqual(Period(.week), .week)
        XCTAssertEqual(Period(.month), .month)
    }

    func testBookingEngineResolvesOrNamesTheMissingPart() {
        let centers = [CostCenter(name: "Plan", clockodoServiceID: 9), CostCenter(name: "Blank")]
        let projects = [
            BookingEngine.Project(number: "P1", customerNumber: " K1 "),
            BookingEngine.Project(number: "P2", customerNumber: " "),
            BookingEngine.Project(number: "P3", customerNumber: "K2"),
            BookingEngine.Project(number: "P4", customerNumber: "K3"),
        ]
        let customers = [
            BookingEngine.Customer(number: "K1", name: "Ann", clockodoID: 4),
            BookingEngine.Customer(number: "K3", name: "Lost", clockodoID: nil),
        ]
        func resolve(_ project: String, _ center: String) -> Result<BookingTarget, BookingFailure> {
            BookingEngine.resolve(
                projectNumber: project, costCenter: center, projects: projects, customers: customers, costCenters: centers)
        }
        XCTAssertEqual(try resolve("P1", "Plan").get(), BookingTarget(customerID: 4, activityID: 9))
        XCTAssertEqual(resolve("P1", "Nope"), .failure(.unknownCostCenter("Nope")))
        XCTAssertEqual(resolve("P1", "Blank"), .failure(.costCenterWithoutServiceID("Blank")))
        XCTAssertEqual(resolve("P9", "Plan"), .failure(.projectNotFound("P9")))
        XCTAssertEqual(resolve("P2", "Plan"), .failure(.projectWithoutCustomer("P2")))
        XCTAssertEqual(resolve("P3", "Plan"), .failure(.customerNotFound("K2")))
        XCTAssertEqual(resolve("P4", "Plan"), .failure(.customerWithoutClockodoID("Lost")))
        XCTAssertEqual(BookingFailure.projectNotFound("P9").key, "clockodo.booking.projectNotFound")
        XCTAssertEqual(BookingFailure.projectNotFound("P9").argument, "P9")
    }

    func testConnectionCheckValidatesUserAndMapsStatus() async throws {
        let values = KeyValues(values: ["email": "a@x", "key": "k1", "user": "12"])
        let http = FakeHttp([(200, page("entries", []))])
        let account = try await ConnectionCheck(http: http, clock: { now }).check(values)
        XCTAssertEqual(account, "a@x")
        XCTAssertEqual(http.script.requests.count, 1)
        XCTAssertTrue(http.script.requests[0].url!.absoluteString.contains("users_id"))

        do {
            _ = try await ConnectionCheck(http: FakeHttp()).check(KeyValues(values: ["email": "a@x", "key": "k1", "user": "abc"]))
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? KeyFieldFailure, KeyFieldFailure(field: "user")) }

        do {
            _ = try await ConnectionCheck(http: FakeHttp([(403, "")])).check(KeyValues(values: ["email": "a@x", "key": "k1"]))
            XCTFail("expected failure")
        } catch let error as any StatusErrorPort { XCTAssertEqual(error.status, 403) }
        XCTAssertTrue(ConnectionCheck.translate(.decoding) is any ShapeErrorPort)
        XCTAssertEqual(ConnectionCheck.translate(.notConnected) as? RequestFailure, .notConnected)
        XCTAssertEqual(ConnectionCheck(http: http).integration, "clockodo")
    }

    func testCredentialsStoreNeedsBothSlots() throws {
        let keychain = FakeKeychain()
        let store = CredentialsStore(keychain: keychain, inlet: "clockodo")
        try keychain.put("a@x", at: KeySlot(inlet: "clockodo", name: "email"))
        XCTAssertNil(try store.load())
        try keychain.put("k1", at: KeySlot(inlet: "clockodo", name: "key"))
        XCTAssertEqual(try store.load(), Credentials(email: "a@x", key: "k1"))
    }

    func testBookedRowStoreIsPerUser() throws {
        let store = BookedRowStore(database: try SQLiteStore.inMemory())
        let row = UUID()
        XCTAssertEqual(try store.bookedIDs(userID: "u1"), [])
        try store.mark(rowID: row, entryID: "e1", userID: "u1")
        XCTAssertEqual(try store.bookedIDs(userID: "u1"), [row])
        XCTAssertEqual(try store.bookedIDs(userID: "u2"), [])
        XCTAssertThrowsError(try store.mark(rowID: row, entryID: "e2", userID: "u1"))
    }

    @MainActor
    private func state(
        master: FakeMasterData = FakeMasterData(), booking: FakeBooking = FakeBooking(),
        centers: [CostCenter] = [CostCenter(name: "Plan", clockodoServiceID: 9)]
    ) throws -> TimeTableState {
        TimeTableState(
            masterData: master, booking: booking, booked: BookedRowStore(database: try SQLiteStore.inMemory()),
            userID: "u1", costCenters: centers)
    }

    @MainActor
    func testStateLoadsSortedActiveMasterDataAndLabels() async throws {
        var master = FakeMasterData()
        master.customersResult.append(TimeCustomer(id: 3, name: "Gone", isActive: false))
        master.entriesResult = [
            TimeEntry(id: 1, customerID: 1, projectID: nil, activityID: 9, text: nil, start: Date(timeIntervalSince1970: 1), seconds: 5),
            TimeEntry(id: 2, customerID: 3, projectID: nil, activityID: 4, text: nil, start: Date(timeIntervalSince1970: 2), seconds: 5),
        ]
        let table = try state(master: master)
        await table.loadMasterData()
        await table.loadEntries(now: now)
        XCTAssertEqual(table.customers.map(\.name), ["Ann", "Zed"])
        XCTAssertNil(table.masterDataFailure)
        XCTAssertEqual(table.entries.map(\.id), [2, 1])
        XCTAssertEqual(table.label(for: table.entries[1]).customer, "Zed")
        XCTAssertEqual(table.label(for: table.entries[1]).activity, "Plan")
        XCTAssertEqual(table.label(for: table.entries[0]).customer, "3")
        XCTAssertEqual(table.projects(forCustomer: 1).map(\.id), [5])
        XCTAssertEqual(table.projects(forCustomer: nil), [])
    }

    @MainActor
    func testStateBooksManualRowOnceAndRemembersIt() async throws {
        let booking = FakeBooking()
        let table = try state(booking: booking)
        table.addManualRow()
        var slice = table.manualRows[0]
        slice.start = now
        slice.end = now.addingTimeInterval(60)
        slice.customerID = 1
        slice.activityID = 9
        slice.text = "  "
        await table.book(slice, projects: [], customers: [], confirmed: true)
        await table.book(slice, projects: [], customers: [], confirmed: true)
        XCTAssertEqual(booking.calls, ["create 1 9 - -"])
        XCTAssertTrue(table.isBooked(slice.id))
        if case .saved = table.rowStates[slice.id] {} else { XCTFail("row must be saved") }
        try table.loadBooked()
        XCTAssertTrue(table.isBooked(slice.id))
        table.removeManualRow(slice.id)
        XCTAssertTrue(table.manualRows.isEmpty)
    }

    @MainActor
    func testStateRejectsBadRowsWithKeys() async throws {
        let booking = FakeBooking()
        let table = try state(booking: booking)
        var slice = TimeSlice(start: now, end: now)
        await table.book(slice, projects: [], customers: [], confirmed: true)
        XCTAssertEqual(table.rowStates[slice.id], .failed("clockodo.table.endBeforeStart"))
        slice.end = now.addingTimeInterval(1)
        await table.book(slice, projects: [], customers: [], confirmed: true)
        XCTAssertEqual(table.rowStates[slice.id], .failed("clockodo.table.selectionMissing"))
        let timer = TimeSlice(projectNumber: "P9", costCenter: "Plan", start: now, end: now.addingTimeInterval(1), origin: .timer)
        await table.book(timer, projects: [], customers: [], confirmed: true)
        XCTAssertEqual(table.rowStates[timer.id], .failed("clockodo.booking.projectNotFound"))
        XCTAssertEqual(booking.calls, [])

        let unconfirmed = TimeSlice(start: now, end: now.addingTimeInterval(1), customerID: 1, activityID: 9)
        await table.book(unconfirmed, projects: [], customers: [], confirmed: false)
        XCTAssertEqual(table.rowStates[unconfirmed.id], .failed("clockodo.write.unconfirmed"))
        XCTAssertFalse(table.isBooked(unconfirmed.id))
    }

    @MainActor
    func testStateBooksTimerRowThroughTheEngine() async throws {
        let booking = FakeBooking()
        let table = try state(booking: booking)
        let timer = TimeSlice(projectNumber: "P1", costCenter: "Plan", start: now, end: now.addingTimeInterval(60), origin: .timer)
        await table.book(
            timer, projects: [BookingEngine.Project(number: "P1", customerNumber: "K1")],
            customers: [BookingEngine.Customer(number: "K1", name: "Ann", clockodoID: 4)], confirmed: true)
        XCTAssertEqual(booking.calls, ["create 4 9 - -"])
    }

    @MainActor
    func testStateEditsAndDeletesEntriesLocally() async throws {
        var master = FakeMasterData()
        master.entriesResult = [TimeEntry(id: 1, customerID: 1, projectID: nil, activityID: 9, text: "old", start: now, seconds: 5)]
        let booking = FakeBooking()
        let table = try state(master: master, booking: booking)
        await table.loadEntries(now: now)
        let entry = table.entries[0]
        await table.editText(entry, text: "  new ", confirmed: true)
        XCTAssertEqual(table.entries[0].text, "new")
        await table.editText(entry, text: " ", confirmed: true)
        XCTAssertNil(table.entries[0].text)
        await table.setBillable(entry, billable: false, confirmed: true)
        XCTAssertFalse(table.entries[0].billable)
        await table.delete(entry, confirmed: false)
        XCTAssertEqual(table.entries.count, 1)
        XCTAssertEqual(table.entryStates[1], .failed("clockodo.write.unconfirmed"))
        await table.delete(entry, confirmed: true)
        XCTAssertTrue(table.entries.isEmpty)
        XCTAssertNil(table.entryStates[1])
        XCTAssertEqual(booking.calls, ["text 1 new", "text 1 ", "billable 1 false", "delete 1", "delete 1"])
    }

    func testTimeSliceSecondsPreferTimerValue() {
        let slice = TimeSlice(start: now, end: now.addingTimeInterval(90))
        XCTAssertEqual(slice.seconds, 90)
        XCTAssertEqual(TimeSlice(start: now, end: now.addingTimeInterval(90), origin: .timer, timerSeconds: 42).seconds, 42)
        XCTAssertEqual(TimeSlice(start: now, end: now.addingTimeInterval(-5)).seconds, 0)
        XCTAssertEqual(CostCenter(name: "x").id, "x")
    }
}
