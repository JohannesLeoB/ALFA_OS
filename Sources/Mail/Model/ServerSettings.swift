import Foundation
import Hub

enum TransportSecurity: String, Codable, Sendable, CaseIterable {
    case none
    case ssl
    case starttls
}

struct ServerSettings: Codable, Equatable, Sendable {
    var host: String
    var port: Int?
    var security: TransportSecurity
    var username: String

    init(host: String = "", port: Int? = nil, security: TransportSecurity = .ssl, username: String = "") {
        self.host = host
        self.port = port
        self.security = security
        self.username = username
    }

    var isComplete: Bool {
        !host.isEmpty && port != nil && !username.isEmpty
    }
}

struct ServerTemplate: Equatable, Sendable {
    let host: String
    let port: Int?
    let security: TransportSecurity

    init(host: String = "", port: Int? = nil, security: TransportSecurity = .ssl) {
        self.host = host
        self.port = port
        self.security = security
    }
}

struct ProviderPreset: Identifiable, Equatable, Sendable {
    let id: String
    let title: PresetTitle
    let incoming: ServerTemplate
    let outgoing: ServerTemplate
}

enum PresetTitle: Equatable, Sendable {
    case key(String)
    case verbatim(String)

    var text: String {
        switch self {
        case .key(let key): key
        case .verbatim(let text): text
        }
    }
}

enum ConnectionField {
    static let address = "address"
    static let name = "name"
    static let username = "username"
    static let password = "password"
    static let incomingHost = "incomingHost"
    static let incomingPort = "incomingPort"
    static let incomingSecurity = "incomingSecurity"
    static let outgoingHost = "outgoingHost"
    static let outgoingPort = "outgoingPort"
    static let outgoingSecurity = "outgoingSecurity"
    static let incomingProtocol = "incomingProtocol"
}

struct Account: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var displayName: String
    var address: String
    var incoming: ServerSettings
    var outgoing: ServerSettings
    var incomingProtocol: IncomingProtocol

    init(id: String, displayName: String, address: String, incoming: ServerSettings, outgoing: ServerSettings,
         incomingProtocol: IncomingProtocol = .imap) {
        self.id = id
        self.displayName = displayName
        self.address = address
        self.incoming = incoming
        self.outgoing = outgoing
        self.incomingProtocol = incomingProtocol
    }
}

enum IncomingProtocol: String, Codable, Sendable, CaseIterable {
    case imap
    case pop3
}

enum MailCredential: Equatable, Sendable {
    case password(String)
    case accessToken(String)

    var isEmpty: Bool {
        switch self {
        case .password(let value), .accessToken(let value): value.isEmpty
        }
    }
}

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

extension Inlet {
    public var ownName: String { title.trimmingCharacters(in: .whitespaces) }

    public var mailboxInitials: String {
        let address = account.trimmingCharacters(in: .whitespaces)
        let parts = address.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        let local = parts.first?.first.map(String.init) ?? ""
        let domain = parts.count > 1 ? parts[1].first.map(String.init) ?? "" : ""
        let initials = local + domain
        return (initials.isEmpty ? ownName.first.map(String.init) ?? "" : initials).uppercased()
    }
}

public enum MailFailure: Error, Equatable, Sendable {
    case folderNotFound(String)
    case accountIncomplete(String)
    case connectionFailed(String)
    case connectionClosed
    case timeout
    case tlsUnavailable
    case credentialsMissing
    case unsupportedAuthentication(String)
    case unsupportedCapability(String)
    case authenticationRejected(String)
    case serverRejected(String)
    case smtpRejected(Int, String)
    case recipientRejected(String, Int, String)
    case malformedResponse(String)
    case messageNotFound(String)
    case invalidMessageID(String)
    case invalidRecipient(String)
    case noRecipients
}

public enum MailboxEvent: Equatable, Sendable {
    case accountsChanged
    case foldersChanged(Inlet.ID)
    case messagesChanged(Inlet.ID, folder: String)
    case newMail(Inlet.ID, count: Int)
    case outboxChanged
    case progress(Inlet.ID, folder: String)
    case refused(Inlet.ID, folder: String)
    case syncFailed(Inlet.ID, Hint)
    case syncFinished(Inlet.ID)
}

enum MessageTextKey: String, Sendable {
    case offline = "mail.hint.offline"
    case rejected = "mail.hint.rejected"
    case failed = "mail.hint.failed"
    case mirrorRefused = "mail.hint.mirrorRefused"
    case notConnected = "hint.mail.notConnected"
    case noInlet = "hint.mail.noInlet"
    case capabilityMissing = "hint.mail.capabilityMissing"
    case tooLarge = "mail.notice.tooLarge.title"
}

enum ConnectionFailure: Error, Equatable, Sendable {
    case missing(String)
    case invalidAddress(String)
    case invalidPort(field: String, value: String)
    case invalidSecurity(field: String, value: String)
    case insecure(field: String)
    case invalidProtocol(String)
}

enum ProbeStep: String, Sendable {
    case incoming
    case outgoing
}

struct ProbeFailure: Error, Equatable, Sendable {
    let step: ProbeStep
    let reason: MailFailure
}
