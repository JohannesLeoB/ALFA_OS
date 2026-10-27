import Assistant
import Foundation

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

enum StatusEngine {
    static func status(code: String, text: String? = nil) -> TrackingStatus {
        if let lowered = text?.lowercased(),
           lowered.contains("zustellung") || lowered.contains("out for delivery") || lowered.contains("in delivery") {
            return .outForDelivery
        }
        switch code.lowercased() {
        case "pre-transit": return .registered
        case "transit": return .inTransit
        case "delivered": return .delivered
        case "failure": return .exception
        default: return .unknown
        }
    }
}
