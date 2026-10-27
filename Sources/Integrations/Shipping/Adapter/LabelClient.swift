import Assistant
import Foundation

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
