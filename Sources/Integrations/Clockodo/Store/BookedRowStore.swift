import Foundation
import GRDB
import Hub
import Storage

struct BookedRowStore: BookedRowPort {
    private struct Record: Codable, FetchableRecord, PersistableRecord {
        static var databaseTableName: String { "bookedRows" }

        var rowID: String
        var clockodoEntryID: String
        var bookedAt: Double
        var userID: String
    }

    private let database: SQLiteStore

    init(database: SQLiteStore) {
        self.database = database
    }

    func bookedIDs(userID: String) throws -> Set<UUID> {
        let records = try database.read { db in
            try Record.filter(Column("userID") == userID).fetchAll(db)
        }
        return Set(records.compactMap { UUID(uuidString: $0.rowID) })
    }

    func mark(rowID: UUID, entryID: String, userID: String, at date: Date = Date()) throws {
        let record = Record(
            rowID: rowID.uuidString, clockodoEntryID: entryID, bookedAt: date.timeIntervalSince1970, userID: userID)
        try database.write { db in
            try record.insert(db)
        }
    }
}

public struct CredentialsStore: CredentialsPort {
    static let emailName = "email"
    static let keyName = "key"

    private let keychain: any KeychainPort
    private let inlet: Inlet.ID

    public init(keychain: any KeychainPort, inlet: Inlet.ID) {
        self.keychain = keychain
        self.inlet = inlet
    }

    public func load() throws -> Credentials? {
        guard let email = try keychain.get(KeySlot(inlet: inlet, name: Self.emailName)), email.isEmpty == false,
              let key = try keychain.get(KeySlot(inlet: inlet, name: Self.keyName)), key.isEmpty == false
        else { return nil }
        return Credentials(email: email, key: key)
    }
}

public struct Credentials: Equatable, Sendable {
    public var email: String
    public var key: String

    public init(email: String, key: String) {
        self.email = email
        self.key = key
    }
}
