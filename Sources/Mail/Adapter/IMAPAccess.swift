import Hub
import Storage

public struct IMAPAccess: ProviderPort {
    static let providerID = "imap"

    public let id: ID = IMAPAccess.providerID
    public let capabilities: Set<Capability> = [.mail]
    public let signIn: any SignInPort
    public let probe: any ProbePort
    private let channels = IMAPChannelRegistry()
    private let database: SQLiteStore?

    public init(database: SQLiteStore? = nil) {
        self.database = database
        signIn = IMAPSignIn(channels: channels)
        probe = ConnectionCheck()
    }

    public var form: [Field] {
        [
            Field(id: ConnectionField.name, title: "field.imap.name"),
            Field(id: ConnectionField.address, title: "field.imap.address"),
            Field(id: ConnectionField.incomingProtocol, title: "field.imap.incomingProtocol"),
            Field(id: ConnectionField.incomingHost, title: "field.imap.incomingHost"),
            Field(id: ConnectionField.incomingPort, title: "field.imap.incomingPort"),
            Field(id: ConnectionField.incomingSecurity, title: "field.imap.incomingSecurity"),
            Field(id: ConnectionField.outgoingHost, title: "field.imap.outgoingHost"),
            Field(id: ConnectionField.outgoingPort, title: "field.imap.outgoingPort"),
            Field(id: ConnectionField.outgoingSecurity, title: "field.imap.outgoingSecurity"),
            Field(id: ConnectionField.username, title: "field.imap.username"),
            Field(id: ConnectionField.password, title: "field.imap.password", secret: true)
        ]
    }

    public var presets: [Preset] {
        ProviderPresets.all.map { entry in
            var values: [Field.ID: String] = [:]
            Self.fill(&values, entry.incoming, host: ConnectionField.incomingHost, port: ConnectionField.incomingPort,
                      security: ConnectionField.incomingSecurity)
            Self.fill(&values, entry.outgoing, host: ConnectionField.outgoingHost, port: ConnectionField.outgoingPort,
                      security: ConnectionField.outgoingSecurity)
            return Preset(id: entry.id, title: entry.title.text, values: values)
        }
    }

    private static func fill(_ values: inout [Field.ID: String], _ template: ServerTemplate, host: String,
                             port: String, security: String) {
        if !template.host.isEmpty { values[host] = template.host }
        if let number = template.port { values[port] = String(number) }
        values[security] = template.security.rawValue
    }

    public func classify(_ error: any Error) -> Classification { FailureEngine.classify(error) }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        let wantsChanges = ObjectIdentifier(port) == ObjectIdentifier((any ChangePort).self)
        guard wantsChanges || ObjectIdentifier(port) == ObjectIdentifier((any MailTransportPort).self) else {
            throw HubFailure.capabilityMissing(inlet.id, inlet.capabilities.first ?? .mail)
        }
        let connection = try ConnectionEngine(values: grant.values)
        let password = connection.password
        if connection.incomingProtocol == .pop3 {
            guard let database else { throw HubFailure.capabilityMissing(inlet.id, .mail) }
            let pop = POPSMTPClient(account: connection.account(id: inlet.id), database: database, password: { password })
            let made: Any = wantsChanges ? POPChangePort(transport: pop) : pop
            guard let typed = made as? P else { throw HubFailure.capabilityMissing(inlet.id, .mail) }
            return typed
        }
        let fingerprint = connection.values.sorted { $0.key < $1.key }.map { $0.key + "=" + $0.value }.joined(separator: "\n")
        let transport = IMAPSMTPClient(
            account: connection.account(id: inlet.id), password: { password },
            channel: channels.channel(for: inlet.id, fingerprint: fingerprint))
        let made: Any = wantsChanges ? IMAPChangePort(transport: transport) : transport
        guard let typed = made as? P else {
            throw HubFailure.capabilityMissing(inlet.id, .mail)
        }
        return typed
    }
}

struct IMAPChangePort: ChangePort {
    let transport: IMAPSMTPClient

    func changes() -> AsyncThrowingStream<Void, any Error> { transport.changes() }
}

struct POPChangePort: ChangePort {
    let transport: POPSMTPClient

    func changes() -> AsyncThrowingStream<Void, any Error> { transport.changes() }
}

struct IMAPSignIn: SignInPort {
    let channels: IMAPChannelRegistry

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        Grant(values: try ConnectionEngine(values: input).values)
    }


    func signOut(_ inlet: Inlet) async throws {
        channels.release(inlet.id)
    }
}
