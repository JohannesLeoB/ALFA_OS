import Foundation

protocol ArtifactPort: Sendable {
    @discardableResult
    func write(_ data: Data, name: String, at date: Date) throws -> URL
}
