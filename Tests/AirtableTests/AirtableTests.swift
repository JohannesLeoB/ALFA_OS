import Assistant
@testable import Calculation
import Foundation
import Hub
import XCTest
@testable import Airtable

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
        throw AirtableFailure.invalidResponse
    }
}

private struct FakeCredentials: CredentialsPort {
    var value: Credentials? = Credentials(token: "pat", baseID: "appAAAAAAAAAAAAAA")

    func load() throws -> Credentials? { value }
}

private final class FakeKeychain: KeychainPort, @unchecked Sendable {
    private let lock = NSLock()
    private var items: [KeySlot: String] = [:]

    func put(_ value: String, at slot: KeySlot) throws { lock.lock(); items[slot] = value; lock.unlock() }
    func get(_ slot: KeySlot) throws -> String? { lock.lock(); defer { lock.unlock() }; return items[slot] }
    func delete(_ slot: KeySlot) throws { lock.lock(); items[slot] = nil; lock.unlock() }
}

private final class FakeRecords: RecordFetchPort, @unchecked Sendable {
    private let lock = NSLock()
    private var tables: [String: [Record]]
    private var failure: AirtableFailure?
    private var fetched = 0

    init(_ tables: [String: [Record]] = [:], failure: AirtableFailure? = nil) {
        self.tables = tables
        self.failure = failure
    }

    var fetchCount: Int { lock.lock(); defer { lock.unlock() }; return fetched }

    func fetchRecords(baseID: String, table: String, filterByFormula: String?) async throws -> [Record] {
        try lock.withLock {
            fetched += 1
            if let failure { throw failure }
            return tables[table] ?? []
        }
    }
}

private func row(_ id: String, _ fields: [String: FieldValue]) -> Record { Record(id: id, fields: fields) }

private let testSaleField = "Sale Net Column"

private let writable = WriteAllowlist(writable: ["appBase": ["Table"]], deletable: ["appBase": ["Table"]])

final class AirtableTests: XCTestCase {
    func testFieldValueDecodesEveryShape() throws {
        let json = #"{"a":"x","b":["p","q"],"c":2.5,"d":true,"e":null,"f":{"k":1}}"#
        let decoded = try JSONDecoder().decode([String: FieldValue].self, from: Data(json.utf8))
        XCTAssertEqual(decoded["a"], .string("x"))
        XCTAssertEqual(decoded["b"], .array(["p", "q"]))
        XCTAssertEqual(decoded["c"], .number(2.5))
        XCTAssertEqual(decoded["d"], .bool(true))
        XCTAssertEqual(decoded["e"], .null)
        XCTAssertEqual(decoded["f"], .null)
        XCTAssertEqual(FieldValue.number(4).anyStringValue, "4")
        XCTAssertEqual(FieldValue.number(4.5).anyStringValue, "4.5")
        XCTAssertNil(FieldValue.array(["a"]).anyStringValue)
        XCTAssertEqual(FieldValue.array(["a"]).firstArrayValue, "a")
        XCTAssertNil(FieldValue.string("a").numberValue)
    }

