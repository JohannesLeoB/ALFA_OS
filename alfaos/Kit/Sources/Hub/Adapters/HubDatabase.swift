import Foundation
import GRDB

public enum HubDatabase {
    public static let fileName = "hub.sqlite"
    public static let directoryName = "ALFA_OS"

    public static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        return base.appendingPathComponent(directoryName, isDirectory: true)
    }

    public static func size(in directory: URL? = nil) -> Int? {
        guard let folder = try? directory ?? defaultDirectory() else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent(fileName).path)
        return (attributes?[.size] as? NSNumber)?.intValue
    }

    public static func open(in directory: URL? = nil) throws -> DatabaseQueue {
        let folder = try directory ?? defaultDirectory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try DatabaseQueue(path: folder.appendingPathComponent(fileName).path)
    }

    public static func inMemory() throws -> DatabaseQueue {
        try DatabaseQueue()
    }
}
