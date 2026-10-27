import Foundation

struct ContactsClient: ContactsFetchPort {
    static let searchEndpoint = "https://people.googleapis.com/v1/people:searchContacts"
    static let readMask = "names,emailAddresses,phoneNumbers,organizations"

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

    private func search(_ query: String) async throws -> [Contact] {
        try ContactParser.contacts(from: try await requests.send(Self.url(query: query)))
    }

    static func url(query: String) throws -> URL {
        try RequestClient.url(searchEndpoint, query: [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "readMask", value: readMask),
        ])
    }

    static func normalize(_ raw: String?) -> String {
        guard let raw else { return "" }
        return raw.replacingOccurrences(of: "_", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .joined(separator: " ")
    }
}
