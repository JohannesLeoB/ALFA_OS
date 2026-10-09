import Foundation

/// Writes a ZIP archive with the "stored" method (no compression) and CRC-32 checksums.
/// Names are UTF-8 (general purpose flag bit 11). Only Foundation is used.
struct ZipWriter: Sendable {
    enum Failure: Error, Equatable, Sendable {
        case invalidName(String)
        case duplicateName(String)
        case tooLarge
    }

    private static let utf8Flag: UInt16 = 0x0800
    private static let versionNeeded: UInt16 = 20

    private var entries: [(name: String, data: Data)] = []

    init() {}

    mutating func add(_ name: String, data: Data) throws {
        guard Self.isValid(name) else { throw Failure.invalidName(name) }
        guard !entries.contains(where: { $0.name == name }) else { throw Failure.duplicateName(name) }
        entries.append((name: name, data: data))
    }

    /// The archive bytes. `modified` sets the time of every entry (UTC, DOS format, years from 1980).
    func archive(modified: Date) throws -> Data {
        guard entries.count <= 0xFFFF else { throw Failure.tooLarge }
        let stamp = Self.dosStamp(modified)
        var body = Data()
        var central = Data()
        for entry in entries {
            guard entry.data.count <= 0xFFFF_FFFF, body.count <= 0xFFFF_FFFF else { throw Failure.tooLarge }
            let name = Data(entry.name.utf8)
            let size = UInt32(entry.data.count)
            let crc = Self.crc32(entry.data)
            let offset = UInt32(body.count)

            body.append(u32: 0x0403_4B50)
            body.append(u16: Self.versionNeeded)
            body.append(u16: Self.utf8Flag)
            body.append(u16: 0)
            body.append(u16: stamp.time)
            body.append(u16: stamp.date)
            body.append(u32: crc)
            body.append(u32: size)
            body.append(u32: size)
            body.append(u16: UInt16(name.count))
            body.append(u16: 0)
            body.append(name)
            body.append(entry.data)

            central.append(u32: 0x0201_4B50)
            central.append(u16: Self.versionNeeded)
            central.append(u16: Self.versionNeeded)
            central.append(u16: Self.utf8Flag)
            central.append(u16: 0)
            central.append(u16: stamp.time)
            central.append(u16: stamp.date)
            central.append(u32: crc)
            central.append(u32: size)
            central.append(u32: size)
            central.append(u16: UInt16(name.count))
            central.append(u16: 0)
            central.append(u16: 0)
            central.append(u16: 0)
            central.append(u16: 0)
            central.append(u32: 0)
            central.append(u32: offset)
            central.append(name)
        }
        guard body.count + central.count + 22 <= 0xFFFF_FFFF else { throw Failure.tooLarge }
        let centralOffset = UInt32(body.count)
        var out = body
        out.append(central)

        out.append(u32: 0x0605_4B50)
        out.append(u16: 0)
        out.append(u16: 0)
        out.append(u16: UInt16(entries.count))
        out.append(u16: UInt16(entries.count))
        out.append(u32: UInt32(central.count))
        out.append(u32: centralOffset)
        out.append(u16: 0)
        return out
    }

    /// A name is relative, uses "/" and has no empty, "." or ".." part.
    static func isValid(_ name: String) -> Bool {
        guard !name.isEmpty, name.utf8.count <= 0xFFFF, !name.hasPrefix("/"), !name.contains("\\") else { return false }
        return name.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { part in
            !part.isEmpty && part != "." && part != ".."
        }
    }

    static func dosStamp(_ date: Date) -> (time: UInt16, date: UInt16) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = min(2107, max(1980, parts.year ?? 1980))
        let time = (parts.hour ?? 0) << 11 | (parts.minute ?? 0) << 5 | (parts.second ?? 0) / 2
        let day = (year - 1980) << 9 | (parts.month ?? 1) << 5 | (parts.day ?? 1)
        return (UInt16(time), UInt16(day))
    }

    private static let crcTable: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func append(u16 value: UInt16) {
        append(contentsOf: [UInt8(value & 0xFF), UInt8(value >> 8)])
    }

    mutating func append(u32 value: UInt32) {
        for shift in stride(from: 0, to: 32, by: 8) {
            append(UInt8((value >> UInt32(shift)) & 0xFF))
        }
    }
}
