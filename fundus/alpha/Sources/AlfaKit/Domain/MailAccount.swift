import Foundation

public enum MailProviderKind: String, Codable, Sendable, CaseIterable {
    case gmail
    case outlook
    case ionos
    case gmx
    case webde
    case icloud
    case generic
}

public enum MailSecurity: String, Codable, Sendable, CaseIterable {
    case none
    case ssl
    case starttls
}

public enum MailAuthentication: String, Codable, Sendable, CaseIterable {
    case oauth
    case password

    public var access: ConnectionAccess {
        switch self {
        case .oauth: .oauth
        case .password: .key
        }
    }
}

public struct MailServerSettings: Codable, Equatable, Sendable {
    public var host: String
    public var port: Int?
    public var security: MailSecurity
    public var authentication: MailAuthentication
    public var username: String

    public init(host: String = "", port: Int? = nil, security: MailSecurity = .ssl,
                authentication: MailAuthentication = .password, username: String = "") {
        self.host = host
        self.port = port
        self.security = security
        self.authentication = authentication
        self.username = username
    }

    public var isComplete: Bool {
        host.isEmpty == false && port != nil && (authentication == .oauth || username.isEmpty == false)
    }
}

public struct MailAccount: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var displayName: String
    public var address: String
    public var provider: MailProviderKind
    public var incoming: MailServerSettings
    public var outgoing: MailServerSettings

    public init(id: String, displayName: String, address: String, provider: MailProviderKind,
                incoming: MailServerSettings, outgoing: MailServerSettings) {
        self.id = id
        self.displayName = displayName
        self.address = address
        self.provider = provider
        self.incoming = incoming
        self.outgoing = outgoing
    }

    public var authentication: MailAuthentication { incoming.authentication }

    public var access: ConnectionAccess { incoming.authentication.access }

    public var isComplete: Bool { incoming.isComplete && outgoing.isComplete }
}

public struct MailServerTemplate: Equatable, Sendable {
    public let host: String
    public let port: Int?
    public let security: MailSecurity

    public init(host: String = "", port: Int? = nil, security: MailSecurity = .ssl) {
        self.host = host
        self.port = port
        self.security = security
    }
}

public struct MailProviderPreset: Identifiable, Equatable, Sendable {
    public let kind: MailProviderKind
    public let title: ConnectionText
    public let incoming: MailServerTemplate
    public let outgoing: MailServerTemplate
    public let authentication: MailAuthentication
    public let asksServer: Bool
    public var id: String { kind.rawValue }

    public init(kind: MailProviderKind, title: ConnectionText, incoming: MailServerTemplate, outgoing: MailServerTemplate,
                authentication: MailAuthentication, asksServer: Bool = false) {
        self.kind = kind
        self.title = title
        self.incoming = incoming
        self.outgoing = outgoing
        self.authentication = authentication
        self.asksServer = asksServer
    }

    public var access: ConnectionAccess { authentication.access }

    public func account(id: String, displayName: String, address: String, username: String? = nil,
                        incoming incomingOverride: MailServerTemplate? = nil,
                        outgoing outgoingOverride: MailServerTemplate? = nil) -> MailAccount {
        let login = (username?.isEmpty == false ? username : nil) ?? address
        let inbound = incomingOverride ?? incoming
        let outbound = outgoingOverride ?? outgoing
        return MailAccount(
            id: id,
            displayName: displayName.isEmpty ? address : displayName,
            address: address,
            provider: kind,
            incoming: MailServerSettings(host: inbound.host, port: inbound.port, security: inbound.security,
                                         authentication: authentication, username: login),
            outgoing: MailServerSettings(host: outbound.host, port: outbound.port, security: outbound.security,
                                         authentication: authentication, username: login))
    }
}

public enum MailProviderPresets {
    public static let all: [MailProviderPreset] = [
        MailProviderPreset(
            kind: .gmail, title: .verbatim("Gmail"),
            incoming: MailServerTemplate(host: "imap.gmail.com", port: 993, security: .ssl),
            outgoing: MailServerTemplate(host: "smtp.gmail.com", port: 465, security: .ssl),
            authentication: .oauth),
        MailProviderPreset(
            kind: .outlook, title: .verbatim("Outlook"),
            incoming: MailServerTemplate(host: "outlook.office365.com", port: 993, security: .ssl),
            outgoing: MailServerTemplate(host: "smtp-mail.outlook.com", port: 587, security: .starttls),
            authentication: .oauth),
        MailProviderPreset(
            kind: .ionos, title: .verbatim("Ionos"),
            incoming: MailServerTemplate(host: "imap.ionos.de", port: 993, security: .ssl),
            outgoing: MailServerTemplate(host: "smtp.ionos.de", port: 465, security: .ssl),
            authentication: .password),
        MailProviderPreset(
            kind: .gmx, title: .verbatim("GMX"),
            incoming: MailServerTemplate(host: "imap.gmx.net", port: 993, security: .ssl),
            outgoing: MailServerTemplate(host: "mail.gmx.net", port: 587, security: .starttls),
            authentication: .password),
        MailProviderPreset(
            kind: .webde, title: .verbatim("Web.de"),
            incoming: MailServerTemplate(host: "imap.web.de", port: 993, security: .ssl),
            outgoing: MailServerTemplate(host: "smtp.web.de", port: 587, security: .starttls),
            authentication: .password),
        MailProviderPreset(
            kind: .icloud, title: .verbatim("iCloud"),
            incoming: MailServerTemplate(host: "imap.mail.me.com", port: 993, security: .ssl),
            outgoing: MailServerTemplate(host: "smtp.mail.me.com", port: 587, security: .starttls),
            authentication: .password),
        MailProviderPreset(
            kind: .generic, title: .key("text.settings.provider.other"),
            incoming: MailServerTemplate(),
            outgoing: MailServerTemplate(),
            authentication: .password, asksServer: true),
    ]

    public static func preset(for kind: MailProviderKind) -> MailProviderPreset {
        all.first { $0.kind == kind } ?? all[all.count - 1]
    }
}
