import Foundation
import CryptoKit

/// The binary files of a document (images), one per content. The ID is the SHA-256 of the content
/// in lower-case hex. The same ID is in `Content.image(assetID:)` and in the file name `assets/<id>.<ext>`.
///
/// Opening a package does not read the image bytes. An entry loads its bytes when `data()` is called.
/// Nothing is cached here: whoever needs an image often keeps it.
public struct AssetStore: Equatable, Sendable {
    /// Where the bytes of an entry are.
    enum Source: Sendable {
        case memory(Data)
        case wrapper(WrapperBox)

        func load() throws -> Data {
            switch self {
            case .memory(let data): return data
            case .wrapper(let box): return try box.contents()
            }
        }
    }

    /// Holds a file wrapper whose contents are read on first use. A lock guards the wrapper, which is not thread safe.
    final class WrapperBox: @unchecked Sendable {
        private let wrapper: FileWrapper
        private let lock = NSLock()
        init(_ wrapper: FileWrapper) { self.wrapper = wrapper }
        func contents() throws -> Data {
            lock.lock(); defer { lock.unlock() }
            guard let data = wrapper.regularFileContents else {
                throw PackageError.unreadable(reason: wrapper.preferredFilename ?? "")
            }
            return data
        }
    }

    /// Two entries with the same ID are equal when the extension is equal: the ID is the hash of the bytes.
    public struct Entry: Equatable, Sendable {
        public let fileExtension: String
        let source: Source
        init(fileExtension: String, source: Source) { self.fileExtension = fileExtension; self.source = source }

        /// True when the bytes are in memory, so `data()` cannot fail and does not read from disk.
        public var isLoaded: Bool { if case .memory = source { true } else { false } }
        /// The bytes. They are read from the package each time, unless they are in memory.
        public func data() throws -> Data { try source.load() }
        public static func == (a: Entry, b: Entry) -> Bool { a.fileExtension == b.fileExtension }
    }

    public private(set) var entries: [String: Entry] = [:]
    public init() {}

    /// Stores bytes and returns the ID. The same bytes give the same ID and are stored once.
    /// The extension of the first store stays.
    @discardableResult
    public mutating func add(_ data: Data, fileExtension: String) -> String {
        let id = Self.hash(of: data)
        if entries[id] == nil { entries[id] = Entry(fileExtension: Self.cleanExtension(fileExtension), source: .memory(data)) }
        return id
    }

    public subscript(id: String) -> Entry? { entries[id] }
    public var ids: [String] { entries.keys.sorted() }
    public var count: Int { entries.count }
    public mutating func remove(_ id: String) { entries[id] = nil }

    /// SHA-256 as 64 lower-case hex characters.
    public static func hash(of data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        var out = [UInt8](); out.reserveCapacity(64)
        for byte in SHA256.hash(data: data) { out.append(digits[Int(byte >> 4)]); out.append(digits[Int(byte & 0xF)]) }
        return String(decoding: out, as: UTF8.self)
    }

    /// Lower-case extension without dot, only a-z0-9, at most 16 characters. Otherwise "bin".
    public static func cleanExtension(_ ext: String) -> String {
        let e = ext.lowercased().drop(while: { $0 == "." })
        return isValidExtension(String(e)) ? String(e) : "bin"
    }
    static func isValidExtension(_ e: String) -> Bool {
        !e.isEmpty && e.utf8.count <= 16 && e.utf8.allSatisfy { ($0 >= 97 && $0 <= 122) || ($0 >= 48 && $0 <= 57) }
    }
    static func isValidID(_ id: String) -> Bool {
        id.utf8.count == 64 && id.utf8.allSatisfy { ($0 >= 97 && $0 <= 102) || ($0 >= 48 && $0 <= 57) }
    }

    /// For the reader: take an entry without recomputing the hash and without reading the bytes.
    mutating func insert(id: String, fileExtension: String, source: Source) {
        entries[id] = Entry(fileExtension: fileExtension, source: source)
    }
}
