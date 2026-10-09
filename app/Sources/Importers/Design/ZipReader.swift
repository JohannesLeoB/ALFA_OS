import Compression
import Foundation

/// Limits for an archive that comes from outside. Sizes are in bytes.
public struct ZipLimits: Equatable, Sendable {
    public var entryBytes: Int
    public var totalBytes: Int
    public var entryCount: Int

    public static let standard = ZipLimits(entryBytes: 64 << 20, totalBytes: 256 << 20, entryCount: 4096)

    public init(entryBytes: Int, totalBytes: Int, entryCount: Int) {
        self.entryBytes = entryBytes
        self.totalBytes = totalBytes
        self.entryCount = entryCount
    }
}

/// One file of an archive, unpacked and checked against its CRC-32.
public struct ZipFile: Equatable, Sendable {
    public let path: String
    public let data: Data
}

/// A file that could not be read. The other files of the archive are still read.
public struct ZipProblem: Equatable, Sendable {
    public let path: String
    public let reason: String
}

public struct ZipContents: Equatable, Sendable {
    public var files: [ZipFile]
    public var problems: [ZipProblem]
}

/// An error that stops the whole archive. An unsafe name stops it too: nothing from it is used.
public enum ZipError: Error, Equatable, Sendable {
    case notAZip
    case corruptDirectory(String)
    case unsafePath(String)
    case tooLarge(String)
    case tooManyEntries
    case unsupported(String)
}

/// Reads ZIP archives with the "stored" and "deflate" methods (no ZIP64, no encryption).
/// Deflate uses the Compression framework on raw deflate data (COMPRESSION_ZLIB).
public enum ZipReader {
    public static func read(_ archive: Data, limits: ZipLimits = .standard) throws -> ZipContents {
        let bytes = [UInt8](archive)
        guard bytes.count >= 22 else { throw ZipError.notAZip }
        guard let end = endOfDirectory(bytes) else { throw ZipError.notAZip }
        let count = Int(u16(bytes, end + 10))
        let directorySize = Int(u32(bytes, end + 12))
        let directoryOffset = Int(u32(bytes, end + 16))
        if count == 0xFFFF || directorySize == 0xFFFF_FFFF || directoryOffset == 0xFFFF_FFFF {
            throw ZipError.unsupported("ZIP64")
        }
        guard count <= limits.entryCount else { throw ZipError.tooManyEntries }
        guard directoryOffset + directorySize <= end else { throw ZipError.corruptDirectory("directory outside the archive") }

        var files: [ZipFile] = []
        var problems: [ZipProblem] = []
        var total = 0
        var position = directoryOffset
        for _ in 0..<count {
            guard position + 46 <= bytes.count, u32(bytes, position) == 0x0201_4B50 else {
                throw ZipError.corruptDirectory("bad central directory header")
            }
            let flags = u16(bytes, position + 8)
            let method = u16(bytes, position + 10)
            let crc = u32(bytes, position + 16)
            let packedSize = Int(u32(bytes, position + 20))
            let size = Int(u32(bytes, position + 24))
            let nameLength = Int(u16(bytes, position + 28))
            let extraLength = Int(u16(bytes, position + 30))
            let commentLength = Int(u16(bytes, position + 32))
            let offset = Int(u32(bytes, position + 42))
            let nameStart = position + 46
            guard nameStart + nameLength <= bytes.count else { throw ZipError.corruptDirectory("name outside the archive") }
            let nameBytes = Array(bytes[nameStart..<(nameStart + nameLength)])
            position = nameStart + nameLength + extraLength + commentLength

            guard packedSize != 0xFFFF_FFFF, size != 0xFFFF_FFFF, offset != 0xFFFF_FFFF else { throw ZipError.unsupported("ZIP64") }
            guard let name = String(bytes: nameBytes, encoding: .utf8) else {
                problems.append(ZipProblem(path: "(name is not UTF-8)", reason: "name is not UTF-8"))
                continue
            }
            try validate(name)
            if name.hasSuffix("/") { continue }
            guard flags & 1 == 0 else {
                problems.append(ZipProblem(path: name, reason: "encrypted files are not read"))
                continue
            }
            guard size <= limits.entryBytes else { throw ZipError.tooLarge(name) }
            total += size
            guard total <= limits.totalBytes else { throw ZipError.tooLarge("archive") }

            do {
                let data = try entry(bytes, offset: offset, packedSize: packedSize, size: size, method: method, crc: crc)
                files.append(ZipFile(path: name, data: data))
            } catch let problem as ZipProblemError {
                problems.append(ZipProblem(path: name, reason: problem.reason))
            }
        }
        return ZipContents(files: files, problems: problems)
    }

