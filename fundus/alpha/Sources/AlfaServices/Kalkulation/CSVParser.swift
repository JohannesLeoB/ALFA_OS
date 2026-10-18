import Foundation
import AlfaCalculation

public enum CSVError: Error, CustomStringConvertible {
    case empty
    case inconsistentColumns(line: Int)

    public var description: String {
        switch self {
        case .empty: "CSV is empty."
        case .inconsistentColumns(let line): "CSV has inconsistent columns at line \(line)."
        }
    }
}

public struct CSVTable {
    public let headers: [String]
    public let rows: [[String: String]]

    public init(data: String) throws {
        try self.init(data: data, lenient: false)
    }

    public init(data: String, lenient: Bool) throws {
        let normalizedData = data
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let records = CSVTable.parseRecords(normalizedData)
        guard var header = records.first, !header.isEmpty else { throw CSVError.empty }
        if let first = header.first { header[0] = first.replacingOccurrences(of: "\u{FEFF}", with: "") }
        let parsedHeaders = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.headers = parsedHeaders
        self.rows = try records.dropFirst().enumerated().compactMap { offset, values -> [String: String]? in
            var values = values
            if values.count != parsedHeaders.count {
                if lenient {
                    if values.count < parsedHeaders.count {
                        values.append(contentsOf: Array(repeating: "", count: parsedHeaders.count - values.count))
                    } else {
                        values = Array(values.prefix(parsedHeaders.count))
                    }
                } else {
                    throw CSVError.inconsistentColumns(line: offset + 2)
                }
            }
            return Dictionary(uniqueKeysWithValues: zip(parsedHeaders, values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
        }
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
            } else if char == "\r" && !inQuotes {
                if index + 1 < characters.count, characters[index + 1] == "\n" {
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                    index += 1
                } else {
                    row.append(field)
                    rows.append(row)
                    row = []
                    field = ""
                }
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

extension Dictionary where Key == String, Value == String {
    func string(_ key: String) -> String {
        self[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func decimal(_ key: String) -> Decimal {
        GermanNumberParser.decimal(string(key)) ?? 0
    }

    func optionalDecimal(_ key: String) -> Decimal? {
        GermanNumberParser.decimal(string(key))
    }

    func int(_ key: String) -> Int {
        let value = string(key)
        if let int = Int(value) { return int }
        if let double = Double(value) { return Int(double) }
        return 0
    }

    func double(_ key: String) -> Double {
        let value = string(key)
        if let double = Double(value) { return double }
        return GermanNumberParser.double(value) ?? 0
    }
}
