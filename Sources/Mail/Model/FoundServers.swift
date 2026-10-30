struct FoundServers: Equatable, Sendable {
    var incoming: ServerTemplate
    var outgoing: ServerTemplate
    var username: String?
    var incomingProtocol: IncomingProtocol = .imap

    var values: [String: String] {
        var result: [String: String] = [:]
        for (template, host, port, security) in [
            (incoming, ConnectionField.incomingHost, ConnectionField.incomingPort, ConnectionField.incomingSecurity),
            (outgoing, ConnectionField.outgoingHost, ConnectionField.outgoingPort, ConnectionField.outgoingSecurity)
        ] {
            result[host] = template.host
            if let number = template.port { result[port] = String(number) }
            result[security] = template.security.rawValue
        }
        if let username { result[ConnectionField.username] = username }
        result[ConnectionField.incomingProtocol] = incomingProtocol.rawValue
        return result
    }
}
