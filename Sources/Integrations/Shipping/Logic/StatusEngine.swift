import Foundation

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
