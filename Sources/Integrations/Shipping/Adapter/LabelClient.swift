import Assistant
import Foundation
import Hub

struct LabelClient: LabelPort {
    static let orderEndpoint = "https://api-eu.dhl.com/parcel/de/shipping/v2/orders"
    static let tokenEndpoint = "https://api-eu.dhl.com/parcel/de/account/auth/ropc/v1/token"

    private let credentials: LabelCredentials?
    private let http: any HttpPort

    init(credentials: LabelCredentials?, http: any HttpPort) {
        self.credentials = credentials
        self.http = http
    }

    func createLabel(_ order: LabelOrder) async throws -> LabelResult {
        let issues = LabelOrderEngine.issues(order)
        guard issues.isEmpty else { throw ShippingFailure.incomplete(issues) }
        guard let credentials, credentials.apiKey.isEmpty == false, credentials.apiSecret.isEmpty == false,
              credentials.user.isEmpty == false, credentials.password.isEmpty == false else {
            throw ShippingFailure.noCredentials
        }
        let token = try await fetchToken(credentials)
        guard let url = URL(string: Self.orderEndpoint) else { throw ShippingFailure.parse("url") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(LabelRequestEngine.request(order))
        return try Self.parse(try await send(request))
    }

    private func fetchToken(_ credentials: LabelCredentials) async throws -> String {
        guard let url = URL(string: Self.tokenEndpoint) else { throw ShippingFailure.parse("url") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.tokenBody(credentials)
        return try Self.parseToken(try await send(request))
    }

    private func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await http.data(for: request)
            if let status = response as? HTTPURLResponse, (200...299).contains(status.statusCode) == false {
                throw ShippingFailure.http(status.statusCode)
            }
            return data
        } catch let failure as ShippingFailure {
            throw failure
        } catch {
            throw ShippingFailure.transport(String(describing: error))
        }
    }

    static func tokenBody(_ credentials: LabelCredentials) -> Data {
        let fields = [
            ("grant_type", "password"),
            ("client_id", credentials.apiKey),
            ("client_secret", credentials.apiSecret),
            ("username", credentials.user),
            ("password", credentials.password),
        ]
        return Data(fields.map { "\($0.0)=\(formEncode($0.1))" }.joined(separator: "&").utf8)
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static func parseToken(_ data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = root["access_token"] as? String, token.isEmpty == false else {
            throw ShippingFailure.parse("noAccessToken")
        }
        return token
    }

    static func parse(_ data: Data) throws -> LabelResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = root["items"] as? [[String: Any]],
              let first = items.first,
              let tracking = first["shipmentNo"] as? String else { throw ShippingFailure.parse("noShipmentNumber") }
        return LabelResult(
            trackingNumber: tracking,
            labelBase64: (first["label"] as? [String: Any])?["b64"] as? String,
            statusText: (first["sstatus"] as? [String: Any])?["title"] as? String)
    }
}

public struct ShipmentClient: ShipmentPort {
    private let tracking: any TrackingPort
    private let text: any TextPort

    public init(tracking: any TrackingPort, text: any TextPort) {
        self.tracking = tracking
        self.text = text
    }

    public func track(number: String) async throws -> ShipmentStatus {
        let shipment = Shipment(trackingNumber: number, carrier: CarrierEngine.detect(number), label: number)
        do {
            let tracked = try await tracking.track(shipment)
            return ShipmentStatus(
                number: tracked.trackingNumber, statusLabel: text.text(tracked.status.key, []), detail: tracked.statusText)
        } catch ShippingFailure.noKey {
            throw PortFailure.notConnected
        } catch let failure as ShippingFailure {
            throw PortFailure.failed(failure.detail)
        }
    }
}

public struct TrackingClient: TrackingPort {
    static let endpoint = "https://api-eu.dhl.com/track/shipments"
    static let keyHeader = "DHL-API-Key"
    static let language = "de"

    private let apiKey: String?
    private let http: any HttpPort

    public init(apiKey: String?, http: any HttpPort) {
        self.apiKey = apiKey
        self.http = http
    }

    public func track(_ shipment: Shipment) async throws -> Shipment {
        guard shipment.carrier == .dhl else { throw ShippingFailure.unsupported }
        guard let apiKey, apiKey.isEmpty == false else { throw ShippingFailure.noKey }
        guard var components = URLComponents(string: Self.endpoint) else { throw ShippingFailure.parse("url") }
        components.queryItems = [
            URLQueryItem(name: "trackingNumber", value: shipment.trackingNumber),
            URLQueryItem(name: "language", value: Self.language),
        ]
        guard let url = components.url else { throw ShippingFailure.parse("url") }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: Self.keyHeader)

        let data: Data
        do {
            let (body, response) = try await http.data(for: request)
            if let status = response as? HTTPURLResponse, (200...299).contains(status.statusCode) == false {
                throw ShippingFailure.http(status.statusCode)
            }
            data = body
        } catch let failure as ShippingFailure {
            throw failure
        } catch {
            throw ShippingFailure.transport(String(describing: error))
        }

        let raw = try Self.parse(data)
        var updated = shipment
        updated.status = StatusEngine.status(code: raw.statusCode, text: raw.statusText)
        updated.statusText = raw.etaText ?? raw.statusText
        return updated
    }

    struct RawStatus: Equatable {
        let statusCode: String
        let statusText: String?
        let etaText: String?
    }

    static func parse(_ data: Data) throws -> RawStatus {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let shipments = root["shipments"] as? [[String: Any]],
              let first = shipments.first else { throw ShippingFailure.parse("noShipment") }
        let status = first["status"] as? [String: Any]
        return RawStatus(
            statusCode: (status?["statusCode"] as? String) ?? "unknown",
            statusText: status?["status"] as? String,
            etaText: first["estimatedTimeOfDelivery"] as? String)
    }
}

public struct ConnectionCheck: ConnectionCheckPort {
    static let probeNumber = "00000000000000000000"
    static let notFound = 404

    private let http: any HttpPort

    public init(http: any HttpPort) {
        self.http = http
    }

    public var integration: String { "dhl" }

    public func check(_ values: KeyValues) async throws -> String? {
        let client = TrackingClient(apiKey: values["key"], http: http)
        let probe = Shipment(trackingNumber: Self.probeNumber, carrier: .dhl, label: "")
        do {
            _ = try await client.track(probe)
        } catch ShippingFailure.http(let code) {
            guard code == Self.notFound else { throw StatusFailure(status: code) }
        } catch ShippingFailure.parse {
            return nil
        } catch ShippingFailure.transport {
            throw URLError(.networkConnectionLost)
        }
        return nil
    }

    private struct StatusFailure: StatusErrorPort {
        let status: Int
    }
}
