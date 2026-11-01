import Core
import Foundation
import GRDB
import LocalAuthentication
import Security
import Storage

final class InletStore: InletPort {
    private let database: SQLiteStore

    init(database: SQLiteStore) {
        self.database = database
    }

    func load() throws -> [Inlet] {
        try database.read { db in
            try Row.fetchAll(db, sql: "SELECT json FROM inlet ORDER BY rowid").compactMap { row in
                let data: Data = row["json"]
                guard var inlet = try? JSONDecoder().decode(Inlet.self, from: data) else { return nil }
                inlet.state = SettingEngine.durable(inlet.state)
                return inlet
            }
        }
    }

    func save(_ inlet: Inlet, slots: [String]? = nil) throws {
        try database.write { db in
            var row = inlet
            if row.state != SettingEngine.durable(row.state) {
                let old = try Data.fetchOne(db, sql: "SELECT json FROM inlet WHERE id = ?", arguments: [inlet.id])
                let stored = old.flatMap { try? JSONDecoder().decode(Inlet.self, from: $0) }
                row.state = SettingEngine.durable(stored?.state ?? row.state)
            }
            let data = try JSONEncoder().encode(row)
            try db.execute(sql: "INSERT INTO inlet (id, json) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET json = excluded.json",
                           arguments: [inlet.id, data])
            if let slots {
                for name in slots {
                    try db.execute(sql: "INSERT OR REPLACE INTO key_slot (inlet, name) VALUES (?, ?)",
                                   arguments: [inlet.id, name])
                }
            }
        }
    }

    func loadReports() throws -> [Inlet.ID: [ReportEntry]] {
        try database.read { db in
            var result: [Inlet.ID: [ReportEntry]] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT json FROM inlet_report ORDER BY seq DESC") {
                let data: Data = row["json"]
                if let entry = try? JSONDecoder().decode(ReportEntry.self, from: data) {
                    result[entry.inlet, default: []].append(entry)
                }
            }
            return result
        }
    }

    func append(_ entry: ReportEntry, limit: Int) throws {
        let data = try JSONEncoder().encode(entry)
        try database.write { db in
            try db.execute(sql: "INSERT INTO inlet_report (inlet, at, json) VALUES (?, ?, ?)",
                           arguments: [entry.inlet, entry.at.timeIntervalSince1970, data])
            try db.execute(sql: """
                DELETE FROM inlet_report WHERE inlet = ? AND seq NOT IN
                (SELECT seq FROM inlet_report WHERE inlet = ? ORDER BY seq DESC LIMIT ?)
                """, arguments: [entry.inlet, entry.inlet, limit])
        }
    }

    func slots(of inlet: Inlet.ID) throws -> [String] {
        try database.read { db in
            try String.fetchAll(db, sql: "SELECT name FROM key_slot WHERE inlet = ? ORDER BY name", arguments: [inlet])
        }
    }

    func delete(_ inlet: Inlet.ID) throws {
        try database.write { db in
            try db.execute(sql: "DELETE FROM inlet_report WHERE inlet = ?", arguments: [inlet])
            try db.execute(sql: "DELETE FROM key_slot WHERE inlet = ?", arguments: [inlet])
            try db.execute(sql: "DELETE FROM inlet WHERE id = ?", arguments: [inlet])
        }
    }
}

public struct IntegrationCatalogStore: IntegrationCatalogPort {
    public let entries: [IntegrationInfo]

    init(entries: [IntegrationInfo]) {
        self.entries = entries
    }

    public func info(_ id: String) -> IntegrationInfo? { entries.first { $0.id == id } }

    public func info(forProvider provider: String) -> IntegrationInfo? {
        entries.first { $0.providers.contains(provider) }
    }

