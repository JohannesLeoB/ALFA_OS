import Design
import Foundation
import GRDB
import Storage

public final class LegacyImportStore {
    private struct Legacy: Sendable {
        var inlets: [(id: String, json: Data)] = []
        var slots: [(inlet: String, name: String)] = []
        var reports: [(inlet: String, at: Double, json: Data)] = []
        var settings: [(key: String, value: Data)] = []
        var costDays: [(inlet: String, capability: String, day: Int, calls: Int, bytes: Int, tokens: Int)] = []
        var skipped: [String] = []
    }

    private static let tables: [String: [String]] = [
        "inlet": ["id", "json"],
        "key_slot": ["inlet", "name"],
        "inlet_report": ["inlet", "at", "json"],
        "setting": ["key", "value"],
        "cost_day": ["inlet", "capability", "day", "calls", "bytes", "tokens"],
    ]

    private let database: SQLiteStore
    private let defaults: UserDefaults
    private let legacyFile: URL

    public init(database: SQLiteStore, defaults: UserDefaults, legacyFile: URL) {
        self.database = database
        self.defaults = defaults
        self.legacyFile = legacyFile
    }

    @discardableResult
    public func run() throws -> LegacyImportResult {
        if let done = try finished() { return done }
        var legacy = Self.read(legacyFile)
        let readable = FileManager.default.fileExists(atPath: legacyFile.path) && !legacy.skipped.contains("file")
        let preferences = collectPreferences(&legacy.skipped)
        let snapshot = legacy
        let seed = LegacyImportResult(outcome: readable ? .imported : .none, skipped: legacy.skipped)
        return try database.write { db in
            var result = seed
            var known = Set<String>()
            for row in snapshot.inlets {
                guard (try? JSONDecoder().decode(Inlet.self, from: row.json)) != nil else {
                    result.skipped.append("inlet:" + row.id)
                    continue
                }
                try db.execute(sql: "INSERT OR IGNORE INTO inlet (id, json) VALUES (?, ?)", arguments: [row.id, row.json])
                known.insert(row.id)
                result.inlets += 1
            }
            for row in snapshot.slots {
                guard known.contains(row.inlet) else {
                    result.skipped.append("key_slot:" + row.inlet)
                    continue
                }
                try db.execute(sql: "INSERT OR IGNORE INTO key_slot (inlet, name) VALUES (?, ?)", arguments: [row.inlet, row.name])
                result.slots += 1
            }
            for row in snapshot.reports {
                guard known.contains(row.inlet), (try? JSONDecoder().decode(ReportEntry.self, from: row.json)) != nil else {
                    result.skipped.append("inlet_report:" + row.inlet)
                    continue
                }
                try db.execute(sql: """
                    INSERT INTO inlet_report (inlet, at, json) SELECT ?, ?, ?
                    WHERE NOT EXISTS (SELECT 1 FROM inlet_report WHERE inlet = ? AND at = ? AND json = ?)
                    """, arguments: [row.inlet, row.at, row.json, row.inlet, row.at, row.json])
                result.reports += 1
            }
            for row in snapshot.settings where row.key != SettingsKey.legacyImportDone {
                try db.execute(sql: "INSERT OR IGNORE INTO setting (key, value) VALUES (?, ?)", arguments: [row.key, row.value])
                result.settings += 1
            }
            for row in snapshot.costDays {
                try db.execute(sql: """
                    INSERT OR IGNORE INTO cost_day (inlet, capability, day, calls, bytes, tokens) VALUES (?, ?, ?, ?, ?, ?)
                    """, arguments: [row.inlet, row.capability, row.day, row.calls, row.bytes, row.tokens])
                result.costDays += 1
            }
            for (key, value) in preferences {
                try db.execute(sql: "INSERT OR IGNORE INTO setting (key, value) VALUES (?, ?)", arguments: [key, value])
                result.preferences += 1
            }
            if result.outcome == .imported, !result.skipped.isEmpty { result.outcome = .partial }
            try db.execute(sql: "INSERT OR REPLACE INTO setting (key, value) VALUES (?, ?)",
                           arguments: [SettingsKey.legacyImportDone, try JSONEncoder().encode(result)])
            return result
        }
    }

    private func finished() throws -> LegacyImportResult? {
        let data: Data? = try database.read { db in
            try Data.fetchOne(db, sql: "SELECT value FROM setting WHERE key = ?", arguments: [SettingsKey.legacyImportDone])
        }
        guard let data else { return nil }
        return SettingStore.decoded(data, as: LegacyImportResult.self) ?? LegacyImportResult(outcome: .none)
    }

