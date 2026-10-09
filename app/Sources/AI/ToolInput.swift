import Foundation
import ALFAcolorCore

/// The limits of the tool inputs. A value above a limit is refused and the model gets the reason.
enum ToolLimits {
    /// The most characters of one note. The same limit as a note in the document.
    static let noteText = ItemNote.maxTextLength
    static let tipText = 300
    static let tagCount = 20
    static let tagLength = 40
    static let titleLength = 120
    static let languageLength = 32
    static let fileCount = 20
    static let fileNameLength = 120
    /// The most bytes of one code file.
    static let codeFileBytes = 200_000
    static let swatchCount = 50
    static let colourNameLength = 60
    static let tokenCount = 200
    static let itemCount = 500
    static let urlLength = 2048
    /// The largest distance of one move in points.
    static let moveDistance = 100_000.0
    /// The most bytes of a design text that `design_read` returns.
    static let designTextBytes = 200_000
}

/// A refused input. The message goes back to the model as an error answer; it never carries content beyond the reason.
struct ToolFailure: Error, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

/// Reads the fields of one tool input. Every check throws `ToolFailure` with the reason.
struct ToolInput {
    private let fields: [String: JSONValue]
    private let document: DocumentSnapshot

    init(_ json: JSONValue, document: DocumentSnapshot) throws {
        guard case let .object(fields) = json else {
            throw ToolFailure("the input is not an object")
        }
        self.fields = fields
        self.document = document
    }

    /// A required text: trimmed, not empty, and no longer than `limit` characters.
    func text(_ key: String, limit: Int) throws -> String {
        let value = try trimmedText(key)
        guard value.count <= limit else {
            throw ToolFailure("\(key) is longer than \(limit) characters")
        }
        return value
    }

    /// An optional text. Missing or blank gives nil.
    func optionalText(_ key: String, limit: Int) throws -> String? {
        guard fields[key] != nil else { return nil }
        let value = try trimmedText(key)
        guard value.count <= limit else {
            throw ToolFailure("\(key) is longer than \(limit) characters")
        }
        return value
    }

    /// An item ID that the document knows.
    func item(_ key: String) throws -> String {
        let value = try trimmedText(key)
        guard document.pieceIDs.contains(value) else {
            throw ToolFailure("unknown item id: \(value)")
        }
        return value
    }

