import Foundation
import AlfaKit

public struct SevdeskContact: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var customerNumber: String?

    public init(id: String, name: String, customerNumber: String? = nil) {
        self.id = id
        self.name = name
        self.customerNumber = customerNumber
    }
}

public struct SevdeskPart: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var partNumber: String?

    public init(id: String, name: String, partNumber: String? = nil) {
        self.id = id
        self.name = name
        self.partNumber = partNumber
    }
}

public struct SevdeskUnity: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct SevdeskOrder: Identifiable, Equatable, Sendable {
    public var id: String
    public var orderNumber: String?
    public var orderType: String
    public var rawStatus: String
    public var sumNet: Double
    public var sumTax: Double
    public var sumGross: Double
    public var contactID: String?

    public var customerInternalNote: String?

    public var header: String?

    public init(
        id: String, orderNumber: String? = nil, orderType: String, rawStatus: String,
        sumNet: Double = 0, sumTax: Double = 0, sumGross: Double = 0, contactID: String? = nil,
        customerInternalNote: String? = nil, header: String? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.orderType = orderType
        self.rawStatus = rawStatus
        self.sumNet = sumNet
        self.sumTax = sumTax
        self.sumGross = sumGross
        self.contactID = contactID
        self.customerInternalNote = customerInternalNote
        self.header = header
    }

    public var zugeordneteProjektnummer: Projektnummer? {
        [customerInternalNote, header]
            .lazy
            .compactMap { $0.flatMap(Projektnummer.ersteImText) }
            .first
    }
}

public protocol SevdeskReading: Sendable {
    func readContact(id: String) async throws -> SevdeskContact?
    func readPart(id: String) async throws -> SevdeskPart?
    func readUnity(id: String) async throws -> SevdeskUnity?
    func readOrder(id: String) async throws -> SevdeskOrder?

    func listOrders(orderType: String) async throws -> [SevdeskOrder]
}

public struct SevdeskReadClient: SevdeskReading {
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

    public func readContact(id: String) async throws -> SevdeskContact? {
        guard let data = try await get(path: "Contact/\(id)") else { return nil }
        return try Self.parseContact(from: data)
    }

    public func readPart(id: String) async throws -> SevdeskPart? {
        guard let data = try await get(path: "Part/\(id)") else { return nil }
        return try Self.parsePart(from: data)
    }

    public func readUnity(id: String) async throws -> SevdeskUnity? {
        guard let data = try await get(path: "Unity/\(id)") else { return nil }
        return try Self.parseUnity(from: data)
    }

    public func readOrder(id: String) async throws -> SevdeskOrder? {
        guard let data = try await get(path: "Order/\(id)") else { return nil }
        return try Self.parseOrders(from: data).first
    }

    public func listOrders(orderType: String = "AN") async throws -> [SevdeskOrder] {
        guard let data = try await get(path: "Order", query: [URLQueryItem(name: "orderType", value: orderType)]) else { return [] }
        return try Self.parseOrders(from: data)
    }

    public func holeBelegPDF(orderID: String) async throws -> Data? {
        guard let data = try await get(
            path: "Order/\(orderID)/getPdf",
            query: [URLQueryItem(name: "download", value: "true")]) else { return nil }
        guard let pdf = Self.parsePDFAntwort(data) else { throw SevdeskError.decodingFailed }
        return pdf
    }

    static func parsePDFAntwort(_ data: Data) -> Data? {
        if data.starts(with: Array("%PDF".utf8)) { return data }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }

        let objekt: [String: Any]?
        if let einzeln = root["objects"] as? [String: Any] { objekt = einzeln } else if let list = root["objects"] as? [[String: Any]] { objekt = list.first } else { objekt = root }
        guard let content = objekt?["content"] as? String,
              let dekodiert = Data(base64Encoded: content, options: .ignoreUnknownCharacters),
              dekodiert.starts(with: Array("%PDF".utf8)) else { return nil }
        return dekodiert
    }

    private func get(path: String, query: [URLQueryItem] = []) async throws -> Data? {
        guard let credentials = try? credentialsStore.load() else { throw SevdeskError.notConnected }
        guard let url = Self.buildURL(baseURL: baseURL, path: path, query: query) else { throw SevdeskError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(credentials.apiToken, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SevdeskError.invalidResponse }
        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode) else { throw SevdeskError.httpError(http.statusCode) }
        return data
    }

    static func buildURL(baseURL: String, path: String, query: [URLQueryItem]) -> URL? {
        var components = URLComponents(string: "\(baseURL)/\(path)")
        if query.isEmpty == false { components?.queryItems = query }
        return components?.url
    }

    static func parseContact(from data: Data) throws -> SevdeskContact? {
        do {
            let decoded = try JSONDecoder().decode(SevdeskSingleResponse<SevdeskContactEntity>.self, from: data)
            guard let entity = decoded.first else { return nil }
            return SevdeskContact(id: entity.id ?? "", name: entity.name ?? "", customerNumber: entity.customerNumber)
        } catch {
            throw SevdeskError.decodingFailed
        }
    }

    static func parsePart(from data: Data) throws -> SevdeskPart? {
        do {
            let decoded = try JSONDecoder().decode(SevdeskSingleResponse<SevdeskPartEntity>.self, from: data)
            guard let entity = decoded.first else { return nil }
            return SevdeskPart(id: entity.id ?? "", name: entity.name ?? "", partNumber: entity.partNumber)
        } catch {
            throw SevdeskError.decodingFailed
        }
    }

    static func parseUnity(from data: Data) throws -> SevdeskUnity? {
        do {
            let decoded = try JSONDecoder().decode(SevdeskSingleResponse<SevdeskUnityEntity>.self, from: data)
            guard let entity = decoded.first else { return nil }
            return SevdeskUnity(id: entity.id ?? "", name: entity.name ?? "")
        } catch {
            throw SevdeskError.decodingFailed
        }
    }

    static func parseOrders(from data: Data) throws -> [SevdeskOrder] {
        do {
            let decoded = try JSONDecoder().decode(SevdeskSingleResponse<SevdeskOrderEntity>.self, from: data)
            return decoded.objects.map { entity in
                SevdeskOrder(
                    id: entity.id ?? "",
                    orderNumber: entity.orderNumber,
                    orderType: entity.orderType ?? "",
                    rawStatus: entity.status ?? "",
                    sumNet: double(from: entity.sumNet),
                    sumTax: double(from: entity.sumTax),
                    sumGross: double(from: entity.sumGross),
                    contactID: entity.contact?.id,
                    customerInternalNote: entity.customerInternalNote,
                    header: entity.header)
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

private struct SevdeskSingleResponse<T: Decodable>: Decodable {
    var objects: [T]
    var first: T? { objects.first }
}

private struct SevdeskContactEntity: Decodable {
    var id: String?
    var name: String?
    var customerNumber: String?
}

private struct SevdeskPartEntity: Decodable {
    var id: String?
    var name: String?
    var partNumber: String?
}

private struct SevdeskUnityEntity: Decodable {
    var id: String?
    var name: String?
}

private struct SevdeskOrderEntity: Decodable {
    var id: String?
    var orderNumber: String?
    var orderType: String?
    var status: String?
    var sumNet: String?
    var sumTax: String?
    var sumGross: String?
    var contact: SevdeskContactRefEntity?
    var customerInternalNote: String?
    var header: String?
}

private struct SevdeskContactRefEntity: Decodable {
    var id: String?
}
