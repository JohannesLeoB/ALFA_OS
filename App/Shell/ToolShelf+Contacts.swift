import Airtable
import Assistant
import Hub

extension ToolShelf {
    func contactFeeds() -> [ContactFeed] {
        var feeds: [ContactFeed] = []
        for inlet in setup.inlets where inlet.provider == "google" && inlet.state.isConnected && inlet.capabilities.contains(.contacts) {
            guard let port = try? access.port((any GoogleContactsPort).self, for: inlet.id),
                  let feed = port as? any ContactFeedPort else { continue }
            feeds.append(ContactFeed(source: .google(inlet), port: feed))
        }
        if let client = airtableClient(inlet("airtable")) {
            let customers = CustomerContactStore(fetch: client)
            if customers.configured { feeds.append(ContactFeed(source: .airtable, port: customers)) }
        }
        return feeds
    }
}
