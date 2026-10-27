import Foundation

public struct Record: Equatable, Sendable {
    public let id: String
    public let fields: [String: FieldValue]

    public init(id: String, fields: [String: FieldValue]) {
        self.id = id
        self.fields = fields
    }
}

public enum FieldValue: Equatable, Sendable, Decodable {
    case string(String)
    case array([String])
    case number(Double)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String].self) { self = .array(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        self = .null
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var anyStringValue: String? {
        switch self {
        case .string(let value): value
        case .number(let value): value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        default: nil
        }
    }

    var firstArrayValue: String? {
        if case .array(let values) = self { return values.first }
        return nil
    }

    var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var jsonValue: Any {
        switch self {
        case .string(let value): value
        case .array(let values): values
        case .number(let value): value
        case .bool(let value): value
        case .null: NSNull()
        }
    }
}
