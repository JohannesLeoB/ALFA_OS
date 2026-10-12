import Foundation
import MykilosKit
import MykilosServices

public struct IMAPProvider: Provider {
    public static let providerID = "imap"

    public let id: ID = IMAPProvider.providerID
    public let capabilities: Set<Capability> = [.mail]
    public let signIn: any SignInPort
    public let probe: any ProbePort

    public init() {
        signIn = IMAPAppPasswordSignIn()
        probe = IMAPProbe()
    }

    package init(probeRun: @escaping IMAPProbeRun) {
        signIn = IMAPAppPasswordSignIn()
        probe = IMAPProbe(run: probeRun)
    }

    public var form: [Field] {
        [
            Field(id: IMAPField.name, title: "field.imap.name"),
            Field(id: IMAPField.address, title: "field.imap.address"),
            Field(id: IMAPField.incomingHost, title: "field.imap.incomingHost"),
            Field(id: IMAPField.incomingPort, title: "field.imap.incomingPort"),
            Field(id: IMAPField.incomingSecurity, title: "field.imap.incomingSecurity"),
            Field(id: IMAPField.outgoingHost, title: "field.imap.outgoingHost"),
            Field(id: IMAPField.outgoingPort, title: "field.imap.outgoingPort"),
            Field(id: IMAPField.outgoingSecurity, title: "field.imap.outgoingSecurity"),
            Field(id: IMAPField.username, title: "field.imap.username"),
            Field(id: IMAPField.password, title: "field.imap.password", secret: true)
        ]
    }

    public var presets: [Preset] {
        var entries: [(id: String, title: String, incoming: MailServerTemplate, outgoing: MailServerTemplate)] = []
        for template in MailProviderPresets.all where template.authentication == .password && template.kind != .generic {
            entries.append((template.id, Self.title(template.title), template.incoming, template.outgoing))
        }
        entries.append(("fastmail", "Fastmail",
                        MailServerTemplate(host: "imap.fastmail.com", port: 993, security: .ssl),
                        MailServerTemplate(host: "smtp.fastmail.com", port: 465, security: .ssl)))
        let other = MailProviderPresets.preset(for: .generic)
        entries.append((other.id, Self.title(other.title), other.incoming, other.outgoing))
        return entries.map { entry in
            var values: [Field.ID: String] = [:]
            Self.fill(&values, entry.incoming, host: IMAPField.incomingHost, port: IMAPField.incomingPort,
                      security: IMAPField.incomingSecurity)
            Self.fill(&values, entry.outgoing, host: IMAPField.outgoingHost, port: IMAPField.outgoingPort,
                      security: IMAPField.outgoingSecurity)
            return Preset(id: entry.id, title: entry.title, values: values)
        }
    }

    private static func fill(_ values: inout [Field.ID: String], _ template: MailServerTemplate, host: String,
                             port: String, security: String) {
        if !template.host.isEmpty { values[host] = template.host }
        if let number = template.port { values[port] = String(number) }
        values[security] = template.security.rawValue
    }

    private static func title(_ text: ConnectionText) -> String {
        switch text {
        case .key(let key): key
        case .verbatim(let text): text
        }
    }

    public func classify(_ error: any Error) -> Classification { IMAPFailure.classify(error) }

    public func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        guard ObjectIdentifier(port) == ObjectIdentifier((any MailTransport).self) else {
            throw HubError.capabilityMissing(inlet.id, inlet.capabilities.first ?? .mail)
        }
        let connection = try IMAPConnection(values: grant.values)
        let password = connection.password
        let transport: any MailTransport = IMAPSMTPMailTransport(
            account: connection.account(id: inlet.id),
            accessToken: { throw MailTransportError.oauthUnavailable(.generic) },
            password: { password })
        guard let typed = transport as? P else {
            throw HubError.capabilityMissing(inlet.id, .mail)
        }
        return typed
    }
}
