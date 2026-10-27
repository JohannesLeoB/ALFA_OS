public struct Mailbox: Item, Equatable {
    public var id: String
    public var inlet: Inlet.ID
    public var name: String
    public var role: String

    public init(id: String, inlet: Inlet.ID, name: String, role: String) {
        self.id = id
        self.inlet = inlet
        self.name = name
        self.role = role
    }
}
