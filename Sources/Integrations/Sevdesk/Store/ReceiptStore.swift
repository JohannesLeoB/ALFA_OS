import Assistant
import Foundation
import GRDB
import Hub
import Storage

public struct ReceiptStore: ReceiptPort {
    static let legacyKey = "sevdesk.receipts"

    private let database: SQLiteStore

    public init(database: SQLiteStore) {
        self.database = database
    }

    public func receipts() async -> [ReceiptEntry] {
        all().map {
            ReceiptEntry(
                kind: $0.kind, number: $0.number, projectNumber: $0.projectNumber,
                customerName: $0.customerName, createdAt: $0.createdAt)
        }
    }

    public func all() -> [Receipt] {
        let rows: [Data] = (try? database.read { db in
            try Data.fetchAll(db, sql: "SELECT json FROM sevdeskReceipts ORDER BY seq")
        }) ?? []
        return rows.compactMap { try? JSONDecoder().decode(Receipt.self, from: $0) }
    }

    public func register(_ receipt: Receipt) throws {
        let data = try JSONEncoder().encode(receipt)
        try database.write { db in
            try db.execute(sql: "INSERT OR IGNORE INTO sevdeskReceipts (orderID, json) VALUES (?, ?)", arguments: [receipt.orderID, data])
        }
    }

    public func merge(_ remote: Receipt) throws {
        try database.write { db in
            let stored = try Data.fetchOne(db, sql: "SELECT json FROM sevdeskReceipts WHERE orderID = ?", arguments: [remote.orderID])
            guard let stored, var local = try? JSONDecoder().decode(Receipt.self, from: stored) else {
                try db.execute(sql: "INSERT OR REPLACE INTO sevdeskReceipts (orderID, json) VALUES (?, ?)",
                               arguments: [remote.orderID, try JSONEncoder().encode(remote)])
                return
            }
            var changed = false
            if remote.lastStatus > local.lastStatus {
                local.lastStatus = remote.lastStatus
                local.lastUpdate = remote.lastUpdate
                changed = true
            }
            if remote.pdfStored && local.pdfStored == false {
                local.pdfStored = true
                changed = true
            }
            guard changed else { return }
            try db.execute(sql: "UPDATE sevdeskReceipts SET json = ? WHERE orderID = ?",
                           arguments: [try JSONEncoder().encode(local), remote.orderID])
        }
    }

    public func adopt(legacy defaults: UserDefaults) throws {
        guard let data = defaults.data(forKey: Self.legacyKey) else { return }
        if let list = try? JSONDecoder().decode([Receipt].self, from: data) {
            for receipt in list { try register(receipt) }
        }
        defaults.removeObject(forKey: Self.legacyKey)
    }
}

public struct CredentialsStore: CredentialsPort {
    static let tokenName = "token"

    private let keychain: any KeychainPort
    private let inlet: Inlet.ID

    public init(keychain: any KeychainPort, inlet: Inlet.ID) {
        self.keychain = keychain
        self.inlet = inlet
    }

    public func load() throws -> Credentials? {
        guard let token = try keychain.get(KeySlot(inlet: inlet, name: Self.tokenName)), token.isEmpty == false else {
            return nil
        }
        return Credentials(token: token)
    }
}

public struct Credentials: Equatable, Sendable {
    public var token: String

    public init(token: String) {
        self.token = token
    }
}
