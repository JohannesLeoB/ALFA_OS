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
}

struct Account: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var displayName: String
    var address: String
    var incoming: ServerSettings
    var outgoing: ServerSettings

    init(id: String, displayName: String, address: String, incoming: ServerSettings, outgoing: ServerSettings) {
        self.id = id
        self.displayName = displayName
        self.address = address
        self.incoming = incoming
        self.outgoing = outgoing
    }
}
