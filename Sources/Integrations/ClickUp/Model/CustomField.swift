struct FieldOption: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var orderIndex: Int?

    init(id: String, name: String, orderIndex: Int? = nil) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
    }
}

struct CustomField: Identifiable, Equatable, Sendable {
    enum WriteKind: Equatable, Sendable {
        case text
        case checkbox
        case date
        case dropdown
        case labels
        case none
    }

    var id: String
    var name: String
    var type: String
    var rawValue: String
    var options: [FieldOption]

    init(id: String, name: String, type: String, rawValue: String, options: [FieldOption] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.rawValue = rawValue
        self.options = options
    }

    var writeKind: WriteKind {
        switch type {
        case "text", "short_text", "number", "url", "email", "phone": .text
        case "checkbox": .checkbox
        case "date": .date
        case "drop_down": options.isEmpty ? .none : .dropdown
        case "labels": options.isEmpty ? .none : .labels
        default: .none
        }
    }

    func optionID(forLabel label: String) throws -> String? {
        let matches = options.filter { $0.name.caseInsensitiveCompare(label) == .orderedSame }
        guard matches.count <= 1 else {
            throw ClickUpFailure.ambiguousOption(field: name, label: label, count: matches.count)
        }
        return matches.first?.id
    }

    static func unique(named name: String, in fields: [CustomField]) throws -> CustomField? {
        let matches = fields.filter { $0.name == name }
        guard matches.count <= 1 else { throw ClickUpFailure.ambiguousField(name: name, count: matches.count) }
        return matches.first
    }
}
