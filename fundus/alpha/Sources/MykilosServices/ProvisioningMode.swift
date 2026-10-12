import Foundation
import Observation
import GRDB
import MykilosKit

public enum ProvisioningMode: String, Codable, Sendable, CaseIterable {
    case test
    case prod
}

private struct AppSettingRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { "appSettings" }
    var key: String
    var value: String
    var updatedAt: Double
}

@MainActor
@Observable
public final class ProvisioningModeStore {
    public private(set) var mode: ProvisioningMode = .test
    public private(set) var saveState: SaveState = .idle

    private let db: GRDBDatabase
    private static let settingKey = "provisioningMode"

    public init(db: GRDBDatabase) {
        self.db = db
    }

    public func load() throws {
        let record = try db.read { dbConn in
            try AppSettingRecord.fetchOne(dbConn, key: Self.settingKey)
        }
        if let record, let loaded = ProvisioningMode(rawValue: record.value) {
            mode = loaded
        } else {
            mode = .test
        }
    }

    public func setMode(_ newMode: ProvisioningMode) throws {
        guard newMode == .test else {
            throw ProvisioningModeError.prodLocked
        }
        saveState = .saving
        do {
            try db.write { dbConn in
                try AppSettingRecord(key: Self.settingKey, value: newMode.rawValue,
                                      updatedAt: Date().timeIntervalSince1970).save(dbConn)
            }
            mode = newMode
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}

public enum ProvisioningModeError: Error, Sendable, Equatable, LocalizedError {
    case prodLocked
    public var errorDescription: String? {
        "PROD-Modus ist gesperrt."
    }
}

public enum TestMarker {
    public static let namePrefix = "TEST_"
    public static let quelleFieldValue = "TEST"

    public static func isTestRecord(name: String?, source: String?) -> Bool {
        (name?.hasPrefix(namePrefix) == true) && (source == quelleFieldValue)
    }
}
