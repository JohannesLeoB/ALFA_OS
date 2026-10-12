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

    public static func open(in directory: URL? = nil) throws -> DatabaseQueue {
        let folder = try directory ?? defaultDirectory()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try DatabaseQueue(path: folder.appendingPathComponent(fileName).path)
    }

    public static func inMemory() throws -> DatabaseQueue {
        try DatabaseQueue()
    }
}
