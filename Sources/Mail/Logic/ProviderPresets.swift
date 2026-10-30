public enum ProviderPresets {
    public static let requiredFields: Set<String> = [
        ConnectionField.address, ConnectionField.password, ConnectionField.incomingHost, ConnectionField.outgoingHost,
    ]
    public static let addressField = ConnectionField.address
    public static let securityFields: Set<String> = [ConnectionField.incomingSecurity, ConnectionField.outgoingSecurity]
    public static let securityChoices: [String] = [TransportSecurity.ssl.rawValue, TransportSecurity.starttls.rawValue]

    public static func choices(for field: String) -> [String]? {
        if securityFields.contains(field) { return securityChoices }
        if field == ConnectionField.incomingProtocol { return IncomingProtocol.allCases.map(\.rawValue) }
        return nil
    }

    public static func choiceKey(field: String, option: String) -> String {
        (field == ConnectionField.incomingProtocol ? "settings.protocol." : "settings.security.") + option
    }

    static let all: [ProviderPreset] = [
        ProviderPreset(
            id: "ionos", title: .verbatim("Ionos"),
            incoming: ServerTemplate(host: "imap.ionos.de", port: 993, security: .ssl),
            outgoing: ServerTemplate(host: "smtp.ionos.de", port: 465, security: .ssl)),
        ProviderPreset(
            id: "gmx", title: .verbatim("GMX"),
            incoming: ServerTemplate(host: "imap.gmx.net", port: 993, security: .ssl),
            outgoing: ServerTemplate(host: "mail.gmx.net", port: 587, security: .starttls)),
        ProviderPreset(
            id: "webde", title: .verbatim("Web.de"),
            incoming: ServerTemplate(host: "imap.web.de", port: 993, security: .ssl),
            outgoing: ServerTemplate(host: "smtp.web.de", port: 587, security: .starttls)),
        ProviderPreset(
            id: "icloud", title: .verbatim("iCloud"),
            incoming: ServerTemplate(host: "imap.mail.me.com", port: 993, security: .ssl),
            outgoing: ServerTemplate(host: "smtp.mail.me.com", port: 587, security: .starttls)),
        ProviderPreset(
            id: "fastmail", title: .verbatim("Fastmail"),
            incoming: ServerTemplate(host: "imap.fastmail.com", port: 993, security: .ssl),
            outgoing: ServerTemplate(host: "smtp.fastmail.com", port: 465, security: .ssl)),
        ProviderPreset(
            id: "generic", title: .key("text.settings.provider.other"),
            incoming: ServerTemplate(), outgoing: ServerTemplate())
    ]
}
