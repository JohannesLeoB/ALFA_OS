import Foundation

enum GoogleFailure: Error, Equatable, Sendable {
    case notConnected(Product)
    case invalidResponse
    case invalidEndpoint
    case api(Product, APIFault)
    case decodingFailed
    case uploadDestinationForbidden(String)
}

struct APIFault: Equatable, Sendable {
    let status: Int
    let reason: String?
    let message: String?
    let state: String?
    let domain: String?
    let errorURI: String?

    init(status: Int, reason: String? = nil, message: String? = nil, state: String? = nil,
         domain: String? = nil, errorURI: String? = nil) {
        self.status = status
        self.reason = reason
        self.message = message
        self.state = state
        self.domain = domain
        self.errorURI = errorURI
    }

    init(status: Int, data: Data) {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            self.init(status: status)
            return
        }
        if let code = object["error"] as? String {
            self.init(status: status, reason: code, message: object["error_description"] as? String,
                      errorURI: object["error_uri"] as? String)
            return
        }
        let error = object["error"] as? [String: Any]
        let first = (error?["errors"] as? [[String: Any]])?.first
        self.init(status: status, reason: first?["reason"] as? String, message: error?["message"] as? String,
                  state: error?["status"] as? String, domain: first?["domain"] as? String)
    }

    var isRateLimit: Bool {
        status == 429 || (status == 403 && (reason == "rateLimitExceeded" || reason == "userRateLimitExceeded"))
    }

    var isServerFault: Bool { (500...599).contains(status) }

    var isRetryable: Bool { isRateLimit || isServerFault }
}

struct RequestPolicy: Equatable, Sendable {
    static let standard = RequestPolicy()

    var maxConcurrentDetails: Int
    var maxAttempts: Int
    var firstDelay: Duration

    init(maxConcurrentDetails: Int = 4, maxAttempts: Int = 3, firstDelay: Duration = .seconds(1)) {
        self.maxConcurrentDetails = max(1, maxConcurrentDetails)
        self.maxAttempts = max(1, maxAttempts)
        self.firstDelay = firstDelay
    }

    func delay(afterAttempt attempt: Int) -> Duration {
        firstDelay * (1 << max(0, attempt - 1))
    }
}

enum SignInFailure: Error, Equatable, Sendable {
    case clientConfigMissing(String)
    case clientConfigInvalid(String)
    case grantIncomplete(String)
    case refreshUnavailable
    case redirectStateMismatch
    case loopbackStartupFailed
    case loopbackCancelled
    case browserFailed
}

enum Product: String, Sendable {
    case gmail
    case drive
    case calendar
    case contacts
    case oauth
}
