import Foundation
import Observation
import GRDB
import AlfaKit

@MainActor
@Observable
public final class ResidentIdentityStore {
    public private(set) var identity: ResidentIdentity?
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func loadByEmail(_ email: String) throws {
        let key = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.isEmpty == false else {
            identity = nil
            return
        }
        let record = try db.read { dbConn in
            try ResidentIdentityRecord.fetchOne(dbConn, key: key)
        }
        identity = record?.toDomain()
    }

    public func save(_ identity: ResidentIdentity) throws {
        saveState = .saving
        do {
            guard identity.hasValidKey else {
                throw ResidentIdentityError.emptyEmailKey
            }
            let record = ResidentIdentityRecord(from: identity)
            try db.write { dbConn in
                try record.save(dbConn)
            }
            self.identity = identity
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public static func userID(forEmail email: String, db: GRDBDatabase) -> String? {
        let key = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.isEmpty == false else { return nil }
        do {
            let record = try db.read { dbConn in
                try ResidentIdentityRecord.fetchOne(dbConn, key: key)
            }
            guard let userID = record?.userID,
                  userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return nil
            }
            return userID
        } catch {
            return nil
        }
    }
}

public enum ResidentIdentityError: Error, Equatable {
    case emptyEmailKey
}