    private func collectPreferences(_ skipped: inout [String]) -> [(String, Data)] {
        var found: [(String, Data)] = []
        func text(_ key: String, allowed: [String]? = nil) {
            guard let raw = defaults.object(forKey: key) else { return }
            guard let value = raw as? String, allowed.map({ $0.contains(value) }) ?? true,
                  let data = try? JSONEncoder().encode(value) else {
                skipped.append("default:" + key)
                return
            }
            found.append((key, data))
        }
        func flag(_ key: String) {
            guard let raw = defaults.object(forKey: key) else { return }
            guard let value = raw as? Bool, let data = try? JSONEncoder().encode(value) else {
                skipped.append("default:" + key)
                return
            }
            found.append((key, data))
        }
        text(SettingsKey.appearance, allowed: AppearanceChoice.allCases.map(\.rawValue))
        text(SettingsKey.startDestination, allowed: StartDestination.allCases.map(\.rawValue))
        flag(SettingsKey.lockOn)
        text(SettingsKey.lockDelay, allowed: LockDelay.allCases.map(\.rawValue))
        flag(SettingsKey.loadImages)
        flag(SettingsKey.assistantOff)
        flag(SettingsKey.chatFiles)
        text(SettingsKey.identityName)
        text(SettingsKey.identityRole)
        text(SettingsKey.identityCode)
        text(SettingsKey.identityPhone)
        flag(SettingsKey.birthdays)
        for entry in CompanyEntry.allCases { text(entry.storageKey) }
        for entry in ImprintEntry.allCases { text(entry.storageKey) }
        return found
    }

    private static func read(_ file: URL) -> Legacy {
        var legacy = Legacy()
        guard FileManager.default.fileExists(atPath: file.path) else { return legacy }
        var configuration = GRDB.Configuration()
        configuration.readonly = true
        guard let queue = try? DatabaseQueue(path: file.path, configuration: configuration) else {
            legacy.skipped.append("file")
            return legacy
        }
        do {
            try queue.read { db in
                for (table, columns) in tables.sorted(by: { $0.key < $1.key }) {
                    guard (try? db.tableExists(table)) == true,
                          let present = try? db.columns(in: table).map(\.name),
                          columns.allSatisfy(present.contains) else {
                        legacy.skipped.append("table:" + table)
                        continue
                    }
                    try load(table, from: db, into: &legacy)
                }
            }
        } catch {
            legacy.skipped.append("read")
        }
        return legacy
    }

    private static func load(_ table: String, from db: Database, into legacy: inout Legacy) throws {
        switch table {
        case "inlet":
            for row in try Row.fetchAll(db, sql: "SELECT id, json FROM inlet ORDER BY rowid") {
                guard let id = String.fromDatabaseValue(row["id"]), let json = Data.fromDatabaseValue(row["json"]) else {
                    legacy.skipped.append("inlet:row")
                    continue
                }
                legacy.inlets.append((id, json))
            }
        case "key_slot":
            for row in try Row.fetchAll(db, sql: "SELECT inlet, name FROM key_slot ORDER BY inlet, name") {
                guard let inlet = String.fromDatabaseValue(row["inlet"]), let name = String.fromDatabaseValue(row["name"]) else {
                    legacy.skipped.append("key_slot:row")
                    continue
                }
                legacy.slots.append((inlet, name))
            }
        case "inlet_report":
            for row in try Row.fetchAll(db, sql: "SELECT inlet, at, json FROM inlet_report ORDER BY seq") {
                guard let inlet = String.fromDatabaseValue(row["inlet"]), let at = Double.fromDatabaseValue(row["at"]),
                      let json = Data.fromDatabaseValue(row["json"]) else {
                    legacy.skipped.append("inlet_report:row")
                    continue
                }
                legacy.reports.append((inlet, at, json))
            }
        case "setting":
            for row in try Row.fetchAll(db, sql: "SELECT key, value FROM setting ORDER BY key") {
                guard let key = String.fromDatabaseValue(row["key"]), let value = Data.fromDatabaseValue(row["value"]) else {
                    legacy.skipped.append("setting:row")
                    continue
                }
                legacy.settings.append((key, value))
            }
        default:
            for row in try Row.fetchAll(db, sql: "SELECT inlet, capability, day, calls, bytes, tokens FROM cost_day") {
                guard let inlet = String.fromDatabaseValue(row["inlet"]), let capability = String.fromDatabaseValue(row["capability"]),
                      let day = Int.fromDatabaseValue(row["day"]), let calls = Int.fromDatabaseValue(row["calls"]),
                      let bytes = Int.fromDatabaseValue(row["bytes"]), let tokens = Int.fromDatabaseValue(row["tokens"]) else {
                    legacy.skipped.append("cost_day:row")
                    continue
                }
                legacy.costDays.append((inlet, capability, day, calls, bytes, tokens))
            }
        }
    }
}

public struct LegacyImportResult: Equatable, Codable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case none
        case imported
        case partial
    }

    var outcome: Outcome
    var inlets = 0
    var slots = 0
    var reports = 0
    var settings = 0
    var costDays = 0
    var preferences = 0
    var skipped: [String] = []

    init(outcome: Outcome, skipped: [String] = []) {
        self.outcome = outcome
        self.skipped = skipped
    }
}
