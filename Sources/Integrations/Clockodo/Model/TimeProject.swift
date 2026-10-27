public struct TimeProject: Hashable, Sendable, Identifiable {
    public let id: Int
    let customerID: Int
    let name: String
    let isActive: Bool

    init(id: Int, customerID: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.customerID = customerID
        self.name = name
        self.isActive = isActive
    }
}

public struct TimeCustomer: Hashable, Sendable, Identifiable {
    public let id: Int
    let name: String
    let isActive: Bool

    init(id: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}

public struct TimeActivity: Hashable, Sendable, Identifiable {
    public let id: Int
    let name: String
    let isActive: Bool

    init(id: Int, name: String, isActive: Bool = true) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }
}
