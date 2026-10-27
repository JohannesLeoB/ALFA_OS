import Foundation
import GRDB
import XCTest
@testable import Storage

final class StorageTests: XCTestCase {
    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func testMigrationsCreateExpectedTablesWithoutLegacyNames() throws {
        let store = try SQLiteStore.inMemory()
        let expected: Set<String> = [
            "inlet", "key_slot", "inlet_report", "setting", "cost_day",
            "mail_folder", "mail_message", "mail_sync", "mail_outbox",
            "auditEntries", "integrationLog", "chatMessages", "chatMemorySummaries",
            "assistantNotes", "assistantTasks", "assistantJournal", "privacyPreferences",
            "samples", "articleCatalog", "articleCatalogFTS", "articleCatalogSync", "bookedRows",
        ]
        let (tables, columns) = try store.read { db -> ([String], [String]) in
            let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'grdb_%'")
            var columns: [String] = []
            for table in tables where !table.hasPrefix("articleCatalogFTS_") {
                columns += try db.columns(in: table).map(\.name)
            }
            return (tables, columns)
        }
        XCTAssertTrue(expected.isSubset(of: Set(tables)))
        let forbidden = ["m", "y", "k"].joined()
        XCTAssertFalse((tables + columns).contains { $0.lowercased().contains(forbidden) })
        XCTAssertFalse(tables.contains("dataFlowLog"))
        XCTAssertFalse(tables.contains("widgetInstances"))
    }

    func testMigrationsRunOnceOnReopen() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try DatabaseStore.open(in: directory)
        try first.write { db in try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('a', x'01')") }
        let second = try DatabaseStore.open(in: directory)
        let count = try second.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM setting") }
        XCTAssertEqual(count, 1)
        XCTAssertNotNil(DatabaseStore.size(in: directory))
        XCTAssertEqual(DatabaseStore.directory().lastPathComponent, "ALFA_OS")
        XCTAssertNil(DatabaseStore.size(in: directory.appendingPathComponent("missing")))
    }

    func testHubAndMailTablesAcceptRows() throws {
        let store = try SQLiteStore.inMemory()
        try store.write { db in
            try db.execute(sql: "INSERT INTO inlet (id, json) VALUES ('i', x'7b7d')")
            try db.execute(sql: "INSERT INTO inlet_report (inlet, at, json) VALUES ('i', 1, x'7b7d')")
            try db.execute(sql: "INSERT INTO cost_day (inlet, capability, day, calls) VALUES ('i', 'mail', 1, 2)")
            try db.execute(sql: "INSERT INTO mail_outbox (id, inlet, draft, state, attempts, position) VALUES ('o', 'i', x'00', 'queued', 0, 0)")
        }
        let (seq, messageID) = try store.read { db in
            (try Int.fetchOne(db, sql: "SELECT seq FROM inlet_report"), try String.fetchOne(db, sql: "SELECT messageID FROM mail_outbox"))
        }
        XCTAssertEqual(seq, 1)
        XCTAssertEqual(messageID, "")
    }

    func testArticleCatalogFullTextSearch() throws {
        let store = try SQLiteStore.inMemory()
        try store.write { db in
            try db.execute(sql: "INSERT INTO articleCatalog (id, articleNumber, searchText, itemJSON) VALUES ('1', 'A1', 'oak table', '{}'), ('2', 'A2', 'steel chair', '{}')")
        }
        let hits = try store.read { db in
            try String.fetchAll(db, sql: "SELECT k.id FROM articleCatalog k JOIN articleCatalogFTS f ON f.rowid = k.rowid WHERE articleCatalogFTS MATCH ?", arguments: ["steel"])
        }
        XCTAssertEqual(hits, ["2"])
    }

    @MainActor
    func testAuditStoreAppendsAndReloadsNewestFirst() throws {
        let database = try SQLiteStore.inMemory()
        let store = AuditStore(database: database)
        let first = AuditEntry(actorUserID: "u", projectID: "p1", action: .estimateAdjusted, summary: "s")
        let second = AuditEntry(timestamp: first.timestamp.addingTimeInterval(5), actorUserID: "u", projectID: "p2", action: .calibrationPromoted, summary: "t")
        try store.append(first)
        try store.append(second)
        XCTAssertEqual(store.entries.map(\.id), [second.id, first.id])
        let fresh = AuditStore(database: database)
        try fresh.load()
        XCTAssertEqual(fresh.entries.map(\.id), [second.id, first.id])
        XCTAssertEqual(fresh.entries.last?.action, .estimateAdjusted)
    }

    @MainActor
    func testIntegrationLogStoreRecordsEntriesNewestFirst() throws {
        let database = try SQLiteStore.inMemory()
        let store = IntegrationLogStore(database: database)
        store.log(integrationID: "a", actorUserID: "u1", action: .success, summary: "one")
        store.log(integrationID: "a", actorUserID: "u2", action: .error, errorMessage: "boom", summary: "two")
        XCTAssertEqual(store.entries.map(\.summary), ["two", "one"])
        XCTAssertEqual(store.entries.first?.errorMessage, "boom")
        let rows = try database.read { db in
            try Row.fetchAll(db, sql: "SELECT actorUserID, action FROM integrationLog ORDER BY actorUserID").map { [$0["actorUserID"] as String, $0["action"] as String] }
        }
        XCTAssertEqual(rows, [["u1", "SUCCESS"], ["u2", "ERROR"]])
    }
}
