import Foundation

/// Beliebiger JSON-Wert. Trägt Felder, die diese Version nicht kennt, unverändert durch Lesen und Schreiben
/// (Vorwärtskompatibilität: ein neueres Programm darf Felder ergänzen, ein älteres verliert sie nicht).
public enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    /// Zahl als Double, egal ob ganz oder gebrochen.
    public var number: Double? {
        switch self { case .int(let i): Double(i); case .double(let d): d; default: nil }
    }
    public var stringValue: String? { if case .string(let s) = self { s } else { nil } }
    public var objectValue: [String: JSONValue]? { if case .object(let o) = self { o } else { nil } }
    public var arrayValue: [JSONValue]? { if case .array(let a) = self { a } else { nil } }
}

extension JSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else if let o = try? c.decode([String: JSONValue].self) { self = .object(o) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Kein gültiger JSON-Wert") }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}

extension JSONValue {
    /// Tief mischen: Objekte werden Schlüssel für Schlüssel vereinigt, bei allem anderen gewinnt `other`.
    func merged(with other: JSONValue) -> JSONValue {
        guard case .object(let a) = self, case .object(let b) = other else { return other }
        var out = a
        for (k, v) in b { out[k] = out[k].map { $0.merged(with: v) } ?? v }
        return .object(out)
    }
}

/// Schlüssel, der nicht vorher bekannt sein muss.
struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(_ s: String) { stringValue = s }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// Unbekannte Felder eines JSON-Objekts herausziehen und wieder zurückschreiben.
enum Extras {
    static func decode(from decoder: Decoder, known: Set<String>) throws -> [String: JSONValue] {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        var out: [String: JSONValue] = [:]
        for key in c.allKeys where !known.contains(key.stringValue) {
            out[key.stringValue] = try c.decode(JSONValue.self, forKey: key)
        }
        return out
    }
    /// Schreibt in denselben Schlüsselbehälter wie die bekannten Felder. Bekannte Felder gewinnen immer.
    static func encode(_ extras: [String: JSONValue], known: Set<String>, to encoder: Encoder) throws {
        let pending = extras.filter { !known.contains($0.key) }
        guard !pending.isEmpty else { return }
        var c = encoder.container(keyedBy: DynamicKey.self)
        for (k, v) in pending { try c.encode(v, forKey: DynamicKey(k)) }
    }
}
