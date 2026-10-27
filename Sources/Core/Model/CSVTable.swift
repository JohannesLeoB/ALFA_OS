import Foundation

public enum CSVFailure: Error, Sendable, Equatable {
    case empty
    case inconsistentColumns(line: Int)
    case duplicateHeader(String)
}

public struct CSVTable: Sendable {
    let headers: [String]
    public let rows: [[String: String]]

    public init(data: String, lenient: Bool = false) throws(CSVFailure) {
        let normalizedData = data
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let records = CSVTable.parseRecords(normalizedData)
        guard var header = records.first, !header.isEmpty else { throw CSVFailure.empty }
        if let first = header.first { header[0] = first.replacingOccurrences(of: "\u{FEFF}", with: "") }
        let parsedHeaders = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var seen = Set<String>()
        for name in parsedHeaders where !seen.insert(name).inserted {
            throw CSVFailure.duplicateHeader(name)
        }
        var parsedRows: [[String: String]] = []
        for (offset, record) in records.dropFirst().enumerated() {
            var values = record
            if values.count != parsedHeaders.count {
                guard lenient else { throw CSVFailure.inconsistentColumns(line: offset + 2) }
                if values.count < parsedHeaders.count {
                    values.append(contentsOf: Array(repeating: "", count: parsedHeaders.count - values.count))
                } else {
                    values = Array(values.prefix(parsedHeaders.count))
                }
            }
            parsedRows.append(Dictionary(uniqueKeysWithValues: zip(parsedHeaders, values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })))
        }
        self.headers = parsedHeaders
        self.rows = parsedRows
    }

    private static func parseRecords(_ data: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let characters = Array(data)
        var index = 0

        while index < characters.count {
            let char = characters[index]
            if char == "\"" {
                if inQuotes, index + 1 < characters.count, characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                row.append(field)
                field = ""
            } else if char == "\n" && !inQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(char)
            }
            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows.filter { !$0.allSatisfy(\.isEmpty) }
    }
}

public extension Dictionary where Key == String, Value == String {
    func string(_ key: String) -> String {
        self[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func int(_ key: String) -> Int {
        let value = string(key)
        if let int = Int(value) { return int }
        if let double = Double(value) { return Int(double) }
        return 0
    }
}
