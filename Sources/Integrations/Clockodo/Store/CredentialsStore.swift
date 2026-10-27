import Hub

public struct CredentialsStore: CredentialsPort {
    static let emailName = "email"
    static let keyName = "key"

    private let keychain: any KeychainPort
    private let inlet: Inlet.ID

    public init(keychain: any KeychainPort, inlet: Inlet.ID) {
        self.keychain = keychain
        self.inlet = inlet
    }

    public func load() throws -> Credentials? {
        guard let email = try keychain.get(KeySlot(inlet: inlet, name: Self.emailName)), email.isEmpty == false,
              let key = try keychain.get(KeySlot(inlet: inlet, name: Self.keyName)), key.isEmpty == false
        else { return nil }
        return Credentials(email: email, key: key)
    }
}

public struct Credentials: Equatable, Sendable {
    public var email: String
    public var key: String

    public init(email: String, key: String) {
        self.email = email
        self.key = key
    }
}
