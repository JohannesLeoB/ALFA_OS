import Foundation

public protocol Repository: Sendable {
    associatedtype Entity: Codable & Identifiable & Sendable
    func loadAll() throws -> [Entity]
    func saveAll(_ entities: [Entity]) throws
}

public enum SaveState: Equatable, Sendable {
    case idle
    case saving
    case saved(Date)
    case failed(String)

    public var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}
