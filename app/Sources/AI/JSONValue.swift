import Foundation

/// A JSON value of any shape. Blocks that come back from the API are kept in this form, so that they can go back unchanged.
public enum JSONValue: Sendable, Equatable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "The value is not JSON.")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .number(value):
            // A whole number is written without a fraction, because the platform rejects "5.0" for counts.
            if let whole = Int(exactly: value) {
                try container.encode(whole)
            } else {
                try container.encode(value)
            }
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }

    /// The member of an object, or nil when the value is not an object or has no such member.
    public subscript(key: String) -> JSONValue? {
        if case let .object(members) = self {
            return members[key]
        }
        return nil
    }

    /// The element of an array, or nil when the value is not an array or has no such element.
    public subscript(index: Int) -> JSONValue? {
        if case let .array(items) = self, items.indices.contains(index) {
            return items[index]
        }
        return nil
    }

    /// The text, when the value is a string.
    public var string: String? {
        if case let .string(text) = self {
            return text
        }
        return nil
    }

    /// The whole number, when the value is a number without a fraction.
    public var int: Int? {
        if case let .number(value) = self {
            return Int(exactly: value)
        }
        return nil
    }
}
