import Foundation

struct OAuthFault: Equatable, Sendable {
    let status: Int
    let reason: String?
    let message: String?

    init(status: Int, reason: String? = nil, message: String? = nil) {
        self.status = status
        self.reason = reason
        self.message = message
    }

    init(status: Int, data: Data) {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        self.init(status: status, reason: object?["error"] as? String, message: object?["error_description"] as? String)
    }

    var isServerFault: Bool { status == 429 || (500...599).contains(status) }
}
