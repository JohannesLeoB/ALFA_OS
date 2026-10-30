import Foundation

struct ContactsClient: ContactsFetchPort {
    static let searchEndpoint = "https://people.googleapis.com/v1/people:searchContacts"
    static let readMask = "names,emailAddresses,phoneNumbers,organizations"
    static let listEndpoint = "https://people.googleapis.com/v1/people/me/connections"
    static let listMask = "names,emailAddresses"
    static let listPageSize = "1000"

    let requests: RequestClient
    let retryDelay: Duration

    init(requests: RequestClient, retryDelay: Duration = .milliseconds(500)) {
        self.requests = requests
        self.retryDelay = retryDelay
    }

    func searchContacts(query rawQuery: String?) async throws -> [Contact] {
        let query = Self.normalize(rawQuery)
        guard !query.isEmpty else { return [] }
        _ = try? await requests.send(Self.url(query: ""))
        var contacts = try await search(query)
        if contacts.isEmpty {
            try? await Task.sleep(for: retryDelay)
            contacts = try await search(query)
        }
        return contacts
    }

    func allContacts() async throws -> [Contact] {
        var contacts: [Contact] = []
        var token: String?
        repeat {
            let page = try ContactParser.page(from: try await requests.send(Self.listURL(token: token)))
            contacts += page.contacts
            token = page.next
        } while token != nil
        return contacts
    }

    private func search(_ query: String) async throws -> [Contact] {
        try ContactParser.contacts(from: try await requests.send(Self.url(query: query)))
    }

    static func url(query: String) throws -> URL {
        try RequestClient.url(searchEndpoint, query: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "readMask", value: readMask),
        ])
    }

    static func listURL(token: String?) throws -> URL {
        var query = [URLQueryItem(name: "personFields", value: listMask), URLQueryItem(name: "pageSize", value: listPageSize)]
        if let token { query.append(URLQueryItem(name: "pageToken", value: token)) }
        return try RequestClient.url(listEndpoint, query: query)
    }

    static func normalize(_ raw: String?) -> String {
        guard let raw else { return "" }
        return raw.replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .joined(separator: " ")
    }
}
