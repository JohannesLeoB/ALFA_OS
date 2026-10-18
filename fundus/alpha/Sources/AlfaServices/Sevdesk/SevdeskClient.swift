import Foundation

public struct SevdeskInvoice: Identifiable, Equatable, Sendable {
    public var id: String
    public var number: String
    public var sumGross: Double
    public var status: String

    public init(id: String, number: String, sumGross: Double, status: String) {
        self.id = id
        self.number = number
        self.sumGross = sumGross
        self.status = status
    }
}

public enum SevdeskError: Error, Sendable, Equatable {
    case notConnected
    case invalidResponse
    case httpError(Int)
    case decodingFailed
}

public protocol SevdeskFetching: Sendable {
    func invoices(contactRef: String) async throws -> [SevdeskInvoice]
}

public struct SevdeskClient: SevdeskFetching {
    private let credentialsStore: SevdeskCredentialsStoring
    private let session: URLSession
    private let baseURL = "https://my.sevdesk.de/api/v1"

    public init(
        credentialsStore: SevdeskCredentialsStoring = KeychainSevdeskCredentialsStore(),
        session: URLSession = .shared
    ) {
        self.credentialsStore = credentialsStore
        self.session = session
    }

    public func invoices(contactRef: String) async throws -> [SevdeskInvoice] {
        guard let credentials = try? credentialsStore.load() else {
            throw SevdeskError.notConnected
        }
        guard let url = Self.buildInvoicesURL(baseURL: baseURL, contactRef: contactRef) else {
            throw SevdeskError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SevdeskError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw SevdeskError.httpError(http.statusCode) }

        return try Self.parseInvoices(from: data)
    }

    static func buildInvoicesURL(baseURL: String, contactRef: String) -> URL? {
        var components = URLComponents(string: "\(baseURL)/Invoice")
        components?.queryItems = [
            URLQueryItem(name: "contact[id]", value: contactRef),
            URLQueryItem(name: "contact[objectName]", value: "Contact"),
            URLQueryItem(name: "limit", value: "100")
        ]
        return components?.url
    }

    static func parseInvoices(from data: Data) throws -> [SevdeskInvoice] {
        do {
            let decoded = try JSONDecoder().decode(SevdeskInvoiceResponse.self, from: data)
            return decoded.objects.map { entity in
                SevdeskInvoice(
                    id: entity.id ?? "",
                    number: entity.invoiceNumber ?? "",
                    sumGross: Self.double(from: entity.sumGross),
                    status: entity.status ?? ""
                )
            }
        } catch {
            throw SevdeskError.decodingFailed
        }
    }

    static func double(from value: String?) -> Double {
        guard let value, let parsed = Double(value) else { return 0 }
        return parsed
    }
}

private struct SevdeskInvoiceResponse: Decodable {
    var objects: [SevdeskInvoiceEntity]
}

private struct SevdeskInvoiceEntity: Decodable {
    var id: String?
    var invoiceNumber: String?
    var sumGross: String?
    var status: String?
}
