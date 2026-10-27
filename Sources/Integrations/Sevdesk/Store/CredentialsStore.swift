import Hub

public struct CredentialsStore: CredentialsPort {
    static let tokenName = "token"

    private let keychain: any KeychainPort
    private let inlet: Inlet.ID

    public init(keychain: any KeychainPort, inlet: Inlet.ID) {
        self.keychain = keychain
        self.inlet = inlet
    }

    public func load() throws -> Credentials? {
        guard let token = try keychain.get(KeySlot(inlet: inlet, name: Self.tokenName)), token.isEmpty == false else {
            return nil
        }
        return Credentials(token: token)
    }
}

public struct Credentials: Equatable, Sendable {
    public var token: String

    public init(token: String) {
        self.token = token
    }
}
