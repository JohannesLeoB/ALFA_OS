import Foundation

final class GoogleStubNet: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) -> (Int, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    nonisolated(unsafe) private static var seen: [URL] = []

    static func install(_ handler: @escaping Handler) {
        lock.withLock {
            self.handler = handler
            seen = []
        }
    }

    static var requests: [URL] { lock.withLock { seen } }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GoogleStubNet.self]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (handler, url) = Self.lock.withLock { () -> (Handler?, URL?) in
            if let url = request.url { Self.seen.append(url) }
            return (Self.handler, request.url)
        }
        let (status, body) = handler?(request) ?? (599, Data())
        let response = HTTPURLResponse(url: url ?? URL(fileURLWithPath: "/"), statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
