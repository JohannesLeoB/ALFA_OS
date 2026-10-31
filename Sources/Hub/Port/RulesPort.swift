import Foundation

@MainActor
public protocol RulesPort: AnyObject {
    func cadence(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence
    func setCadence(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence)
    var queue: [SyncJob] { get }
    func progress(_ inlet: Inlet.ID, _ capability: Capability) -> RunProgress?
    func lastSync(_ inlet: Inlet.ID, _ capability: Capability) -> Date?
    @discardableResult
    func syncNow(_ inlet: Inlet.ID, _ capability: Capability) async -> SyncReport
}
