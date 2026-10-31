import Foundation

public enum UnsubscribeClient {
    private static let timeout: TimeInterval = 15

    public static func post(_ url: URL) async -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        guard let (_, response) = try? await session.data(for: UnsubscribeEngine.request(url)),
              let http = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(http.statusCode)
    }
}
