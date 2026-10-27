import Foundation

struct CustomerSearchEngine: Sendable {
    static let hitLimit = 15
    static let exampleLimit = 8

    let customers: [CustomerEntry]
    let projectCounts: [String: Int]

    init(customers: [CustomerEntry], projectCounts: [String: Int] = [:]) {
        self.customers = customers
        self.projectCounts = projectCounts
    }

    func lookup(_ query: String) -> [CustomerEntry] {
        let tokens = query.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).filter { $0.count >= 2 }
        guard tokens.isEmpty == false else { return [] }
        func matches(_ haystack: String) -> Bool {
            let lowered = haystack.lowercased()
            return tokens.contains { lowered.contains($0) }
        }
        return customers
            .filter { matches($0.name) || matches($0.number) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            .prefix(Self.hitLimit)
            .map { $0 }
    }

    func overview() -> [Phrase] {
        let examples = customers
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
            .prefix(Self.exampleLimit).map(\.name)
        var lines: [Phrase] = [.make("assistant.customers.overview", String(customers.count))]
        if examples.isEmpty == false { lines.append(.make("assistant.customers.examples", examples.joined(separator: ", "))) }
        return lines
    }

    func describe(_ customer: CustomerEntry) -> Phrase {
        let count = projectCounts[customer.number] ?? 0
        var parts: [Phrase] = [.make("assistant.customers.row", customer.name, customer.number)]
        if count > 0 {
            parts.append(.make(count == 1 ? "assistant.customers.projectOne" : "assistant.customers.projectMany", String(count)))
        }
        return .join(parts, " ")
    }
}

struct CustomerEntry: Sendable, Equatable {
    let number: String
    let name: String

    init(number: String, name: String) {
        self.number = number
        self.name = name
    }
}
