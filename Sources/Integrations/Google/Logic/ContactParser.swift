import Foundation

enum ContactParser {
    private struct SearchResponse: Decodable { var results: [Result]? }

    private struct ListResponse: Decodable {
        var connections: [Person]?
        var nextPageToken: String?
    }

    private struct Result: Decodable { var person: Person? }

    private struct Person: Decodable {
        var resourceName: String?
        var names: [Name]?
        var emailAddresses: [Value]?
        var phoneNumbers: [Value]?
        var organizations: [Organization]?
    }

    private struct Name: Decodable { var displayName: String? }

    private struct Value: Decodable { var value: String? }

    private struct Organization: Decodable { var name: String? }

    static func contacts(from data: Data) throws -> [Contact] {
        guard let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        return (decoded.results ?? []).map { contact($0.person) }
    }

    static func page(from data: Data) throws -> (contacts: [Contact], next: String?) {
        guard let decoded = try? JSONDecoder().decode(ListResponse.self, from: data) else {
            throw GoogleFailure.decodingFailed
        }
        let next = decoded.nextPageToken.flatMap { $0.isEmpty ? nil : $0 }
        return ((decoded.connections ?? []).map { contact($0) }, next)
    }

    private static func contact(_ person: Person?) -> Contact {
        Contact(
            id: person?.resourceName ?? UUID().uuidString,
            displayName: person?.names?.first?.displayName ?? "",
            email: person?.emailAddresses?.first?.value,
            phone: person?.phoneNumbers?.first?.value,
            organization: person?.organizations?.first?.name)
    }
}
