import Foundation

/// A JSON value of any shape. Fields that a version of the app does not know are kept as these values,
/// so that a later version still finds them when the file is written again.
public enum PlaceJSON: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([PlaceJSON])
    case object([String: PlaceJSON])

    public init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let flag = try? single.decode(Bool.self) {
            self = .bool(flag)
        } else if let number = try? single.decode(Double.self) {
            self = .number(number)
        } else if let text = try? single.decode(String.self) {
            self = .string(text)
        } else if let list = try? single.decode([PlaceJSON].self) {
            self = .array(list)
        } else {
            self = .object(try single.decode([String: PlaceJSON].self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .null: try single.encodeNil()
        case .bool(let flag): try single.encode(flag)
        case .number(let number): try single.encode(number)
        case .string(let text): try single.encode(text)
        case .array(let list): try single.encode(list)
        case .object(let fields): try single.encode(fields)
        }
    }
}

/// A key of any name, for reading and writing the fields that are not declared in a type.
struct AnyKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ name: String) { stringValue = name }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// The fields of a stored object that the type does not declare. They are read and written back unchanged.
enum UnknownFields {
    /// The fields of the decoder whose names are not in `known`.
    static func read(from decoder: Decoder, skipping known: Set<String>) throws -> [String: PlaceJSON] {
        let container = try decoder.container(keyedBy: AnyKey.self)
        var fields: [String: PlaceJSON] = [:]
        for key in container.allKeys where !known.contains(key.stringValue) {
            fields[key.stringValue] = try container.decode(PlaceJSON.self, forKey: key)
        }
        return fields
    }

    /// Writes the fields next to the declared ones. A name that the type declares is never overwritten.
    static func write(_ fields: [String: PlaceJSON], to encoder: Encoder, skipping known: Set<String>) throws {
        var container = encoder.container(keyedBy: AnyKey.self)
        for (name, value) in fields.sorted(by: { $0.key < $1.key }) where !known.contains(name) {
            try container.encode(value, forKey: AnyKey(name))
        }
    }
}
