import Core
import Foundation

public enum DatabaseStore {
    static let fileName = "alfa.sqlite"

    public static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(AppIdentity.name, isDirectory: true)
    }

    public static func size(in directory: URL? = nil) -> Int? {
        let folder = directory ?? Self.directory()
        let attributes = try? FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(fileName).path)
        return (attributes?[.size] as? NSNumber)?.intValue
    }

    public static func open(in directory: URL? = nil) throws -> SQLiteStore {
        let folder = directory ?? Self.directory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try SQLiteStore(path: folder.appendingPathComponent(fileName).path)
    }
}