    public static let standard = IntegrationCatalogStore(entries: [
        IntegrationInfo(
            id: "google", access: .browser, companyOwned: false, fields: [],
            areas: [IntegrationArea(id: "mail", capability: .mail), IntegrationArea(id: "contacts", capability: .contacts),
                    IntegrationArea(id: "files", capability: .files)],
            extras: [IntegrationExtra(id: "driveFolders", capability: .files, kind: .projectRoot, actionKey: "settings.sync.now")],
            listsAccounts: false, providers: ["google"], logo: IntegrationLogo(resource: "google", kind: .mark)),
        IntegrationInfo(
            id: "mailaccounts", access: .password, companyOwned: false, fields: [],
            areas: [IntegrationArea(id: "mail", capability: .mail)], extras: [],
            listsAccounts: true, providers: ["imap", "microsoft"], logo: IntegrationLogo(resource: "mailaccounts", kind: .mark)),
        IntegrationInfo(
            id: "clickup", access: .key, companyOwned: false, fields: [IntegrationField(id: "token", secret: true)],
            areas: [IntegrationArea(id: "phases", capability: .tasks), IntegrationArea(id: "taskFields", capability: .tasks)],
            extras: [], listsAccounts: false, providers: ["clickup"], logo: IntegrationLogo(resource: "clickup", kind: .mark)),
        IntegrationInfo(
            id: "clockodo", access: .emailKey, companyOwned: false,
            fields: [IntegrationField(id: "email", secret: false), IntegrationField(id: "key", secret: true),
                     IntegrationField(id: "user", secret: false, optional: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["clockodo"],
            logo: IntegrationLogo(resource: "clockodo", kind: .full)),
        IntegrationInfo(
            id: "claude", access: .key, companyOwned: false,
            fields: [IntegrationField(id: "key", secret: true),
                     IntegrationField(id: "model", secret: false, optional: true, fallbackKey: "settings.value.default")],
            areas: [], extras: [], listsAccounts: false, providers: ["claude"],
            logo: IntegrationLogo(resource: "claude", kind: .full)),
        IntegrationInfo(
            id: "airtable", access: .key, companyOwned: true,
            fields: [IntegrationField(id: "base", secret: false), IntegrationField(id: "token", secret: true)],
            areas: [IntegrationArea(id: "projects", capability: nil)],
            extras: [IntegrationExtra(id: "cache", capability: nil, kind: .clear, actionKey: "settings.action.clear")],
            listsAccounts: false,
            providers: ["airtable"], logo: IntegrationLogo(resource: "airtable", kind: .mark)),
        IntegrationInfo(
            id: "sevdesk", access: .key, companyOwned: true, fields: [IntegrationField(id: "token", secret: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["sevdesk"],
            logo: IntegrationLogo(resource: "sevdesk", kind: .full)),
        IntegrationInfo(
            id: "dhl", access: .key, companyOwned: true,
            fields: [IntegrationField(id: "key", secret: true), IntegrationField(id: "shipKey", secret: true, optional: true),
                     IntegrationField(id: "secret", secret: true, optional: true), IntegrationField(id: "user", secret: false, optional: true),
                     IntegrationField(id: "password", secret: true, optional: true),
                     IntegrationField(id: "billing", secret: false, optional: true)],
            areas: [], extras: [], listsAccounts: false, providers: ["dhl"],
            logo: IntegrationLogo(resource: "dhl", kind: .wide)),
    ])
}

public final class CostStore: CostPort {
    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    static func day(of date: Date) -> Int {
        Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    public func book(_ item: CostItem) {
        let day = Self.day(of: item.at)
        try? database.write { db in
            try db.execute(sql: """
                INSERT INTO cost_day (inlet, capability, day, calls, bytes, tokens) VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(inlet, capability, day) DO UPDATE SET
                    calls = calls + excluded.calls, bytes = bytes + excluded.bytes, tokens = tokens + excluded.tokens
                """, arguments: [item.inlet, item.capability.rawValue, day, item.cost.calls, item.cost.bytes, item.cost.tokens])
        }
    }
}

public struct KeychainStore: KeychainPort {
    static let encodingStatus: Int32 = -1
    static let missingOwnerStatus: OSStatus = -67068

    private let prefix: String

    public init(prefix: String = AppIdentity.keychainPrefix) {
        self.prefix = prefix
    }

    static func service(for slot: KeySlot, prefix: String = AppIdentity.keychainPrefix) -> String {
        prefix + "hub." + slot.inlet
    }

    static func account(for slot: KeySlot) -> String {
        slot.name
    }

    private func identity(_ slot: KeySlot) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service(for: slot, prefix: prefix),
            kSecAttrAccount: Self.account(for: slot),
        ]
    }

    public func put(_ value: String, at slot: KeySlot) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainFailure.status(Self.encodingStatus) }
        let query = identity(slot)
        let added = SecItemAdd(query.merging([kSecValueData: data]) { _, new in new } as CFDictionary, nil)
        if added == errSecSuccess { return }
        guard added == errSecDuplicateItem else { throw KeychainFailure.status(added) }
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if updated == errSecSuccess { return }
        let removed = SecItemDelete(query as CFDictionary)
        guard removed == errSecSuccess || removed == errSecItemNotFound else { throw KeychainFailure.status(removed) }
        let readded = SecItemAdd(query.merging([kSecValueData: data]) { _, new in new } as CFDictionary, nil)
        guard readded == errSecSuccess else { throw KeychainFailure.status(readded) }
    }

    public func get(_ slot: KeySlot) throws -> String? {
        let context = LAContext()
        context.interactionNotAllowed = true
        let query = identity(slot).merging([
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: context,
        ]) { _, new in new }
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound || status == Self.missingOwnerStatus { return nil }
        guard status == errSecSuccess else { throw KeychainFailure.status(status) }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw KeychainFailure.status(Self.encodingStatus)
        }
        return value
    }

    public func delete(_ slot: KeySlot) throws {
        let status = SecItemDelete(identity(slot) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound || status == Self.missingOwnerStatus else {
            throw KeychainFailure.status(status)
        }
    }
}
