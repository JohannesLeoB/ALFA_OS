import Foundation

enum ContactParser {
    private struct SearchResponse: Decodable { var results: [Result]? }

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
        return (decoded.results ?? []).map { result in
            let person = result.person
            return Contact(
                id: person?.resourceName ?? UUID().uuidString,
                displayName: person?.names?.first?.displayName ?? "",
                email: person?.emailAddresses?.first?.value,
                phone: person?.phoneNumbers?.first?.value,
                organization: person?.organizations?.first?.name)
        }
    }
}
