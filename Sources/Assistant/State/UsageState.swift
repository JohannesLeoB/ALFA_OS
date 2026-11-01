import Foundation
import Observation

@MainActor @Observable
public final class UsageState {
    public private(set) var totals = UsageTotals()
    public private(set) var inputPrice = ""
    public private(set) var outputPrice = ""
    public private(set) var now = Date()

    @ObservationIgnored private let store: any UsagePort
    @ObservationIgnored private let calendar: Calendar

    public init(store: any UsagePort, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        refresh()
    }

    public func refresh(now: Date = Date()) {
        self.now = now
        let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
        totals = store.totals(from: start)
        inputPrice = store.price(.input)
        outputPrice = store.price(.output)
    }

    public var estimate: Double? {
        UsageEngine.estimate(totals, input: inputPrice, output: outputPrice)
    }

    public var days: Int? {
        totals.since.map { UsageEngine.days(since: $0, now: now) }
    }

    public func setPrice(_ text: String, for kind: UsagePrice) {
        store.setPrice(text, for: kind)
        switch kind {
        case .input: inputPrice = text
        case .output: outputPrice = text
        }
    }

    public func reset() {
        store.reset()
        refresh(now: now)
    }
}
