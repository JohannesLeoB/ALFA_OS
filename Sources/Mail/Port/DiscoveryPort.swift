import Foundation

public protocol DiscoveryPort: Sendable {
    func document(_ url: URL) async -> Data?
    func records(_ name: String, type: UInt16) async -> [Data]
}
