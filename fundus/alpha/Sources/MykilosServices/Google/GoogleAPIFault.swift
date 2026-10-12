import Foundation

public struct GoogleAPIFault: Equatable, Sendable {
    public let status: Int
    public let reason: String?
    public let message: String?
    public let state: String?
    public let domain: String?
    public let errorURI: String?
    public let body: String

    public init(status: Int, reason: String? = nil, message: String? = nil, state: String? = nil,
                domain: String? = nil, errorURI: String? = nil, body: String = "") {
        self.status = status
        self.reason = reason
        self.message = message
        self.state = state
        self.domain = domain
        self.errorURI = errorURI
        self.body = body
    }

    public init(status: Int, data: Data) {
        let body = String(decoding: data, as: UTF8.self)
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            self.init(status: status, body: body)
            return
        }
        if let code = object["error"] as? String {
            self.init(status: status, reason: code, message: object["error_description"] as? String,
                      errorURI: object["error_uri"] as? String, body: body)
            return
        }
        let error = object["error"] as? [String: Any]
        let first = (error?["errors"] as? [[String: Any]])?.first
        self.init(status: status, reason: first?["reason"] as? String, message: error?["message"] as? String,
                  state: error?["status"] as? String, domain: first?["domain"] as? String, body: body)
    }

    public var isRateLimit: Bool {
        status == 429 || (status == 403 && (reason == "rateLimitExceeded" || reason == "userRateLimitExceeded"))
    }

    public var isServerFault: Bool { (500...599).contains(status) }

    public var isRetryable: Bool { isRateLimit || isServerFault }
}

public struct GmailRequestPolicy: Equatable, Sendable {
    public var maxConcurrentDetails: Int
    public var maxAttempts: Int
    public var firstDelay: Duration

    public init(maxConcurrentDetails: Int = 4, maxAttempts: Int = 3, firstDelay: Duration = .seconds(1)) {
        self.maxConcurrentDetails = max(1, maxConcurrentDetails)
        self.maxAttempts = max(1, maxAttempts)
        self.firstDelay = firstDelay
    }

    public static let standard = GmailRequestPolicy()

    func delay(afterAttempt attempt: Int) -> Duration {
        firstDelay * (1 << max(0, attempt - 1))
    }
}
