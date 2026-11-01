import Assistant
import Foundation
import Hub

struct SevdeskClient: Sendable {
    static let baseURL = "https://my.sevdesk.de/api/v1"
    static let versionPath = "Tools/bookkeepingSystemVersion"
    static let offerType = "AN"

    private let credentials: any CredentialsPort
    private let http: any HttpPort

    init(credentials: any CredentialsPort, http: any HttpPort) {
        self.credentials = credentials
        self.http = http
    }

    func check() async throws {
        _ = try await get(path: Self.versionPath)
    }

    func contact(id: String) async throws -> Contact? {
        guard let data = try await get(path: "Contact/\(id)") else { return nil }
        return try SevdeskResponseParser.contact(from: data)
    }

    func order(id: String) async throws -> Order? {
        guard let data = try await get(path: "Order/\(id)") else { return nil }
        return try SevdeskResponseParser.orders(from: data).first
    }

    func orders(type: String = "AN") async throws -> [Order] {
        guard let data = try await get(path: "Order", query: [URLQueryItem(name: "orderType", value: type)]) else { return [] }
        return try SevdeskResponseParser.orders(from: data)
    }

    func contact(customerNumber: String) async throws -> ContactMatch {
        let number = customerNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard number.isEmpty == false else { return .none }
        guard let data = try await get(path: "Contact", query: [
            URLQueryItem(name: "customerNumber", value: number),
            URLQueryItem(name: "depth", value: "1"),
        ]) else { return .none }
        return SevdeskResponseParser.match(byNumber: number, from: data)
    }

    func contact(name: String) async throws -> ContactMatch {
        let wanted = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard wanted.isEmpty == false else { return .none }
        guard let data = try await get(path: "Contact", query: [
            URLQueryItem(name: "name", value: wanted),
            URLQueryItem(name: "depth", value: "1"),
        ]) else { return .none }
        return SevdeskResponseParser.match(byName: wanted, from: data)
    }

    func tenant(orderNumber: String? = nil) async throws -> TenantFinding {
        var gaps: [TenantFinding.Gap] = []
        let numbered = orderNumber?.isEmpty == false

        let version = try await get(path: Self.versionPath).flatMap { SevdeskResponseParser.version(from: $0) }
        if version == nil { gaps.append(.versionUnreadable) }

        var query = [URLQueryItem(name: "orderType", value: Self.offerType), URLQueryItem(name: "limit", value: "1")]
        if let orderNumber, numbered { query.append(URLQueryItem(name: "orderNumber", value: orderNumber)) }
        let template = try await get(path: "Order", query: query).flatMap { SevdeskResponseParser.template(from: $0) }
        if let template {
            if template.contactPersonID == nil { gaps.append(.contactPersonMissing) }
            if template.addressCountryID == nil { gaps.append(.addressCountryMissing) }
            if template.taxRate == nil { gaps.append(.taxRateMissing) }
        } else {
            gaps.append(numbered ? .noOfferForNumber : .noOffer)
        }

        var units: [TenantFinding.Unit] = []
        var positionTaxRate: Double?
        if let orderID = template?.orderID {
            if let data = try await get(
                path: "Order/\(orderID)/getPositions", query: [URLQueryItem(name: "embed", value: "unity")]) {
                units = SevdeskResponseParser.units(from: data)
                positionTaxRate = SevdeskResponseParser.positionTaxRate(from: data)
            }
            if units.isEmpty { gaps.append(.unitsMissing) }
            if positionTaxRate == nil { gaps.append(.positionTaxRateMissing) }
            if let header = template?.taxRate, let positions = positionTaxRate, header != positions {
                gaps.append(.taxRateMismatch(header: header, positions: positions))
            }
        }

        let nextNumber = await nextOrderNumber()
        if nextNumber == nil { gaps.append(.nextNumberUnavailable) }

        return TenantFinding(
            version: version, template: template, units: units, positionTaxRate: positionTaxRate,
            nextNumber: nextNumber, gaps: gaps)
    }

    private func nextOrderNumber() async -> String? {
        let query = [
            URLQueryItem(name: "orderType", value: Self.offerType),
            URLQueryItem(name: "useNextNumber", value: "false"),
        ]
        guard let data = try? await get(path: "Order/Factory/getNextOrderNumber", query: query) else { return nil }
        return SevdeskResponseParser.nextNumber(from: data)
    }

    static func url(path: String, query: [URLQueryItem]) -> URL? {
        var components = URLComponents(string: "\(baseURL)/\(path)")
        if query.isEmpty == false { components?.queryItems = query }
        return components?.url
    }

    private func get(path: String, query: [URLQueryItem] = []) async throws -> Data? {
        guard let held = try? credentials.load() else { throw SevdeskFailure.notConnected }
        guard let url = Self.url(path: path, query: query) else { throw SevdeskFailure.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue(held.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await http.data(for: request)
        guard let status = response as? HTTPURLResponse else { throw SevdeskFailure.invalidResponse }
        if status.statusCode == 404 { return nil }
        guard (200...299).contains(status.statusCode) else { throw SevdeskFailure.http(status.statusCode) }
        return data
    }
}

public struct ConnectionCheck: ConnectionCheckPort {
    private let http: any HttpPort

    public init(http: any HttpPort) {
        self.http = http
    }

    public var integration: String { "sevdesk" }

    public func check(_ values: KeyValues) async throws -> String? {
        let client = SevdeskClient(credentials: HeldCredentials(credentials: Credentials(token: values["token"])), http: http)
        do {
            try await client.check()
            return nil
        } catch let failure as SevdeskFailure {
            throw Self.translate(failure)
        }
    }

    static func translate(_ failure: SevdeskFailure) -> any Error {
        switch failure {
        case .http(let code): StatusFailure(status: code)
        case .invalidResponse, .decoding: ShapeFailure()
        case .notConnected: failure
        }
    }

    private struct HeldCredentials: CredentialsPort {
        let credentials: Credentials

        func load() throws -> Credentials? { credentials }
    }

    private struct StatusFailure: StatusErrorPort {
        let status: Int
    }

    private struct ShapeFailure: ShapeErrorPort {}
}
