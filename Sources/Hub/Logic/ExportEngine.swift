import Foundation

public enum ExportEngine {
    public static let formatVersion = 1

    static let secretMarks = [
        "password", "passwd", "passphrase", "secret", "token", "apikey", "api_key", "credential", "authorization", "bearer",
        "keychain", "privatekey", "private_key", "accesskey", "access_key", "refresh", "cookie",
    ]

    static let profilePrefixes = ["settings.identity."]
    static let companyPrefixes = ["settings.company.", "settings.imprint."]
    static let mailboxPrefix = "settings.mailbox."
    static let appExact: Set<String> = ["appearance", "settings.startView", "google.drive.projectsRoot"]
    static let appPrefixes = [
        "settings.lock.", "settings.privacy.", "settings.contacts.source.", "cadence|", "lastsync|", "calculation.",
    ]

    public static func isSecret(_ name: String) -> Bool {
        let lowered = name.lowercased()
        return secretMarks.contains { lowered.contains($0) }
    }

    public static func fileName(at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "ALFA_OS-Export-" + formatter.string(from: date) + ".zip"
    }

    public static func component(_ text: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-@")
        let mapped = String(text.map { allowed.contains($0) ? $0 : "_" })
        let trimmed = mapped.drop { $0 == "." }
        return trimmed.isEmpty ? "_" : String(trimmed)
    }

    public static func files(from source: ExportSource) -> [ExportFile] {
        var collected = Collector()
        settingFiles(source.settings, into: &collected)
        collected.add("contacts.json", contacts(source.contacts))
        collected.add("templates.json", json(source.templates.sorted()))
        for table in ExportTable.allCases {
            tableFiles(table, rows: source.tables[table] ?? [], into: &collected)
        }
        for mail in source.rawMails {
            collected.add("mail/\(component(mail.inlet))/pop/\(component(mail.id)).eml", mail.data)
        }
        let listing = collected.files.map { ["path": $0.path, "bytes": $0.data.count] as [String: Any] }
        let manifest: [String: Any] = [
            "app": "ALFA_OS",
            "formatVersion": formatVersion,
            "generatedAt": ISO8601DateFormatter().string(from: source.generatedAt),
            "files": listing,
            "excluded": ["keychain", "tokens", "passwords", "apiKeys"],
        ]
        collected.add("manifest.json", json(manifest))
        return collected.files
    }

    private struct Collector {
        var files: [ExportFile] = []
        var taken: Set<String> = []

        mutating func add(_ path: String, _ data: Data) {
            var name = path
            var number = 2
            let stem = (path as NSString).deletingPathExtension
            let suffix = (path as NSString).pathExtension
            while taken.contains(name.lowercased()) {
                name = stem + "-" + String(number) + (suffix.isEmpty ? "" : "." + suffix)
                number += 1
            }
            taken.insert(name.lowercased())
            files.append(ExportFile(path: name, data: data))
        }
    }

    private static func json(_ value: Any) -> Data {
        let clean = scrub(value, dropping: [])
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard JSONSerialization.isValidJSONObject(clean),
              let data = try? JSONSerialization.data(withJSONObject: clean, options: options) else { return Data("null".utf8) }
        return data
    }

    static func scrub(_ value: Any, dropping extra: Set<String>) -> Any {
        if let dictionary = value as? [String: Any] {
            var result: [String: Any] = [:]
            for (name, item) in dictionary where !isSecret(name) && !extra.contains(name) {
                result[name] = scrub(item, dropping: extra)
            }
            return result
        }
        if let list = value as? [Any] { return list.map { scrub($0, dropping: extra) } }
        return value
    }

