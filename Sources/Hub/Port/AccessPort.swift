@MainActor
public protocol AccessPort: AnyObject {
    func stock<T: Item>(_ kind: DataKind, as type: T.Type) -> StockState<T>
    func port<P>(_ port: P.Type, for inlet: Inlet.ID) throws(HubFailure) -> P
    func inlets(for capability: Capability) -> [Inlet]
    func configured(for capability: Capability) -> [Inlet]
    func classify(_ error: any Error, inlet: Inlet.ID) -> Classification
    func track<T>(_ inlet: Inlet.ID, _ capability: Capability, body: @MainActor (SyncReporter) async -> T) async -> T
    var events: AsyncStream<InletEvent> { get }
}
