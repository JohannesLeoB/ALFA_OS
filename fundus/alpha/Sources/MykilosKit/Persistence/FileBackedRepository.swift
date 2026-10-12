import Foundation

public final class FileBackedRepository<Entity: Codable & Identifiable & Sendable>: Repository, @unchecked Sendable {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    public init(filename: String, directory: URL? = nil) throws {
        let base: URL
        if let directory {
            base = directory
        } else {
            guard let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw PersistenceError.directoryUnavailable
            }
            base = appSupport.appendingPathComponent(AppKennung.name, isDirectory: true)
        }
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        self.fileURL = base.appendingPathComponent(filename).appendingPathExtension("json")

        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate)
        }
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            return Date(timeIntervalSinceReferenceDate: try container.decode(Double.self))
        }
        self.encoder = e
        self.decoder = d
    }

    public func loadAll() throws -> [Entity] {
        lock.lock(); defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data: Data
        do { data = try Data(contentsOf: fileURL) } catch { throw PersistenceError.decodeFailed }
        do { return try decoder.decode([Entity].self, from: data) } catch { throw PersistenceError.decodeFailed }
    }

    public func saveAll(_ entities: [Entity]) throws {
        lock.lock(); defer { lock.unlock() }
        let data: Data
        do { data = try encoder.encode(entities) } catch { throw PersistenceError.encodeFailed }
        do { try data.write(to: fileURL, options: [.atomic]) } catch { throw PersistenceError.writeFailed }
    }
}