    /// A name is relative, uses "/" only and has no empty, "." or ".." part and no drive letter.
    public static func validate(_ name: String) throws {
        guard !name.isEmpty, name.utf8.count <= 0xFFFF else { throw ZipError.unsafePath(name) }
        guard !name.hasPrefix("/"), !name.contains("\\"), !name.contains(":"), !name.contains("\0") else {
            throw ZipError.unsafePath(name)
        }
        var parts = name.split(separator: "/", omittingEmptySubsequences: false)
        if name.hasSuffix("/") { parts.removeLast() }
        for part in parts where part.isEmpty || part == "." || part == ".." {
            throw ZipError.unsafePath(name)
        }
    }

    // MARK: - One entry

    private struct ZipProblemError: Error { let reason: String }

    private static func entry(_ bytes: [UInt8], offset: Int, packedSize: Int, size: Int, method: UInt16, crc: UInt32) throws -> Data {
        guard offset + 30 <= bytes.count, u32(bytes, offset) == 0x0403_4B50 else {
            throw ZipProblemError(reason: "local header is missing")
        }
        let start = offset + 30 + Int(u16(bytes, offset + 26)) + Int(u16(bytes, offset + 28))
        guard start + packedSize <= bytes.count else { throw ZipProblemError(reason: "data is cut off") }
        let packed = Array(bytes[start..<(start + packedSize)])
        let data: Data
        switch method {
        case 0:
            guard packedSize == size else { throw ZipProblemError(reason: "stored size does not match") }
            data = Data(packed)
        case 8:
            data = try inflate(packed, size: size)
        default:
            throw ZipProblemError(reason: "method \(method) is not read")
        }
        guard crc32(data) == crc else { throw ZipProblemError(reason: "checksum does not match") }
        return data
    }

    private static func inflate(_ packed: [UInt8], size: Int) throws -> Data {
        if size == 0 { return Data() }
        guard !packed.isEmpty else { throw ZipProblemError(reason: "deflate data is empty") }
        // One byte more than declared: a larger result shows up as a wrong size.
        var output = [UInt8](repeating: 0, count: size + 1)
        let written = packed.withUnsafeBufferPointer { source in
            output.withUnsafeMutableBufferPointer { target in
                compression_decode_buffer(target.baseAddress!, target.count, source.baseAddress!, source.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw ZipProblemError(reason: "deflate size does not match") }
        return Data(output[0..<size])
    }

    // MARK: - Layout helpers

    /// The offset of the end-of-central-directory record, searched from the end (the comment can be up to 64 KB).
    private static func endOfDirectory(_ bytes: [UInt8]) -> Int? {
        var index = bytes.count - 22
        let lowest = max(0, bytes.count - 22 - 0xFFFF)
        while index >= lowest {
            if u32(bytes, index) == 0x0605_4B50 { return index }
            index -= 1
        }
        return nil
    }

    static func u16(_ bytes: [UInt8], _ at: Int) -> UInt16 {
        UInt16(bytes[at]) | UInt16(bytes[at + 1]) << 8
    }

    static func u32(_ bytes: [UInt8], _ at: Int) -> UInt32 {
        UInt32(u16(bytes, at)) | UInt32(u16(bytes, at + 2)) << 16
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }

    private static let crcTable: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }
}
