import AlfaServices
import DrawingKit
import Foundation

public struct ClaudeDesigner: Designer {
    public static let model = "claude-opus-5-5"
    public static let products = ["plan", "iso", "perspective", "steps", "customer"]
    static let projectKeys = ["lastName", "project", "street", "city", "customer", "date"]
    static let attachmentLimit = 30_000_000
    static let retries = 2

    private let credentials: ClaudeCredentialsStoring
    private let http: ClaudeHTTPClient
    private let url: URL
    private let pause: @Sendable (Double) async -> Void
    private let skill: String

    public init(credentials: ClaudeCredentialsStoring = KeychainClaudeCredentialsStore(),
                http: ClaudeHTTPClient = URLSession.shared,
                url: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
                pause: @escaping @Sendable (Double) async -> Void = { seconds in
                    try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                }) {
        self.credentials = credentials
        self.http = http
        self.url = url
        self.pause = pause
        skill = Bundle.module.url(forResource: "designer", withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    public func design(_ brief: Brief) async throws -> Proposal {
        guard let key = try credentials.load()?.apiKey, !key.isEmpty else { throw DesignError.noKey }
        guard brief.attachments.reduce(0, { $0 + $1.data.count }) <= Self.attachmentLimit else {
            throw DesignError.tooLarge
        }
        let request = try self.request(brief, key: key)
        var attempt = 0
        while true {
            let (data, response) = try await http.data(for: request)
            guard let status = (response as? HTTPURLResponse)?.statusCode else { throw DesignError.malformed("response") }
            if (200...299).contains(status) {
                return try Self.proposal(from: data, materials: brief.materials, catalog: brief.catalog)
            }
            guard Self.retryable(status), attempt < Self.retries else {
                throw DesignError.http(status, String(decoding: data.prefix(400), as: UTF8.self))
            }
            let header = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After")
            await pause(Self.delay(attempt: attempt, retryAfter: header))
            attempt += 1
        }
    }

    static func retryable(_ status: Int) -> Bool {
        status == 429 || (500...599).contains(status)
    }

    static func delay(attempt: Int, retryAfter: String?) -> Double {
        if let header = retryAfter, let seconds = Double(header.trimmingCharacters(in: .whitespaces)), seconds >= 0 {
            return min(seconds, 20)
        }
        return attempt == 0 ? 2 : 4
    }

    func request(_ brief: Brief, key: String) throws -> URLRequest {
        let text = brief.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !brief.attachments.isEmpty else { throw DesignError.emptyBrief }
        var content: [[String: Any]] = []
        for a in brief.attachments {
            guard a.supported else { throw DesignError.unsupported(a.name) }
            let kind = a.mediaType == Attachment.document ? "document" : "image"
            content.append(["type": kind, "source": ["type": "base64", "media_type": a.mediaType,
                                                     "data": a.data.base64EncodedString()]])
        }
        var prompt = text
        if !brief.current.isEmpty, let current = try? JSONEncoder().encode(brief.current) {
            prompt += "\n\nCurrent parts:\n" + String(decoding: current, as: UTF8.self)
        }
        content.append(["type": "text", "text": prompt])
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "thinking": ["type": "adaptive"],
            "output_config": ["effort": "high", "format": ["type": "json_schema", "schema": Self.schema]],
            "fallbacks": "default",
            "system": skill + "\n\nMaterials: " + brief.materials.sorted().joined(separator: ", ")
                + "\nCatalogue codes: " + brief.catalog.sorted().joined(separator: ", "),
            "messages": [["role": "user", "content": content]]
        ]
        var r = URLRequest(url: url)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(key, forHTTPHeaderField: "x-api-key")
        r.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        r.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        r.timeoutInterval = 600
        r.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return r
    }

    static func proposal(from data: Data, materials: [String], catalog: [String] = []) throws -> Proposal {
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data) else { throw DesignError.malformed("reply") }
        if reply.stopReason == "refusal" { throw DesignError.refused(reply.stopDetails?.explanation ?? "") }
        if reply.stopReason == "max_tokens" { throw DesignError.truncated }
        guard let text = reply.content.first(where: { $0.type == "text" })?.text,
              let wire = try? JSONDecoder().decode(Wire.self, from: Data(text.utf8)) else {
            throw DesignError.malformed("json")
        }
        do { try Validate.parts(wire.parts) } catch let e as DrawingError { throw DesignError.invalid(e) }
        if let odd = wire.parts.first(where: { !materials.contains($0.material) }) {
            throw DesignError.unknownMaterial(odd.material)
        }
        if let odd = wire.variants.flatMap(\.slots).first(where: { !catalog.contains($0.code) }) {
            throw DesignError.unknownMaterial(odd.code)
        }
        let project = Dictionary(wire.project.filter { projectKeys.contains($0.key) }.map { ($0.key, $0.value) },
                                 uniquingKeysWith: { _, last in last })
        let variants = wire.variants.map { variant in
            Variant(id: variant.id, name: variant.name,
                    slots: Dictionary(variant.slots.map { ($0.role, $0.code) }, uniquingKeysWith: { _, last in last }))
        }
        return Proposal(parts: wire.parts, project: project, products: wire.products.filter { products.contains($0) },
                        assumptions: wire.assumptions, questions: wire.questions, variants: variants)
    }

    struct Reply: Decodable {
        struct Block: Decodable { var type: String; var text: String? }
        struct Details: Decodable { var explanation: String? }
        var content: [Block]
        var stopReason: String?
        var stopDetails: Details?
        enum CodingKeys: String, CodingKey { case content, stopReason = "stop_reason", stopDetails = "stop_details" }
    }

    struct Wire: Decodable {
        struct Pair: Decodable { var key: String; var value: String }
        struct Slot: Decodable { var role: String; var code: String }
        struct WireVariant: Decodable { var id: String; var name: String; var slots: [Slot] }
        var parts: [Part]
        var project: [Pair]
        var products: [String]
        var assumptions: [String]
        var questions: [String]
        var variants: [WireVariant]
    }

    static var schema: [String: Any] {
        func number() -> [String: Any] { ["type": "number"] }
        func text() -> [String: Any] { ["type": "string"] }
        func list(_ item: [String: Any]) -> [String: Any] { ["type": "array", "items": item] }
        func object(_ fields: [String: [String: Any]]) -> [String: Any] {
            ["type": "object", "properties": fields, "required": fields.keys.sorted(), "additionalProperties": false]
        }
        let axes: [String: Any] = ["type": "string", "enum": ["x", "y", "z", "w", "d", "h"]]
        let part = object(["id": text(), "name": text(), "material": text(), "role": text(), "group": text(),
                           "given": list(axes),
                           "x": number(), "y": number(), "z": number(), "w": number(), "d": number(), "h": number()])
        let pair = object(["key": ["type": "string", "enum": projectKeys],
                           "value": text()])
        let slot = object(["role": text(), "code": text()])
        let variant = object(["id": text(), "name": text(), "slots": list(slot)])
        return object(["parts": list(part), "project": list(pair),
                       "products": list(["type": "string", "enum": products]),
                       "assumptions": list(text()), "questions": list(text()),
                       "variants": list(variant)])
    }
}
