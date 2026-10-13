import Foundation
import GRDB
import Hub
import struct MykilosKit.EmailDraft
import protocol MykilosServices.MailTransport
import struct MykilosServices.MailFolder
import struct MykilosServices.MailMessagePage
import struct MykilosServices.MailMessageBody
import enum MykilosServices.MailFlag
import enum MykilosServices.MailTransportError

struct TestTimedOut: Error {}

@MainActor
func within<T: Sendable>(_ limit: Duration, _ work: @escaping @MainActor () async throws -> T) async throws -> T {
    let task = Task { @MainActor in try await work() }
    let expired = Locked(false)
    let watchdog = Task {
        try await Task.sleep(for: limit)
        expired.with { $0 = true }
        task.cancel()
    }
    defer { watchdog.cancel() }
    let result = await task.result
    if expired.with({ $0 }) { throw TestTimedOut() }
    return try result.get()
}

final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) { self.value = value }

    func with<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

actor Gate {
    private var open = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if open { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        open = true
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

final class MailTransportFake: MailTransport, @unchecked Sendable {
    struct State {
        var folders: [MailFolder] = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        var failure: MailTransportError?
        var listFoldersCalls = 0
        var sent: [EmailDraft] = []
        var gate: Gate?
    }

    private let state = Locked(State())

    var listFoldersCalls: Int { state.with { $0.listFoldersCalls } }
    var sent: [EmailDraft] { state.with { $0.sent } }
    func setFailure(_ error: MailTransportError?) { state.with { $0.failure = error } }
    func setGate(_ gate: Gate?) { state.with { $0.gate = gate } }

    func listFolders() async throws -> [MailFolder] {
        let (failure, folders, gate) = state.with { s -> (MailTransportError?, [MailFolder], Gate?) in
            s.listFoldersCalls += 1
            return (s.failure, s.folders, s.gate)
        }
        if let gate { await gate.wait() }
        if let failure { throw failure }
        return folders
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        if let failure = state.with({ $0.failure }) { throw failure }
        return MailMessagePage(messages: [])
    }

    func fetchBody(messageID: String) async throws -> MailMessageBody {
        if let failure = state.with({ $0.failure }) { throw failure }
        return MailMessageBody(text: "")
    }

    func send(_ draft: EmailDraft) async throws {
        if let failure = state.with({ $0.failure }) { throw failure }
        state.with { $0.sent.append(draft) }
    }

    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {
        if let failure = state.with({ $0.failure }) { throw failure }
    }
}

struct FakeCalendar: CalendarPort {}

final class FakeKeychain: KeychainPort, @unchecked Sendable {
    private let entries = Locked<[KeySlot: String]>([:])

    var slots: Set<KeySlot> { entries.with { Set($0.keys) } }
    func put(_ value: String, at slot: KeySlot) throws { entries.with { $0[slot] = value } }
    func get(_ slot: KeySlot) throws -> String? { entries.with { $0[slot] } }
    func delete(_ slot: KeySlot) throws { entries.with { $0[slot] = nil } }
}

final class HandCadence: CadencePort, @unchecked Sendable {
    private let runner = Locked<SyncRunner?>(nil)
    private let planned = Locked<[String: Cadence]>([:])
    private let continuation: AsyncStream<SyncReport>.Continuation
    let reports: AsyncStream<SyncReport>

    init() {
        (reports, continuation) = AsyncStream<SyncReport>.makeStream()
    }

    func planned(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence? {
        planned.with { $0[inlet + "|" + capability.rawValue] }
    }

    func attach(_ runner: @escaping SyncRunner) { self.runner.with { $0 = runner } }

    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence) {
        planned.with { $0[inlet + "|" + capability.rawValue] = cadence }
    }

    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async {
        guard let run = runner.with({ $0 }) else { return }
        continuation.yield(await run(inlet, capability))
    }
}

final class FakeCost: CostPort, @unchecked Sendable {
    private let items = Locked<[CostItem]>([])

    func book(_ item: CostItem) { items.with { $0.append(item) } }

    func sum(_ inlet: Inlet.ID, _ period: Period) -> Cost {
        items.with { all in
            all.filter { $0.inlet == inlet && period.contains($0.at) }.reduce(Cost.zero) {
                Cost(calls: $0.calls + $1.cost.calls, bytes: $0.bytes + $1.cost.bytes, tokens: $0.tokens + $1.cost.tokens)
            }
        }
    }
}

struct FakeSignIn: SignInPort {
    let signedOut: Locked<[Inlet.ID]>

    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        Grant(values: ["token": input["address"] ?? inlet.id])
    }

    func renew(_ grant: Grant) async throws -> Grant { grant }

    func signOut(_ inlet: Inlet) async throws { signedOut.with { $0.append(inlet.id) } }
}

struct FakeProbe: ProbePort {
    let accepting: Locked<Bool>

    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        let account = grant.values["token"] ?? inlet.id
        if accepting.with({ $0 }) { return ProbeResult(account: account) }
        return ProbeResult(account: account, rejection: Hint(text: "hint.fake.rejected"))
    }
}

final class FakeProvider: Provider, @unchecked Sendable {
    let id = "fake"
    let capabilities: Set<Capability>
    let form: [Field] = []
    let presets: [Preset] = []
    let mail = MailTransportFake()
    private let accepting = Locked(true)
    private let signedOutList = Locked<[Inlet.ID]>([])
    let signIn: any SignInPort
    let probe: any ProbePort

    init(capabilities: Set<Capability>, signIn: (any SignInPort)? = nil) {
        self.capabilities = capabilities
        self.signIn = signIn ?? FakeSignIn(signedOut: signedOutList)
        probe = FakeProbe(accepting: accepting)
    }

    func classify(_ error: any Error) -> Classification { IMAPProvider().classify(error) }

    var signedOut: [Inlet.ID] { signedOutList.with { $0 } }
    func setAccepting(_ value: Bool) { accepting.with { $0 = value } }

    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        let made: Any
        switch ObjectIdentifier(port) {
        case ObjectIdentifier((any MailTransport).self): made = mail as any MailTransport
        case ObjectIdentifier((any CalendarPort).self): made = FakeCalendar() as any CalendarPort
        default: throw HubError.capabilityMissing(inlet.id, inlet.capabilities.first ?? .mail)
        }
        guard let typed = made as? P else { throw HubError.capabilityMissing(inlet.id, .mail) }
        return typed
    }
}