    func testFetchPagesWithOffsetAndFilter() async throws {
        let http = FakeHttp([
            (200, #"{"records":[{"id":"r1","fields":{"Name":"a"}}],"offset":"next"}"#),
            (200, #"{"records":[{"id":"r2","fields":{"Name":"b"}}]}"#),
        ])
        let client = AirtableClient(credentials: FakeCredentials(), http: http, allowlist: writable)
        let rows = try await client.fetchRecords(baseID: "appBase", table: "Tisch Eins", filterByFormula: "FALSE()")
        XCTAssertEqual(rows.map(\.id), ["r1", "r2"])
        XCTAssertEqual(rows[0].fields["Name"], .string("a"))
        let sent = http.script.requests
        XCTAssertEqual(sent.count, 2)
        XCTAssertEqual(sent[0].httpMethod, "GET")
        XCTAssertEqual(sent[0].value(forHTTPHeaderField: "Authorization"), "Bearer pat")
        XCTAssertNil(sent[0].value(forHTTPHeaderField: "Content-Type"))
        let first = sent[0].url!.absoluteString
        XCTAssertTrue(first.hasPrefix("https://api.airtable.com/v0/appBase/Tisch%20Eins?"))
        XCTAssertTrue(first.contains("pageSize=100"))
        XCTAssertTrue(first.contains("filterByFormula=FALSE()"))
        XCTAssertFalse(first.contains("offset"))
        XCTAssertTrue(sent[1].url!.absoluteString.contains("offset=next"))
    }

    func testFetchMapsFailures() async {
        let client = { (http: FakeHttp, credentials: FakeCredentials) in
            AirtableClient(credentials: credentials, http: http, allowlist: writable)
        }
        do {
            _ = try await client(FakeHttp(), FakeCredentials(value: nil)).fetchRecords(baseID: "b", table: "t")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? AirtableFailure, .notConnected) }
        do {
            _ = try await client(FakeHttp([(422, #"{"error":{"type":"X","message":"bad field"}}"#)]), FakeCredentials())
                .fetchRecords(baseID: "b", table: "t")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? AirtableFailure, .rejected(422, "bad field")) }
        do {
            _ = try await client(FakeHttp([(503, "")]), FakeCredentials()).fetchRecords(baseID: "b", table: "t")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? AirtableFailure, .http(503)) }
        do {
            _ = try await client(FakeHttp([(200, "[]")]), FakeCredentials()).fetchRecords(baseID: "b", table: "t")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? AirtableFailure, .decoding) }
    }

    func testCreateUpdateDeleteRespectAllowlistAndBuildRequests() async throws {
        let http = FakeHttp([(200, #"{"records":[{"id":"recNew"}]}"#), (200, "{}"), (200, "{}")])
        let client = AirtableClient(credentials: FakeCredentials(), http: http, allowlist: writable)
        let id = try await client.createRecord(baseID: "appBase", table: "Table", fields: ["Name": .string("n"), "Qty": .number(2)])
        XCTAssertEqual(id, "recNew")
        try await client.updateRecord(baseID: "appBase", table: "Table", recordID: "rec1", fields: ["Qty": .number(3)])
        try await client.deleteRecord(baseID: "appBase", table: "Table", recordID: "rec1")
        let sent = http.script.requests
        XCTAssertEqual(sent.map(\.httpMethod), ["POST", "PATCH", "DELETE"])
        XCTAssertEqual(sent[1].url?.absoluteString, "https://api.airtable.com/v0/appBase/Table/rec1")
        XCTAssertEqual(sent[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNil(sent[2].httpBody)
        let created = try JSONSerialization.jsonObject(with: sent[0].httpBody!) as? [String: Any]
        let fields = ((created?["records"] as? [[String: Any]])?.first?["fields"]) as? [String: Any]
        XCTAssertEqual(fields?["Name"] as? String, "n")
        XCTAssertEqual(fields?["Qty"] as? Double, 2)
        let patched = try JSONSerialization.jsonObject(with: sent[1].httpBody!) as? [String: Any]
        XCTAssertEqual((patched?["fields"] as? [String: Any])?["Qty"] as? Double, 3)
    }

    func testWritesOutsideAllowlistNeverReachTheNetwork() async {
        let http = FakeHttp()
        let client = AirtableClient(credentials: FakeCredentials(), http: http, allowlist: WriteAllowlist(writable: ["appBase": ["Table"]]))
        do {
            _ = try await client.createRecord(baseID: "appBase", table: "Other", fields: [:])
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? AirtableFailure, .writeNotAllowed(baseID: "appBase", table: "Other")) }
        do {
            try await client.updateRecord(baseID: "appOther", table: "Table", recordID: "r", fields: [:])
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? AirtableFailure, .writeNotAllowed(baseID: "appOther", table: "Table")) }
        do {
            try await client.deleteRecord(baseID: "appBase", table: "Table", recordID: "r")
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? AirtableFailure, .deleteNotAllowed(baseID: "appBase", table: "Table")) }
        XCTAssertTrue(http.script.requests.isEmpty)
    }

    func testAllowlistDropsEmptyEntries() {
        let list = WriteAllowlist(writable: ["": ["", "T"], "appA": ["", "T"], "appB": [""]])
        XCTAssertFalse(list.allowsWrite(baseID: "", table: ""))
        XCTAssertFalse(list.allowsWrite(baseID: "", table: "T"))
        XCTAssertTrue(list.allowsWrite(baseID: "appA", table: "T"))
        XCTAssertFalse(list.allowsWrite(baseID: "appA", table: ""))
        XCTAssertFalse(list.allowsWrite(baseID: "appB", table: ""))
        XCTAssertFalse(list.allowsDelete(baseID: "appA", table: "T"))
    }

    func testCredentialsStoreReadsTokenAndBaseFromKeychain() throws {
        let keychain = FakeKeychain()
        let store = CredentialsStore(keychain: keychain, inlet: "inlet-1")
        XCTAssertNil(try store.load())
        try keychain.put("pat", at: KeySlot(inlet: "inlet-1", name: "token"))
        XCTAssertEqual(try store.load(), Credentials(token: "pat", baseID: ""))
        try keychain.put("appBase", at: KeySlot(inlet: "inlet-1", name: "base"))
        XCTAssertEqual(try store.load(), Credentials(token: "pat", baseID: "appBase"))
        try keychain.put("", at: KeySlot(inlet: "inlet-1", name: "token"))
        XCTAssertNil(try store.load())
    }

    func testConnectionCheckValidatesBaseAndProbesOnce() async throws {
        let base = "appAAAAAAAAAAAAAA"
        let http = FakeHttp([(200, #"{"records":[]}"#)])
        let check = ConnectionCheck(http: http, table: "Projects")
        XCTAssertEqual(check.integration, "airtable")
        let account = try await check.check(KeyValues(values: ["base": base, "token": "pat"]))
        XCTAssertEqual(account, base)
        let url = http.script.requests[0].url!.absoluteString
        XCTAssertTrue(url.contains("/v0/\(base)/Projects"))
        XCTAssertTrue(url.contains("filterByFormula=FALSE()"))
        XCTAssertEqual(http.script.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer pat")
        for bad in ["", "xyz", "appShort", "app" + String(repeating: "A", count: 30)] {
            do {
                _ = try await check.check(KeyValues(values: ["base": bad, "token": "pat"]))
                XCTFail("expected failure for \(bad)")
            } catch { XCTAssertEqual(error as? KeyFieldFailure, KeyFieldFailure(field: "base")) }
        }
        do {
            _ = try await ConnectionCheck(http: http, table: "").check(KeyValues(values: ["base": base, "token": "pat"]))
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? KeyFieldFailure, KeyFieldFailure(field: "base")) }
    }

    func testConnectionCheckTranslatesFailuresForTheHub() async {
        let values = KeyValues(values: ["base": "appAAAAAAAAAAAAAA", "token": "pat"])
        do {
            _ = try await ConnectionCheck(http: FakeHttp([(401, "")]), table: "P").check(values)
            XCTFail("expected failure")
        } catch { XCTAssertEqual((error as? any StatusErrorPort)?.status, 401) }
        do {
            _ = try await ConnectionCheck(http: FakeHttp([(403, #"{"error":{"message":"no"}}"#)]), table: "P").check(values)
            XCTFail("expected failure")
        } catch { XCTAssertEqual((error as? any StatusErrorPort)?.status, 403) }
        do {
            _ = try await ConnectionCheck(http: FakeHttp([(200, "nope")]), table: "P").check(values)
            XCTFail("expected failure")
        } catch { XCTAssertTrue(error is any ShapeErrorPort) }
    }

    private let articleFields: [String: FieldValue] = [
        "Artikelnummer": .string("K-100"), "Hersteller": .array(["man1"]), "Kategorie": .array(["cat1"]),
        "Bezeichnung": .string("Kochfeld Induktion"), "Beschreibung": .string("Flaechenfeld 80 cm"),
        "Variante": .string("schwarz"), "Ma\u{00DF}e": .string("80x52"), "Netto-EK (\u{20AC})": .number(400),
        testSaleField: .number(650), "EAN/GTIN": .number(4001234567890),
        "Review-Status": .string(" Verifiziert "), "Konfidenz": .number(0.95), "Fundstelle": .string("S. 3"),
    ]

    func testArticleEngineMapsRecordsAndKeepsDetailText() throws {
        let records = [
            row("rec1", articleFields),
            row("rec2", ["Artikelnummer": .string("  ")]),
            row("rec3", ["Bezeichnung": .string("ohne Nummer")]),
            row("rec4", ["Artikelnummer": .number(77), "Beschreibung": .string("Nur Beschreibung")]),
        ]
        let entries = try ArticleEngine.entries(from: records, manufacturers: ["man1": "Gaggenau"], categories: ["cat1": "Kochfelder"],
                                                saleField: testSaleField)
        XCTAssertEqual(entries.map(\.id), ["rec1", "rec4"])
        let first = entries[0]
        XCTAssertEqual(first.manufacturer, "Gaggenau")
        XCTAssertEqual(first.category, "Kochfelder")
        XCTAssertEqual(first.summary, "Kochfeld Induktion")
        XCTAssertEqual(first.detailText, "Flaechenfeld 80 cm schwarz 80x52")
        XCTAssertEqual(first.purchaseNet, 400)
        XCTAssertEqual(first.saleNet, 650)
        XCTAssertEqual(first.ean, "4001234567890")
        XCTAssertEqual(first.review?.status, .verified)
        XCTAssertEqual(first.review?.confidence, 0.95)
        XCTAssertEqual(first.review?.location, "S. 3")
        XCTAssertNil(first.review?.openQuestion)
        XCTAssertEqual(entries[1].articleNumber, "77")
        XCTAssertEqual(entries[1].summary, "Nur Beschreibung")
        XCTAssertEqual(entries[1].detailText, "Nur Beschreibung")
        XCTAssertNil(entries[1].review)
        let article = ArticleEngine.article(first)
        XCTAssertEqual(article, Article(id: "rec1", articleNumber: "K-100", manufacturer: "Gaggenau",
                                        summary: "Kochfeld Induktion", purchaseNet: 400, saleNet: 650))
    }

    func testMissingSaleFieldConfigIsAClearFailure() async {
        XCTAssertThrowsError(try ArticleEngine.entries(from: [], manufacturers: [:], categories: [:], saleField: "")) {
            XCTAssertEqual($0 as? KeyFieldFailure, KeyFieldFailure(field: "airtable.field.sale_price"))
        }
        let store = ArticleStore(fetch: FakeRecords(catalogTables()), baseID: "appBase", articleTable: "Articles",
                                 manufacturerTable: "Makers", categoryTable: "Cats", saleField: "")
        let state = await store.search(term: "a", limit: 1)
        XCTAssertEqual(state, .failed(String(describing: KeyFieldFailure(field: "airtable.field.sale_price"))))
    }

    func testDetailTextOmitsDescriptionEqualToTitle() {
        let fields: [String: FieldValue] = ["Bezeichnung": .string("A"), "Beschreibung": .string("A"), "Variante": .string("v")]
        XCTAssertEqual(ArticleEngine.detailText(from: fields), "v")
        XCTAssertNil(ArticleEngine.detailText(from: ["Bezeichnung": .string("A")]))
    }

    func testReviewStateParsesStatusSpellings() {
        XCTAssertEqual(ReviewStateEngine.status(of: "Ungepr\u{00FC}ft"), .unchecked)
        XCTAssertEqual(ReviewStateEngine.status(of: "ungeprueft"), .unchecked)
        XCTAssertEqual(ReviewStateEngine.status(of: "BEANSTANDET"), .disputed)
        XCTAssertNil(ReviewStateEngine.status(of: "offen"))
        XCTAssertNil(ReviewStateEngine.state(from: ["Review-Status": .string("offen")]))
        let state = ReviewStateEngine.state(from: ["Review-Status": .string("Verifiziert"), "Kl\u{00E4}rung offen": .string(" Preis? ")])
        XCTAssertEqual(state?.openQuestion, "Preis?")
    }

    func testSearchRanksExactBeforePrefixAndSortsByNumber() {
        let entries = [
            CatalogEntry(id: "1", articleNumber: "B-2", manufacturer: "Bora", summary: "Kochfeld Abzug"),
            CatalogEntry(id: "2", articleNumber: "A-1", manufacturer: "Gaggenau", summary: "Kochfeld"),
            CatalogEntry(id: "3", articleNumber: "C-3", manufacturer: "Miele", summary: "Backofen"),
        ]
        XCTAssertEqual(ArticleEngine.search(entries, term: "kochfeld").map(\.id), ["2", "1"])
        XCTAssertEqual(ArticleEngine.search(entries, term: "kochf").map(\.id), ["2", "1"])
        XCTAssertEqual(ArticleEngine.search(entries, term: "kochfeld bora").map(\.id), ["1", "2"])
        XCTAssertEqual(ArticleEngine.search(entries, term: "zzz").count, 0)
        XCTAssertEqual(ArticleEngine.search(entries, term: " ").count, 3)
        XCTAssertEqual(ArticleEngine.tokens("A, b-cd! e"), ["cd"])
    }

    private func catalogTables() -> [String: [Record]] {
        [
            "Articles": [row("rec1", articleFields), row("rec2", ["Artikelnummer": .string("X-1"), "Bezeichnung": .string("Spuele")])],
            "Makers": [row("man1", ["Name": .string("Gaggenau")])],
            "Cats": [row("cat1", ["Name": .string("Kochfelder")])],
        ]
    }

    private func articleStore(_ records: FakeRecords) -> ArticleStore {
        ArticleStore(fetch: records, baseID: "appBase", articleTable: "Articles", manufacturerTable: "Makers", categoryTable: "Cats", saleField: testSaleField)
    }

    func testArticleStoreSearchesLimitsAndCaches() async {
        let records = FakeRecords(catalogTables())
        let store = articleStore(records)
        let state = await store.search(term: "gaggenau", limit: 5)
        guard case .matches(let hits) = state else { return XCTFail("expected matches, got \(state)") }
        XCTAssertEqual(hits.map(\.id), ["rec1"])
        XCTAssertEqual(hits[0].manufacturer, "Gaggenau")
        let all = await store.search(term: "", limit: 1)
        guard case .matches(let limited) = all else { return XCTFail("expected matches") }
        XCTAssertEqual(limited.count, 1)
        XCTAssertEqual(records.fetchCount, 3)
        let price = await store.purchaseNet(matching: "spuele")
        XCTAssertNil(price)
        let priced = await store.purchaseNet(matching: "kochfeld")
        XCTAssertEqual(priced, 400)
        XCTAssertEqual(records.fetchCount, 3)
        await store.reload()
        _ = await store.search(term: "x", limit: 1)
        XCTAssertEqual(records.fetchCount, 6)
    }

    func testArticleStoreStates() async {
        let empty = await articleStore(FakeRecords()).search(term: "a", limit: 3)
        XCTAssertEqual(empty, .empty)
        let offline = await articleStore(FakeRecords(failure: .notConnected)).search(term: "a", limit: 3)
        XCTAssertEqual(offline, .notConnected)
        let broken = await articleStore(FakeRecords(failure: .http(500))).search(term: "a", limit: 3)
        XCTAssertEqual(broken, .failed("http 500"))
        let unmapped = FakeRecords(["Articles": [row("r", ["Bezeichnung": .string("x")])]])
        let state = await articleStore(unmapped).search(term: "a", limit: 3)
        XCTAssertEqual(state, .failed("unmapped 1"))
        let price = await articleStore(FakeRecords(failure: .http(500))).purchaseNet(matching: "a")
        XCTAssertNil(price)
    }

    func testStockEngineAndStoreMapRows() async {
        let rows = [
            row("s1", ["Bezeichnung": .string("Schrank"), "Bestand": .number(4), "Hersteller": .string("X"),
                          "Kategorie": .string("Korpus"), "Artikelnummer": .string("A1"), "EK netto (\u{20AC})": .number(10),
                          "VK netto (\u{20AC})": .number(20)]),
            row("s2", ["Bezeichnung": .string(" ")]),
            row("s3", ["Bestand": .number(1)]),
        ]
        XCTAssertEqual(StockEngine.items(from: rows), [
            StockItem(id: "s1", label: "Schrank", manufacturer: "X", category: "Korpus", articleNumber: "A1", quantity: 4,
                      purchaseNet: 10, saleNet: 20)
        ])
        let records = FakeRecords(["Lagerliste": rows])
        let store = StockStore(fetch: records, baseID: "appBase")
        let first = await store.current()
        let second = await store.current()
        XCTAssertEqual(first, second)
        XCTAssertEqual(records.fetchCount, 1)
        await store.reload()
        _ = await store.current()
        XCTAssertEqual(records.fetchCount, 2)
        let empty = await StockStore(fetch: FakeRecords(), baseID: "appBase").current()
        XCTAssertEqual(empty, .empty)
        let offline = await StockStore(fetch: FakeRecords(failure: .notConnected), baseID: "appBase").current()
        XCTAssertEqual(offline, .notConnected)
        let failed = await StockStore(fetch: FakeRecords(failure: .decoding), baseID: "appBase").current()
        XCTAssertEqual(failed, .failed("decoding"))
    }

    private let modelRows = [
        row("p1", ["Schl\u{00FC}ssel": .string("fixkosten_sockel"), "Wert": .string("7.000,5")]),
        row("p2", ["Schl\u{00FC}ssel": .string("variabel_pro_korpus"), "Wert": .number(700)]),
        row("p3", ["Schl\u{00FC}ssel": .string("band_low"), "Wert": .string("0,7")]),
        row("p4", ["Schl\u{00FC}ssel": .string(""), "Wert": .number(1)]),
        row("p5", ["Schl\u{00FC}ssel": .string("anfahrt_pro_km")]),
    ]

    func testEstimationParametersMergeOverSeed() async throws {
        let store = EstimationParameterStore(fetch: FakeRecords(["Sch\u{00E4}tzmodell": modelRows]), baseID: "appBase")
        let parameters = try await store.load()
        let seed = CarcassParameters.seed()
        XCTAssertEqual(parameters?.variablePerCarcass, 700)
        XCTAssertEqual(parameters?.bandLow, 0.7)
        XCTAssertEqual(parameters?.travelPerKm, seed.travelPerKm)
        XCTAssertEqual(parameters?.fixedBase, seed.fixedBase)
        let viaPort = await store.parameters()
        XCTAssertEqual(viaPort, parameters)
        XCTAssertEqual(EstimationParameterStore.number(.string("1,5")), 1.5)
        XCTAssertNil(EstimationParameterStore.number(.string("abc")))
        XCTAssertNil(EstimationParameterStore.number(nil))
    }

    func testEstimationParametersFallBackWhenEmptyOrBroken() async {
        let empty = EstimationParameterStore(fetch: FakeRecords(), baseID: "appBase")
        let none = await empty.parameters()
        XCTAssertNil(none)
        let broken = EstimationParameterStore(fetch: FakeRecords(failure: .http(500)), baseID: "appBase")
        let missing = await broken.parameters()
        XCTAssertNil(missing)
        do {
            _ = try await broken.load()
            XCTFail("expected failure")
        } catch { XCTAssertEqual(error as? AirtableFailure, .http(500)) }
    }

    func testAnchorRowsFlattenEveryFieldToText() async throws {
        let records = FakeRecords(["Preisanker": [
            row("a1", ["candidate_id": .string("c1"), "price_net": .number(1200), "tags": .array(["x", "y"]),
                          "flag": .bool(true), "empty": .null]),
        ]])
        let rows = try await AnchorRowStore(fetch: records, baseID: "appBase").fetchAnchorRows()
        XCTAssertEqual(rows, [["candidate_id": "c1", "price_net": "1200", "tags": "x", "flag": "", "empty": ""]])
    }

    func testFailureDetailsAreStable() {
        XCTAssertEqual(AirtableFailure.http(401).detail, "http 401")
        XCTAssertEqual(AirtableFailure.rejected(422, "m").detail, "http 422: m")
        XCTAssertEqual(AirtableFailure.writeNotAllowed(baseID: "b", table: "t").detail, "writeNotAllowed t@b")
    }
}
