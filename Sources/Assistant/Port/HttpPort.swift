import Foundation

public protocol HttpPort: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
    func lines(for request: URLRequest) async throws -> (AsyncThrowingStream<String, any Error>, URLResponse)
}
