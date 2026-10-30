import Foundation

enum AutoconfigEngine {
    struct Entry: Equatable {
        var outgoing: Bool
        var type: String
        var hostname = ""
        var port: Int?
        var socketType = ""
        var username = ""
        var authentication: [String] = []
    }

    static func servers(_ data: Data, address: String) -> FoundServers? {
        let reader = Reader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        guard parser.parse() else { return nil }
        let entries = reader.entries.map { resolved($0, address: address) }
        let incoming = entries.first { !$0.outgoing && $0.type == "imap" && usable($0) }
            ?? entries.first { !$0.outgoing && $0.type == "pop3" && usable($0) }
        guard let incoming,
              let outgoing = entries.first(where: { $0.outgoing && $0.type == "smtp" && usable($0) }),
              let inTemplate = template(incoming), let outTemplate = template(outgoing) else { return nil }
        let username = incoming.username.isEmpty || incoming.username.lowercased() == address.lowercased()
            ? nil : incoming.username
        return FoundServers(incoming: inTemplate, outgoing: outTemplate, username: username,
                            incomingProtocol: incoming.type == "pop3" ? .pop3 : .imap)
    }

    static func usable(_ entry: Entry) -> Bool {
        !entry.hostname.isEmpty && ["SSL", "STARTTLS"].contains(entry.socketType.uppercased())
            && entry.authentication.contains { $0.lowercased() == "password-cleartext" }
    }

    private static func template(_ entry: Entry) -> ServerTemplate? {
        let security: TransportSecurity = entry.socketType.uppercased() == "SSL" ? .ssl : .starttls
        return ServerTemplate(host: entry.hostname.lowercased(), port: entry.port, security: security)
    }

    private static func resolved(_ entry: Entry, address: String) -> Entry {
        let parts = address.split(separator: "@", maxSplits: 1).map(String.init)
        let local = parts.first ?? ""
        let domain = parts.count > 1 ? parts[1] : ""
        func fill(_ text: String) -> String {
            text.replacingOccurrences(of: "%EMAILADDRESS%", with: address)
                .replacingOccurrences(of: "%EMAILLOCALPART%", with: local)
                .replacingOccurrences(of: "%EMAILDOMAIN%", with: domain)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var result = entry
        result.hostname = fill(entry.hostname)
        result.username = fill(entry.username)
        return result
    }

    private final class Reader: NSObject, XMLParserDelegate {
        var entries: [Entry] = []
        private var current: Entry?
        private var text = ""

        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
                    attributes: [String: String] = [:]) {
            text = ""
            guard name == "incomingServer" || name == "outgoingServer" else { return }
            current = Entry(outgoing: name == "outgoingServer", type: (attributes["type"] ?? "").lowercased())
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
            text = ""
            guard current != nil else { return }
            switch name {
            case "hostname": current?.hostname = value
            case "port": current?.port = Int(value).flatMap { (1...65535).contains($0) ? $0 : nil }
            case "socketType": current?.socketType = value
            case "username": current?.username = value
            case "authentication": current?.authentication.append(value)
            case "incomingServer", "outgoingServer":
                if let entry = current { entries.append(entry) }
                current = nil
            default: break
            }
        }
    }
}
