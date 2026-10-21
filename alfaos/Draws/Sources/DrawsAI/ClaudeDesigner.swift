import AlfaServices
import DrawingKit
import Foundation

public struct ClaudeDesigner: Designer {
    public static let model = "claude-opus-5-5"
    public static let products = ["plan", "iso", "perspective", "steps", "customer"]

    private let credentials: ClaudeCredentialsStoring
    private let http: ClaudeHTTPClient
    private let url: URL
    private let skill: String

    public init(credentials: ClaudeCredentialsStoring = KeychainClaudeCredentialsStore(),
                http: ClaudeHTTPClient = URLSession.shared,
                url: URL = URL(string: "https://api.anthropic.com/v1/messages")!) {
        self.credentials = credentials
        self.http = http
        self.url = url
        skill = Bundle.module.url(forResource: "designer", withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    }

    public func design(_ brief: Brief) async throws -> Proposal {
        guard let key = try credentials.load()?.apiKey, !key.isEmpty else { throw DesignError.noKey }
        let request = try self.request(brief, key: key)
        let (data, response) = try await http.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw DesignError.malformed("response") }
        guard (200...299).contains(status) else {
            throw DesignError.http(status, String(decoding: data.prefix(400), as: UTF8.self))
        }
        return try Self.proposal(from: data, materials: brief.materials)
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
            "system": skill + "\n\nMaterials: " + brief.materials.sorted().joined(separator: ", "),
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

    static func proposal(from data: Data, materials: [String]) throws -> Proposal {
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
        let project = Dictionary(wire.project.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
        return Proposal(parts: wire.parts, project: project, products: wire.products.filter { products.contains($0) },
                        assumptions: wire.assumptions, questions: wire.questions)
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
        var parts: [Part]
        var project: [Pair]
        var products: [String]
        var assumptions: [String]
        var questions: [String]
    }

    static var schema: [String: Any] {
        func number() -> [String: Any] { ["type": "number"] }
        func text() -> [String: Any] { ["type": "string"] }
        func list(_ item: [String: Any]) -> [String: Any] { ["type": "array", "items": item] }
        func object(_ fields: [String: [String: Any]]) -> [String: Any] {
            ["type": "object", "properties": fields, "required": fields.keys.sorted(), "additionalProperties": false]
        }
        let part = object(["id": text(), "name": text(), "material": text(),
                           "x": number(), "y": number(), "z": number(), "w": number(), "d": number(), "h": number()])
        let pair = object(["key": ["type": "string", "enum": ["lastName", "project", "street", "city", "customer", "date"]],
                           "value": text()])
        return object(["parts": list(part), "project": list(pair),
                       "products": list(["type": "string", "enum": products]),
                       "assumptions": list(text()), "questions": list(text())])
    }
}
