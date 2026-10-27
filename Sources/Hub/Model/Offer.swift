public struct Offer: Identifiable, Equatable, Sendable {
    public var id: String
    public var provider: String
    public var title: String
    var capabilities: Set<Capability>
    var owner: Owner
    public var way: Way
    public var preset: Preset?

    init(id: String, provider: String, title: String, capabilities: Set<Capability>, owner: Owner,
                way: Way, preset: Preset? = nil) {
        self.id = id
        self.provider = provider
        self.title = title
        self.capabilities = capabilities
        self.owner = owner
        self.way = way
        self.preset = preset
    }
}

public enum Way: Equatable, Sendable {
    case signIn
    case form([Field])
    case key([Field])
}

public struct Preset: Identifiable, Equatable, Sendable {
    public typealias ID = String
    public var id: ID
    var title: String
    public var values: [Field.ID: String]

    public init(id: ID, title: String, values: [Field.ID: String]) {
        self.id = id
        self.title = title
        self.values = values
    }
}

public struct Renewal: Equatable, Sendable {
    public var offer: Offer
    public var values: [Field.ID: String]
}
