public struct ContactPerson: Equatable, Sendable, Codable {
    public let name: String
    public let address: String

    public init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}
