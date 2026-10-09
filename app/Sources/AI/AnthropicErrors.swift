import Foundation

/// Turns a failed answer of the API into an `AIError`. The key never appears in the result.
enum AnthropicErrors {
    /// The longest message that the app keeps from a refused request.
    static let maxMessageLength = 300

    static func error(for http: HTTPURLResponse, body: Data, key: String) -> AIError {
        let status = http.statusCode
        switch status {
        case 400..<500:
            break
        case 500..<600:
            return .overloaded(status: status)
        default:
            return .network("HTTP status \(status)")
        }

        switch status {
        case 401:
            return .invalidKey
        case 403:
            return .forbidden
        case 429:
            // The console sends this code when the monthly limit of the organization is reached.
            if String(decoding: body, as: UTF8.self).contains("enforced_spend_limit_reached") {
                return .spendLimitReached
            }
            return .rateLimited(retryAfter: retryAfter(in: http))
        default:
            return .badRequest(message(in: body, status: status, key: key))
        }
    }

    /// The text of the error body, with the key removed and cut to the limit.
    static func message(in body: Data, status: Int, key: String) -> String {
        let text: String
        if let decoded = try? JSONDecoder().decode(WireErrorBody.self, from: body), let message = decoded.error?.message {
            text = message
        } else {
            text = "HTTP status \(status)"
        }
        let safe = text.replacingOccurrences(of: key, with: "[redacted]")
        return String(safe.prefix(maxMessageLength))
    }

    static func retryAfter(in http: HTTPURLResponse) -> TimeInterval? {
        http.headerValue("retry-after").flatMap { TimeInterval($0.trimmingCharacters(in: .whitespaces)) }
    }
}

private struct WireErrorBody: Decodable {
    let error: Inner?

    struct Inner: Decodable {
        let message: String?
    }
}
