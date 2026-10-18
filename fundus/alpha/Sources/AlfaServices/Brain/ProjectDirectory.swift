import Foundation
import AlfaKit

public struct ProjectDirectory: Sendable {
    public struct Entry: Sendable, Equatable {
        public let projectNumber: String
        public let title: String
        public let customerName: String?
        public let driveFolderID: String?
        public let phase: String?
        public let budget: Double?
        public init(projectNumber: String, title: String, customerName: String?, driveFolderID: String?,
                    phase: String? = nil, budget: Double? = nil) {
            self.projectNumber = projectNumber; self.title = title
            self.customerName = customerName; self.driveFolderID = driveFolderID
            self.phase = phase; self.budget = budget
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry]) { self.entries = entries }

    public init(projects: [Project], customers: [Customer]) {
        let nameByNumber = Dictionary(customers.map { ($0.customerNumber, $0.name) },
                                      uniquingKeysWith: { a, _ in a })
        self.entries = projects.map { p in
            Entry(projectNumber: p.projectNumber, title: p.title,
                  customerName: nameByNumber[p.customerNumber], driveFolderID: p.links.driveFolderID,
                  phase: p.phase, budget: p.links.budget)
        }
    }

    public func resolve(_ query: String) -> Entry? {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else { return nil }
        if let exact = entries.first(where: { $0.projectNumber.lowercased() == q }) { return exact }
        return entries.first { e in
            e.projectNumber.lowercased().contains(q)
                || e.title.lowercased().contains(q)
                || (e.customerName?.lowercased().contains(q) ?? false)
        }
    }
}
