import Assistant
import Foundation
import Hub

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
