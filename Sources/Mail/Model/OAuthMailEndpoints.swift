public struct OAuthMailEndpoints: Equatable, Sendable {
    public var incomingHost: String
    public var incomingPort: Int
    public var outgoingHost: String
    public var outgoingPort: Int
    public var serverFilesSent: Bool

    public init(incomingHost: String, incomingPort: Int, outgoingHost: String, outgoingPort: Int,
                serverFilesSent: Bool = false) {
        self.incomingHost = incomingHost
        self.incomingPort = incomingPort
        self.outgoingHost = outgoingHost
        self.outgoingPort = outgoingPort
        self.serverFilesSent = serverFilesSent
    }

    func account(id: String, address: String, name: String) -> Account {
        Account(
            id: id, displayName: name, address: address,
            incoming: ServerSettings(host: incomingHost, port: incomingPort, security: .ssl, username: address),
            outgoing: ServerSettings(host: outgoingHost, port: outgoingPort, security: .starttls, username: address))
    }
}
