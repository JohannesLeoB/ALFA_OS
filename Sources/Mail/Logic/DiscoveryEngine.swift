import Foundation

public enum DiscoveryEngine {
    static let directory = "https://autoconfig.thunderbird.net/v1.1/"

    public static func choices(for address: String, using port: any DiscoveryPort) async -> [[String: String]] {
        await servers(for: address, using: port)?.choices ?? []
    }

    static func servers(for address: String, using port: any DiscoveryPort) async -> FoundServers? {
        let address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let domain = domain(of: address) else { return nil }
        for url in ownURLs(domain: domain, address: address) {
            if let found = await config(url, address: address, port: port) { return found }
        }
        if let found = await services(domain, port: port) { return found }
        if let url = URL(string: directory + domain), let found = await config(url, address: address, port: port) {
            return found
        }
        let exchangers = await port.records(domain, type: DNSRecordEngine.mailExchangerType)
            .compactMap(DNSRecordEngine.mailExchanger)
            .sorted { $0.preference < $1.preference }
        guard let host = exchangers.first?.host else { return nil }
        for base in bases(of: host) where base != domain {
            guard let url = URL(string: directory + base) else { continue }
            if let found = await config(url, address: address, port: port) { return found }
        }
        return nil
    }

    public static func domain(of address: String) -> String? {
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return nil }
        let domain = parts[1].lowercased()
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count > 1, labels.allSatisfy({ !$0.isEmpty }),
              domain.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }) else { return nil }
        return domain
    }

    static func ownURLs(domain: String, address: String) -> [URL] {
        var query = URLComponents(string: "https://autoconfig." + domain + "/mail/config-v1.1.xml")
        query?.queryItems = [URLQueryItem(name: "emailaddress", value: address)]
        return [query?.url, URL(string: "https://" + domain + "/.well-known/autoconfig/mail/config-v1.1.xml")]
            .compactMap { $0 }
    }

    static func bases(of host: String) -> [String] {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return labels.count == 2 ? [host] : [] }
        let parent = labels.dropFirst().joined(separator: ".")
        let registered = labels.suffix(2).joined(separator: ".")
        return parent == registered ? [parent] : [parent, registered]
    }

    private static func config(_ url: URL, address: String, port: any DiscoveryPort) async -> FoundServers? {
        guard let data = await port.document(url) else { return nil }
        return AutoconfigEngine.servers(data, address: address)
    }

    private static func services(_ domain: String, port: any DiscoveryPort) async -> FoundServers? {
        async let imaps = service("_imaps._tcp." + domain, port: port)
        async let imap = service("_imap._tcp." + domain, port: port)
        async let submissions = service("_submissions._tcp." + domain, port: port)
        async let submission = service("_submission._tcp." + domain, port: port)
        async let pop3s = service("_pop3s._tcp." + domain, port: port)
        async let pop3 = service("_pop3._tcp." + domain, port: port)
        let records = await (imaps, imap, submissions, submission)
        let pops = await (pop3s, pop3)
        let imapIncoming = records.0.map { ServerTemplate(host: $0.target, port: $0.port, security: .ssl) }
            ?? records.1.map { ServerTemplate(host: $0.target, port: $0.port, security: .starttls) }
        let popIncoming = pops.0.map { ServerTemplate(host: $0.target, port: $0.port, security: .ssl) }
            ?? pops.1.map { ServerTemplate(host: $0.target, port: $0.port, security: .starttls) }
        let incoming = imapIncoming ?? popIncoming
        let outgoing = records.2.map { ServerTemplate(host: $0.target, port: $0.port, security: .ssl) }
            ?? records.3.map { ServerTemplate(host: $0.target, port: $0.port, security: .starttls) }
        guard let incoming, let outgoing else { return nil }
        return FoundServers(incoming: incoming, outgoing: outgoing, username: nil,
                            incomingProtocol: imapIncoming == nil ? .pop3 : .imap,
                            alternative: imapIncoming == nil ? nil : popIncoming)
    }

    private static func service(_ name: String, port: any DiscoveryPort) async -> SRVRecord? {
        await port.records(name, type: DNSRecordEngine.serviceType)
            .compactMap(DNSRecordEngine.service)
            .filter { !$0.target.isEmpty && $0.port > 0 }
            .sorted { ($0.priority, -$0.weight) < ($1.priority, -$1.weight) }
            .first
    }
}

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
        let imap = entries.first { !$0.outgoing && $0.type == "imap" && usable($0) }
        let pop = entries.first { !$0.outgoing && $0.type == "pop3" && usable($0) }
        guard let incoming = imap ?? pop,
              let outgoing = entries.first(where: { $0.outgoing && $0.type == "smtp" && usable($0) }),
              let inTemplate = template(incoming), let outTemplate = template(outgoing) else { return nil }
        let username = incoming.username.isEmpty || incoming.username.lowercased() == address.lowercased()
            ? nil : incoming.username
        return FoundServers(incoming: inTemplate, outgoing: outTemplate, username: username,
                            incomingProtocol: incoming.type == "pop3" ? .pop3 : .imap,
                            alternative: imap == nil ? nil : pop.flatMap(template))
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

enum DNSRecordEngine {
    static let mailExchangerType: UInt16 = 15
    static let serviceType: UInt16 = 33

    static func mailExchanger(_ data: Data) -> (preference: Int, host: String)? {
        let bytes = [UInt8](data)
        guard bytes.count > 2, let host = name(bytes, from: 2), !host.isEmpty else { return nil }
        return (number(bytes, at: 0), host)
    }

    static func service(_ data: Data) -> SRVRecord? {
        let bytes = [UInt8](data)
        guard bytes.count > 6, let target = name(bytes, from: 6) else { return nil }
        return SRVRecord(priority: number(bytes, at: 0), weight: number(bytes, at: 2), port: number(bytes, at: 4),
                         target: target)
    }

    private static func number(_ bytes: [UInt8], at index: Int) -> Int {
        Int(bytes[index]) << 8 | Int(bytes[index + 1])
    }

    private static func name(_ bytes: [UInt8], from start: Int) -> String? {
        var labels: [String] = []
        var index = start
        while index < bytes.count {
            let length = Int(bytes[index])
            if length == 0 { return labels.joined(separator: ".").lowercased() }
            guard length < 64, index + 1 + length <= bytes.count,
                  let label = String(bytes: bytes[(index + 1)..<(index + 1 + length)], encoding: .utf8) else { return nil }
            labels.append(label)
            index += 1 + length
        }
        return nil
    }
}

struct FoundServers: Equatable, Sendable {
    var incoming: ServerTemplate
    var outgoing: ServerTemplate
    var username: String?
    var incomingProtocol: IncomingProtocol = .imap
    var alternative: ServerTemplate?

    var choices: [[String: String]] {
        guard let alternative else { return [values] }
        var other = self
        other.incoming = alternative
        other.incomingProtocol = incomingProtocol == .imap ? .pop3 : .imap
        return [values, other.values]
    }

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

struct SRVRecord: Equatable, Sendable {
    let priority: Int
    let weight: Int
    let port: Int
    let target: String
}
