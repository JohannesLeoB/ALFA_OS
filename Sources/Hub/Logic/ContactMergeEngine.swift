import Foundation

enum ContactMergeEngine {
    static func merge(_ lists: [[ContactPerson]]) -> [ContactPerson] {
        var merged: [ContactPerson] = []
        var index: [String: Int] = [:]
        for person in lists.joined() {
            let key = person.address.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            if let at = index[key] {
                if merged[at].name.isEmpty, !person.name.isEmpty { merged[at] = ContactPerson(name: person.name, address: merged[at].address) }
            } else {
                index[key] = merged.count
                merged.append(person)
            }
        }
        return merged
    }
}
