import Foundation

enum ConnectionFailure: Error, Equatable, Sendable {
    case missing(String)
    case invalidAddress(String)
    case invalidPort(field: String, value: String)
    case invalidSecurity(field: String, value: String)
    case insecure(field: String)
    case invalidProtocol(String)
}

struct ConnectionEngine: Equatable, Sendable {
    private static let implicitIncoming = 993
    private static let explicitIncoming = 143
    private static let implicitPOP = 995
    private static let explicitPOP = 110
    private static let implicitOutgoing = 465
    private static let explicitOutgoing = 587

    var address: String
    var name: String
    var username: String
    var password: String
    var incoming: ServerSettings
    var outgoing: ServerSettings
    var incomingProtocol: IncomingProtocol

    init(values: [String: String]) throws(ConnectionFailure) {
        func text(_ key: String) -> String { (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        let address = text(ConnectionField.address)
        guard !address.isEmpty else { throw .missing(ConnectionField.address) }
        guard address.contains("@"), !address.hasPrefix("@"), !address.hasSuffix("@"),
              address.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            throw .invalidAddress(address)
        }
        let password = values[ConnectionField.password] ?? ""
        guard !password.isEmpty else { throw .missing(ConnectionField.password) }
        let username = text(ConnectionField.username).isEmpty ? address : text(ConnectionField.username)
        self.address = address
        self.name = String(text(ConnectionField.name).unicodeScalars.filter { !$0.properties.generalCategory.isControl }
            .map(Character.init))
        self.username = username
        self.password = password
        let kind = text(ConnectionField.incomingProtocol).lowercased()
        guard let incomingProtocol = kind.isEmpty ? .imap : IncomingProtocol(rawValue: kind) else {
            throw .invalidProtocol(kind)
        }
        self.incomingProtocol = incomingProtocol
        let pop = incomingProtocol == .pop3
        incoming = try Self.endpoint(
            host: text(ConnectionField.incomingHost), port: text(ConnectionField.incomingPort),
            security: text(ConnectionField.incomingSecurity), username: username,
            fields: (ConnectionField.incomingHost, ConnectionField.incomingPort, ConnectionField.incomingSecurity),
            implicit: pop ? Self.implicitPOP : Self.implicitIncoming, explicit: pop ? Self.explicitPOP : Self.explicitIncoming)
        outgoing = try Self.endpoint(
            host: text(ConnectionField.outgoingHost), port: text(ConnectionField.outgoingPort),
            security: text(ConnectionField.outgoingSecurity), username: username,
            fields: (ConnectionField.outgoingHost, ConnectionField.outgoingPort, ConnectionField.outgoingSecurity),
            implicit: Self.implicitOutgoing, explicit: Self.explicitOutgoing)
    }

    private static func endpoint(host: String, port: String, security: String, username: String,
                                 fields: (host: String, port: String, security: String),
                                 implicit: Int, explicit: Int) throws(ConnectionFailure) -> ServerSettings {
        guard !host.isEmpty else { throw .missing(fields.host) }
        let mode: TransportSecurity
        switch security.lowercased() {
        case "ssl": mode = .ssl
        case "starttls": mode = .starttls
        case "none": throw .insecure(field: fields.security)
        case "": mode = port.isEmpty || Int(port) == implicit ? .ssl : .starttls
        default: throw .invalidSecurity(field: fields.security, value: security)
        }
        let number: Int
        if port.isEmpty {
            number = mode == .ssl ? implicit : explicit
        } else {
            guard let parsed = Int(port), (1...65535).contains(parsed) else {
                throw .invalidPort(field: fields.port, value: port)
            }
            number = parsed
        }
        return ServerSettings(host: host, port: number, security: mode, username: username)
    }

    var values: [String: String] {
        var result = [
            ConnectionField.address: address,
            ConnectionField.username: username,
            ConnectionField.password: password,
            ConnectionField.incomingHost: incoming.host,
            ConnectionField.incomingPort: String(incoming.port ?? 0),
            ConnectionField.incomingSecurity: incoming.security.rawValue,
            ConnectionField.outgoingHost: outgoing.host,
            ConnectionField.outgoingPort: String(outgoing.port ?? 0),
            ConnectionField.outgoingSecurity: outgoing.security.rawValue
        ]
        if !name.isEmpty { result[ConnectionField.name] = name }
        if incomingProtocol != .imap { result[ConnectionField.incomingProtocol] = incomingProtocol.rawValue }
        return result
    }

    func account(id: String) -> Account {
        Account(id: id, displayName: name, address: address, incoming: incoming, outgoing: outgoing,
                incomingProtocol: incomingProtocol)
    }
}

private extension Unicode.GeneralCategory {
    var isControl: Bool { self == .control || self == .lineSeparator || self == .paragraphSeparator }
}
