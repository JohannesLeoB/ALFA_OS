import Hub

extension ContactSearchClient: ContactFeedPort {
    func people() async throws -> [ContactPerson] {
        do {
            return try await contacts.allContacts().compactMap { contact in
                contact.email.map { ContactPerson(name: contact.displayName, address: $0) }
            }
        } catch {
            throw FailureEngine.port(error)
        }
    }
}
