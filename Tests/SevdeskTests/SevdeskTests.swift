import Assistant
import Foundation
import Hub
import Storage
import XCTest
@testable import Sevdesk

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
        throw SevdeskFailure.invalidResponse
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

private func client(_ replies: [(Int, String)] = [], credentials: FakeCredentials = FakeCredentials()) -> (SevdeskClient, Script) {
    let http = FakeHttp(replies)
    return (SevdeskClient(credentials: credentials, http: http), http.script)
}

private func defaults() -> UserDefaults {
    UserDefaults(suiteName: "sevdesk.tests." + UUID().uuidString)!
}

private func receipt(_ id: String, status: Int = 100, pdf: Bool = false, at seconds: TimeInterval = 0) -> Receipt {
    Receipt(
        orderID: id, number: "AN-" + id, projectNumber: "2024-001", customerNumber: "K1", customerName: "Ann",
        contactID: "c1", createdAt: Date(timeIntervalSince1970: seconds), lastStatus: status, pdfStored: pdf)
}

final class SevdeskTests: XCTestCase {
    func testCheckIsOneAuthenticatedRequest() async throws {
        let (api, script) = client([(200, #"{"objects":{"version":"2.0"}}"#)])
        try await api.check()
        XCTAssertEqual(script.requests.count, 1)
        let request = script.requests[0]
        XCTAssertEqual(request.url?.absoluteString, "https://my.sevdesk.de/api/v1/Tools/bookkeepingSystemVersion")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "tok")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testEveryRequestUsesTheSingleBaseURL() async throws {
        let (api, script) = client(Array(repeating: (200, #"{"objects":[]}"#), count: 8))
        _ = try await api.contact(id: "1")
        _ = try await api.order(id: "2")
        _ = try await api.orders()
        _ = try await api.tenant()
        for request in script.requests {
            XCTAssertTrue(request.url!.absoluteString.hasPrefix(SevdeskClient.baseURL + "/"))
        }
    }

    func testFailuresAreTyped() async {
        let cases: [(SevdeskClient, SevdeskFailure)] = [
            (client(credentials: FakeCredentials(value: nil)).0, .notConnected),
            (client([(401, "")]).0, .http(401)),
            (client([(500, "")]).0, .http(500)),
            (client([(200, "[]")]).0, .decoding),
        ]
        for (api, expected) in cases {
            do {
                _ = try await api.orders()
                XCTFail("expected failure")
            } catch { XCTAssertEqual(error as? SevdeskFailure, expected) }
        }
    }

    func testNotFoundIsNil() async throws {
        let (api, _) = client([(404, ""), (404, ""), (404, "")])
        let contact = try await api.contact(id: "9")
        let order = try await api.order(id: "9")
        let orders = try await api.orders()
        XCTAssertNil(contact)
        XCTAssertNil(order)
        XCTAssertEqual(orders, [])
    }

    func testContactAndOrderMapFields() async throws {
        let (api, script) = client([
            (200, #"{"objects":[{"id":"5","name":"Ann","customerNumber":"K1"}]}"#),
            (200, #"""
            {"objects":[{"id":"7","orderNumber":"AN-1","orderType":"AN","status":"200","sumNet":"10.5","sumTax":"2",
            "sumGross":"12.5","contact":{"id":"5"},"customerInternalNote":"n","header":"h"}]}
            """#),
        ])
        let contact = try await api.contact(id: "5")
        XCTAssertEqual(contact, Sevdesk.Contact(id: "5", name: "Ann", customerNumber: "K1"))
        let orders = try await api.orders(type: "RE")
        XCTAssertEqual(orders, [
            Order(
                id: "7", orderNumber: "AN-1", orderType: "AN", rawStatus: "200", sumNet: 10.5, sumTax: 2, sumGross: 12.5,
                contactID: "5", customerInternalNote: "n", header: "h"),
        ])
        XCTAssertEqual(script.requests[0].url?.path, "/api/v1/Contact/5")
        XCTAssertEqual(script.requests[1].url?.query, "orderType=RE")
    }

    func testContactMatchByNumber() async throws {
        let one = #"{"objects":[{"id":"1","name":"Ann Co","customerNumber":" K1 "},{"id":"2","name":"x","customerNumber":"K2"}]}"#
        let (api, script) = client([(200, one)])
        let match = try await api.contact(customerNumber: " K1 ")
        XCTAssertEqual(match, .unique(id: "1", name: "Ann Co"))
        XCTAssertTrue(script.requests[0].url!.absoluteString.contains("customerNumber=K1"))

        let two = #"{"objects":[{"id":"1","name":"A","customerNumber":"K1"},{"id":"2","name":"B","customerNumber":"K1"}]}"#
        let ambiguous = try await client([(200, two)]).0.contact(customerNumber: "K1")
        XCTAssertEqual(ambiguous, .ambiguous([
            ContactMatch.Candidate(id: "1", name: "A"), ContactMatch.Candidate(id: "2", name: "B"),
        ]))

        let person = #"{"objects":[{"id":"3","surename":"Ann","familyname":"Lee","customerNumber":"K1","parent":{"id":"9"}}]}"#
        let only = try await client([(200, person)]).0.contact(customerNumber: "K1")
        XCTAssertEqual(only, .contactPersonOnly(ContactMatch.Candidate(id: "3", name: "Ann Lee", isContactPerson: true)))

        let blank = try await client().0.contact(customerNumber: "  ")
        XCTAssertEqual(blank, ContactMatch.none)
    }

    func testContactMatchByNameIgnoresCase() async throws {
        let body = #"{"objects":[{"id":"1","name":"ann co"},{"id":"2","name":"other"}]}"#
        let match = try await client([(200, body)]).0.contact(name: "Ann Co")
        XCTAssertEqual(match, .unique(id: "1", name: "ann co"))
        let none = try await client([(200, body)]).0.contact(name: "zzz")
        XCTAssertEqual(none, ContactMatch.none)
    }

    func testTenantProbeCollectsGaps() async throws {
        let (api, script) = client([
            (200, #"{"objects":{"version":"2.0"}}"#),
            (200, #"{"objects":[{"id":"7","orderNumber":"AN-1","contact":{"id":3},"taxRate":19}]}"#),
            (200, #"{"objects":[{"taxRate":7,"unity":{"id":1,"name":"Stk"}},{"taxRate":7,"unity":{"id":1,"name":"Stk"}},{"taxRate":19}]}"#),
            (200, #"{"objects":"AN-2"}"#),
        ])
        let finding = try await api.tenant()
        XCTAssertEqual(finding.version, "2.0")
        XCTAssertEqual(finding.template?.orderID, "7")
        XCTAssertEqual(finding.template?.contactID, "3")
        XCTAssertEqual(finding.units, [TenantFinding.Unit(id: "1", name: "Stk")])
        XCTAssertEqual(finding.positionTaxRate, 7)
        XCTAssertEqual(finding.nextNumber, "AN-2")
        XCTAssertEqual(finding.gaps, [
            .contactPersonMissing, .addressCountryMissing, .taxRateMismatch(header: 19, positions: 7),
        ])
        XCTAssertEqual(script.requests.count, 4)
        XCTAssertEqual(finding.gaps.last?.arguments, ["19.0", "7.0"])
        XCTAssertEqual(finding.gaps.first?.key, "sevdesk.gap.contactPersonMissing")
    }

    func testTenantProbeWithoutOfferAndNumber() async throws {
        let (api, script) = client([(200, "{}"), (200, #"{"objects":[]}"#), (500, "")])
        let finding = try await api.tenant(orderNumber: "AN-9")
        XCTAssertNil(finding.template)
        XCTAssertNil(finding.nextNumber)
        XCTAssertEqual(finding.gaps, [.versionUnreadable, .noOfferForNumber, .nextNumberUnavailable])
        XCTAssertTrue(script.requests[1].url!.absoluteString.contains("orderNumber=AN-9"))
    }

    func testConnectionCheckTranslatesFailures() async throws {
        let values = KeyValues(values: ["token": "tok"])
        let accepted = FakeHttp([(200, "{}")])
        let account = try await ConnectionCheck(http: accepted).check(values)
        XCTAssertNil(account)
        XCTAssertEqual(accepted.script.requests.count, 1)
        XCTAssertEqual(accepted.script.requests[0].value(forHTTPHeaderField: "Authorization"), "tok")

        do {
            _ = try await ConnectionCheck(http: FakeHttp([(401, "")])).check(values)
            XCTFail("expected failure")
        } catch let error as any StatusErrorPort {
            XCTAssertEqual(error.status, 401)
        }
        XCTAssertTrue(ConnectionCheck.translate(.decoding) is any ShapeErrorPort)
        XCTAssertTrue(ConnectionCheck.translate(.invalidResponse) is any ShapeErrorPort)
        XCTAssertEqual(ConnectionCheck.translate(.notConnected) as? SevdeskFailure, .notConnected)
        XCTAssertEqual(ConnectionCheck(http: accepted).integration, "sevdesk")
    }

    func testCredentialsStoreReadsTheTokenSlot() throws {
        let keychain = FakeKeychain()
        let store = CredentialsStore(keychain: keychain, inlet: "sevdesk")
        XCTAssertNil(try store.load())
        try keychain.put("", at: KeySlot(inlet: "sevdesk", name: "token"))
        XCTAssertNil(try store.load())
        try keychain.put("abc", at: KeySlot(inlet: "sevdesk", name: "token"))
        XCTAssertEqual(try store.load(), Credentials(token: "abc"))
    }

    func testReceiptStoreRegistersWithoutDuplicates() async throws {
        let store = ReceiptStore(database: try SQLiteStore.inMemory())
        let initial = await store.receipts()
        XCTAssertEqual(initial, [])
        try store.register(receipt("a", at: 1))
        try store.register(receipt("a", status: 900, at: 2))
        try store.register(receipt("b", at: 3))
        XCTAssertEqual(store.all().map(\.orderID), ["a", "b"])
        XCTAssertEqual(store.all()[0].lastStatus, 100)
        let entries = await store.receipts()
        XCTAssertEqual(entries.map(\.number), ["AN-a", "AN-b"])
        XCTAssertEqual(entries[0], ReceiptEntry(
            kind: "AN", number: "AN-a", projectNumber: "2024-001", customerName: "Ann", createdAt: Date(timeIntervalSince1970: 1)))
    }

    func testReceiptStoreMergeOnlyMovesForward() throws {
        let store = ReceiptStore(database: try SQLiteStore.inMemory())
        try store.merge(receipt("a"))
        XCTAssertEqual(store.all().count, 1)
        var remote = receipt("a", status: 200, pdf: true)
        remote.lastUpdate = "u1"
        try store.merge(remote)
        XCTAssertEqual(store.all()[0].lastStatus, 200)
        XCTAssertEqual(store.all()[0].lastUpdate, "u1")
        XCTAssertTrue(store.all()[0].pdfStored)
        try store.merge(receipt("a", status: 150))
        XCTAssertEqual(store.all()[0].lastStatus, 200)
        XCTAssertTrue(store.all()[0].pdfStored)
    }
}


extension SevdeskTests {
    func testReceiptStoreAdoptsLegacyDefaultsOnce() throws {
        let legacy = defaults()
        legacy.set(try JSONEncoder().encode([receipt("a", at: 1), receipt("b", at: 2)]), forKey: ReceiptStore.legacyKey)
        let store = ReceiptStore(database: try SQLiteStore.inMemory())
        try store.adopt(legacy: legacy)
        XCTAssertEqual(store.all().map(\.orderID), ["a", "b"])
        XCTAssertNil(legacy.data(forKey: ReceiptStore.legacyKey))
        try store.adopt(legacy: legacy)
        XCTAssertEqual(store.all().count, 2)
    }
}

extension SevdeskTests {
    func testReceiptStoreMergeStoresAStatusStepWithoutPdf() throws {
        let store = ReceiptStore(database: try SQLiteStore.inMemory())
        try store.merge(receipt("a"))
        var remote = receipt("a", status: 200)
        remote.lastUpdate = "u1"
        try store.merge(remote)
        XCTAssertEqual(store.all()[0].lastStatus, 200)
        XCTAssertEqual(store.all()[0].lastUpdate, "u1")
        XCTAssertFalse(store.all()[0].pdfStored)
    }

    func testReceiptStoreMergeKeepsTheUpdateOnEqualStatus() throws {
        let store = ReceiptStore(database: try SQLiteStore.inMemory())
        var first = receipt("a", status: 200)
        first.lastUpdate = "u1"
        try store.merge(first)
        var same = receipt("a", status: 200)
        same.lastUpdate = "u2"
        try store.merge(same)
        XCTAssertEqual(store.all()[0].lastUpdate, "u1")
    }

    func testNextNumberReadsTheFirstNonEmptyListEntry() {
        XCTAssertEqual(ResponseParser.nextNumber(from: Data(#"{"objects":["AN-3","AN-4"]}"#.utf8)), "AN-3")
        XCTAssertNil(ResponseParser.nextNumber(from: Data(#"{"objects":[""]}"#.utf8)))
        XCTAssertNil(ResponseParser.nextNumber(from: Data(#"{"objects":[]}"#.utf8)))
    }
}