    private static func parsed(_ data: Data) -> Any? {
        try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    private static func contacts(_ data: Data?) -> Data {
        json(data.flatMap(parsed) ?? [Any]())
    }

    private static func settingFiles(_ settings: [String: Data], into collected: inout Collector) {
        var profile: [String: Any] = [:]
        var company: [String: Any] = [:]
        var app: [String: Any] = [:]
        var mailboxes: [String: [String: Any]] = [:]
        for (name, data) in settings where !isSecret(name) {
            guard let value = parsed(data) else { continue }
            if profilePrefixes.contains(where: { name.hasPrefix($0) }) {
                profile[name] = value
            } else if companyPrefixes.contains(where: { name.hasPrefix($0) }) {
                company[name] = value
            } else if name.hasPrefix(mailboxPrefix) {
                let rest = name.dropFirst(mailboxPrefix.count)
                guard let dot = rest.firstIndex(of: ".") else { continue }
                mailboxes[String(rest[rest.index(after: dot)...]), default: [:]][String(rest[..<dot])] = value
            } else if appExact.contains(name) || appPrefixes.contains(where: { name.hasPrefix($0) }) {
                app[name] = value
            }
        }
        collected.add("profile.json", json(profile))
        collected.add("company.json", json(company))
        collected.add("mailboxes.json", json(mailboxes))
        collected.add("settings.json", json(app))
    }

    private static func tableFiles(_ table: ExportTable, rows: [ExportRow], into collected: inout Collector) {
        let objects = rows.map { object($0, of: table) }
        guard let column = table.inletColumn else {
            collected.add(table.path, json(objects))
            return
        }
        var groups: [String: [[String: Any]]] = [:]
        for (row, object) in zip(rows, objects) {
            var inlet = ""
            if case .text(let text)? = row[column] { inlet = text }
            groups[inlet, default: []].append(object)
        }
        for inlet in groups.keys.sorted() {
            collected.add(table.path.replacingOccurrences(of: "{inlet}", with: component(inlet)), json(groups[inlet] ?? []))
        }
    }

    private static func object(_ row: ExportRow, of table: ExportTable) -> [String: Any] {
        var result: [String: Any] = [:]
        for column in table.columns where !isSecret(column) {
            guard let value = row[column] else { continue }
            if table.jsonColumns.contains(column) {
                let decoded = bytes(value).flatMap(parsed).map { scrub($0, dropping: table.droppedKeys) } ?? NSNull()
                if column == table.mergedColumn, let merged = decoded as? [String: Any] {
                    result.merge(merged) { _, new in new }
                } else {
                    result[column] = decoded
                }
            } else {
                result[column] = plain(value)
            }
        }
        return result
    }

    private static func bytes(_ value: ExportValue) -> Data? {
        switch value {
        case .blob(let data): data
        case .text(let text): Data(text.utf8)
        default: nil
        }
    }

    private static func plain(_ value: ExportValue) -> Any {
        switch value {
        case .null: NSNull()
        case .integer(let number): number
        case .real(let number): number
        case .text(let text): text
        case .blob(let data): data.base64EncodedString()
        }
    }
}

public enum ArchiveEngine {
    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1 }
        return value
    }

    static func checksum(_ data: Data) -> UInt32 {
        var value: UInt32 = 0xFFFF_FFFF
        for byte in data { value = table[Int((value ^ UInt32(byte)) & 0xFF)] ^ (value >> 8) }
        return ~value
    }

    public static func archive(_ files: [ExportFile], at date: Date) throws(ExportFailure) -> Data {
        guard files.count <= Int(UInt16.max) else { throw .tooLarge }
        let stamp = dosStamp(date)
        let limit = Int(UInt32.max)
        var body = Data()
        var directory = Data()
        for file in files {
            let name = Data(file.path.utf8)
            let size = file.data.count
            guard name.count <= Int(UInt16.max), size <= limit, body.count + size + name.count + 30 <= limit else { throw .tooLarge }
            let crc = checksum(file.data)
            let offset = UInt32(body.count)
            body.append(local(name: name, crc: crc, size: UInt32(size), stamp: stamp))
            body.append(file.data)
            directory.append(central(name: name, crc: crc, size: UInt32(size), stamp: stamp, offset: offset))
        }
        guard body.count + directory.count + 22 <= limit else { throw .tooLarge }
        var result = body
        result.append(directory)
        result.append(end(count: UInt16(files.count), size: UInt32(directory.count), offset: UInt32(body.count)))
        return result
    }

    private static func local(name: Data, crc: UInt32, size: UInt32, stamp: (time: UInt16, date: UInt16)) -> Data {
        var data = Data()
        data.put(0x0403_4B50 as UInt32)
        data.put(20 as UInt16)
        data.put(0x0800 as UInt16)
        data.put(0 as UInt16)
        data.put(stamp.time)
        data.put(stamp.date)
        data.put(crc)
        data.put(size)
        data.put(size)
        data.put(UInt16(name.count))
        data.put(0 as UInt16)
        data.append(name)
        return data
    }

    private static func central(name: Data, crc: UInt32, size: UInt32, stamp: (time: UInt16, date: UInt16), offset: UInt32) -> Data {
        var data = Data()
        data.put(0x0201_4B50 as UInt32)
        data.put(20 as UInt16)
        data.put(20 as UInt16)
        data.put(0x0800 as UInt16)
        data.put(0 as UInt16)
        data.put(stamp.time)
        data.put(stamp.date)
        data.put(crc)
        data.put(size)
        data.put(size)
        data.put(UInt16(name.count))
        data.put(0 as UInt16)
        data.put(0 as UInt16)
        data.put(0 as UInt16)
        data.put(0 as UInt16)
        data.put(0 as UInt32)
        data.put(offset)
        data.append(name)
        return data
    }

    private static func end(count: UInt16, size: UInt32, offset: UInt32) -> Data {
        var data = Data()
        data.put(0x0605_4B50 as UInt32)
        data.put(0 as UInt16)
        data.put(0 as UInt16)
        data.put(count)
        data.put(count)
        data.put(size)
        data.put(offset)
        data.put(0 as UInt16)
        return data
    }

    private static func dosStamp(_ date: Date) -> (time: UInt16, date: UInt16) {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max((parts.year ?? 1980) - 1980, 0)
        let day = UInt16(year << 9 | (parts.month ?? 1) << 5 | (parts.day ?? 1))
        let time = UInt16((parts.hour ?? 0) << 11 | (parts.minute ?? 0) << 5 | (parts.second ?? 0) / 2)
        return (time, day)
    }
}

private extension Data {
    mutating func put<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
