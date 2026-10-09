import Foundation

/// Reads and writes the assistant settings as one text. The text is a JSON object. A key that this version
/// does not know stays in the text, so that a newer version can read it again. A missing or broken value
/// gives the default of that setting only.
public enum AssistantSettingsCodec {
    /// The settings of the text. Missing, blank or broken text gives the defaults.
    public static func read(_ text: String?) -> AssistantOverrides {
        var overrides = AssistantOverrides()
        guard let members = members(of: text) else { return overrides }

        if let tier = members["tier"]?.string.flatMap(AssistantTier.init(rawValue:)) {
            overrides.tier = tier
        }
        if case let .object(named)? = members["models"] {
            for (key, value) in named {
                guard let kind = AITaskKind(rawValue: key), let id = value.string, !id.isEmpty else { continue }
                overrides.models[kind] = id
            }
        }
        overrides.effort = members["effort"]?.string.flatMap(AIEffort.init(rawValue:))
        overrides.thinking = members["thinking"]?.string.flatMap(thinking(named:))
        overrides.maxTokens = members["maxTokens"]?.int
        overrides.toolRounds = members["toolRounds"]?.int
        overrides.webSearch = bool(members["webSearch"])
        overrides.searchesPerMessage = members["searchesPerMessage"]?.int
        overrides.allowedDomains = strings(members["allowedDomains"])
        overrides.blockedDomains = strings(members["blockedDomains"])
        overrides.countryCode = members["countryCode"]?.string
        overrides.timeZone = members["timeZone"]?.string
        overrides.cache = members["cache"]?.string.flatMap(cache(named:))
        overrides.structuredNames = bool(members["structuredNames"])
        return overrides
    }

    /// The text with the settings written in. A value that is not set is removed from the text; keys that
    /// this version does not know are kept as they were.
    public static func write(_ overrides: AssistantOverrides, over text: String?) -> String {
        var members = members(of: text) ?? [:]
        put(&members, "tier", .string(overrides.tier.rawValue))

        let models = overrides.models.filter { !$0.value.isEmpty }
        put(&members, "models", models.isEmpty ? nil : .object(
            Dictionary(uniqueKeysWithValues: models.map { ($0.key.rawValue, JSONValue.string($0.value)) })
        ))
        put(&members, "effort", overrides.effort.map { .string($0.rawValue) })
        put(&members, "thinking", overrides.thinking.map { .string(name(of: $0)) })
        put(&members, "maxTokens", overrides.maxTokens.map { .number(Double($0)) })
        put(&members, "toolRounds", overrides.toolRounds.map { .number(Double($0)) })
        put(&members, "webSearch", overrides.webSearch.map { .bool($0) })
        put(&members, "searchesPerMessage", overrides.searchesPerMessage.map { .number(Double($0)) })
        put(&members, "allowedDomains", overrides.allowedDomains.isEmpty ? nil : .array(overrides.allowedDomains.map { .string($0) }))
        put(&members, "blockedDomains", overrides.blockedDomains.isEmpty ? nil : .array(overrides.blockedDomains.map { .string($0) }))
        put(&members, "countryCode", overrides.countryCode.map { .string($0) })
        put(&members, "timeZone", overrides.timeZone.map { .string($0) })
        put(&members, "cache", overrides.cache.map { .string(name(of: $0)) })
        put(&members, "structuredNames", overrides.structuredNames.map { .bool($0) })
        return encode(members)
    }

    // MARK: names of the values in the text

    private static func thinking(named name: String) -> AIThinking? {
        switch name {
        case "adaptive": .adaptive
        case "disabled": .disabled
        case "betweenTools": .betweenTools
        default: nil
        }
    }

    private static func name(of thinking: AIThinking) -> String {
        switch thinking {
        case .adaptive: "adaptive"
        case .disabled: "disabled"
        case .betweenTools: "betweenTools"
        }
    }

    private static func cache(named name: String) -> AICachePolicy? {
        switch name {
        case "automatic5m": .automatic(ttl: .fiveMinutes)
        case "automatic1h": .automatic(ttl: .oneHour)
        case "off": .off
        default: nil
        }
    }

    private static func name(of cache: AICachePolicy) -> String {
        switch cache {
        case .automatic(ttl: .fiveMinutes): "automatic5m"
        case .automatic(ttl: .oneHour): "automatic1h"
        case .off: "off"
        }
    }

    // MARK: JSON

    private static func members(of text: String?) -> [String: JSONValue]? {
        guard let text, let data = text.data(using: .utf8),
              case let .object(members)? = try? JSONDecoder().decode(JSONValue.self, from: data) else {
            return nil
        }
        return members
    }

    private static func encode(_ members: [String: JSONValue]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(JSONValue.object(members)) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    private static func put(_ members: inout [String: JSONValue], _ key: String, _ value: JSONValue?) {
        if let value {
            members[key] = value
        } else {
            members.removeValue(forKey: key)
        }
    }

    private static func bool(_ value: JSONValue?) -> Bool? {
        if case let .bool(flag)? = value { return flag }
        return nil
    }

    private static func strings(_ value: JSONValue?) -> [String] {
        guard case let .array(items)? = value else { return [] }
        return items.compactMap { $0.string }
    }
}
