import Foundation

public enum Retry {
    public static let limit = 2

    public static func retryable(_ status: Int) -> Bool {
        status == 429 || (500...599).contains(status)
    }

    public static func delay(attempt: Int, retryAfter: String?) -> Double {
        if let header = retryAfter, let seconds = Double(header.trimmingCharacters(in: .whitespaces)), seconds >= 0 {
            return min(seconds, 20)
        }
        return attempt == 0 ? 2 : 4
    }
}
