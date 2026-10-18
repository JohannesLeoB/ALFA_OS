import Foundation
import AlfaKit

public struct ContactDirectory: Sendable {
    public let contacts: [StudioContact]

    public init(contacts: [StudioContact]) {
        self.contacts = contacts
    }

    public func search(_ query: String, limit: Int = 8) -> [StudioContact] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard q.isEmpty == false else { return [] }
        let hits = contacts.filter { $0.matches(q) }
        let ranked = hits.sorted { lhs, rhs in
            rank(lhs, q) < rank(rhs, q)
        }
        return Array(ranked.prefix(limit))
    }

    private func rank(_ c: StudioContact, _ q: String) -> Int {
        let name = c.name.lowercased()
        if name == q { return 0 }
        if name.hasPrefix(q) { return 1 }
        return 2
    }
}
