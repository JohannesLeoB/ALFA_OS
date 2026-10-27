import Assistant
import Foundation

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

enum CarrierEngine {
    static func detect(_ raw: String) -> Carrier {
        let number = normalize(raw)
        guard number.isEmpty == false else { return .unknown }
        if number.hasPrefix("JJD") || number.hasPrefix("GM") || number.hasPrefix("LX") { return .dhl }
        if number.hasPrefix("H"), number.dropFirst().allSatisfy(\.isNumber), number.count >= 8 { return .hermes }
        if number.allSatisfy(\.isNumber), (12...22).contains(number.count) { return .dhl }
        return .unknown
    }

    static func normalize(_ raw: String) -> String {
        raw.filter { !$0.isWhitespace }.uppercased()
    }
}
