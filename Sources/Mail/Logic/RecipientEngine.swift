enum RecipientEngine {
    static func parse(_ raw: String?) -> [Participant] {
        AddressListParser.split(raw ?? "").enumerated().map { index, entry in
            let parts = PersonName.display(entry)
            return Participant(id: index, name: parts.name, address: parts.address.isEmpty ? entry : parts.address)
        }
    }

    static func format(_ people: [Participant]) -> String? {
        let entries = people.map { person -> String in
            guard !person.name.isEmpty else { return person.address }
            let quoted = person.name.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"" + quoted + "\" <" + person.address + ">"
        }
        return entries.isEmpty ? nil : entries.joined(separator: ", ")
    }

    static func summary(_ people: [Participant]) -> String {
        guard let first = people.first else { return "" }
        if people.count > NameLimit.recipientsInline { return first.first }
        return people.map { $0.name.isEmpty ? PersonName.middle($0.address, limit: NameLimit.summary) : $0.name }
            .joined(separator: ", ")
    }
}
