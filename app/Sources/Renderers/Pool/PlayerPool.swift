/// The players that run live at once. A player that starts beyond the limit stops the oldest one.
@MainActor
public final class PlayerPool<ID: Hashable> {
    public let limit: Int
    /// The live players, the oldest first.
    private var order: [ID] = []
    private var stops: [ID: () -> Void] = [:]

    public init(limit: Int) {
        self.limit = max(1, limit)
    }

    public var liveIDs: [ID] { order }

    /// Makes `id` the newest live player and stops the players beyond the limit. `stop` is called when the player is evicted.
    public func claim(_ id: ID, stop: @escaping () -> Void) {
        order.removeAll { $0 == id }
        order.append(id)
        stops[id] = stop
        while order.count > limit {
            let oldest = order.removeFirst()
            let evicted = stops.removeValue(forKey: oldest)
            evicted?()
        }
    }

    /// Takes `id` out of the pool without stopping it. The player stopped itself.
    public func release(_ id: ID) {
        order.removeAll { $0 == id }
        stops[id] = nil
    }

    /// Stops every live player, the oldest first.
    public func stopAll() {
        let all = order
        for id in all {
            let stop = stops.removeValue(forKey: id)
            order.removeAll { $0 == id }
            stop?()
        }
    }
}
