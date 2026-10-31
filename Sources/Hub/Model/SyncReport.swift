import Foundation

public struct SyncReport: Equatable, Sendable {
    public enum Result: Equatable, Sendable {
        case finished(items: Int)
        case skipped
        case failed(Hint)
    }

    public var inlet: Inlet.ID
    public var capability: Capability
    public var result: Result

    init(inlet: Inlet.ID, capability: Capability, result: Result) {
        self.inlet = inlet
        self.capability = capability
        self.result = result
    }
}

public struct SyncJob: Equatable, Sendable {
    var inlet: Inlet.ID
    var capability: Capability
    var startedAt: Date

    init(inlet: Inlet.ID, capability: Capability, startedAt: Date) {
        self.inlet = inlet
        self.capability = capability
        self.startedAt = startedAt
    }
}

public struct RunProgress: Equatable, Sendable {
    public let done: Int
    public let total: Int

    public init?(done: Int, total: Int) {
        guard total > 0 else { return nil }
        self.total = total
        self.done = min(max(done, 0), total)
    }
}

public struct SyncReporter: Sendable {
    private let deliver: @Sendable (RunProgress) -> Void

    public init(_ deliver: @escaping @Sendable (RunProgress) -> Void) {
        self.deliver = deliver
    }

    public func callAsFunction(done: Int, total: Int) {
        guard let progress = RunProgress(done: done, total: total) else { return }
        deliver(progress)
    }
}

public struct SyncOutcome: Sendable {
    var deliveries: [DataKind: [any Item]]

    public init(deliveries: [DataKind: [any Item]] = [:]) {
        self.deliveries = deliveries
    }

    var count: Int { deliveries.values.reduce(0) { $0 + $1.count } }
}

public protocol Item: Identifiable, Sendable where ID == String {
    var inlet: Inlet.ID { get }
}

public struct ReportEntry: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    var inlet: Inlet.ID
    var event: ReportEvent
    var capability: Capability?
    var at: Date
    var ok: Bool
    var kind: FailureKind?
    var hint: String?
    var original: Original?

    init(id: UUID = UUID(), inlet: Inlet.ID, event: ReportEvent, capability: Capability? = nil, at: Date,
                ok: Bool, kind: FailureKind? = nil, hint: String? = nil, original: Original? = nil) {
        self.id = id
        self.inlet = inlet
        self.event = event
        self.capability = capability
        self.at = at
        self.ok = ok
        self.kind = kind
        self.hint = hint
        self.original = original
    }
}

public enum ReportEvent: String, Codable, Equatable, Sendable {
    case signIn
    case probe
    case sync
    case renewal
    case write
}

public struct Cost: Equatable, Sendable {
    var calls: Int
    var bytes: Int
    var tokens: Int

    init(calls: Int = 0, bytes: Int = 0, tokens: Int = 0) {
        self.calls = calls
        self.bytes = bytes
        self.tokens = tokens
    }
}

public struct CostItem: Equatable, Sendable {
    var inlet: Inlet.ID
    var capability: Capability
    var cost: Cost
    var at: Date

    init(inlet: Inlet.ID, capability: Capability, cost: Cost, at: Date) {
        self.inlet = inlet
        self.capability = capability
        self.cost = cost
        self.at = at
    }
}

public struct CostMeter: Sendable {
    let inlet: Inlet.ID
    let capability: Capability
    let cost: any CostPort
    let clock: @Sendable () -> Date

    init(inlet: Inlet.ID, capability: Capability, cost: any CostPort, clock: @escaping @Sendable () -> Date) {
        self.inlet = inlet
        self.capability = capability
        self.cost = cost
        self.clock = clock
    }

    public func record(calls: Int = 1, bytes: Int = 0, tokens: Int = 0) {
        cost.book(CostItem(inlet: inlet, capability: capability,
                           cost: Cost(calls: calls, bytes: bytes, tokens: tokens), at: clock()))
    }
}

public struct FileEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let mimeType: String
    public let isFolder: Bool
    public let size: Int?

    public init(id: String, name: String, mimeType: String, isFolder: Bool = false, size: Int? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.isFolder = isFolder
        self.size = size
    }
}

public struct FileFolder: Identifiable, Hashable, Sendable {
    public static let ownDrive = "root"

    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct ProjectFolder: Item, Equatable {
    public var id: String
    public var inlet: Inlet.ID
    public var folder: FileFolder

    init(inlet: Inlet.ID, folder: FileFolder) {
        self.id = inlet + "/" + folder.id
        self.inlet = inlet
        self.folder = folder
    }
}

public struct ContactSource: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: ContactSourceKind
    public let account: String

    public init(id: String, kind: ContactSourceKind, account: String = "") {
        self.id = id
        self.kind = kind
        self.account = account
    }

    public static let airtable = ContactSource(id: ContactSourceKind.airtable.rawValue, kind: .airtable)

    public static let mail = ContactSource(id: ContactSourceKind.mail.rawValue, kind: .mail)

    public static func googleID(_ inlet: Inlet.ID) -> String { ContactSourceKind.google.rawValue + "." + inlet }

    public static func google(_ inlet: Inlet) -> ContactSource {
        ContactSource(id: googleID(inlet.id), kind: .google, account: inlet.account)
    }
}

public enum ContactSourceKind: String, CaseIterable, Sendable {
    case google
    case airtable
    case mail

    public var key: String { "settings.contacts.source." + rawValue }
}

public struct ContactFeed: Sendable {
    public let source: ContactSource
    public let port: any ContactFeedPort

    public init(source: ContactSource, port: any ContactFeedPort) {
        self.source = source
        self.port = port
    }
}

public struct ContactPerson: Equatable, Sendable, Codable {
    public let name: String
    public let address: String

    public init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}
