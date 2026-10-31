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

enum AirtableFailure: Error, Equatable, Sendable {
    case notConnected
    case invalidResponse
    case http(Int)
    case rejected(Int, String)
    case decoding
    case writeNotAllowed(baseID: String, table: String)
    case deleteNotAllowed(baseID: String, table: String)
    case unmapped(Int)

    var detail: String {
        switch self {
        case .notConnected: "notConnected"
        case .invalidResponse: "invalidResponse"
        case .http(let code): "http \(code)"
        case .rejected(let code, let message): "http \(code): \(message)"
        case .decoding: "decoding"
        case .writeNotAllowed(let baseID, let table): "writeNotAllowed \(table)@\(baseID)"
        case .deleteNotAllowed(let baseID, let table): "deleteNotAllowed \(table)@\(baseID)"
        case .unmapped(let count): "unmapped \(count)"
        }
    }
}

struct CatalogEntry: Equatable, Sendable {
    let id: String
    let articleNumber: String
    let manufacturer: String?
    let category: String?
    let summary: String?
    let detailText: String?
    let ean: String?
    let purchaseNet: Double?
    let saleNet: Double?
    let review: ReviewState?

    init(id: String, articleNumber: String, manufacturer: String? = nil, category: String? = nil,
         summary: String? = nil, detailText: String? = nil, ean: String? = nil, purchaseNet: Double? = nil,
         saleNet: Double? = nil, review: ReviewState? = nil) {
        self.id = id
        self.articleNumber = articleNumber
        self.manufacturer = manufacturer
        self.category = category
        self.summary = summary
        self.detailText = detailText
        self.ean = ean
        self.purchaseNet = purchaseNet
        self.saleNet = saleNet
        self.review = review
    }
}
