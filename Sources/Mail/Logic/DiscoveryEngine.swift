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

    static func domain(of address: String) -> String? {
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