    /// One to `ToolLimits.itemCount` item IDs that the document knows.
    func items(_ key: String) throws -> [String] {
        let list = try array(key, min: 1, max: ToolLimits.itemCount)
        var ids: [String] = []
        for element in list {
            guard let id = element.string?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
                throw ToolFailure("\(key) must hold item ids as text")
            }
            guard document.pieceIDs.contains(id) else {
                throw ToolFailure("unknown item id: \(id)")
            }
            ids.append(id)
        }
        return ids
    }

    /// Tags: one to `ToolLimits.tagCount`, each not empty and short. Duplicates are dropped; the order stays.
    func tags(_ key: String) throws -> [String] {
        var result: [String] = []
        for element in try array(key, min: 1, max: ToolLimits.tagCount) {
            guard let tag = element.string?.trimmingCharacters(in: .whitespacesAndNewlines), !tag.isEmpty else {
                throw ToolFailure("\(key) must hold texts, not empty")
            }
            guard tag.count <= ToolLimits.tagLength else {
                throw ToolFailure("a tag is longer than \(ToolLimits.tagLength) characters")
            }
            if !result.contains(tag) {
                result.append(tag)
            }
        }
        return result
    }

    /// Code files: a map from file name to text. The names must not reach outside the card.
    func files(_ key: String) throws -> [String: String] {
        guard case let .object(map)? = fields[key] else {
            throw ToolFailure("\(key) must be an object of file names and texts")
        }
        guard !map.isEmpty, map.count <= ToolLimits.fileCount else {
            throw ToolFailure("\(key) must hold 1 to \(ToolLimits.fileCount) files")
        }
        var result: [String: String] = [:]
        for (name, value) in map {
            try checkFileName(name)
            guard let body = value.string else {
                throw ToolFailure("file \(name) is not text")
            }
            guard body.utf8.count <= ToolLimits.codeFileBytes else {
                throw ToolFailure("file \(name) is larger than \(ToolLimits.codeFileBytes) bytes")
            }
            result[name] = body
        }
        return result
    }

    /// A colour as `#RRGGBB`.
    static func isHex(_ value: String) -> Bool {
        guard value.count == 7, value.first == "#" else { return false }
        return value.dropFirst().allSatisfy { $0.isHexDigit }
    }

    /// A token name: lower case letters and digits, with hyphens between; no dots, no braces, not empty.
    static func isTokenName(_ value: String) -> Bool {
        guard let first = value.first, first.isLowercase || first.isNumber, value.count <= 63 else { return false }
        return value.allSatisfy { ($0.isLowercase && $0.isASCII) || ($0.isASCII && $0.isNumber) || $0 == "-" }
    }

    /// A hex colour from a field.
    func hex(_ key: String) throws -> String {
        let value = try trimmedText(key)
        guard Self.isHex(value) else {
            throw ToolFailure("\(key) must be a colour as #RRGGBB")
        }
        return value
    }

    /// A token name from a field.
    func tokenName(_ key: String) throws -> String {
        let value = try trimmedText(key)
        guard Self.isTokenName(value) else {
            throw ToolFailure("\(key) must use lower case letters, digits and hyphens")
        }
        return value
    }

    /// A web address of the given schemes, not longer than the limit.
    func url(_ key: String, schemes: [String]) throws -> String {
        let value = try trimmedText(key)
        guard value.count <= ToolLimits.urlLength else {
            throw ToolFailure("\(key) is longer than \(ToolLimits.urlLength) characters")
        }
        guard schemes.contains(where: { value.lowercased().hasPrefix($0 + "://") }), URL(string: value)?.host != nil else {
            throw ToolFailure("\(key) must be an address that starts with \(schemes.joined(separator: " or "))://")
        }
        return value
    }

    /// One finite distance, within the move limit.
    func distance(_ key: String) throws -> Double {
        guard case let .number(value)? = fields[key], value.isFinite, abs(value) <= ToolLimits.moveDistance else {
            throw ToolFailure("\(key) must be a finite distance up to \(Int(ToolLimits.moveDistance))")
        }
        return value
    }

    /// One value out of a fixed list of texts.
    func choice(_ key: String, from allowed: [String], default fallback: String?) throws -> String {
        guard fields[key] != nil else {
            if let fallback { return fallback }
            throw ToolFailure("\(key) is missing")
        }
        let value = try trimmedText(key)
        guard allowed.contains(value) else {
            throw ToolFailure("\(key) must be one of: \(allowed.joined(separator: ", "))")
        }
        return value
    }

    /// The objects of a list field, one to `max` of them.
    func objects(_ key: String, max: Int) throws -> [[String: JSONValue]] {
        try array(key, min: 1, max: max).map { element in
            guard case let .object(object) = element else {
                throw ToolFailure("\(key) must hold objects")
            }
            return object
        }
    }

    /// A token ID that the design set knows.
    func token(_ key: String) throws -> String {
        let value = try trimmedText(key)
        guard document.tokenIDs.contains(value) else {
            throw ToolFailure("unknown token id: \(value)")
        }
        return value
    }

    /// The optional name of an object of a list. Blank or missing gives nil; a name is short text.
    func optionalName(_ object: [String: JSONValue], in list: String) throws -> String? {
        guard object["name"] != nil else { return nil }
        guard let value = object["name"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw ToolFailure("\(list) name must be text")
        }
        guard value.count <= ToolLimits.colourNameLength else {
            throw ToolFailure("\(list) name is longer than \(ToolLimits.colourNameLength) characters")
        }
        return value.isEmpty ? nil : value
    }

    /// A colour of an object of a list, as #RRGGBB.
    func hexValue(_ object: [String: JSONValue], _ key: String, in list: String) throws -> String {
        guard let value = object[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), Self.isHex(value) else {
            throw ToolFailure("\(list) needs a colour as #RRGGBB in \(key)")
        }
        return value
    }

    /// A token ID of an object of a list, which the design set must know.
    func tokenValue(_ object: [String: JSONValue], _ key: String, in list: String) throws -> String {
        guard let value = object[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolFailure("\(list) needs a token id in \(key)")
        }
        guard document.tokenIDs.contains(value) else {
            throw ToolFailure("unknown token id: \(value)")
        }
        return value
    }

    /// A token name of an object of a list.
    func tokenNameValue(_ object: [String: JSONValue], _ key: String, in list: String) throws -> String {
        guard let value = object[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), Self.isTokenName(value) else {
            throw ToolFailure("\(list) needs a name with lower case letters, digits and hyphens in \(key)")
        }
        return value
    }

    /// The text of one field of an object of a list.
    static func text(of object: [String: JSONValue], _ key: String, in list: String) throws -> String {
        guard let value = object[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolFailure("\(list) needs a non-empty \(key)")
        }
        return value
    }

    // MARK: private

    private func trimmedText(_ key: String) throws -> String {
        guard let value = fields[key]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ToolFailure("\(key) is missing or empty")
        }
        return value
    }

    private func array(_ key: String, min: Int, max: Int) throws -> [JSONValue] {
        guard case let .array(list)? = fields[key] else {
            throw ToolFailure("\(key) must be a list")
        }
        guard list.count >= min, list.count <= max else {
            throw ToolFailure("\(key) must hold \(min) to \(max) entries")
        }
        return list
    }

    private func checkFileName(_ name: String) throws {
        guard !name.isEmpty, name.count <= ToolLimits.fileNameLength else {
            throw ToolFailure("a file name is empty or too long")
        }
        guard name != ".", name != "..", !name.contains("/"), !name.contains("\\"),
              !name.unicodeScalars.contains(where: { $0.value < 32 }) else {
            throw ToolFailure("file name \(name) is not allowed")
        }
    }
}
