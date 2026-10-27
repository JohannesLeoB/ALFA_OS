import Foundation
import Observation

@MainActor @Observable
public final class StockState<T: Item>: StockFeedPort {
    public private(set) var items: [T] = []
    public private(set) var phase: StockPhase = .empty

    @ObservationIgnored private var refresher: (@MainActor () async -> Void)?
    @ObservationIgnored private var before: StockPhase?

    public init(refresher: @escaping @MainActor () async -> Void) {
        self.refresher = refresher
    }

    public func refresh() async {
        await refresher?()
    }

    func begin() {
        before = phase
        phase = .loading
    }

    func end() {
        if phase == .loading, let before { phase = before }
        before = nil
    }

    public func apply(inlet: Inlet.ID, records: [any Item], at: Date) {
        items = items.filter { $0.inlet != inlet } + records.compactMap { $0 as? T }
        phase = .current(since: at)
    }

    func drop(inlet: Inlet.ID) {
        items = items.filter { $0.inlet != inlet }
        if items.isEmpty, case .current = phase { phase = .empty }
    }

    func disturb(_ hint: Hint) {
        phase = .disturbed(hint)
    }
}

public enum StockPhase: Equatable, Sendable {
    case empty
    case loading
    case current(since: Date)
    case disturbed(Hint)
}
