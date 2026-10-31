import Foundation

public protocol ExportPort: Sendable {
    var isAvailable: Bool { get }
    func collect(at date: Date) throws(ExportFailure) -> ExportSource
    func save(_ data: Data, to url: URL) throws(ExportFailure)
}
