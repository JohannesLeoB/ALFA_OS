import Foundation

enum FormBodyEngine {
    static func encode(_ values: [String: String]) -> Data {
        Data(values.map { key, value in "\(escape(key))=\(escape(value))" }.sorted().joined(separator: "&").utf8)
    }

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
