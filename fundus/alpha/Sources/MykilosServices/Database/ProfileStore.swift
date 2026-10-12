import Foundation
import Observation
import GRDB
import MykilosKit

@MainActor
@Observable
public final class ProfileStore {
    public private(set) var profile: UserProfile?
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load() throws {
        let record = try db.read { dbConn in
            try ProfileRecord.fetchOne(dbConn, key: ProfileRecord.localID)
        }
        profile = record?.toDomain()
    }

    public func save(_ profile: UserProfile) throws {
        saveState = .saving
        do {
            let record = ProfileRecord(from: profile)
            try db.write { dbConn in
                try record.save(dbConn)
            }
            self.profile = profile
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public var isEmpty: Bool {
        profile?.isComplete != true
    }

    public static func ensureUserID(
        db: GRDBDatabase,
        googleEmail: String? = nil,
        anchorStore: any IdentityAnchorStoring = KeychainIdentityAnchorStore()
    ) -> String {
        do {
            if let email = googleEmail,
               email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                let keychainAnchor = (try? anchorStore.userID(forEmail: email)).flatMap { $0 }
                let anchoredUserID = ResidentIdentityStore.userID(forEmail: email, db: db)
                    ?? keychainAnchor
                if let alteUUID = anchoredUserID,
                   alteUUID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    let existing = try db.read { dbConn in
                        try ProfileRecord.fetchOne(dbConn, key: ProfileRecord.localID)
                    }
                    if existing?.userID != alteUUID {
                        let base = existing ?? ProfileRecord(from: UserProfile.empty)
                        let rebound = base.withUserID(alteUUID)
                        try db.write { dbConn in try rebound.save(dbConn) }
                    }
                    return alteUUID
                }
            }
            if let existing = try db.read({ dbConn in
                try ProfileRecord.fetchOne(dbConn, key: ProfileRecord.localID)
            }) {
                if let userID = existing.userID,
                   userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    return userID
                }
                let freshID = UUID().uuidString
                let updated = existing.withUserID(freshID)
                try db.write { dbConn in try updated.save(dbConn) }
                return freshID
            }
            let freshID = UUID().uuidString
            let placeholder = ProfileRecord(from: UserProfile.empty).withUserID(freshID)
            try db.write { dbConn in try placeholder.save(dbConn) }
            return freshID
        } catch {
            return "local"
        }
    }

    @discardableResult
    public static func resetToFreshGuest(db: GRDBDatabase) -> String {
        let freshID = UUID().uuidString
        do {
            let guest = ProfileRecord(from: UserProfile.empty).withUserID(freshID)
            try db.write { dbConn in try guest.save(dbConn) }
            return freshID
        } catch {
            return "local"
        }
    }
}
