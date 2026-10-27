public struct Shipment: Codable, Sendable, Equatable, Identifiable {
    var trackingNumber: String
    var carrier: Carrier
    var label: String
    var status: TrackingStatus
    var statusText: String?
    var projectNumber: String?

    public var id: String { trackingNumber }

    init(
        trackingNumber: String, carrier: Carrier, label: String, status: TrackingStatus = .unknown,
        statusText: String? = nil, projectNumber: String? = nil
    ) {
        self.trackingNumber = trackingNumber
        self.carrier = carrier
        self.label = label
        self.status = status
        self.statusText = statusText
        self.projectNumber = projectNumber
    }
}

enum Carrier: String, Codable, Sendable, CaseIterable, Equatable {
    case dhl
    case hermes
    case unknown
}

enum TrackingStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case registered
    case inTransit
    case outForDelivery
    case delivered
    case exception
    case unknown

    var key: String { "shipping.status." + rawValue }
}
