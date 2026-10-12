import Foundation
import MykilosKit

package enum IMAPSetupError: Error, Equatable, Sendable {
    case missing(String)
    case invalidAddress(String)
    case invalidPort(field: String, value: String)
    case invalidSecurity(field: String, value: String)
    case insecure(field: String)
}

package enum IMAPField {
    package static let address = "address"
    package static let name = "name"
    package static let username = "username"
    package static let password = "password"
    package static let incomingHost = "incomingHost"
    package static let incomingPort = "incomingPort"
    package static let incomingSecurity = "incomingSecurity"
    package static let outgoingHost = "outgoingHost"
    package static let outgoingPort = "outgoingPort"
    package static let outgoingSecurity = "outgoingSecurity"
}

package struct IMAPConnection: Equatable, Sendable {
    package var address: String
    package var name: String
    package var username: String
    package var password: String
    package var incoming: MailServerSettings
    package var outgoing: MailServerSettings

    package init(values: [String: String]) throws(IMAPSetupError) {
        func text(_ key: String) -> String { (values[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        let address = text(IMAPField.address)
        guard !address.isEmpty else { throw .missing(IMAPField.address) }
        guard address.contains("@"), !address.hasPrefix("@"), !address.hasSuffix("@") else {
            throw .invalidAddress(address)
        }
        let password = values[IMAPField.password] ?? ""
        guard !password.isEmpty else { throw .missing(IMAPField.password) }
        let username = text(IMAPField.username).isEmpty ? address : text(IMAPField.username)
        self.address = address
        self.name = String(text(IMAPField.name).unicodeScalars.filter { !$0.properties.generalCategory.isControl }.map(Character.init))
        self.username = username
        self.password = password
        incoming = try Self.endpoint(
            host: text(IMAPField.incomingHost), port: text(IMAPField.incomingPort),
            security: text(IMAPField.incomingSecurity), username: username,
            fields: (IMAPField.incomingHost, IMAPField.incomingPort, IMAPField.incomingSecurity),
            implicit: 993, explicit: 143)
        outgoing = try Self.endpoint(
            host: text(IMAPField.outgoingHost), port: text(IMAPField.outgoingPort),
            security: text(IMAPField.outgoingSecurity), username: username,
            fields: (IMAPField.outgoingHost, IMAPField.outgoingPort, IMAPField.outgoingSecurity),
            implicit: 465, explicit: 587)
    }

    private static func endpoint(host: String, port: String, security: String, username: String,
                                 fields: (host: String, port: String, security: String),
                                 implicit: Int, explicit: Int) throws(IMAPSetupError) -> MailServerSettings {
        guard !host.isEmpty else { throw .missing(fields.host) }
        let mode: MailSecurity
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
        return MailServerSettings(host: host, port: number, security: mode, authentication: .password, username: username)
    }

    package var values: [String: String] {
        var result = [
            IMAPField.address: address,
            IMAPField.username: username,
            IMAPField.password: password,
            IMAPField.incomingHost: incoming.host,
            IMAPField.incomingPort: String(incoming.port ?? 0),
            IMAPField.incomingSecurity: incoming.security.rawValue,
            IMAPField.outgoingHost: outgoing.host,
            IMAPField.outgoingPort: String(outgoing.port ?? 0),
            IMAPField.outgoingSecurity: outgoing.security.rawValue
        ]
        if !name.isEmpty { result[IMAPField.name] = name }
        return result
    }

    package func account(id: String) -> MailAccount {
        MailAccount(id: id, displayName: name, address: address, provider: .generic,
                    incoming: incoming, outgoing: outgoing)
    }
}

private extension Unicode.GeneralCategory {
    var isControl: Bool { self == .control || self == .lineSeparator || self == .paragraphSeparator }
}
