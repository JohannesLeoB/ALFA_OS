import Foundation

/// The spend in EUR, month by month. Months are calendar months in UTC, named "YYYY-MM".
public struct SpendLedger: Codable, Sendable, Equatable {
    /// The booked spend of one month.
    public struct Month: Codable, Sendable, Equatable {
        public var costEUR: Decimal
        public var requests: Int
        public var byModel: [String: Decimal]
        public var byTask: [String: Decimal]

        public init() {
            costEUR = 0
            requests = 0
            byModel = [:]
            byTask = [:]
        }
    }

    public private(set) var months: [String: Month]

    public init() {
        months = [:]
    }

    /// The month of a date, in UTC.
    public static func monthKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let parts = calendar.dateComponents([.year, .month], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        return "\(year)-" + (month < 10 ? "0" : "") + "\(month)"
    }

    public func month(_ key: String) -> Month {
        months[key] ?? Month()
    }

    /// Adds one call to the month of the date.
    public mutating func book(cost: Decimal, model: String, task: String, at date: Date) {
        let key = Self.monthKey(for: date)
        var month = months[key] ?? Month()
        month.costEUR += cost
        month.requests += 1
        month.byModel[model, default: 0] += cost
        month.byTask[task, default: 0] += cost
        months[key] = month
    }
}

/// Keeps the ledger outside the module. The app passes UserDefaults, a test passes memory.
public protocol LedgerStore: Sendable {
    func load() -> Data?
    func save(_ data: Data)
}

/// The book of the app: the ledger, the app's own monthly limit and the prices.
public actor SpendBook {
    private let store: any LedgerStore
    private var ledger: SpendLedger
    private let monthlyLimitEUR: Decimal?
    private let prices: PriceTable
    private let usdToEur: Decimal
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - monthlyLimitEUR: The app's own limit. nil or 0 turns the assistant off.
    ///   - usdToEur: The rate used for every booking and estimate.
    public init(
        store: any LedgerStore,
        monthlyLimitEUR: Decimal?,
        prices: PriceTable = .standard,
        usdToEur: Decimal,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.store = store
        self.monthlyLimitEUR = monthlyLimitEUR
        self.prices = prices
        self.usdToEur = usdToEur
        self.now = now
        if let data = store.load(), let saved = try? JSONDecoder().decode(SpendLedger.self, from: data) {
            ledger = saved
        } else {
            ledger = SpendLedger()
        }
    }

    /// The spend of the month that contains now.
    public func currentMonth() -> SpendLedger.Month {
        ledger.month(SpendLedger.monthKey(for: now()))
    }

    public func spend(inMonth date: Date) -> SpendLedger.Month {
        ledger.month(SpendLedger.monthKey(for: date))
    }

    /// Throws `AIError.limitStop` when the estimate of the request would pass the limit, or when the limit is off.
    /// Nothing is sent in that case.
    public func checkBeforeSending(_ request: AIRequest) throws {
        let spent = currentMonth().costEUR
        try SpendGuard.check(
            request,
            spent: spent,
            limit: monthlyLimitEUR,
            prices: prices,
            usdToEur: usdToEur
        )
    }

    /// Books the actual usage of a call that returned an answer.
    public func book(_ usage: AIUsage, model: String, task: String) {
        let cost = AICost.compute(usage: usage, model: model, prices: prices, usdToEur: usdToEur)
        ledger.book(cost: cost, model: model, task: task, at: now())
        if let data = try? JSONEncoder().encode(ledger) {
            store.save(data)
        }
    }
}
