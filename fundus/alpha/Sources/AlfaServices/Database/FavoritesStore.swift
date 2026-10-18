import Foundation
import Observation
import GRDB
import AlfaKit

struct ProjectFavoriteRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "projectFavorites" }
    var projectNumber: String
    var addedAt: Double
}

@MainActor
@Observable
public final class FavoritesStore {
    public private(set) var favorites: Set<String> = []
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load() throws {
        let records = try db.read { try ProjectFavoriteRecord.fetchAll($0) }
        favorites = Set(records.map(\.projectNumber))
    }

    public func isFavorite(_ projectNumber: String) -> Bool {
        favorites.contains(projectNumber)
    }

    public func toggle(projectNumber: String) throws {
        saveState = .saving
        do {
            if favorites.contains(projectNumber) {
                _ = try db.write { try ProjectFavoriteRecord.deleteOne($0, key: projectNumber) }
                favorites.remove(projectNumber)
            } else {
                let record = ProjectFavoriteRecord(
                    projectNumber: projectNumber, addedAt: Date().timeIntervalSince1970)
                try db.write { try record.insert($0) }
                favorites.insert(projectNumber)
            }
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
