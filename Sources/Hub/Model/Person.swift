public struct Person: Identifiable, Equatable, Codable, Sendable {
    public typealias ID = String
    public var id: ID
    var name: String

    public init(id: ID, name: String) {
        self.id = id
        self.name = name
    }
}

public enum Owner: Hashable, Codable, Sendable {
    case person(Person.ID)
    case company
}
