import Foundation

public struct ToolInput: Sendable, Equatable {
    let values: [String: String]

    init(_ values: [String: String] = [:]) {
        self.values = values
    }

    init(json: Data) {
        let object = (try? JSONDecoder().decode([String: JSONValue].self, from: json)) ?? [:]
        self.values = object.compactMapValues(\.scalarText)
    }

    func text(_ key: String) -> String {
        (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func optionalText(_ key: String) -> String? {
        let value = text(key)
        return value.isEmpty ? nil : value
    }

    func integer(_ key: String) -> Int? {
        Int(text(key))
    }

    func number(_ key: String) -> Double? {
        Double(text(key))
    }

    func flag(_ key: String) -> Bool {
        text(key).lowercased() == "true"
    }
}
