import Calculation
import Foundation
import Hub

struct ToolDefinition: Encodable, Equatable, Sendable {
    struct Property: Encodable, Equatable, Sendable {
        let type: String
        let description: String
    }

    struct InputSchema: Encodable, Equatable, Sendable {
        let type = "object"
        let properties: [String: Property]
        let required: [String]
    }

    let name: String
    let description: String
    let inputSchema: InputSchema
    var cacheControl: CacheControl?

    init(tool: any ToolPort, text: any TextPort) {
        var properties: [String: Property] = [:]
        var required: [String] = []
        for parameter in tool.parameters {
            properties[parameter.name] = Property(
                type: parameter.kind.rawValue,
                description: text.text(tool.parameterKey(parameter.name), []))
            if parameter.required { required.append(parameter.name) }
        }
        self.name = tool.name
        self.description = text.text(tool.descriptionKey, [])
        self.inputSchema = InputSchema(properties: properties, required: required)
    }

    enum CodingKeys: String, CodingKey {
        case name, description, inputSchema = "input_schema", cacheControl = "cache_control"
    }
}

struct CacheControl: Encodable, Equatable, Sendable {
    let type = "ephemeral"

    init() {}
}

public struct ToolInput: Sendable, Equatable {
    let values: [String: String]

    init(_ values: [String: String] = [:]) {
        self.values = values
    }

    init(json: Data) {
        let object = (try? JSONDecoder().decode([String: JSONValue].self, from: json)) ?? [:]
        self.values = object.compactMapValues(\.scalarText)
    }

    func text(_ key: String) -> String {
        (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func optionalText(_ key: String) -> String? {
        let value = text(key)
        return value.isEmpty ? nil : value
    }

    func integer(_ key: String) -> Int? {
        Int(text(key))
    }

    func number(_ key: String) -> Double? {
        Double(text(key))
    }

    func flag(_ key: String) -> Bool {
        text(key).lowercased() == "true"
    }
}

struct ToolManifest: Sendable, Equatable {
    static let version = 2
    static let umbrellaID = "ASSISTANT_TOOL_CALL"

    private let identifiers: [String: String]

    init(tools: [any ToolPort]) {
        var identifiers: [String: String] = [:]
        for tool in tools { identifiers[tool.name] = tool.manifestID }
        self.identifiers = identifiers
    }

    func identifier(forTool name: String) -> String {
        identifiers[name] ?? Self.umbrellaID
    }
}

public struct ToolParameter: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case string
        case integer
        case number
    }

    let name: String
    let kind: Kind
    let required: Bool

    init(_ name: String, kind: Kind = .string, required: Bool = false) {
        self.name = name
        self.kind = kind
        self.required = required
    }
}

public struct ToolResult: Sendable, Equatable {
    var lines: [Phrase]
    var isError: Bool
    var cards: [ContentBlock]

    init(lines: [Phrase], isError: Bool = false, cards: [ContentBlock] = []) {
        self.lines = lines
        self.isError = isError
        self.cards = cards
    }

    init(_ line: Phrase, isError: Bool = false, cards: [ContentBlock] = []) {
        self.init(lines: [line], isError: isError, cards: cards)
    }

    static func failure(_ key: String, _ arguments: String...) -> ToolResult {
        ToolResult(.key(key, arguments), isError: true)
    }

    func render(_ text: any TextPort) -> String {
        lines.map { $0.render(text) }.joined(separator: "\n")
    }
}

public struct ToolScope: Sendable, Equatable {
    var projectID: String?
    var driveFolderID: String?
    var taskListID: String?

    init(projectID: String? = nil, driveFolderID: String? = nil, taskListID: String? = nil) {
        self.projectID = Self.clean(projectID)
        self.driveFolderID = Self.clean(driveFolderID)
        self.taskListID = Self.clean(taskListID)
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public enum FocusNeed: Sendable, Equatable {
    case none
    case driveFolder
    case taskList
}

public enum ToolAccess: String, Sendable, Equatable {
    case read
    case propose
    case write
}

indirect enum Phrase: Codable, Sendable, Equatable {
    case key(String, [String])
    case raw(String)
    case notice(Notice)
    case join([Phrase], String)

    static func make(_ key: String, _ arguments: String...) -> Phrase {
        .key(key, arguments)
    }

    func render(_ text: any TextPort) -> String {
        switch self {
        case .key(let key, let arguments): text.text(key, arguments)
        case .raw(let value): value
        case .notice(let notice): text.text(notice.key, notice.arguments)
        case .join(let parts, let separator): parts.map { $0.render(text) }.joined(separator: separator)
        }
    }
}

public enum PrivacyCategory: String, CaseIterable, Codable, Sendable, Equatable {
    case mail
    case calendar
    case contacts
    case drive
    case clickUp
    case notes
    case tasks
    case catalogCalculation
    case studioKnowledge
    case chat
    case time

    public var key: String {
        switch self {
        case .mail: "settings.privacy.category.mail"
        case .calendar: "settings.privacy.category.calendar"
        case .contacts: "settings.privacy.category.contacts"
        case .drive: "settings.privacy.category.drive"
        case .clickUp: "settings.privacy.category.clickUp"
        case .notes: "settings.privacy.category.notes"
        case .tasks: "settings.privacy.category.tasks"
        case .catalogCalculation: "settings.privacy.category.catalogCalculation"
        case .studioKnowledge: "settings.privacy.category.studioKnowledge"
        case .chat: "settings.privacy.category.chat"
        case .time: "settings.privacy.category.time"
        }
    }
}

public struct PrivacySettings: Codable, Equatable, Sendable {
    public var disabled: Set<PrivacyCategory>

    public init(disabled: Set<PrivacyCategory> = []) {
        self.disabled = disabled
    }

    public func shares(_ category: PrivacyCategory) -> Bool {
        disabled.contains(category) == false
    }
}

public struct PrivacySnapshot: Sendable, Equatable {
    var choices: PrivacyChoices
    var settings: PrivacySettings

    public init(choices: PrivacyChoices = PrivacyChoices(), settings: PrivacySettings = PrivacySettings()) {
        self.choices = choices
        self.settings = settings
    }

    var assistantOff: Bool { choices.assistantOff }
    var chatFiles: Bool { choices.chatFiles }

    func shares(_ category: PrivacyCategory) -> Bool {
        settings.shares(category)
    }
}
