import Foundation

/// The JSON of the tools of a request. A broken tool setting throws before anything is sent.
enum AIToolWire {
    /// The tools in the order of their names, so that the same tools always give the same bytes.
    /// Two tools with the same name keep the order in which they were given.
    static func tools(_ tools: [AITool]) throws -> [JSONValue] {
        let ordered = tools.enumerated().sorted { left, right in
            (left.element.name, left.offset) < (right.element.name, right.offset)
        }
        return try ordered.map { try json(for: $0.element) }
    }

    static func json(for tool: AITool) throws -> JSONValue {
        switch tool {
        case let .client(name, description, inputSchema):
            return .object([
                "name": .string(name),
                "description": .string(description),
                "input_schema": inputSchema,
            ])
        case let .webSearch(maxUses, allowedDomains, blockedDomains, userLocation):
            var object: [String: JSONValue] = [
                "type": .string(AIToolVersion.webSearch),
                "name": .string("web_search"),
            ]
            try addDomains(allowedDomains, blockedDomains, to: &object)
            if let maxUses {
                object["max_uses"] = .number(Double(maxUses))
            }
            if let userLocation {
                object["user_location"] = try location(userLocation)
            }
            return .object(object)
        case let .webFetch(maxUses, allowedDomains, blockedDomains, citations, maxContentTokens):
            var object: [String: JSONValue] = [
                "type": .string(AIToolVersion.webFetch),
                "name": .string("web_fetch"),
            ]
            try addDomains(allowedDomains, blockedDomains, to: &object)
            if let maxUses {
                object["max_uses"] = .number(Double(maxUses))
            }
            if let citations {
                object["citations"] = .object(["enabled": .bool(citations)])
            }
            if let maxContentTokens {
                object["max_content_tokens"] = .number(Double(maxContentTokens))
            }
            return .object(object)
        }
    }

    /// The domain lists. The platform takes one of the two lists, never both.
    private static func addDomains(
        _ allowed: [String]?,
        _ blocked: [String]?,
        to object: inout [String: JSONValue]
    ) throws {
        if allowed != nil, blocked != nil {
            throw AIError.toolConfiguration("allowed_domains and blocked_domains cannot be used together")
        }
        if let allowed {
            object["allowed_domains"] = .array(allowed.map(JSONValue.string))
        }
        if let blocked {
            object["blocked_domains"] = .array(blocked.map(JSONValue.string))
        }
    }

    /// The location of the user. At least one field must be set.
    private static func location(_ value: AIUserLocation) throws -> JSONValue {
        var object: [String: JSONValue] = ["type": .string("approximate")]
        let fields: [(String, String?)] = [
            ("city", value.city),
            ("region", value.region),
            ("country", value.country),
            ("timezone", value.timezone),
        ]
        for (key, text) in fields {
            if let text {
                object[key] = .string(text)
            }
        }
        guard object.count > 1 else {
            throw AIError.toolConfiguration("the user location needs at least one field")
        }
        return .object(object)
    }
}
