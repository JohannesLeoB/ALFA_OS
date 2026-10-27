import Hub

public struct CredentialsStore: CredentialsPort {
    static let tokenName = "token"
    static let baseName = "base"

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
        let base = try keychain.get(KeySlot(inlet: inlet, name: Self.baseName)) ?? ""
        return Credentials(token: token, baseID: base)
    }
}

public struct Credentials: Equatable, Sendable {
    public var token: String
    var baseID: String

    public init(token: String, baseID: String) {
        self.token = token
        self.baseID = baseID
    }
}
