import Foundation
import class GRDB.DatabaseQueue
import protocol Hub.Record
@testable import Hub
@testable import Mail
@testable import ShellCore
import XCTest
import class GRDB.DatabaseQueue
import enum AlfaServices.GoogleGmailError
import enum AlfaServices.GoogleOAuthError
import enum AlfaServices.MailFlag
import enum AlfaServices.MailTransportError
import protocol AlfaServices.MailTransport
import struct AlfaKit.EmailDraft
import struct AlfaServices.GoogleAPIFault
import struct AlfaServices.IMAPSMTPMailTransport
import struct AlfaServices.MailAttachmentInfo
import struct AlfaServices.MailFolder
import enum AlfaServices.MailFolderRole
import struct AlfaServices.MailMessageBody
import struct AlfaServices.MailMessagePage
import struct AlfaServices.MailMessageSummary
import struct AlfaServices.MailProbeError
import struct AlfaServices.MailStoredDraft

let protocolLog = Locked<[String]>([])
let protocolStep = Locked("")

func canonical(_ value: Any) -> String {
    if let date = value as? Date {
        return abs(date.timeIntervalSinceNow) < 86_400 ? "<now>" : "date(\(date.timeIntervalSince1970))"
    }
    if value is UUID { return "<uuid>" }
    if let data = value as? Data { return "data" + [UInt8](data).description }
    if let text = value as? String { return "\"" + text + "\"" }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .optional:
        guard let child = mirror.children.first else { return "nil" }
        return "some(" + canonical(child.value) + ")"
    case .collection:
        return "[" + mirror.children.map { canonical($0.value) }.joined(separator: ",") + "]"
    case .set:
        return "set[" + mirror.children.map { canonical($0.value) }.sorted().joined(separator: ",") + "]"
    case .dictionary:
        let pairs = mirror.children.map { child -> String in
            let kv = Array(Mirror(reflecting: child.value).children)
            return canonical(kv[0].value) + ":" + canonical(kv[1].value)
        }
        return "dict[" + pairs.sorted().joined(separator: ",") + "]"
    case .struct, .tuple, .enum:
        let inner = mirror.children.map { ($0.label.map { $0 + "=" } ?? "") + canonical($0.value) }
        return String(describing: type(of: value)) + (mirror.displayStyle == .enum ? "." + enumCase(value) : "") + "(" + inner.joined(separator: ",") + ")"
    case .class:
        return String(describing: type(of: value))
    default:
        return String(describing: value)
    }
}

func enumCase(_ value: Any) -> String {
    let text = String(describing: value)
    return String(text.prefix { $0 != "(" })
}

func note(_ kind: String, _ value: Any) {
    let step = protocolStep.with { $0 }
    let line = step + " " + kind + " " + canonical(value)
    let scrubbed = line.replacingOccurrences(of: "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}", with: "<uuid>", options: .regularExpression)
    protocolLog.with { $0.append(scrubbed) }
}

func recordEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T,
                               _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    if let value = try? a() { note("eq", value) }
    XCTAssertEqual(try a(), try b(), message(), file: file, line: line)
}

func recordEqual<T: FloatingPoint>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T, accuracy: T,
                                   _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    if let value = try? a() { note("eq", value) }
    XCTAssertEqual(try a(), try b(), accuracy: accuracy, message(), file: file, line: line)
}

func recordNotEqual<T: Equatable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T,
                                  _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    if let value = try? a() { note("ne", value) }
    XCTAssertNotEqual(try a(), try b(), message(), file: file, line: line)
}

func recordTrue(_ a: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    note("true", (try? a()) as Any)
    XCTAssertTrue(try a(), message(), file: file, line: line)
}

func recordFalse(_ a: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    note("false", (try? a()) as Any)
    XCTAssertFalse(try a(), message(), file: file, line: line)
}

func recordNil(_ a: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    note("nil", (try? a()) == nil)
    XCTAssertNil(try a(), message(), file: file, line: line)
}

func recordNotNil(_ a: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    note("notnil", (try? a()) != nil)
    XCTAssertNotNil(try a(), message(), file: file, line: line)
}

func recordGreaterThan<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T,
                                      _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    note("gt", (try? a() > b()) as Any)
    XCTAssertGreaterThan(try a(), try b(), message(), file: file, line: line)
}

func recordLessThanOrEqual<T: Comparable>(_ a: @autoclosure () throws -> T, _ b: @autoclosure () throws -> T,
                                          _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
    note("le", (try? a() <= b()) as Any)
    XCTAssertLessThanOrEqual(try a(), try b(), message(), file: file, line: line)
}

func recordThrowsError<T>(_ a: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "",
                          file: StaticString = #filePath, line: UInt = #line, _ handler: (Error) -> Void = { _ in }) {
    XCTAssertThrowsError(try a(), message(), file: file, line: line) { error in
        note("throws", String(describing: error))
        handler(error)
    }
}

enum Fixture {
    static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static func data(_ path: String) throws -> Data {
        try Data(contentsOf: repo.appendingPathComponent(path))
    }
    static func theme() throws -> TokenTheme {
        try TokenTheme(data: data("gestaltung/alfa-interface/tokens.json"))
    }
    static func metrics() throws -> ShellMetrics {
        try ShellMetrics(data: data("alfaos/App/Resources/shell.json"))
    }
    static func directory() throws -> AppDirectory {
        try AppDirectory(data: data("alfaos/App/Resources/apps.json"))
    }
    static func geometry() throws -> ShellGeometry {
        try ShellGeometry(theme: theme(), metrics: metrics())
    }
    static let screen = Size(width: 1512, height: 982)
}

@MainActor
final class DesignTests {
    func runTheShellGeometryReadsTheDeliveredSheet() throws {
        let g = try Fixture.geometry()
        recordEqual(g.laneRest, Design.Size.laneRestWidth)
        recordEqual(g.foldAt, Design.Size.foldThreshold)
        recordEqual(g.blobTop, Design.Size.edge)
        recordEqual(g.strip, Design.Size.edge + Design.Size.blobHeight + Design.Size.gutter)
        recordEqual(g.blobAwakeWidth, Design.Size.blobAwakeWidth)
        recordEqual(g.windowMin.width, 2 * g.margin + 2 * g.gap + g.minimum.reduce(0, +))
        recordEqual(DesignColors.light.ground, RGB(1, 1, 1, 1))
        recordEqual(DesignColors.dark.ground.red, 13.0 / 255.0, accuracy: 0.001)
        recordEqual(CardStack.tops(count: 6), [8, 16, 24, 68, 112, 156])
        recordEqual(CardStack.tops(count: 3), [8, 52, 96])
        recordFalse(DesignStamp.adoptedAt.isEmpty)
    }
}

@MainActor
final class ThemeTests {
    func runRealSourceHasEveryGeneratedKey() throws {
        let theme = try Fixture.theme()
        recordEqual(theme.missing, [])
        recordEqual(theme.missingText, [])
        recordEqual(Set(ThemeKey.all).count, ThemeKey.all.count)
    }
    func runRemovedTokenIsMagentaAndListed() throws {
        let data = try Fixture.data("gestaltung/alfa-interface/tokens.json")
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var color = try XCTUnwrap(root["color"] as? [String: Any])
        var tokens = try XCTUnwrap(color["tokens"] as? [[String: Any]])
        tokens.removeAll { ($0["name"] as? String) == "color-background-container" }
        color["tokens"] = tokens
        root["color"] = color
        let theme = try TokenTheme(data: JSONSerialization.data(withJSONObject: root))
        recordEqual(theme.color(.colorBackgroundContainer, .light), RGB.missing)
        recordEqual(theme.color(.colorBackgroundContainer, .dark), RGB.missing)
        recordEqual(theme.missing, [.colorBackgroundContainer])
    }
    func runValuesParse() throws {
        let theme = try Fixture.theme()
        recordEqual(theme.length(.componentLaneEdge), 16)
        recordEqual(theme.curve(.motionCurveStandard), CubicBezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1))
        let style = try XCTUnwrap(theme.textStyle(.name))
        recordEqual(style.size, 13)
        recordEqual(style.weight, 500)
        recordEqual(style.tracking, 0.065, accuracy: 1e-9)
    }
    func runBrokenAliasesAreMagenta() throws {
        let json = """
        {"color":{"themes":[{"id":"light"}],"tokens":[
        {"name":"a","value":"{b}"},{"name":"b","value":"{a}"},{"name":"c","value":"{nowhere}"},{"name":"d","value":"nonsense"}]},
        "type":{"families":{},"groups":[]}}
        """
        let theme = try TokenTheme(data: Data(json.utf8))
        for name in ["a", "b", "c", "d"] {
            recordEqual(theme.color(ThemeKey(name), .light), RGB.missing, name)
        }
    }
    func runShellMeasuresComeFromTheDataFile() throws {
        let metrics = try Fixture.metrics()
        for key in ShellMeasure.allCases {
            recordGreaterThan(metrics.measure(key), 0, key.rawValue)
        }
    }
    func runMissingMeasureFailsLoading() throws {
        let json = """
        {"measures":{"menu-field-padding":5}}
        """
        recordThrowsError(try ShellMetrics(data: Data(json.utf8)))
    }
}

@MainActor
final class SettingsTests {
    private func catalogKeys() throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("App/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        return Set(strings.keys)
    }
    func runTheSettingsWordsAreInTheCatalogAndTheTokenSheetCarriesItsStamp() throws {
        var keys = SettingsGroup.allCases.map(\.key)
        keys += SettingsSection.allCases.map(\.key)
        keys += AppearanceChoice.allCases.map(\.key)
        keys += SettingsLabel.allCases.map(\.key)
        recordEqual(Set(keys).subtracting(try catalogKeys()).sorted(), [])
        recordEqual(Set(SettingsSection.allCases.map(\.group)), Set(SettingsGroup.allCases))
        for value in [TokenStamp.delivery, TokenStamp.deliveredAt, TokenStamp.adoptedAt, TokenStamp.state] {
            recordFalse(value.isEmpty)
        }
        recordLessThanOrEqual(TokenStamp.deliveredAt, TokenStamp.adoptedAt)
    }
}

@MainActor
final class LayoutTests {
    private func widths(_ window: Double, _ state: LaneState, _ g: ShellGeometry, _ rules: AreaRules) -> [Double] {
        LaneLayout.widths(windowWidth: window, state: state, geometry: g, rules: rules).all
    }
    func runTheLanesFollowTheAccordionOfTheDeliveredShell() throws {
        let g = try Fixture.geometry()
        let rules = AreaRules(minimum: g.minimum)
        let rest = LaneState(rest: g.laneRest)
        let avail = LaneLayout.available(1512, g)
        recordEqual(widths(1512, rest, g, rules), [280, 896, 280])
        for window in [1512.0, 1200, 1024, 800, 640] {
            let w = widths(window, rest, g, rules)
            recordEqual(w.reduce(0, +), LaneLayout.available(window, g), "\(window)")
        }
        recordEqual(widths(700, rest, g, rules)[0], g.laneFolded)
        let foldedLeft = LaneLayout.drag(lane: .leading, proposed: g.foldAt - 1, start: [280, 896, 280], state: rest, geometry: g, rules: rules)
        recordEqual(widths(1512, foldedLeft, g, rules), [56, 1120, 280])
        let bothFolded = LaneLayout.drag(lane: .trailing, proposed: 0, start: [56, 1120, 280], state: foldedLeft, geometry: g, rules: rules)
        recordEqual(widths(1512, bothFolded, g, rules), [56, avail - 112, 56])
        let middleFolded = LaneLayout.toggleFold(lane: .center, state: rest)
        recordEqual(widths(1512, middleFolded, g, rules)[1], g.laneFolded)
        recordEqual(widths(1512, middleFolded, g, rules).reduce(0, +), avail)
        let wide = LaneLayout.drag(lane: .trailing, proposed: 900, start: [280, 896, 280], state: rest, geometry: g, rules: rules)
        recordEqual(widths(1512, wide, g, rules), [56, 500, 900])
        for lane in [Lane.leading, .trailing] {
            let held = LaneLayout.drag(lane: lane, proposed: 150, start: [280, 896, 280], state: rest, geometry: g, rules: AreaRules.rules(for: "mail", geometry: g))
            recordEqual(widths(1512, held, g, rules)[lane.index], 280, lane.rawValue)
        }
        let folded = LaneLayout.toggleFold(lane: .trailing, state: LaneLayout.drag(lane: .trailing, proposed: 240, start: [280, 896, 280], state: rest, geometry: g, rules: rules))
        recordEqual(widths(1512, LaneLayout.toggleFold(lane: .trailing, state: folded), g, rules), [280, 896, 280])
        let maximized = LaneLayout.toggleMaximize(lane: .center, state: rest)
        recordEqual(widths(1512, maximized, g, rules), [56, avail - 112, 56])
        recordNil(LaneLayout.toggleMaximize(lane: .center, state: maximized).maximized)
    }
}

@MainActor
final class BlobTests {
    func runHomeSitsInTheStripAtTheMargin() throws {
        let g = try Fixture.geometry()
        let origin = BlobPlacement.home(geometry: g).origin(window: Fixture.screen, geometry: g)
        recordEqual(origin, Point(x: 16, y: 16))
    }
    func runThrowSettlesAtTheNearestEdge() throws {
        let g = try Fixture.geometry()
        let placement = BlobPlacement.settle(dropAt: Point(x: 1400, y: 500), velocity: Point(x: 0, y: 0), window: Fixture.screen, geometry: g)
        recordEqual(placement.edge, .trailing)
        let thrown = BlobPlacement.settle(dropAt: Point(x: 700, y: 500), velocity: Point(x: -1000, y: 0), window: Fixture.screen, geometry: g)
        recordEqual(thrown.edge, .leading)
    }
    func runMenuOpensBelowAtTheTopAndAboveAtTheBottom() throws {
        let g = try Fixture.geometry()
        let top = BlobPlacement.home(geometry: g).menuOrigin(window: Fixture.screen, geometry: g)
        recordTrue(top.opensDownward)
        recordEqual(top.origin, Point(x: g.margin, y: g.blobTop))
        let bottom = BlobPlacement(edge: .bottom, offset: 16).menuOrigin(window: Fixture.screen, geometry: g)
        recordFalse(bottom.opensDownward)
    }
}

@MainActor
final class ShellModelTests {
    func runDirectoryDrivesTheMenuAndSearch() throws {
        let directory = try Fixture.directory()
        recordEqual(directory.apps.map(\.id), ["mail", "settings"])
        let titles = ["app.mail": "Mail", "app.settings": "Einstellungen", "group.communication": "Kommunikation", "group.core": "Kern"]
        let rows = directory.rows(matching: "stell", title: { titles[$0] ?? $0 })
        recordEqual(rows.map(\.group.id), ["core"])
        recordEqual(directory.rows(matching: "", title: { $0 }).count, 2)
    }
    func runSelectClosesTheMenuAndKeepsLaneStatePerArea() throws {
        let model = ShellModel(directory: try Fixture.directory(), geometry: try Fixture.geometry(), window: Fixture.screen)
        model.toggleMenu()
        recordEqual(model.phase, .menuOpen)
        model.toggleFold(.leading)
        model.select("settings")
        recordEqual(model.phase, .rest)
        recordFalse(model.laneState("settings").folded[0])
        recordTrue(model.laneState("mail").folded[0])
        model.select("nowhere")
        recordEqual(model.currentID, "settings")
    }
    func runAssistantExcludesTheMenuAndSnapshotRoundTrips() throws {
        let g = try Fixture.geometry()
        let model = ShellModel(directory: try Fixture.directory(), geometry: g, window: Fixture.screen)
        model.toggleMenu()
        model.toggleAssistant()
        recordTrue(model.assistantOpen)
        recordFalse(model.menuOpen)
        model.dragLane(.trailing, proposed: 250)
        let data = try JSONEncoder().encode(model.snapshot)
        let restored = ShellModel(directory: try Fixture.directory(), geometry: g, window: Fixture.screen, snapshot: try JSONDecoder().decode(ShellSnapshot.self, from: data))
        recordEqual(restored.laneState("mail").preferred[2], 250)
    }
    private func model(snapshot: ShellSnapshot? = nil) throws -> ShellModel {
        ShellModel(directory: try Fixture.directory(), geometry: try Fixture.geometry(), window: Fixture.screen, snapshot: snapshot)
    }

}

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
        var calls: [String] = []
        var body = MailMessageBody(text: "")
        var attachment = Data("12345".utf8)
    }
    private let state = Locked(State())
    var listFoldersCalls: Int { state.with { $0.listFoldersCalls } }
    var sent: [EmailDraft] { state.with { $0.sent } }
    var calls: [String] { state.with { $0.calls } }
    func setBody(_ body: MailMessageBody) { state.with { $0.body = body } }
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
        return state.with { $0.body }
    }
    func send(_ draft: EmailDraft) async throws {
        if let failure = state.with({ $0.failure }) { throw failure }
        state.with { $0.sent.append(draft) }
    }
    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {
        if let failure = state.with({ $0.failure }) { throw failure }
    }
    private func record(_ call: String) throws {
        let failure = state.with { s -> MailTransportError? in
            s.calls.append(call)
            return s.failure
        }
        if let failure { throw failure }
    }
    func archive(messageID: String) async throws { try record("archive:" + messageID) }
    func move(messageID: String, toFolderID: String) async throws { try record("move:" + messageID + ">" + toFolderID) }
    func trash(messageID: String) async throws { try record("trash:" + messageID) }
    func markSpam(messageID: String) async throws { try record("spam:" + messageID) }
    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data {
        try record("attachment:" + messageID + "/" + attachmentID)
        return state.with { $0.attachment }
    }
    func fetchThread(messageID: String, threadID: String) async throws -> [MailMessageSummary] {
        try record("thread:" + threadID)
        return []
    }
    func saveDraft(_ draft: EmailDraft, replacing draftID: String?) async throws -> String {
        try record("saveDraft")
        return "d1"
    }
    func fetchDraft(messageID: String) async throws -> MailStoredDraft {
        try record("fetchDraft:" + messageID)
        return MailStoredDraft(id: "d1", draft: EmailDraft(subject: "s", body: "b"))
    }
    func deleteDraft(id: String) async throws { try record("deleteDraft:" + id) }
    func sendDraft(id: String) async throws { try record("sendDraft:" + id) }
}

struct FakeCalendar: CalendarPort {}

final class FakeKeychain: KeychainPort, @unchecked Sendable {
    private let entries = Locked<[KeySlot: String]>([:])
    private let failing = Locked(false)
    func setFailing(_ value: Bool) { failing.with { $0 = value } }
    var slots: Set<KeySlot> { entries.with { Set($0.keys) } }
    func put(_ value: String, at slot: KeySlot) throws {
        if failing.with({ $0 }) { throw TestTimedOut() }
        entries.with { $0[slot] = value }
    }
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

@MainActor
struct ScriptedRig {
    let hub: Hub
    let provider: FakeProvider
    let keychain: FakeKeychain
    let cadence: HandCadence
    let database: DatabaseQueue
    static let mailOffer = Offer(id: "fake.mail", provider: "fake", title: "Mail", capabilities: [.mail], owner: .person("p1"), way: .signIn)
    static func make(capabilities: Set<Capability> = [.mail], offer: Offer = ScriptedRig.mailOffer, catalog: PortCatalog = .withMail, database: DatabaseQueue? = nil,
                     provider: FakeProvider? = nil, keychain: FakeKeychain? = nil) throws -> ScriptedRig {
        let provider = provider ?? FakeProvider(capabilities: capabilities)
        let keychain = keychain ?? FakeKeychain()
        let cadence = HandCadence()
        let database = try database ?? DatabaseQueue()
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [offer]), providers: [provider],
            keychain: keychain, cadence: cadence, cost: FakeCost(), catalog: catalog, database: database
        ))
        return ScriptedRig(hub: hub, provider: provider, keychain: keychain, cadence: cadence, database: database)
    }
    func connect(_ address: String, offer: Offer = ScriptedRig.mailOffer) async throws(SetupError) -> Inlet {
        try await hub.setup.add(offer, input: .fields(["address": address]))
    }
}

struct GoogleRig {
    let hub: Hub
    let keychain: FakeKeychain
    let cadence: HandCadence
    let inlet: Inlet
    let clock: Locked<Date>
    let database: DatabaseQueue
    let offer: Offer
    let provider: GoogleProvider
}

struct GivenSignIn: SignInPort {
    let grant: Grant
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { grant }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}

@MainActor
func scriptedGoogleRig(token: @escaping @Sendable () -> (Int, Data), other: @escaping @Sendable (String) -> (Int, Data)? = { _ in nil },
                     expire: Bool = true, start: Date = Date(), advance: TimeInterval = 7200, keychain: FakeKeychain = FakeKeychain()) async throws -> GoogleRig {
    let clock = Locked(start)
    let grant = Grant(values: [
        "accessToken": "old-access", "refreshToken": "old-refresh", "expiresAt": String(clock.with { $0 }.addingTimeInterval(3600).timeIntervalSince1970)
    ])
    GoogleStubNet.install { request in
        let path = request.url?.path ?? ""
        if path.hasSuffix("/token") { return token() }
        if path.hasSuffix("/userinfo") { return (200, Data(#"{"email":"a@example.test"}"#.utf8)) }
        if path.hasSuffix("/labels") { return (200, Data(#"{"labels":[{"id":"INBOX","name":"INBOX","type":"system"}]}"#.utf8)) }
        return other(path) ?? (404, Data())
    }
    let offer = Offer(id: "google.mail", provider: "google", title: "Google", capabilities: [.mail], owner: .person("p1"), way: .signIn)
        let cadence = HandCadence()
    let provider = GoogleProvider(
        config: GoogleClientConfig(clientID: "id", clientSecret: "secret"), openBrowser: { _ in false },
        session: GoogleStubNet.session(), signIn: GivenSignIn(grant: grant), clock: { clock.with { $0 } }
    )
    let database = try DatabaseQueue()
    let hub = try Hub.make(HubConfiguration(
        person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [offer]), providers: [provider],
        keychain: keychain, cadence: cadence, cost: FakeCost(), catalog: .withMail, database: database
    ))
    let inlet = try await hub.setup.add(offer)
    if expire { clock.with { $0 = $0.addingTimeInterval(advance) } }
    return GoogleRig(hub: hub, keychain: keychain, cadence: cadence, inlet: inlet, clock: clock, database: database, offer: offer, provider: provider)
}

final class GoogleStubNet: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) -> (Int, Data)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: Handler?
    nonisolated(unsafe) private static var seen: [URL] = []
    static func install(_ handler: @escaping Handler) {
        lock.withLock {
            self.handler = handler
            seen = []
        }
    }
    static var requests: [URL] { lock.withLock { seen } }
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GoogleStubNet.self]
        return URLSession(configuration: configuration)
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (handler, url) = Self.lock.withLock { () -> (Handler?, URL?) in
            if let url = request.url { Self.seen.append(url) }
            return (Self.handler, request.url)
        }
        let (status, body) = handler?(request) ?? (599, Data())
        let response = HTTPURLResponse(url: url ?? URL(fileURLWithPath: "/"), statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
final class HubTests {
    struct Rig {
        let hub: Hub
        let provider: FakeProvider
        let keychain: FakeKeychain
        let cadence: HandCadence
        let cost: FakeCost
        let person: Person
    }
    static let mailOffer = Offer(id: "fake.mail", provider: "fake", title: "Mail", capabilities: [.mail], owner: .person("p1"), way: .signIn)
    func rig(capabilities: Set<Capability> = [.mail, .calendar], company: CompanySetup? = nil) throws -> Rig {
        let provider = FakeProvider(capabilities: capabilities)
        let keychain = FakeKeychain()
        let cadence = HandCadence()
        let cost = FakeCost()
        let person = Person(id: "p1", name: "P")
        let setup = company ?? CompanySetup(offers: [Self.mailOffer])
        let configuration = HubConfiguration(
            person: person, company: setup, providers: [provider], keychain: keychain, cadence: cadence, cost: cost, catalog: .withMail, database: try DatabaseQueue()
        )
        return Rig(hub: try Hub.make(configuration), provider: provider, keychain: keychain, cadence: cadence, cost: cost, person: person)
    }
    func connect(_ rig: Rig, _ address: String) async throws -> Inlet {
        try await rig.hub.setup.add(Self.mailOffer, input: .fields(["address": address]))
    }
    func runStartsEmptyAndNothingThrows() throws {
        let rig = try rig()
        recordEqual(rig.hub.setup.inlets, [])
        let stock = rig.hub.access.stock(.mailboxes, as: MailboxRecord.self)
        recordEqual(stock.items, [])
        recordEqual(stock.state, .empty)
        recordEqual(rig.hub.access.inlets(for: .mail), [])
        recordTrue(rig.keychain.slots.isEmpty)
    }
    func runRejectedProbeLeavesNothingBehind() async throws {
        let rig = try rig()
        rig.provider.setAccepting(false)
        do {
            _ = try await connect(rig, "a@x")
            XCTFail("add must throw")
        } catch SetupError.probeFailed {
        }
        recordEqual(rig.hub.setup.inlets, [])
        recordTrue(rig.keychain.slots.isEmpty)
    }
    func runAcceptedProbeConnectsAndPortsFollowCapabilities() async throws {
        let rig = try rig(capabilities: [.mail])
        let inlet = try await connect(rig, "a@x")
        guard case .connected = inlet.state else { return XCTFail("state \(inlet.state)") }
        recordEqual(rig.hub.setup.inlets.map(\.id), [inlet.id])
        let transport = try rig.hub.access.port(MailTransport.self, for: inlet.id)
        let folders = try await transport.listFolders()
        recordEqual(folders.map(\.id), ["INBOX"])
        recordEqual(rig.provider.mail.listFoldersCalls, 1)
        recordThrowsError(try rig.hub.access.port(CalendarPort.self, for: inlet.id)) {
            recordEqual($0 as? HubError, .capabilityMissing(inlet.id, .calendar))
        }
    }
    func runFourthMailAccountNeedsALargerLimit() async throws {
        let rig = try rig()
        for address in ["a@x", "b@x", "c@x"] { _ = try await connect(rig, address) }
        do {
            _ = try await connect(rig, "d@x")
            XCTFail("add must throw")
        } catch {
            recordEqual(error as? SetupError, .limitReached(.mail, max: 3))
        }
        recordEqual(rig.hub.setup.inlets.count, 3)
        rig.hub.rules.setLimit(.mail, 5)
        _ = try await connect(rig, "d@x")
        recordEqual(rig.hub.setup.inlets.count, 4)
    }
    func runCadenceRunsOnePairOnceAndCountsTheCall() async throws {
        let rig = try rig()
        let inlet = try await connect(rig, "a@x")
        rig.hub.rules.setCadence(inlet.id, .mail, .every(.seconds(300)))
        recordEqual(rig.cadence.planned(inlet.id, .mail), .every(.seconds(300)))
        let gate = Gate()
        rig.provider.mail.setGate(gate)
        let first = Task { @MainActor in await rig.cadence.trigger(inlet.id, .mail) }
        for _ in 0..<400 where rig.provider.mail.listFoldersCalls == 0 { try await Task.sleep(for: .milliseconds(5)) }
        recordEqual(rig.provider.mail.listFoldersCalls, 1)
        await rig.cadence.trigger(inlet.id, .mail)
        await gate.release()
        await first.value
        recordEqual(rig.provider.mail.listFoldersCalls, 1)
        recordEqual(rig.hub.rules.cost(inlet.id, .all).calls, 1)
        let stock = rig.hub.access.stock(.mailboxes, as: MailboxRecord.self)
        recordEqual(stock.items.map(\.name), ["Inbox"])
        guard case .connected = rig.hub.setup.inlets[0].state else { return XCTFail("state") }
    }
    func runRemoveKeepsTheKeysOfTheOtherInlet() async throws {
        let rig = try rig()
        let a = try await connect(rig, "a@x")
        let b = try await connect(rig, "b@x")
        recordEqual(Set(rig.keychain.slots.map(\.inlet)), [a.id, b.id])
        try await rig.hub.setup.remove(a.id)
        recordEqual(rig.keychain.slots.map(\.inlet), [b.id])
        recordEqual(rig.hub.setup.inlets.map(\.id), [b.id])
        _ = try rig.hub.access.port(MailTransport.self, for: b.id)
    }
    func runRemoveTurnsTheCadenceOfTheInletOff() async throws {
        let rig = try rig(capabilities: [.mail])
        let a = try await connect(rig, "a@x")
        recordNotEqual(rig.cadence.planned(a.id, .mail), .off)
        try await rig.hub.setup.remove(a.id)
        recordEqual(rig.cadence.planned(a.id, .mail), .off)
    }
}

@MainActor
final class SetupFlowTests {
    static let offer = Offer(id: "imap.mail", provider: IMAPProvider.providerID, title: "GMX", capabilities: [.mail], owner: .person("p1"), way: .form([]))
    private func values(_ address: String = "jo@gmx.example") -> [Field.ID: String] {
        var result = IMAPProviderTests.gmx
        result["address"] = address
        result["username"] = address
        return result
    }
    private func attempt(_ hub: Hub, _ address: String) async -> SetupError? {
        let input = Input.fields(values(address))
        do throws(SetupError) {
            _ = try await hub.setup.add(Self.offer, input: input)
            return nil
        } catch {
            return error
        }
    }
    private func makeHub(
        keychain: any KeychainPort = FakeKeychain(), limits: [Capability: Int] = CompanySetup().limits, cadence: HandCadence = HandCadence(), database: DatabaseQueue? = nil,
        providers: [any Provider]? = nil, offers: [Offer]? = nil, deadlines: HubDeadlines = .standard, run: @escaping IMAPProbeRun = { _, _ in }
    ) throws -> Hub {
        let configuration = HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: offers ?? [Self.offer], limits: limits),
            providers: providers ?? [IMAPProvider(probeRun: run)], keychain: keychain, cadence: cadence, cost: FakeCost(), catalog: .withMail, database: try database ?? DatabaseQueue(),
            deadlines: deadlines)
        return try Hub.make(configuration)
    }
    func runCancelDuringTheProbe() async throws {
        let stuck = try makeHub(run: { _, _ in try await Task.sleep(for: .seconds(3600)) })
        let addTask = Task { @MainActor () -> SetupError? in
            do {
                _ = try await stuck.setup.add(Self.offer, input: .fields(values()))
                return nil
            } catch {
                return error as? SetupError
            }
        }
        try await Task.sleep(for: .milliseconds(300))
        addTask.cancel()
        let addError = await addTask.value
        recordEqual(addError, .cancelled)
        let calls = Locked(0)
        let hub = try makeHub(run: { _, _ in
            let number = calls.with { (count: inout Int) -> Int in
                count += 1
                return count
            }
            if number > 1 { try await Task.sleep(for: .seconds(3600)) }
        })
        let inlet = try await hub.setup.add(Self.offer, input: .fields(values()))
        let probeTask = Task { @MainActor in _ = try? await hub.setup.probe(inlet.id) }
        try await Task.sleep(for: .milliseconds(300))
        recordEqual(hub.setup.inlets.first?.state, .connecting)
        probeTask.cancel()
        await probeTask.value
        recordEqual(hub.setup.inlets.first?.state.canRenew, true)
    }
    func runInletOfAMissingProvider() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let accepting = Locked(true)
        let first = try makeHub(keychain: keychain, database: database, run: { _, _ in
            if !accepting.with({ $0 }) { throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO")) }
        })
        let connected = try await first.setup.add(Self.offer, input: .fields(values("jo@gmx.example")))
        let failedOne = try await first.setup.add(Self.offer, input: .fields(values("ka@gmx.example")))
        accepting.with { $0 = false }
        _ = try? await first.setup.probe(failedOne.id)
        accepting.with { $0 = true }
        let restarted = try makeHub(keychain: keychain, database: database, providers: [], offers: [])
        recordEqual(restarted.setup.inlets.first { $0.id == failedOne.id }?.state.canRenew, true)
        recordThrowsError(try restarted.access.port((any MailTransport).self, for: connected.id))
        recordEqual(restarted.setup.inlets.count, 2)
    }
    func runOneCorruptSettingRowStopsTheWholeHub() throws {
        let limitDatabase = try DatabaseQueue()
        _ = try makeHub(database: limitDatabase)
        try limitDatabase.write { db in
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('limit|mail', ?)", arguments: [Data("x".utf8)])
        }
        let cadenceDatabase = try DatabaseQueue()
        _ = try makeHub(database: cadenceDatabase)
        try cadenceDatabase.write { db in
            try db.execute(sql: "INSERT INTO setting (key, value) VALUES ('cadence|x|mail', ?)", arguments: [Data("garbage".utf8)])
        }
    }

}

@MainActor
final class IMAPProviderTests {
    static let gmx: [Field.ID: String] = [
        "address": "jo@gmx.example", "incomingHost": "imap.gmx.net", "incomingPort": "993", "incomingSecurity": "ssl", "outgoingHost": "mail.gmx.net", "outgoingPort": "587",
        "outgoingSecurity": "starttls", "username": "jo@gmx.example", "password": "app-secret"
    ]
    static let offer = Offer(id: "imap.mail", provider: IMAPProvider.providerID, title: "GMX", capabilities: [.mail], owner: .person("p1"), way: .form([]))
    private func probe(_ provider: IMAPProvider, values: [Field.ID: String] = IMAPProviderTests.gmx) async throws -> ProbeResult {
        let inlet = Inlet(id: "imap-1", provider: provider.id, capabilities: [.mail], owner: .person("p1"), title: "GMX")
        let grant = try await provider.signIn.signIn(inlet, input: values)
        return try await provider.probe.probe(inlet, grant)
    }
    func runPresetGMXFillsServerAndPorts() throws {
        let gmx = try XCTUnwrap(IMAPProvider().presets.first { $0.id == "gmx" })
        recordEqual(gmx.values["incomingHost"], "imap.gmx.net")
        recordEqual(gmx.values["incomingPort"], "993")
        recordEqual(gmx.values["incomingSecurity"], "ssl")
        recordEqual(gmx.values["outgoingHost"], "mail.gmx.net")
        recordEqual(gmx.values["outgoingPort"], "587")
        recordEqual(gmx.values["outgoingSecurity"], "starttls")
    }
    func runPresetsWithoutGmailAndOutlook() throws {
        let provider = IMAPProvider()
        recordEqual(provider.presets.map(\.id), ["ionos", "gmx", "webde", "icloud", "fastmail", "generic"])
        recordFalse(provider.presets.contains { $0.id == "gmail" || $0.id == "outlook" })
        let ionos = try XCTUnwrap(provider.presets.first { $0.id == "ionos" })
        recordEqual(ionos.values["incomingHost"], "imap.ionos.de")
        recordEqual(ionos.values["outgoingHost"], "smtp.ionos.de")
        recordEqual(ionos.values["outgoingPort"], "465")
        let fastmail = try XCTUnwrap(provider.presets.first { $0.id == "fastmail" })
        recordEqual(fastmail.values["incomingHost"], "imap.fastmail.com")
        recordEqual(fastmail.values["outgoingHost"], "smtp.fastmail.com")
        recordEqual(provider.presets.last?.values["incomingHost"], nil)
        let ids = Set(provider.form.map(\.id))
        for preset in provider.presets { recordTrue(Set(preset.values.keys).isSubset(of: ids), preset.id) }
        recordEqual(provider.form.filter(\.secret).map(\.id), ["password"])
        recordEqual(provider.capabilities, [.mail])
    }
    func runSignInRejectsNone() async throws {
        let provider = IMAPProvider()
        let inlet = Inlet(id: "i", provider: provider.id, capabilities: [.mail], owner: .company, title: "t")
        for field in ["incomingSecurity", "outgoingSecurity"] {
            var values = Self.gmx
            values[field] = "none"
            do {
                _ = try await provider.signIn.signIn(inlet, input: values)
                XCTFail("plain connection must throw")
            } catch let error as IMAPSetupError {
                recordEqual(error, .insecure(field: field))
            }
        }
    }
    func runSignInChecksPasswordAndPortAndKeepsThePasswordInTheGrant() async throws {
        let provider = IMAPProvider()
        let inlet = Inlet(id: "i", provider: provider.id, capabilities: [.mail], owner: .company, title: "t")
        var values = Self.gmx
        values["password"] = ""
        do {
            _ = try await provider.signIn.signIn(inlet, input: values)
            XCTFail("empty password must throw")
        } catch let error as IMAPSetupError {
            recordEqual(error, .missing("password"))
        }
        values = Self.gmx
        values["incomingPort"] = "99999"
        do {
            _ = try await provider.signIn.signIn(inlet, input: values)
            XCTFail("bad port must throw")
        } catch let error as IMAPSetupError {
            recordEqual(error, .invalidPort(field: "incomingPort", value: "99999"))
        }
        let grant = try await provider.signIn.signIn(inlet, input: Self.gmx)
        recordEqual(grant.values["password"], "app-secret")
        recordEqual(grant.values["outgoingSecurity"], "starttls")
    }
    func runProbeIsGreenWhenTheRunSucceedsAndHandsOverTheAccount() async throws {
        let seen = Locked<[String]>([])
        let provider = IMAPProvider(probeRun: { account, password in
            seen.with { $0 = [account.incoming.host, account.outgoing.host, account.address, password] }
        })
        let result = try await probe(provider)
        recordTrue(result.accepted)
        recordEqual(result.account, "jo@gmx.example")
        recordEqual(seen.with { $0 }, ["imap.gmx.net", "mail.gmx.net", "jo@gmx.example", "app-secret"])
    }
    func runProbeNamesTheServerAnswerOfTheFailedStep() async throws {
        let login = IMAPProvider(probeRun: { _, _ in
            throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO Invalid credentials"))
        })
        let first = try await probe(login).rejection
        recordEqual(first, Hint(text: "hint.imap.login.rejected", detail: "NO Invalid credentials", fixIn: .inlet("imap-1")))
        let auth = IMAPProvider(probeRun: { _, _ in
            throw MailProbeError(step: .outgoing, reason: .authenticationRejected("535 Authentication credentials invalid"))
        })
        let second = try await probe(auth).rejection
        recordEqual(second?.text, "hint.smtp.auth.rejected")
        recordEqual(second?.detail, "535 Authentication credentials invalid")
        let timeout = IMAPProvider(probeRun: { _, _ in throw MailProbeError(step: .incoming, reason: .timeout) })
        let third = try await probe(timeout).rejection
        recordEqual(third?.text, "hint.imap.connection.timeout")
        let other = IMAPProvider(probeRun: { _, _ in throw URLError(.cannotFindHost) })
        let fourth = try await probe(other).rejection
        recordEqual(fourth?.text, "hint.imap.failed")
    }
    func runAdapterDeliversAMailTransportWithoutTouchingTheNetwork() throws {
        let provider = IMAPProvider()
        let inlet = Inlet(id: "i", provider: provider.id, capabilities: [.mail], owner: .company, title: "t")
        let grant = Grant(values: Self.gmx)
        _ = try provider.adapter(MailTransport.self, for: inlet, grant, renewal: .ignoring) as any MailTransport
        recordThrowsError(try provider.adapter((any CalendarPort).self, for: inlet, grant, renewal: .ignoring)) {
            recordEqual($0 as? HubError, .capabilityMissing(inlet.id, .mail))
        }
    }
    private func rig(keychain: FakeKeychain, run: @escaping IMAPProbeRun) throws -> Hub {
        let configuration = HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.offer]),
            providers: [IMAPProvider(probeRun: run)], keychain: keychain, cadence: HandCadence(), cost: FakeCost(), catalog: .withMail, database: try DatabaseQueue())
        return try Hub.make(configuration)
    }
    func runHubStoresThePasswordInTheKeychainAfterAGreenProbe() async throws {
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain, run: { _, _ in })
        let inlet = try await hub.setup.add(Self.offer, input: .fields(Self.gmx))
        guard case .connected = inlet.state else { return XCTFail("state \(inlet.state)") }
        recordEqual(try keychain.get(KeySlot(inlet: inlet.id, name: "password")), "app-secret")
        _ = try hub.access.port(MailTransport.self, for: inlet.id)
    }
    func runHubKeepsNothingAfterARedProbe() async throws {
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain, run: { _, _ in
            throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO x"))
        })
        do {
            _ = try await hub.setup.add(Self.offer, input: .fields(Self.gmx))
            XCTFail("add must throw")
        } catch SetupError.probeFailed(let hint) {
            recordEqual(hint.text, "hint.imap.login.rejected")
        }
        recordEqual(hub.setup.inlets, [])
        recordTrue(keychain.slots.isEmpty)
    }
    func runSenderNameOfTheTransportIsTheFormValue() async throws {
        var values = Self.gmx
        values["name"] = "Jo Berger"
        var catalog = PortCatalog.standard
        catalog.register((any MailTransport).self, capability: .mail)
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.offer]),
            providers: [IMAPProvider(probeRun: { _, _ in })], keychain: FakeKeychain(), cadence: HandCadence(), cost: FakeCost(), catalog: catalog, database: try DatabaseQueue()))
        let inlet = try await hub.setup.add(Self.offer, input: .fields(values))
        let transport = try hub.access.port((any MailTransport).self, for: inlet.id)
        let name = (transport as? IMAPSMTPMailTransport)?.account.displayName
        recordEqual(name, "Jo Berger")
    }
    func runAddressWithInnerSpaceIsRejected() {
        var input = Self.gmx
        input["address"] = "jo @gmx.example"
        recordNil(try? IMAPConnection(values: input))
    }
}

@MainActor
final class GoogleProviderTests {
    static let offer = Offer(id: "google.mail", provider: "google", title: "Google", capabilities: [.mail], owner: .person("p1"), way: .signIn)
    static let grant = Grant(values: [
        "accessToken": "stub-access", "refreshToken": "stub-refresh", "expiresAt": String(Date().addingTimeInterval(3600).timeIntervalSince1970)
    ])
    func rig(keychain: FakeKeychain) throws -> Hub {
        let provider = GoogleProvider(
            config: GoogleClientConfig(clientID: "id", clientSecret: "secret"), openBrowser: { _ in false }, session: GoogleStubNet.session(), signIn: GivenSignIn(grant: Self.grant)
        )
        let configuration = HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.offer]), providers: [provider], keychain: keychain, cadence: HandCadence(), cost: FakeCost(),
            catalog: .withMail, database: try DatabaseQueue()
        )
        return try Hub.make(configuration)
    }
    func runGoogleProviderDeliversMailTransportAfterGreenProbe() async throws {
        GoogleStubNet.install { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/userinfo") {
                return (200, Data(#"{"email":"a@example.test","name":"A"}"#.utf8))
            }
            if path.hasSuffix("/labels") {
                return (200, Data(#"{"labels":[{"id":"INBOX","name":"INBOX","type":"system"},{"id":"Label_1","name":"Kunden","type":"user"},{"id":"Label_2","name":"Archiv","type":"user"}]}"#.utf8))
            }
            return (404, Data())
        }
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain)
        let inlet = try await hub.setup.add(Self.offer)
        guard case .connected = inlet.state else { return XCTFail("state \(inlet.state)") }
        recordEqual(inlet.account, "a@example.test")
        let transport = try hub.access.port(MailTransport.self, for: inlet.id)
        let folders = try await transport.listFolders()
        recordEqual(folders.first?.role, .inbox)
        recordEqual(folders.filter { $0.role == .other }.map(\.id), ["Label_2", "Label_1"])
        recordEqual(folders.filter { $0.role == .other }.map(\.name), ["Archiv", "Kunden"])
        recordThrowsError(try hub.access.port(CalendarPort.self, for: inlet.id)) {
            recordEqual($0 as? HubError, .capabilityMissing(inlet.id, .calendar))
        }
    }
    func runRedProbeFailsAndLeavesNothingInTheKeychain() async throws {
        GoogleStubNet.install { _ in (401, Data()) }
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain)
        do {
            _ = try await hub.setup.add(Self.offer)
            XCTFail("add must throw")
        } catch SetupError.probeFailed(let hint) {
            recordEqual(hint.text, "hint.google.userinfo")
            recordEqual(hint.detail, "HTTP 401")
        }
        recordEqual(hub.setup.inlets, [])
        recordTrue(keychain.slots.isEmpty)
    }
    func runRedLabelsProbeNamesTheStatus() async throws {
        GoogleStubNet.install { request in
            if request.url?.path.hasSuffix("/userinfo") == true {
                return (200, Data(#"{"email":"a@example.test"}"#.utf8))
            }
            return (403, Data())
        }
        let keychain = FakeKeychain()
        let hub = try rig(keychain: keychain)
        do {
            _ = try await hub.setup.add(Self.offer)
            XCTFail("add must throw")
        } catch SetupError.probeFailed(let hint) {
            recordEqual(hint.text, "hint.google.labels")
            recordEqual(hint.detail, "HTTP 403")
        }
        recordTrue(keychain.slots.isEmpty)
    }
    func runClientConfigLoadsFromFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        recordThrowsError(try GoogleClientConfig.load(from: folder))
        try Data(#"{"clientID":"cid","clientSecret":"sec"}"#.utf8)
            .write(to: folder.appendingPathComponent(GoogleClientConfig.fileName))
        recordEqual(try GoogleClientConfig.load(from: folder), GoogleClientConfig(clientID: "cid", clientSecret: "sec"))
    }

}

@MainActor
final class GoogleRenewalTests {
    static let offer = Offer(id: "google.mail", provider: "google", title: "Google", capabilities: [.mail], owner: .person("p1"), way: .signIn)
    struct Rig {
        let hub: Hub
        let keychain: FakeKeychain
        let inlet: Inlet
        let clock: Locked<Date>
        let events: Locked<[HubEvent]>
        let collector: Task<Void, Never>
    }
    func rig(refresh: @escaping @Sendable () -> (Int, Data)) async throws -> Rig {
        let clock = Locked(Date())
        let grant = Grant(values: [
            "accessToken": "old-access", "refreshToken": "old-refresh", "expiresAt": String(clock.with { $0 }.addingTimeInterval(3600).timeIntervalSince1970)
        ])
        GoogleStubNet.install { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/token") { return refresh() }
            if path.hasSuffix("/userinfo") { return (200, Data(#"{"email":"a@example.test"}"#.utf8)) }
            if path.hasSuffix("/labels") { return (200, Data(#"{"labels":[{"id":"INBOX","name":"INBOX","type":"system"}]}"#.utf8)) }
            return (404, Data())
        }
        let keychain = FakeKeychain()
        let provider = GoogleProvider(
            config: GoogleClientConfig(clientID: "id", clientSecret: "secret"), openBrowser: { _ in false }, session: GoogleStubNet.session(), signIn: GivenSignIn(grant: grant),
            clock: { clock.with { $0 } }
        )
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.offer]), providers: [provider], keychain: keychain, cadence: HandCadence(), cost: FakeCost(),
            catalog: .withMail, database: try DatabaseQueue()
        ))
        let inlet = try await hub.setup.add(Self.offer)
        let events = Locked<[HubEvent]>([])
        let stream = hub.access.events
        let collector = Task { for await event in stream { events.with { $0.append(event) } } }
        clock.with { $0 = $0.addingTimeInterval(7200) }
        return Rig(hub: hub, keychain: keychain, inlet: inlet, clock: clock, events: events, collector: collector)
    }
    func waitUntil(_ condition: @escaping () -> Bool) async throws {
        var attempts = 0
        while attempts < 400 {
            if condition() { break }
            try await Task.sleep(for: .milliseconds(5))
            attempts += 1
        }
        let reached = condition()
        recordTrue(reached)
    }
    func runGreenRenewalWritesTheNewGrantIntoTheSlotsOfThisInlet() async throws {
        let rig = try await rig { (200, Data(#"{"access_token":"new-access","expires_in":3600}"#.utf8)) }
        defer { rig.collector.cancel() }
        let slot = KeySlot(inlet: rig.inlet.id, name: "accessToken")
        recordEqual(try rig.keychain.get(slot), "old-access")
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        _ = try await transport.listFolders()
        try await waitUntil { (try? rig.keychain.get(slot)) == "new-access" }
        recordEqual(try rig.keychain.get(KeySlot(inlet: rig.inlet.id, name: "refreshToken")), "old-refresh")
        recordEqual(Set(rig.keychain.slots.map(\.inlet)), [rig.inlet.id])
        try await waitUntil { rig.events.with { $0.contains(.inletChanged(rig.inlet.id)) } }
        guard case .connected = rig.hub.setup.inlets[0].state else { return XCTFail("state") }
    }
    func runRedRenewalMarksTheInletExpiredAndPortThrows() async throws {
        let rig = try await rig { (400, Data()) }
        defer { rig.collector.cancel() }
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        do {
            _ = try await transport.listFolders()
            XCTFail("listFolders must throw")
        } catch {
        }
        try await waitUntil {
            if case .failed(let hint) = rig.hub.setup.inlets[0].state { return hint.text == "hint.signin.expired" }
            return false
        }
        try await waitUntil { rig.events.with { $0.contains(.inletChanged(rig.inlet.id)) } }
        recordThrowsError(try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)) {
            recordEqual($0 as? HubError, .notConnected(rig.inlet.id))
        }
    }
    func runServerOutageDuringRenewalKeepsTheInletConnected() async throws {
        let rig = try await rig { (503, Data()) }
        defer { rig.collector.cancel() }
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        do {
            _ = try await transport.listFolders()
            XCTFail("listFolders must throw")
        } catch {
        }
        try await Task.sleep(for: .milliseconds(50))
        guard case .connected = rig.hub.setup.inlets[0].state else { return XCTFail("state \(rig.hub.setup.inlets[0].state)") }
        recordEqual(try rig.keychain.get(KeySlot(inlet: rig.inlet.id, name: "accessToken")), "old-access")
        _ = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
    }
    func runSyncAfterServerOutageOnRenewalKeepsTheInletConnected() async throws {
        let rig = try await scriptedGoogleRig(token: { (503, Data()) })
        await rig.cadence.trigger(rig.inlet.id, .mail)
        let state = rig.hub.setup.inlets[0].state
        guard case .connected = state else { return XCTFail("state \(state)") }
    }

}

@MainActor
final class RenewTests {
    struct Rig {
        let hub: Hub
        let provider: FakeProvider
        let keychain: FakeKeychain
    }
    static let mailOffer = Offer(id: "fake.mail", provider: "fake", title: "Mail", capabilities: [.mail], owner: .person("p1"), way: .signIn)
    func rig(capabilities: Set<Capability>) throws -> Rig {
        let provider = FakeProvider(capabilities: capabilities)
        let keychain = FakeKeychain()
        let configuration = HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [Self.mailOffer]), providers: [provider],
            keychain: keychain, cadence: HandCadence(), cost: FakeCost(), catalog: .withMail, database: try DatabaseQueue()
        )
        return Rig(hub: try Hub.make(configuration), provider: provider, keychain: keychain)
    }
    func connect(_ rig: Rig, _ address: String) async throws -> Inlet {
        try await rig.hub.setup.add(Self.mailOffer, input: .fields(["address": address]))
    }
    func runFailedInletIsRenewedInPlace() async throws {
        let rig = try rig(capabilities: [.mail])
        let first = try await connect(rig, "a@x")
        rig.provider.setAccepting(false)
        do {
            _ = try await rig.hub.setup.probe(first.id)
            XCTFail("probe must throw")
        } catch SetupError.probeFailed {
        }
        recordTrue(rig.hub.setup.inlets[0].state.canRenew)
        recordEqual(rig.hub.setup.renewal(of: first.id)?.offer, Self.mailOffer)
        rig.provider.setAccepting(true)
        let renewed = try await connect(rig, "a@x")
        recordEqual(renewed.id, first.id)
        recordEqual(rig.hub.setup.inlets.map(\.id), [first.id])
        recordNotNil(rig.hub.setup.inlets[0].state.probed)
        recordEqual(rig.keychain.slots.map(\.inlet), [first.id])
        recordNil(rig.hub.setup.renewal(of: first.id))
        _ = try rig.hub.access.port(MailTransport.self, for: first.id)
    }
    func runConnectedInletStillRefusesTheSameAccount() async throws {
        let rig = try rig(capabilities: [.mail])
        _ = try await connect(rig, "a@x")
        do {
            _ = try await connect(rig, "a@x")
            XCTFail("add must throw")
        } catch {
            recordEqual(error as? SetupError, .duplicate)
        }
        recordEqual(rig.hub.setup.inlets.count, 1)
    }
}

@MainActor
final class FailureTests {
    private let google = GoogleProvider(config: GoogleClientConfig(clientID: "id", clientSecret: ""), openBrowser: { _ in false })
    func runGmailKeepsStatusReasonTextAndBody() {
        let body = Data(#"{"error":{"code":403,"message":"User-rate limit exceeded.","errors":[{"domain":"usageLimits","reason":"userRateLimitExceeded","message":"User-rate limit exceeded."}],"status":"PERMISSION_DENIED"}}"#.utf8)
        let result = google.classify(GoogleGmailError.api(GoogleAPIFault(status: 403, data: body)))
        recordEqual(result.kind, .transient)
        recordEqual(result.original.provider, "gmail")
        recordEqual(result.original.status, 403)
        recordEqual(result.original.code, "userRateLimitExceeded")
        recordEqual(result.original.text, "User-rate limit exceeded.")
        recordEqual(result.original.extra["domain"], "usageLimits")
        recordEqual(result.original.extra["state"], "PERMISSION_DENIED")
        recordEqual(result.original.body, String(decoding: body, as: UTF8.self))
        let hint = Hint(text: "hint.provider.transient", classification: result)
        recordEqual(hint.code, "gmail.403.userRateLimitExceeded")
        recordEqual(hint.codeKey, "hint.code.gmail.403.userRateLimitExceeded")
        recordEqual(hint.detail, "User-rate limit exceeded.")
    }
    func runGmailTableOfTheGoogleErrorPage() {
        func kind(_ status: Int, _ reason: String?) -> FailureKind {
            google.classify(GoogleGmailError.api(GoogleAPIFault(status: status, reason: reason))).kind
        }
        recordEqual(kind(403, "rateLimitExceeded"), .transient)
        recordEqual(kind(403, "dailyLimitExceeded"), .rejected)
        recordEqual(kind(429, nil), .transient)
        recordEqual(kind(500, "backendError"), .transient)
        recordEqual(kind(503, nil), .transient)
        recordEqual(kind(401, "authError"), .signIn)
        recordEqual(kind(404, "notFound"), .rejected)
    }
    func runOAuthKeepsErrorAndDescription() {
        let body = Data(#"{"error":"invalid_grant","error_description":"Token has been expired or revoked."}"#.utf8)
        let result = google.classify(GoogleOAuthError.api(GoogleAPIFault(status: 400, data: body)))
        recordEqual(result.kind, .signIn)
        recordEqual(result.original.provider, "oauth")
        recordEqual(result.original.status, 400)
        recordEqual(result.original.code, "invalid_grant")
        recordEqual(result.original.text, "Token has been expired or revoked.")
        recordEqual(result.original.label, "oauth.400.invalid_grant")
        recordEqual(google.classify(GoogleOAuthError.api(GoogleAPIFault(status: 400, reason: "invalid_request"))).kind, .rejected)
        recordEqual(google.classify(GoogleOAuthError.api(GoogleAPIFault(status: 503))).kind, .transient)
    }
    func runImapKeepsResponseCodeAndServerText() {
        let imap = IMAPProvider()
        let denied = imap.classify(MailTransportError.authenticationRejected("NO [AUTHENTICATIONFAILED] Invalid credentials"))
        recordEqual(denied.kind, .signIn)
        recordEqual(denied.original.provider, "imap")
        recordEqual(denied.original.code, "AUTHENTICATIONFAILED")
        recordEqual(denied.original.text, "NO [AUTHENTICATIONFAILED] Invalid credentials")
        recordEqual(denied.original.extra["status"], "NO")
        let down = imap.classify(MailTransportError.serverRejected("NO [UNAVAILABLE] Maintenance"))
        recordEqual(down.kind, .transient)
        recordEqual(down.original.code, "UNAVAILABLE")
        recordEqual(down.original.text, "NO [UNAVAILABLE] Maintenance")
        recordEqual(imap.classify(MailTransportError.serverRejected("BAD Command unknown")).kind, .rejected)
    }
    func runSmtpKeepsReplyCodeEnhancedCodeAndText() {
        let imap = IMAPProvider()
        let auth = imap.classify(MailTransportError.authenticationRejected("535 5.7.8 Authentication credentials invalid"))
        recordEqual(auth.kind, .signIn)
        recordEqual(auth.original.provider, "smtp")
        recordEqual(auth.original.status, 535)
        recordEqual(auth.original.code, "5.7.8")
        recordEqual(auth.original.text, "535 5.7.8 Authentication credentials invalid")
        let later = imap.classify(MailTransportError.smtpRejected(451, "4.3.0 Try again later"))
        recordEqual(later.kind, .transient)
        recordEqual(later.original.code, "4.3.0")
        recordEqual(later.original.text, "4.3.0 Try again later")
        let relay = imap.classify(MailTransportError.recipientRejected("a@x.test", 550, "5.7.1 Relay denied"))
        recordEqual(relay.kind, .rejected)
        recordEqual(relay.original.extra["recipient"], "a@x.test")
        recordEqual(relay.original.status, 550)
    }
    func runHealthFollowsTheDocumentedCases() async throws {
        let rig = try ScriptedRig.make()
        let inlet = try await rig.connect("a@x")
        recordEqual(rig.hub.setup.health(of: inlet.id), .online)
        rig.provider.mail.setFailure(.serverRejected("NO [UNAVAILABLE] Maintenance"))
        await rig.cadence.trigger(inlet.id, .mail)
        recordEqual(rig.hub.setup.health(of: inlet.id), .limited)
        recordEqual(rig.hub.access.health(of: inlet.id), .limited)
        recordTrue(rig.hub.setup.inlets[0].state.isConnected)
        rig.provider.mail.setFailure(nil)
        await rig.cadence.trigger(inlet.id, .mail)
        recordEqual(rig.hub.setup.health(of: inlet.id), .online)
        rig.provider.mail.setFailure(.authenticationRejected("NO [AUTHENTICATIONFAILED] Invalid credentials"))
        await rig.cadence.trigger(inlet.id, .mail)
        recordEqual(rig.hub.setup.health(of: inlet.id), .failed)
        let state = rig.hub.setup.inlets[0].state
        recordEqual(state.hint?.text, "hint.signin.expired")
        recordEqual(state.hint?.original?.code, "AUTHENTICATIONFAILED")
    }
    func runReportKeepsTheOriginalAcrossARestart() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let rig = try ScriptedRig.make(database: database, keychain: keychain)
        let inlet = try await rig.connect("a@x")
        rig.provider.mail.setFailure(.smtpRejected(451, "4.3.0 Try again later"))
        await rig.cadence.trigger(inlet.id, .mail)
        let again = try ScriptedRig.make(database: database, provider: rig.provider, keychain: keychain)
        let entry = try XCTUnwrap(again.hub.setup.report(for: inlet.id).first)
        recordEqual(entry.event, .sync)
        recordEqual(entry.capability, .mail)
        recordFalse(entry.ok)
        recordEqual(entry.kind, .transient)
        recordEqual(entry.original?.code, "4.3.0")
        recordEqual(entry.original?.status, 451)
        recordEqual(entry.original?.text, "4.3.0 Try again later")
        recordEqual(again.hub.setup.health(of: inlet.id), .limited)
        let stored = again.hub.setup.inlets[0].state
        recordTrue(stored.isConnected)
    }
    func runReportIsLimitedPerInlet() async throws {
        let provider = FakeProvider(capabilities: [.mail])
        let cadence = HandCadence()
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [ScriptedRig.mailOffer]),
            providers: [provider], keychain: FakeKeychain(), cadence: cadence, cost: FakeCost(), catalog: .withMail, database: try DatabaseQueue(), reportLimit: 3))
        let inlet = try await hub.setup.add(ScriptedRig.mailOffer, input: .fields(["address": "a@x"]))
        for number in 1...5 {
            provider.mail.setFailure(.smtpRejected(450, "4.2.0 Attempt \(number)"))
            await cadence.trigger(inlet.id, .mail)
        }
        let entries = hub.setup.report(for: inlet.id)
        recordEqual(entries.count, 3)
        recordEqual(entries.map { $0.original?.text }, ["4.2.0 Attempt 5", "4.2.0 Attempt 4", "4.2.0 Attempt 3"])
    }
    func runSignInDeadlineEndsWithTheSignInTimeout() async throws {
        let stuck = StuckSignIn()
        let provider = FakeProvider(capabilities: [.mail], signIn: stuck)
        let hub = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [ScriptedRig.mailOffer]),
            providers: [provider], keychain: FakeKeychain(), cadence: HandCadence(), cost: FakeCost(), catalog: .withMail, database: try DatabaseQueue(),
            deadlines: HubDeadlines(signIn: .milliseconds(200), probe: .seconds(5))))
        let outcome = try await within(.seconds(3)) { () -> SetupError? in
            do throws(SetupError) {
                _ = try await hub.setup.add(ScriptedRig.mailOffer, input: .none)
                return nil
            } catch {
                return error
            }
        }
        guard case .probeFailed(let hint)? = outcome else { return XCTFail("add must fail, got \(String(describing: outcome))") }
        recordEqual(hint.text, "hint.signin.timeout")
        recordEqual(hub.setup.inlets, [])
    }
}

private struct StuckSignIn: SignInPort {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant {
        try await Task.sleep(for: .seconds(3600))
        return Grant(values: [:])
    }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}

private actor Ticker {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private(set) var requested: [Duration] = []
    var waiters: Int { waiting.count }
    func sleep(_ duration: Duration) async {
        requested.append(duration)
        await withCheckedContinuation { waiting.append($0) }
    }
    func tick() {
        let current = waiting
        waiting = []
        current.forEach { $0.resume() }
    }
}

private actor Counter {
    private(set) var calls = 0
    private var gate: CheckedContinuation<Void, Never>?
    private var blocking = false
    func block() { blocking = true }
    func run() async {
        calls += 1
        guard blocking else { return }
        blocking = false
        await withCheckedContinuation { gate = $0 }
    }
    func release() {
        gate?.resume()
        gate = nil
    }
}

@MainActor
final class AdapterTimerTests {
    private func until(_ condition: @Sendable () async -> Bool) async -> Bool {
        for _ in 0..<400 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return await condition()
    }
    func runIntervalTriggersExactlyOnceAfterTheTick() async throws {
        let ticker = Ticker()
        let counter = Counter()
        let cadence = TimerCadence(sleep: { await ticker.sleep($0) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .finished(items: 0))
        }
        cadence.plan("i1", .mail, .every(.seconds(300)))
        let armed = await until { await ticker.waiters == 1 }
        recordTrue(armed)
        let requested = await ticker.requested
        recordEqual(requested, [.seconds(300)])
        let before = await counter.calls
        recordEqual(before, 0)
        await ticker.tick()
        let fired = await until { await counter.calls == 1 }
        recordTrue(fired)
        let rearmed = await until { await ticker.waiters == 1 }
        recordTrue(rearmed)
        try await Task.sleep(for: .milliseconds(30))
        let after = await counter.calls
        recordEqual(after, 1)
        cadence.plan("i1", .mail, .off)
    }
    func runSecondTriggerDuringARunIsSkipped() async throws {
        let counter = Counter()
        await counter.block()
        let cadence = TimerCadence(sleep: { _ in try await Task.sleep(for: .seconds(3600)) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .finished(items: 0))
        }
        let first = Task { await cadence.trigger("i1", .mail) }
        let started = await until { await counter.calls == 1 }
        recordTrue(started)
        await cadence.trigger("i1", .mail)
        let during = await counter.calls
        recordEqual(during, 1)
        await cadence.trigger("i2", .mail)
        let other = await until { await counter.calls == 2 }
        recordTrue(other)
        await counter.release()
        await first.value
        await cadence.trigger("i1", .mail)
        let again = await counter.calls
        recordEqual(again, 3)
    }
    func runReplanningWithOffStopsTheTimer() async throws {
        let ticker = Ticker()
        let counter = Counter()
        let cadence = TimerCadence(sleep: { await ticker.sleep($0) })
        cadence.attach { inlet, capability in
            await counter.run()
            return SyncReport(inlet: inlet, capability: capability, result: .skipped)
        }
        cadence.plan("i1", .mail, .every(.seconds(10)))
        _ = await until { await ticker.waiters == 1 }
        cadence.plan("i1", .mail, .manual)
        await ticker.tick()
        try await Task.sleep(for: .milliseconds(30))
        let calls = await counter.calls
        recordEqual(calls, 0)
    }
}

@MainActor
final class AdapterCostTests {
    private func date(_ day: Int, hour: Int = 12) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day * 86_400 + hour * 3_600))
    }
    func runSumsPerDayAndInlet() throws {
        let cost = try CountingCost(try HubDatabase.inMemory())
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1, bytes: 10), at: date(100, hour: 1)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 2, bytes: 5, tokens: 3), at: date(100, hour: 23)))
        cost.book(CostItem(inlet: "a", capability: .calendar, cost: Cost(calls: 4), at: date(100)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 8), at: date(101)))
        cost.book(CostItem(inlet: "b", capability: .mail, cost: Cost(calls: 16), at: date(100)))
        let dayOne = Period(from: date(100, hour: 0), to: date(100, hour: 23))
        recordEqual(cost.sum("a", dayOne), Cost(calls: 7, bytes: 15, tokens: 3))
        recordEqual(cost.sum("a", Period(from: date(101, hour: 0), to: date(101, hour: 23))), Cost(calls: 8))
        recordEqual(cost.sum("a", .all), Cost(calls: 15, bytes: 15, tokens: 3))
        recordEqual(cost.sum("b", .all), Cost(calls: 16))
        recordEqual(cost.sum("none", .all), .zero)
    }
    func runRowsAreKeptPerInletCapabilityAndDay() throws {
        let database = try HubDatabase.inMemory()
        let cost = try CountingCost(database)
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1), at: date(5)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1), at: date(5, hour: 3)))
        cost.book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 1), at: date(6)))
        cost.book(CostItem(inlet: "a", capability: .files, cost: Cost(calls: 1), at: date(6)))
        let rows = try database.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM cost_day") }
        recordEqual(rows, 3)
    }
    func runSurvivesReopeningTheSameDatabase() throws {
        let database = try HubDatabase.inMemory()
        try CountingCost(database).book(CostItem(inlet: "a", capability: .mail, cost: Cost(calls: 2), at: date(7)))
        recordEqual(try CountingCost(database).sum("a", .all), Cost(calls: 2))
    }
}

@MainActor
final class AdapterKeychainTests {
    func runServiceNameFollowsPrefixAndInlet() {
        let slot = KeySlot(inlet: "imap-123", name: "password")
        recordEqual(KeychainAdapter.service(for: slot, prefix: "p."), "p.hub.imap-123")
        recordEqual(KeychainAdapter.account(for: slot), "password")
    }
    func runSlotsOfOneInletShareTheServiceAndDifferInAccount() {
        let a = KeySlot(inlet: "x", name: "a"), b = KeySlot(inlet: "x", name: "b")
        recordEqual(KeychainAdapter.service(for: a), KeychainAdapter.service(for: b))
        recordNotEqual(KeychainAdapter.account(for: a), KeychainAdapter.account(for: b))
        recordNotEqual(KeychainAdapter.service(for: a), KeychainAdapter.service(for: KeySlot(inlet: "y", name: "a")))
    }
}

@MainActor
final class ScriptedGate {
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false
    var hasWaiter: Bool { !waiting.isEmpty }
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiting.append($0) }
    }
    func release() {
        isOpen = true
        let all = waiting
        waiting = []
        for continuation in all { continuation.resume() }
    }
}

@MainActor
final class ScriptedEngine: MailEngine {
    var accounts: [Inlet] = []
    var folderList: [String: [MailFolder]] = [:]
    var pendingFolders: [String: [MailFolder]] = [:]
    var pages: [String: MailMessagePage] = [:]
    var pageGates: [String: ScriptedGate] = [:]
    var folderGates: [String: ScriptedGate] = [:]
    var pageCalls: [String] = []
    var flagCalls: [String] = []
    var bodyError: HubError?
    var outbox: [OutboxItem] = []
    let events: AsyncStream<MailEngineEvent>
    let feed: AsyncStream<MailEngineEvent>.Continuation
    init() {
        (events, feed) = AsyncStream<MailEngineEvent>.makeStream()
    }
    static func key(_ inlet: String, _ folder: String, _ token: String?) -> String {
        inlet + "|" + folder + "|" + (token ?? "-")
    }
    func folders(_ inlet: Inlet.ID) -> [MailFolder] { folderList[inlet] ?? [] }
    func refreshFolders(_ inlet: Inlet.ID) async throws(HubError) {
        if let gate = folderGates[inlet] { await gate.wait() }
        if let pending = pendingFolders[inlet] { folderList[inlet] = pending }
    }
    func messages(_ inlet: Inlet.ID, folder: String) -> [MailMessageSummary] { [] }
    func lastSync(_ inlet: Inlet.ID, folder: String) -> Date? { nil }
    func loadPage(_ inlet: Inlet.ID, folder: String, query: String?, pageToken: String?) async throws(HubError)
        -> MailMessagePage {
        let key = Self.key(inlet, folder, pageToken)
        pageCalls.append(key)
        if let gate = pageGates[key] { await gate.wait() }
        return pages[key] ?? MailMessagePage(messages: [])
    }
    func searchLocal(_ inlet: Inlet.ID, query: String) -> [MailMessageSummary] { [] }
    func body(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailMessageBody {
        if let bodyError { throw bodyError }
        return MailMessageBody(text: "text of " + messageID)
    }
    func setFlags(_ inlet: Inlet.ID, messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>)
        async throws(HubError) {
        flagCalls.append(messageID + "+" + add.map(\.rawValue).sorted().joined(separator: ","))
    }
    func archive(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {}
    func move(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubError) {}
    func trash(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {}
    func markSpam(_ inlet: Inlet.ID, messageID: String) async throws(HubError) {}
    func attachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String) async throws(HubError) -> Data { Data() }
    func thread(_ inlet: Inlet.ID, messageID: String, threadID: String) async throws(HubError) -> [MailMessageSummary] { [] }
    func saveDraft(_ inlet: Inlet.ID, _ draft: EmailDraft, replacing draftID: String?) async throws(HubError) -> String { "" }
    func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailStoredDraft {
        MailStoredDraft(id: "", draft: EmailDraft(subject: "", body: ""))
    }
    func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubError) {}
    func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: EmailDraft) async -> SendOutcome { .sent }
    func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome { .sent }
    func retryOutbox() async {}
    func unreadCount(_ inlet: Inlet.ID) -> Int { 0 }
}

let scriptedInbox = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]

final class TransportDouble: MailTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _folders: [MailFolder] = []
    private var _pages: [String: MailMessagePage] = [:]
    private var _tokenPages: [String: MailMessagePage] = [:]
    private var _failures: [Int: Error] = [:]
    private var _sendError: Error?
    private var _listError: Error?
    private var _sent: [EmailDraft] = []
    private var _sendCalls = 0
    private var _listCalls = 0
    var folders: [MailFolder] { get { lock.withLock { _folders } } set { lock.withLock { _folders = newValue } } }
    var sendError: Error? { get { lock.withLock { _sendError } } set { lock.withLock { _sendError = newValue } } }
    var listError: Error? { get { lock.withLock { _listError } } set { lock.withLock { _listError = newValue } } }
    var sent: [EmailDraft] { lock.withLock { _sent } }
    var sendCalls: Int { lock.withLock { _sendCalls } }
    func setPage(_ folder: String, _ page: MailMessagePage) { lock.withLock { _pages[folder] = page } }
    func setTokenPage(_ token: String?, _ page: MailMessagePage) { lock.withLock { _tokenPages[token ?? "-"] = page } }
    func failList(call: Int, _ error: Error) { lock.withLock { _failures[call] = error } }
    func listFolders() async throws -> [MailFolder] {
        if let error = listError { throw error }
        return folders
    }
    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MailMessagePage {
        if let error = listError { throw error }
        let (failure, page) = lock.withLock { () -> (Error?, MailMessagePage?) in
            _listCalls += 1
            return (_failures[_listCalls], _pages[folderID] ?? _tokenPages[pageToken ?? "-"])
        }
        if let failure { throw failure }
        return page ?? MailMessagePage(messages: [])
    }
    func fetchBody(messageID: String) async throws -> MailMessageBody { MailMessageBody(text: "body") }
    func send(_ draft: EmailDraft) async throws {
        lock.withLock { _sendCalls += 1 }
        if let error = sendError { throw error }
        lock.withLock { _sent.append(draft) }
    }
    func setFlags(messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>) async throws {}
    private var _calls: [String] = []
    private var _actionError: Error?
    private var _attachment = Data()
    private var _thread: [MailMessageSummary] = []
    private var _stored: MailStoredDraft?
    private var _savedID = "draft-1"
    var calls: [String] { lock.withLock { _calls } }
    var actionError: Error? { get { lock.withLock { _actionError } } set { lock.withLock { _actionError = newValue } } }
    var attachment: Data { get { lock.withLock { _attachment } } set { lock.withLock { _attachment = newValue } } }
    var thread: [MailMessageSummary] { get { lock.withLock { _thread } } set { lock.withLock { _thread = newValue } } }
    var stored: MailStoredDraft? { get { lock.withLock { _stored } } set { lock.withLock { _stored = newValue } } }
    var savedID: String { get { lock.withLock { _savedID } } set { lock.withLock { _savedID = newValue } } }
    private func record(_ call: String) throws {
        let error = lock.withLock { () -> Error? in
            _calls.append(call)
            return _actionError
        }
        if let error { throw error }
    }
    func archive(messageID: String) async throws { try record("archive:" + messageID) }
    func move(messageID: String, toFolderID: String) async throws { try record("move:" + messageID + ">" + toFolderID) }
    func trash(messageID: String) async throws { try record("trash:" + messageID) }
    func markSpam(messageID: String) async throws { try record("spam:" + messageID) }
    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data {
        try record("attachment:" + messageID + "/" + attachmentID)
        return attachment
    }
    func fetchThread(messageID: String, threadID: String) async throws -> [MailMessageSummary] {
        try record("thread:" + messageID + "/" + threadID)
        return thread
    }
    func saveDraft(_ draft: EmailDraft, replacing draftID: String?) async throws -> String {
        try record("saveDraft:" + (draftID ?? "-") + ":" + draft.subject)
        return savedID
    }
    func fetchDraft(messageID: String) async throws -> MailStoredDraft {
        try record("fetchDraft:" + messageID)
        guard let stored else { throw MailTransportError.messageNotFound(messageID) }
        return stored
    }
    func deleteDraft(id: String) async throws { try record("deleteDraft:" + id) }
    func sendDraft(id: String) async throws {
        try record("sendDraft:" + id)
        lock.withLock { _sendCalls += 1 }
    }
}

func mailTestClassify(_ error: Error) -> Classification {
    if error is GoogleGmailError {
        return GoogleProvider(config: GoogleClientConfig(clientID: "id", clientSecret: ""), openBrowser: { _ in false }).classify(error)
    }
    return IMAPProvider().classify(error)
}

@MainActor
final class HubDouble: HubAccess {
    var mailInlets: [Inlet] = []
    var transports: [Inlet.ID: TransportDouble] = [:]
    private let stream: AsyncStream<HubEvent>
    private let continuation: AsyncStream<HubEvent>.Continuation
    init() {
        (stream, continuation) = AsyncStream<HubEvent>.makeStream()
    }
    var events: AsyncStream<HubEvent> { stream }
    func push(_ event: HubEvent) { continuation.yield(event) }
    func inlets(for capability: Capability) -> [Inlet] {
        capability == .mail ? mailInlets : []
    }
    func port<P>(_ port: P.Type, for inlet: Inlet.ID) throws(HubError) -> P {
        guard let known = mailInlets.first(where: { $0.id == inlet }), known.state.isConnected, let transport = transports[inlet] as? P else { throw .notConnected(inlet) }
        return transport
    }
    func stock<T: Record>(_ kind: DataKind, as type: T.Type) -> Stock<T> {
        fatalError()
    }
    func write(_ order: WriteOrder) async throws(HubError) {}
    func classify(_ error: any Error, inlet: Inlet.ID) -> Classification { mailTestClassify(error) }
    func health(of inlet: Inlet.ID) -> InletHealth { .online }
    func add(_ id: Inlet.ID, connected: Bool = true) -> TransportDouble {
        let transport = TransportDouble()
        transports[id] = transport
        mailInlets.append(Inlet(id: id, provider: "test", capabilities: [.mail], owner: .person("p"), title: id, state: connected ? .connected(probed: Date()) : .failed(Hint(text: "x"))))
        return transport
    }
    func remove(_ id: Inlet.ID) {
        mailInlets.removeAll { $0.id == id }
        transports[id] = nil
    }
}

func message(_ id: String, seen: Bool = false, subject: String = "s") -> MailMessageSummary {
    MailMessageSummary(id: id, subject: subject, from: "a", flags: seen ? [.seen] : [])
}

func draft() -> EmailDraft {
    EmailDraft(to: "z@example.test", subject: "s", body: "b")
}

@MainActor
func eventually(_ condition: @MainActor () -> Bool) async -> Bool {
    for _ in 0..<200 {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

@MainActor
final class ModelFakeEngine: MailEngine {
    var accounts: [Inlet] = []
    var folderList: [String: [MailFolder]] = [:]
    var mirror: [String: [MailMessageSummary]] = [:]
    var pages: [String?: MailMessagePage] = [:]
    var searchHits: [MailMessageSummary] = []
    var bodies: [String: MailMessageBody] = [:]
    var pageError: HubError?
    var bodyError: HubError?
    var flagError: HubError?
    var sendOutcome: SendOutcome = .sent
    var sentDrafts: [EmailDraft] = []
    var flagCalls: [(String, Set<MailFlag>, Set<MailFlag>)] = []
    var unread: [Inlet.ID: Int] = [:]
    var outbox: [OutboxItem] = []
    var actionError: HubError?
    var actionCalls: [String] = []
    var attachmentData = Data()
    var threadMessages: [MailMessageSummary] = []
    var savedDraftID = "remote-1"
    var storedDraft: MailStoredDraft?
    var savedDrafts: [(draft: EmailDraft, replacing: String?)] = []
    var sentFromDraft: [(id: String, draft: EmailDraft)] = []
    var saveGate: CheckedContinuation<Void, Never>?
    var holdSave = false
    var gate: CheckedContinuation<Void, Never>?
    var holdPages = false
    let events: AsyncStream<MailEngineEvent>
    let feed: AsyncStream<MailEngineEvent>.Continuation
    init() {
        (events, feed) = AsyncStream<MailEngineEvent>.makeStream()
    }
    func folders(_ inlet: Inlet.ID) -> [MailFolder] { folderList[inlet] ?? [] }
    func refreshFolders(_ inlet: Inlet.ID) async throws(HubError) {}
    func messages(_ inlet: Inlet.ID, folder: String) -> [MailMessageSummary] { mirror[inlet + folder] ?? [] }
    func lastSync(_ inlet: Inlet.ID, folder: String) -> Date? { Date(timeIntervalSince1970: 100) }
    func loadPage(_ inlet: Inlet.ID, folder: String, query: String?, pageToken: String?) async throws(HubError)
        -> MailMessagePage {
        if holdPages { await withCheckedContinuation { gate = $0 } }
        if let pageError { throw pageError }
        return pages[pageToken] ?? MailMessagePage(messages: [])
    }
    func searchLocal(_ inlet: Inlet.ID, query: String) -> [MailMessageSummary] { searchHits }
    func body(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailMessageBody {
        if let bodyError { throw bodyError }
        return bodies[messageID] ?? MailMessageBody(text: "text of " + messageID)
    }
    func setFlags(_ inlet: Inlet.ID, messageID: String, add: Set<MailFlag>, remove: Set<MailFlag>)
        async throws(HubError) {
        if let flagError { throw flagError }
        flagCalls.append((messageID, add, remove))
    }
    func send(_ inlet: Inlet.ID, _ draft: EmailDraft) async -> SendOutcome {
        sentDrafts.append(draft)
        return sendOutcome
    }
    private func act(_ call: String) throws(HubError) {
        actionCalls.append(call)
        if let actionError { throw actionError }
    }
    func archive(_ inlet: Inlet.ID, messageID: String) async throws(HubError) { try act("archive:" + messageID) }
    func move(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubError) {
        try act("move:" + messageID + ">" + toFolder)
    }
    func trash(_ inlet: Inlet.ID, messageID: String) async throws(HubError) { try act("trash:" + messageID) }
    func markSpam(_ inlet: Inlet.ID, messageID: String) async throws(HubError) { try act("spam:" + messageID) }
    func attachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String) async throws(HubError) -> Data {
        try act("attachment:" + messageID + "/" + attachmentID)
        return attachmentData
    }
    func thread(_ inlet: Inlet.ID, messageID: String, threadID: String) async throws(HubError) -> [MailMessageSummary] {
        try act("thread:" + messageID + "/" + threadID)
        return threadMessages
    }
    func saveDraft(_ inlet: Inlet.ID, _ draft: EmailDraft, replacing draftID: String?) async throws(HubError) -> String {
        if holdSave { await withCheckedContinuation { saveGate = $0 } }
        try act("saveDraft")
        savedDrafts.append((draft, draftID))
        return savedDraftID
    }
    func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubError) -> MailStoredDraft {
        try act("loadDraft:" + messageID)
        return storedDraft ?? MailStoredDraft(id: "remote-9", draft: EmailDraft(subject: "stored", body: "text"))
    }
    func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubError) { try act("deleteDraft:" + draftID) }
    func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: EmailDraft) async -> SendOutcome {
        sentFromDraft.append((draftID, draft))
        return sendOutcome
    }
    func retryOutbox() async {}
    func unreadCount(_ inlet: Inlet.ID) -> Int { unread[inlet] ?? 0 }
    func release() {
        gate?.resume()
        gate = nil
        saveGate?.resume()
        saveGate = nil
    }
}

func fakeAccount(_ id: String, state: InletState = .connected(probed: Date()), address: String = "me@x.test")
    -> Inlet {
    Inlet(id: id, provider: "p", capabilities: [.mail], owner: .company, title: id, account: address, state: state)
}

func fakeMessage(_ id: String, flags: Set<MailFlag> = [], attachments: Int = 0, thread: String = "",
                 from: String = "Anna Berg <anna@x.test>", subject: String = "Hello") -> MailMessageSummary {
    MailMessageSummary(id: id, threadID: thread, subject: subject, from: from, fromRaw: from, toRaw: "me@x.test, bob@x.test", ccRaw: "carl@x.test", snippet: "snip " + id,
                       flags: flags, attachmentCount: attachments)
}

@MainActor
final class ModelTextTests {
    func runPlainTextUsesTheSharedConverter() {
        recordEqual(MailText.plain("<style>p{color:red}</style><p>Hello</p><p>World &amp; Co</p>"), "Hello\nWorld & Co")
    }
}

@MainActor
final class CatalogTests {
    private func catalogKeys() throws -> Set<String> {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("App/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        return Set(strings.keys)
    }
    func runEveryStateOfTheMailModuleHasATextInTheCatalog() throws {
        var keys: [String] = MailDraftState.Kind.allCases.map(\.key)
        keys += MailListState.Kind.allCases.compactMap(\.key)
        keys += MailRowState.Kind.allCases.map(\.key)
        keys += MailCardContent.Kind.allCases.compactMap(\.key)
        keys += MailTextKey.allCases.map(\.rawValue)
        keys.append(Hint.signInExpiredText)
        let missing = Set(keys).subtracting(try catalogKeys()).sorted()
        recordEqual(missing, [], "BUG-4-24")
    }
}

@MainActor
final class CoreTests {
    private func make() throws -> (MailCore, HubDouble, TransportDouble, TransportDouble) {
        let hub = HubDouble()
        let one = hub.add("one")
        let two = hub.add("two")
        for transport in [one, two] {
            transport.folders = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox), MailFolder(id: "S", name: "Sent", role: .sent)]
        }
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        return (core, hub, one, two)
    }
    func runAccountsAndFoldersComeFromTheHub() async throws {
        let (core, _, _, _) = try make()
        recordEqual(core.accounts.map(\.id), ["one", "two"])
        recordTrue(core.folders("one").isEmpty)
        try await core.refreshFolders("one")
        recordEqual(core.folders("one").map(\.id), ["INBOX", "S"])
        recordEqual(core.folders("one").first?.role, .inbox)
        recordTrue(core.folders("two").isEmpty)
    }
    func runNotConnectedSurfacesAsHubError() async throws {
        let hub = HubDouble()
        _ = hub.add("off", connected: false)
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        do {
            try await core.refreshFolders("off")
            XCTFail("expected error")
        } catch {
            recordEqual(error, .notConnected("off"))
        }
    }
    func runLoadPageFillsMirror() async throws {
        let (core, _, one, _) = try make()
        one.setPage("INBOX", MailMessagePage(messages: [message("1"), message("2", seen: true)], nextPageToken: "t"))
        let page = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        recordEqual(page.nextPageToken, "t")
        recordEqual(core.messages("one", folder: "INBOX").map(\.id), ["1", "2"])
        recordEqual(core.messages("one", folder: "INBOX").last?.flags, [.seen])
        recordNotNil(core.lastSync("one", folder: "INBOX"))
        recordNil(core.lastSync("one", folder: "S"))
        one.setPage("INBOX", MailMessagePage(messages: [message("3")]))
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: "t")
        recordEqual(core.messages("one", folder: "INBOX").map(\.id), ["1", "2", "3"])
        recordEqual(core.searchLocal("one", query: "s").count, 3)
    }
    func runSendWithoutNetworkQueuesAndRetrySends() async throws {
        let (core, _, one, _) = try make()
        one.sendError = MailTransportError.connectionFailed("down")
        let outcome = await core.send("one", draft())
        guard case .queued(let id) = outcome else { return XCTFail("expected queued") }
        recordEqual(core.outbox.map(\.id), [id])
        recordEqual(core.outbox.first?.state, .waiting)
        one.sendError = nil
        await core.retryOutbox()
        recordEqual(one.sent.count, 1)
        recordTrue(core.outbox.isEmpty)
        let (gmailCore, _, gmail, _) = try make()
        gmail.sendError = GoogleGmailError.httpError(503)
        _ = await gmailCore.send("one", draft())
        let stateAfter503 = gmailCore.outbox.first?.state
        gmail.sendError = nil
        await gmailCore.retryOutbox()
        recordEqual(stateAfter503, .waiting)
        recordEqual(gmail.sent.count, 1)
    }
    func runOutboxSurvivesAReopenedDatabase() async throws {
        let hub = HubDouble()
        let one = hub.add("one")
        one.sendError = MailTransportError.timeout
        let database = try DatabaseQueue()
        let first = try MailCore(hub: hub, database: database)
        _ = await first.send("one", draft())
        let second = try MailCore(hub: hub, database: database)
        recordEqual(second.outbox.count, 1)
        recordEqual(second.outbox.first?.draft, draft())
        let html = EmailDraft(to: "z@example.test", subject: "s", body: "plain", bodyHTML: "<b>formatted</b>")
        let htmlDatabase = try DatabaseQueue()
        let htmlFirst = try MailCore(hub: hub, database: htmlDatabase)
        _ = await htmlFirst.send("one", html)
        recordEqual(htmlFirst.outbox.first?.draft.bodyHTML, "<b>formatted</b>")
    }
    func runRejectionStaysFailedAndIsNotRetried() async throws {
        let (core, _, one, _) = try make()
        one.sendError = MailTransportError.recipientRejected("z@example.test", 550, "no such user")
        _ = await core.send("one", draft())
        guard case .failed(let hint) = core.outbox.first?.state else { return XCTFail("expected failed") }
        recordEqual(hint.text, "mail.hint.rejected")
        let calls = one.sendCalls
        one.sendError = nil
        await core.retryOutbox()
        recordEqual(one.sendCalls, calls)
        recordEqual(core.outbox.count, 1)
    }
    func runUnreadCountPerAccount() async throws {
        let (core, _, one, two) = try make()
        one.setPage("INBOX", MailMessagePage(messages: [message("1"), message("2"), message("3", seen: true)]))
        two.setPage("INBOX", MailMessagePage(messages: [message("9")]))
        try await core.refreshFolders("one")
        try await core.refreshFolders("two")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = try await core.loadPage("two", folder: "INBOX", query: nil, pageToken: nil)
        recordEqual(core.unreadCount("one"), 2)
        recordEqual(core.unreadCount("two"), 1)
        try await core.setFlags("one", messageID: "1", add: [.seen], remove: [])
        recordEqual(core.unreadCount("one"), 1)
        let (pagedCore, _, paged, _) = try make()
        paged.setTokenPage(nil, MailMessagePage(messages: (1...5).map { message("p1-\($0)") }, nextPageToken: "t"))
        paged.setTokenPage("t", MailMessagePage(messages: (1...5).map { message("p2-\($0)") }))
        try await pagedCore.refreshFolders("one")
        _ = try await pagedCore.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = try await pagedCore.loadPage("one", folder: "INBOX", query: nil, pageToken: "t")
        recordEqual(pagedCore.unreadCount("one"), 10)
    }
    func runSyncFinishedBringsNewMailAndRetriesOutbox() async throws {
        let (core, hub, one, _) = try make()
        var seen: [MailEngineEvent] = []
        let stream = core.events
        let collector = Task { for await event in stream { seen.append(event) } }
        defer { collector.cancel() }
        one.setPage("INBOX", MailMessagePage(messages: [message("1")]))
        hub.push(.syncFinished(.mail, "one"))
        let first = await eventually { core.lastSync("one", folder: "INBOX") != nil }
        recordTrue(first)
        recordFalse(seen.contains { if case .newMail = $0 { true } else { false } })
        one.sendError = MailTransportError.timeout
        _ = await core.send("one", draft())
        one.sendError = nil
        one.setPage("INBOX", MailMessagePage(messages: [message("2"), message("3"), message("1")]))
        hub.push(.syncFinished(.mail, "one"))
        let done = await eventually { core.outbox.isEmpty }
        recordTrue(done)
        recordTrue(seen.contains(.newMail("one", count: 2)))
        recordEqual(core.unreadCount("one"), 3)
    }
    func runSyncFailureKeepsLastStateAndReports() async throws {
        let (core, hub, one, _) = try make()
        var seen: [MailEngineEvent] = []
        let stream = core.events
        let collector = Task { for await event in stream { seen.append(event) } }
        defer { collector.cancel() }
        one.setPage("INBOX", MailMessagePage(messages: [message("1")]))
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        one.listError = MailTransportError.timeout
        hub.push(.syncFinished(.mail, "one"))
        let failed = await eventually { seen.contains { if case .syncFailed("one", _) = $0 { true } else { false } } }
        recordTrue(failed)
        recordEqual(core.messages("one", folder: "INBOX").map(\.id), ["1"])
    }
    func runGmailHttpErrorsAreClassified() {
        let hub = HubDouble()
        let unauthorized = MailFailure.classify(GoogleGmailError.httpError(401), inlet: "i", hub: hub)
        let tooMany = MailFailure.classify(GoogleGmailError.httpError(429), inlet: "i", hub: hub)
        let unavailable = MailFailure.classify(GoogleGmailError.httpError(503), inlet: "i", hub: hub)
        recordEqual(unauthorized.hint.text, Hint.signInExpiredText)
        recordTrue(tooMany.isTransient)
        recordEqual(tooMany.hint.code, "gmail.429")
        recordTrue(unavailable.isTransient)
    }
    func runSendAgainAfterARejectionLeavesTheFailedItemInTheOutbox() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        let id = try XCTUnwrap(model.compose(to: "z@example.test"))
        model.edit(id) { $0.subject = "s" }
        transport.sendError = MailTransportError.recipientRejected("z@example.test", 550, "no such user")
        await model.send(id)
        guard case .sendFailed(let hint) = model.draft(id)?.state else { return XCTFail("state \(String(describing: model.draft(id)?.state))") }
        recordEqual(hint.text, MailTextKey.rejected.rawValue)
        transport.sendError = nil
        await model.send(id)
        recordEqual(model.draft(id)?.state, .sent)
        recordEqual(transport.sent.count, 1)
    }
    func runOutboxItemOfARemovedAccountWaitsForever() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        transport.setTokenPage(nil, MailMessagePage(messages: [message("1")]))
        transport.sendError = MailTransportError.timeout
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = await core.send("one", draft())
        hub.remove("one")
        await core.retryOutbox()
        await core.retryOutbox()
        let item = core.outbox.first
        recordEqual(item?.state, .waiting)
    }
    func runRejectedSignInIsShownAsExpiredSignIn() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.listError = MailTransportError.authenticationRejected("bad password")
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        recordEqual(model.listState, .signInExpired("one"))
    }
    func runLocalSearchMatchesTheTextAsTyped() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        transport.setPage("INBOX", MailMessagePage(messages: [message("1", subject: "abc"), message("2", subject: "\u{C4}rger im B\u{FC}ro")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
    }
    func runAMailSentFromTheOutboxIsGoneAfterAReopen() async throws {
        let hub = HubDouble()
        let one = hub.add("one")
        one.sendError = MailTransportError.timeout
        let database = try DatabaseQueue()
        let first = try MailCore(hub: hub, database: database)
        _ = await first.send("one", draft())
        recordEqual(first.outbox.count, 1)
        one.sendError = nil
        await first.retryOutbox()
        recordEqual(one.sent.count, 1)
        recordTrue(first.outbox.isEmpty)
        let second = try MailCore(hub: hub, database: database)
        recordTrue(second.outbox.isEmpty)
    }
    func runLocalSearchListsTheNewestHitsFirst() async throws {
        let (core, _, one, _) = try make()
        let day: TimeInterval = 86_400
        let old = MailMessageSummary(id: "old", subject: "hit", from: "a", receivedAt: Date(timeIntervalSince1970: day))
        let new = MailMessageSummary(id: "new", subject: "hit", from: "a", receivedAt: Date(timeIntervalSince1970: 3 * day))
        let middle = MailMessageSummary(id: "middle", subject: "hit", from: "a", receivedAt: Date(timeIntervalSince1970: 2 * day))
        one.setPage("INBOX", MailMessagePage(messages: [old, new, middle]))
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        recordEqual(core.searchLocal("one", query: "hit").map(\.id), ["new", "middle", "old"])
    }
}

@MainActor
final class CoreActionTests {
    private func make() async throws -> (MailCore, TransportDouble, HubDouble) {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox), MailFolder(id: "WORK", name: "Work", role: .other)]
        transport.setPage("INBOX", MailMessagePage(messages: [message("1"), message("2")]))
        transport.setPage("WORK", MailMessagePage(messages: [message("1"), message("3")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        try await core.refreshFolders("one")
        _ = try await core.loadPage("one", folder: "INBOX", query: nil, pageToken: nil)
        _ = try await core.loadPage("one", folder: "WORK", query: nil, pageToken: nil)
        return (core, transport, hub)
    }
    private func collect(_ core: MailCore, during work: () async throws -> Void) async rethrows -> [MailEngineEvent] {
        var seen: [MailEngineEvent] = []
        let stream = core.events
        let task = Task { @MainActor in
            for await event in stream { seen.append(event) }
        }
        await Task.yield()
        try await work()
        await Task.yield()
        task.cancel()
        await task.value
        return seen
    }
    private func stepArchiveLeavesTheInboxOnlyAndTellsTheListSo() async throws {
        let (core, transport, _) = try await make()
        let events = try await collect(core) { try await core.archive("one", messageID: "1") }
        recordEqual(transport.calls, ["archive:1"])
        recordEqual(core.messages("one", folder: "INBOX").map(\.id), ["2"])
        recordEqual(core.messages("one", folder: "WORK").map(\.id), ["1", "3"])
        recordEqual(core.unreadCount("one"), 1)
        recordEqual(events, [.messagesChanged("one", folder: "INBOX")])
    }
    private func stepTrashAndSpamLeaveEveryFolder() async throws {
        let (core, transport, _) = try await make()
        try await core.trash("one", messageID: "1")
        recordEqual(core.messages("one", folder: "INBOX").map(\.id), ["2"])
        recordEqual(core.messages("one", folder: "WORK").map(\.id), ["3"])
        try await core.markSpam("one", messageID: "3")
        recordEqual(core.messages("one", folder: "WORK").map(\.id), [])
        recordEqual(transport.calls, ["trash:1", "spam:3"])
    }
    private func stepMoveAsksTheTransportForTheTargetAndDropsTheMessageFromTheMirror() async throws {
        let (core, transport, _) = try await make()
        try await core.move("one", messageID: "2", toFolder: "WORK")
        recordEqual(transport.calls, ["move:2>WORK"])
        recordEqual(core.messages("one", folder: "INBOX").map(\.id), ["1"])
    }
    private func stepAProviderRefusalKeepsTheMessageAndCarriesTheOriginalAnswer() async throws {
        let (core, transport, _) = try await make()
        transport.actionError = MailTransportError.serverRejected("NO [CANNOT] folder is read only")
        do {
            try await core.trash("one", messageID: "1")
            XCTFail("trash must throw")
        } catch {
            guard case .provider(let hint) = error else { return XCTFail("\(error)") }
            recordEqual(hint.text, "mail.hint.rejected")
            recordEqual(hint.detail, "NO [CANNOT] folder is read only")
        }
        recordEqual(core.messages("one", folder: "INBOX").map(\.id), ["1", "2"])
    }
    private func stepAttachmentAndThreadComeFromTheTransport() async throws {
        let (core, transport, _) = try await make()
        transport.attachment = Data("pdf".utf8)
        transport.thread = [message("1"), message("2")]
        let data = try await core.attachment("one", messageID: "1", attachmentID: "a")
        let thread = try await core.thread("one", messageID: "2", threadID: "t")
        recordEqual(data, Data("pdf".utf8))
        recordEqual(thread.map(\.id), ["1", "2"])
        recordEqual(transport.calls, ["attachment:1/a", "thread:2/t"])
    }
    private func stepDraftsAreSavedLoadedAndDeletedThroughTheTransport() async throws {
        let (core, transport, _) = try await make()
        transport.stored = MailStoredDraft(id: "d7", draft: draft())
        let id = try await core.saveDraft("one", draft(), replacing: "d1")
        let stored = try await core.loadDraft("one", messageID: "m7")
        try await core.deleteDraft("one", draftID: "d7")
        recordEqual(id, "draft-1")
        recordEqual(stored.id, "d7")
        recordEqual(transport.calls, ["saveDraft:d1:s", "fetchDraft:m7", "deleteDraft:d7"])
    }
    private func stepSendingFromADraftStoresTheLatestTextThenSendsTheDraft() async throws {
        let (core, transport, _) = try await make()
        let outcome = await core.sendDraft("one", draftID: "d1", draft())
        recordEqual(outcome, .sent)
        recordEqual(transport.calls, ["saveDraft:d1:s", "sendDraft:draft-1"])
        recordTrue(transport.sent.isEmpty)
        recordTrue(core.outbox.isEmpty)
    }
    private func stepAQueuedDraftKeepsItsDraftThroughARestartAndGoesOutAsADraft() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.actionError = MailTransportError.timeout
        let database = try DatabaseQueue()
        let first = try MailCore(hub: hub, database: database)
        let outcome = await first.sendDraft("one", draftID: "d1", draft())
        guard case .queued = outcome else { return XCTFail("expected queued") }
        let second = try MailCore(hub: hub, database: database)
        recordEqual(second.outbox.first?.draftID, "d1")
        transport.actionError = nil
        await second.retryOutbox()
        recordTrue(second.outbox.isEmpty)
        recordTrue(transport.sent.isEmpty)
        recordEqual(transport.calls.suffix(2), ["saveDraft:d1:s", "sendDraft:draft-1"])
    }
    func runTheCoreActions() async throws {
        try await stepArchiveLeavesTheInboxOnlyAndTellsTheListSo()
        try await stepTrashAndSpamLeaveEveryFolder()
        try await stepMoveAsksTheTransportForTheTargetAndDropsTheMessageFromTheMirror()
        try await stepAProviderRefusalKeepsTheMessageAndCarriesTheOriginalAnswer()
        try await stepAttachmentAndThreadComeFromTheTransport()
        try await stepDraftsAreSavedLoadedAndDeletedThroughTheTransport()
        try await stepSendingFromADraftStoresTheLatestTextThenSendsTheDraft()
        try await stepAQueuedDraftKeepsItsDraftThroughARestartAndGoesOutAsADraft()
    }
}

@MainActor
final class CoreModelTests {
    func runModelOverCoreShowsOfflineWhenTheNetworkDrops() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        transport.setPage("INBOX", MailMessagePage(messages: [MailMessageSummary(id: "m1", subject: "s", from: "a")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        recordEqual(model.listState, .loaded)
        transport.listError = MailTransportError.timeout
        await model.loadSelection()
        guard case .offline = model.listState else { return XCTFail("state \(model.listState)") }
    }
}

@MainActor
final class AccountTests {
    private func engineWithTwoAccounts() -> ScriptedEngine {
        let engine = ScriptedEngine()
        engine.accounts = [fakeAccount("a"), fakeAccount("b")]
        engine.folderList = ["a": scriptedInbox, "b": scriptedInbox]
        engine.pages[ScriptedEngine.key("a", "INBOX", nil)] =
            MailMessagePage(messages: [fakeMessage("a1")], nextPageToken: "token-of-a")
        engine.pages[ScriptedEngine.key("b", "INBOX", nil)] = MailMessagePage(messages: [fakeMessage("b1")])
        return engine
    }
    func runRemovingTheSelectedAccountLetsLoadMoreUseTheTokenOfTheOldOne() async {
        let engine = engineWithTwoAccounts()
        let model = MailModel(engine: engine)
        await model.start()
        recordEqual(model.selectedInlet, "a")
        recordEqual(model.nextPageToken, "token-of-a")
        engine.accounts = [fakeAccount("b")]
        await model.handle(.accountsChanged)
        recordEqual(model.selectedInlet, "b")
        engine.pageCalls = []
        await model.loadMore()
        let calls = engine.pageCalls
        recordFalse(calls.contains { $0.hasSuffix("|token-of-a") }, "calls \(calls)")
    }
    func runRemovingTheOnlyAccountStillListsItsRows() async {
        let engine = engineWithTwoAccounts()
        engine.accounts = [fakeAccount("a")]
        let model = MailModel(engine: engine)
        await model.start()
        recordEqual(model.rows.map(\.id), ["a1"])
        engine.accounts = []
        await model.handle(.accountsChanged)
        recordNil(model.selectedInlet)
        let rows = model.rows.map(\.id)
        let listState = model.listState
        recordEqual(listState, .notConnected(nil))
        recordEqual(rows, [])
        recordNil(model.nextPageToken)
        recordTrue(model.folders.isEmpty)
    }
    func runLoadMoreOfTheOldAccountLandsInTheNewAccountWhileItsFoldersLoad() async {
        let engine = engineWithTwoAccounts()
        engine.folderList["b"] = []
        engine.pendingFolders["b"] = scriptedInbox
        engine.pages[ScriptedEngine.key("a", "INBOX", "token-of-a")] =
            MailMessagePage(messages: [fakeMessage("a2")], nextPageToken: "token-of-a-2")
        let moreGate = ScriptedGate()
        engine.pageGates[ScriptedEngine.key("a", "INBOX", "token-of-a")] = moreGate
        let folderGate = ScriptedGate()
        engine.folderGates["b"] = folderGate
        let model = MailModel(engine: engine)
        await model.start()
        let more = Task { await model.loadMore() }
        let waitingMore = await eventually { moreGate.hasWaiter }
        recordTrue(waitingMore)
        let switching = Task { await model.selectAccount("b") }
        let waitingFolders = await eventually { folderGate.hasWaiter }
        recordTrue(waitingFolders)
        moreGate.release()
        await more.value
        let inlet = model.selectedInlet
        folderGate.release()
        await switching.value
        recordEqual(inlet, "b")
    }
    func runOneRejectedLoadMoreEndsPagingUntilTheFolderIsSelectedAgain() async throws {
        let hub = HubDouble()
        let transport = hub.add("two")
        transport.folders = scriptedInbox
        transport.setTokenPage(nil, MailMessagePage(messages: [message("1")], nextPageToken: "t1"))
        transport.setTokenPage("t1", MailMessagePage(messages: [message("9")]))
        transport.failList(call: 2, GoogleGmailError.api(GoogleAPIFault(status: 403, reason: "rateLimitExceeded")))
        let model = MailModel(engine: try MailCore(hub: hub, database: DatabaseQueue()))
        await model.start()
        recordTrue(model.canLoadMore)
        await model.loadMore()
        let afterFailure = model.canLoadMore
        let stateAfterFailure = model.listState
        await model.loadMore()
        let ids = model.summaries.map(\.id)
        guard case .offline = stateAfterFailure else { return XCTFail("state \(stateAfterFailure)") }
        recordTrue(afterFailure)
        recordEqual(ids, ["1", "9"])
    }
    func runRowsRemovedOnTheServerStayInTheListAfterASync() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        transport.setTokenPage(nil, MailMessagePage(messages: [message("1"), message("2")]))
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        let model = MailModel(engine: core)
        await model.start()
        recordEqual(model.summaries.map(\.id), ["1", "2"])
        transport.setTokenPage(nil, MailMessagePage(messages: [message("2")]))
        hub.push(.syncFinished(.mail, "one"))
        let mirrored = await eventually { core.messages("one", folder: "INBOX").map(\.id) == ["2"] }
        recordTrue(mirrored)
    }
    func runAccountAddedLaterIsNotSelectedWhenNothingIsSelected() async {
        let engine = ScriptedEngine()
        let model = MailModel(engine: engine)
        await model.start()
        recordNil(model.selectedInlet)
        engine.accounts = [fakeAccount("a")]
        engine.folderList["a"] = scriptedInbox
        await model.handle(.accountsChanged)
        recordEqual(model.accounts.map(\.id), ["a"])
    }

}

private final class SetupKeychain: KeychainPort, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [KeySlot: String] = [:]
    func put(_ value: String, at slot: KeySlot) throws { lock.withLock { entries[slot] = value } }
    func get(_ slot: KeySlot) throws -> String? { lock.withLock { entries[slot] } }
    func delete(_ slot: KeySlot) throws { lock.withLock { entries[slot] = nil } }
}

private final class SetupCadence: CadencePort, @unchecked Sendable {
    private let lock = NSLock()
    private var planned: [String: Cadence] = [:]
    let reports = AsyncStream<SyncReport> { _ in }
    func planned(_ inlet: Inlet.ID, _ capability: Capability) -> Cadence? {
        lock.withLock { planned[inlet + "|" + capability.rawValue] }
    }
    func attach(_ runner: @escaping SyncRunner) {}
    func plan(_ inlet: Inlet.ID, _ capability: Capability, _ cadence: Cadence) {
        lock.withLock { planned[inlet + "|" + capability.rawValue] = cadence }
    }
    func trigger(_ inlet: Inlet.ID, _ capability: Capability) async {}
}

private final class SetupCost: CostPort, @unchecked Sendable {
    func book(_ item: CostItem) {}
    func sum(_ inlet: Inlet.ID, _ period: Period) -> Cost { .zero }
}

private struct SetupSignIn: SignInPort {
    func signIn(_ inlet: Inlet, input: [Field.ID: String]) async throws -> Grant { Grant(values: ["token": inlet.id]) }
    func renew(_ grant: Grant) async throws -> Grant { grant }
    func signOut(_ inlet: Inlet) async throws {}
}

private final class SetupFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Bool
    init(_ value: Bool) { current = value }
    var value: Bool {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}

private struct SetupProbe: ProbePort {
    let accepting: SetupFlag
    func probe(_ inlet: Inlet, _ grant: Grant) async throws -> ProbeResult {
        accepting.value ? ProbeResult(account: "a@x.test") : ProbeResult(account: "a@x.test", rejection: Hint(text: "hint.setup"))
    }
}

private struct SetupProvider: Provider {
    let id = "double"
    let capabilities: Set<Capability> = [.mail]
    let form: [Field] = []
    let presets: [Preset] = []
    let signIn: any SignInPort = SetupSignIn()
    let probe: any ProbePort
    init(accepting: SetupFlag = SetupFlag(true)) { probe = SetupProbe(accepting: accepting) }
    func adapter<P>(_ port: P.Type, for inlet: Inlet, _ grant: Grant, renewal: GrantRenewal) throws -> P {
        throw HubError.capabilityMissing(inlet.id, .mail)
    }
}

@MainActor
final class SetupTests {
    private let person = Person(id: "p1", name: "P")
    private var temps: [URL] = []
    func cleanup() { for url in temps { try? FileManager.default.removeItem(at: url) } }
    private func directory(withGoogle: Bool) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("alfa-setup-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        if withGoogle {
            let json = #"{"clientID":"id.example","clientSecret":"secret"}"#
            try json.write(to: url.appendingPathComponent("google-client.json"), atomically: true, encoding: .utf8)
        }
        temps.append(url)
        return url
    }
    private func assembly(withGoogle: Bool, cadence: SetupCadence = SetupCadence()) throws -> MailSetup.Assembly {
        try MailSetup.make(
            person: person, company: CompanySetup(), openBrowser: { _ in true }, directory: try directory(withGoogle: withGoogle), database: try HubDatabase.inMemory(),
            keychain: SetupKeychain(), cadence: cadence, cost: SetupCost()
        )
    }
    private func assembled(accepting: SetupFlag, database: DatabaseQueue) throws -> MailSetup.Assembly {
        try MailSetup.assemble(
            person: person, company: CompanySetup(), providers: [SetupProvider(accepting: accepting)],
            database: database, keychain: SetupKeychain(), cadence: SetupCadence(), cost: SetupCost(), cadences: MailSetup.defaultCadences, clock: { Date() })
    }
    private func rows(_ database: DatabaseQueue, _ inlet: Inlet.ID) throws -> Int {
        try database.read { db in
            try Int.fetchOne(db, sql: "SELECT (SELECT COUNT(*) FROM mail_message WHERE inlet = ?) + (SELECT COUNT(*) FROM mail_folder WHERE inlet = ?)", arguments: [inlet, inlet]) ?? 0
        }
    }
    func runOffersDependOnTheGoogleConfiguration() throws {
        let imapOnly = try assembly(withGoogle: false).hub.setup.offers
        recordFalse(imapOnly.isEmpty)
        recordEqual(Set(imapOnly.map(\.provider)), ["imap"])
        for offer in imapOnly {
            guard case .form(let fields) = offer.way else { return XCTFail("way \(offer.way)") }
            recordFalse(fields.isEmpty)
            recordEqual(offer.capabilities, [.mail])
            recordEqual(offer.owner, .person("p1"))
        }
        recordTrue(imapOnly.allSatisfy { $0.preset != nil })
        let withGoogle = try assembly(withGoogle: true).hub.setup.offers
        recordEqual(Set(withGoogle.map(\.provider)), ["google", "imap"])
        let google = withGoogle.filter { $0.provider == "google" }
        recordEqual(google.count, 1)
        recordEqual(google.first?.way, .signIn)
    }
    func runAssemblyIsUsableWithoutAnyInlet() throws {
        let result = try assembly(withGoogle: false)
        recordEqual(result.hub.setup.inlets, [])
        recordEqual(result.engine.accounts, [])
        recordEqual(result.model.accounts, [])
    }
    func runCadenceOfANewInletComesFromTheConfiguration() async throws {
        let cadence = SetupCadence()
        let result = try MailSetup.assemble(
            person: person, company: CompanySetup(), providers: [SetupProvider()], database: try HubDatabase.inMemory(), keychain: SetupKeychain(), cadence: cadence, cost: SetupCost(),
            cadences: MailSetup.defaultCadences, clock: { Date() }
        )
        let offer = try XCTUnwrap(result.hub.setup.offers.first)
        recordEqual(offer.way, .signIn)
        let inlet = try await result.hub.setup.add(offer)
        recordEqual(cadence.planned(inlet.id, .mail), .every(.seconds(300)))
        recordEqual(result.hub.rules.cadence(inlet.id, .mail), .every(.seconds(300)))
        let configuredCadence = SetupCadence()
        let configured = try MailSetup.assemble(
            person: person, company: CompanySetup(), providers: [SetupProvider()],
            database: try HubDatabase.inMemory(), keychain: SetupKeychain(), cadence: configuredCadence, cost: SetupCost(), cadences: [.mail: .seconds(60)], clock: { Date() }
        )
        let configuredInlet = try await configured.hub.setup.add(try XCTUnwrap(configured.hub.setup.offers.first))
        recordEqual(configuredCadence.planned(configuredInlet.id, .mail), .every(.seconds(60)))
    }
    func runRenewalKeepsTheCadenceTheUserSet() async throws {
        let accepting = SetupFlag(true)
        let result = try assembled(accepting: accepting, database: try HubDatabase.inMemory())
        let offer = try XCTUnwrap(result.hub.setup.offers.first)
        let inlet = try await result.hub.setup.add(offer)
        recordEqual(result.hub.rules.cadence(inlet.id, .mail), .every(.seconds(300)))
        result.hub.rules.setCadence(inlet.id, .mail, .every(.seconds(60)))
        accepting.value = false
        _ = try? await result.hub.setup.probe(inlet.id)
        recordTrue(result.hub.setup.inlets[0].state.canRenew)
        accepting.value = true
        let renewed = try await result.hub.setup.add(offer)
        recordEqual(renewed.id, inlet.id)
    }
    func runRemovedAccountTakesItsMirroredMailWithIt() async throws {
        let database = try HubDatabase.inMemory()
        let result = try assembled(accepting: SetupFlag(true), database: database)
        let inlet = try await result.hub.setup.add(try XCTUnwrap(result.hub.setup.offers.first))
        let mirror = try MailMirror(database)
        try mirror.replaceFolders(inlet.id, [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)])
        try mirror.replaceMessages(inlet.id, folder: "INBOX", [MailMessageSummary(id: "m1", subject: "s", from: "a")], at: Date())
        try await result.hub.setup.remove(inlet.id)
        let left = try rows(database, inlet.id)
        recordEqual(left, 2)
    }
}

@MainActor
final class MailModelTests {
    func makeModel(_ engine: ModelFakeEngine, state: InletState = .connected(probed: Date())) -> MailModel {
        engine.accounts = [fakeAccount("a", state: state)]
        engine.folderList["a"] = [MailFolder(id: "SENT", name: "Sent", role: .sent), MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        return MailModel(engine: engine)
    }
    func runListEmptyLoadingLoadedFailed() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [])
        await model.start()
        recordEqual(model.selectedFolder, "INBOX")
        recordEqual(model.listState, .empty(folder: "INBOX"))
        engine.holdPages = true
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")])
        let task = Task { await model.loadSelection() }
        await Task.yield()
        await Task.yield()
        recordEqual(model.listState, .loading)
        engine.holdPages = false
        engine.release()
        await task.value
        recordEqual(model.listState, .loaded)
        engine.pageError = .provider(Hint(text: "hint.x"))
        await model.loadSelection()
        recordEqual(model.listState, .failed(Hint(text: "hint.x")))
    }
    func runSearchWithoutHitsIsEmptySearch() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        await model.search("zzz")
        recordEqual(model.listState, .emptySearch(query: "zzz", folder: "INBOX"))
    }
    func runFilterWithoutHitsIsNoFilterMatch() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1", flags: [.seen])])
        await model.start()
        model.setFilter(.unread)
        recordEqual(model.listState, .noFilterMatch)
        model.setFilter(.all)
        recordEqual(model.listState, .loaded)
    }
    func runLoadMoreAppendsByPageToken() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")], nextPageToken: "t2")
        engine.pages["t2"] = MailMessagePage(messages: [fakeMessage("m2")])
        await model.start()
        recordTrue(model.canLoadMore)
        await model.loadMore()
        recordEqual(model.summaries.map(\.id), ["m1", "m2"])
        recordFalse(model.canLoadMore)
    }
    func runSendWithoutSubjectIsBlocked() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        let id = model.compose(to: "z@x.test")!
        await model.send(id)
        recordEqual(model.draft(id)?.state, .sendBlocked(.noSubject))
        model.edit(id) { $0.subject = "s" ; $0.to = nil }
        await model.send(id)
        recordEqual(model.draft(id)?.state, .sendBlocked(.noRecipient))
        recordTrue(engine.sentDrafts.isEmpty)
    }
    func runSendQueuedIsQueuedInOutbox() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        let draft = EmailDraft(to: "z@x.test", subject: "s", body: "b")
        let item = OutboxItem(inlet: "a", draft: draft)
        engine.outbox = [item]
        engine.sendOutcome = .queued(item.id)
        let id = model.compose(to: "z@x.test")!
        model.edit(id) { $0.subject = "s" }
        await model.send(id)
        recordEqual(model.draft(id)?.state, .queuedInOutbox)
        engine.outbox = []
        await model.handle(.outboxChanged)
        recordEqual(model.draft(id)?.state, .sent)
    }
    func runSendSent() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        let id = model.compose(to: "z@x.test")!
        model.edit(id) { $0.subject = "s" }
        await model.send(id)
        recordEqual(model.draft(id)?.state, .sent)
    }
    func runUnreadPerAccountAndTotal() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.accounts.append(fakeAccount("b"))
        engine.unread = ["a": 3, "b": 4]
        await model.start()
        recordEqual(model.unread, ["a": 3, "b": 4])
        recordEqual(model.totalUnread, 7)
        engine.unread["a"] = 5
        await model.handle(.newMail("a", count: 2))
        recordEqual(model.totalUnread, 9)
    }
    func runSignInExpiredFromAccountState() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine, state: .failed(Hint(text: "hint.signin.expired")))
        await model.start()
        recordEqual(model.listState, .signInExpired("a"))
    }
    func runNotConnectedFromAccountState() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine, state: .created)
        await model.start()
        recordEqual(model.listState, .notConnected("a"))
    }
    func runContactFromSignatureYieldsCommand() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")])
        engine.bodies["m1"] = .init(text: "Hi\n\n--\nAnna Berg\nBerg GmbH\nTel +49 30 1234567\n")
        await model.start()
        await model.contactFromSignature("m1")
        var iterator = model.commands.makeAsyncIterator()
        let command = await iterator.next()
        guard case .contactFromSignature(let ref, let contact) = command else { return XCTFail("no command") }
        recordEqual(ref, MailMessageRef(inlet: "a", messageID: "m1"))
        recordEqual(contact.name, "Anna Berg")
        recordEqual(contact.organisation, "Berg GmbH")
    }
    func runCardLimitDropsOldest() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: (1...12).map { fakeMessage("m\($0)", flags: [.seen]) })
        await model.start()
        recordEqual(model.cardLimit, 6)
        for index in 1...12 { await model.open("m\(index)", pin: true) }
        recordEqual(model.cards.count, 6)
        recordEqual(model.cards.first?.id, "m7")
        model.setCardLimit(2)
        recordEqual(model.cards.map(\.id), ["m11", "m12"])
        model.setCardLimit(6)
        await model.open("m1")
        await model.open("m2")
        recordEqual(model.cards.map(\.id), ["m11", "m12", "m2"])
    }
    func runOpenMarksReadAndFlagFailureKeepsHint() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")])
        engine.unread = ["a": 1]
        await model.start()
        await model.open("m1")
        recordEqual(engine.flagCalls.first?.1, [.seen])
        recordEqual(model.rows.first?.states.contains(.unread), false)
        engine.flagError = .provider(Hint(text: "hint.f"))
        await model.setStarred("m1", true)
        recordEqual(model.actionFailure(for: "m1"), Hint(text: "hint.f"))
        recordEqual(model.rows.first?.states.contains(.starred), false)
    }
    func runReplyAllBuildsDraft() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1", thread: "th", subject: "Hello")])
        await model.start()
        let id = await model.reply(to: "m1", all: true)!
        let draft = model.draft(id)!.draft
        recordEqual(draft.subject, "Re: Hello")
        recordEqual(draft.to, "Anna Berg <anna@x.test>")
        recordEqual(draft.cc, "bob@x.test, carl@x.test")
        recordEqual(draft.inReplyTo, "m1")
        recordEqual(draft.threadID, "th")
        recordTrue(draft.body.contains("> text of m1"))
        let forward = await model.forward("m1")!
        recordEqual(model.draft(forward)?.draft.subject, "Fwd: Hello")
        recordTrue(model.draft(forward)!.draft.attachments.isEmpty)
    }
    func runOfflineKeepsLastSync() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pageError = .provider(Hint(text: MailTextKey.offline.rawValue))
        await model.start()
        recordEqual(model.listState, .offline(lastSync: Date(timeIntervalSince1970: 100)))
    }
    func runRowStatesAndThreadCount() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [
            fakeMessage("m1", flags: [.flagged], attachments: 1, thread: "t"), fakeMessage("m2", thread: "t"), fakeMessage("m3", flags: [.seen])])
        await model.start()
        recordEqual(model.rows[0].states, [.unread, .starred, .hasAttachments, .threadCount(2)])
        recordEqual(model.rows[1].states, [.unread, .threadCount(2)])
        recordEqual(model.rows[0].states.first?.key, "mail.row.unread")
        recordEqual(model.rows[2].states, [])
        recordFalse(model.rows[2].selected)
        await model.open("m3")
        recordTrue(model.rows[2].selected)
        recordEqual(model.rows[2].states, [.selected])
        recordFalse(model.rows[0].selected)
    }
    func runSelectFolderChangesTheSelectionAndKeepsTheRole() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")])
        await model.start()
        await model.selectFolder("SENT")
        recordEqual(model.selectedFolder, "SENT")
        recordEqual(model.sortedFolders.first { $0.id == model.selectedFolder }?.role, .sent)
    }
    func runADraftWithOnlyBccCountsAsHavingARecipient() async {
        let engine = ModelFakeEngine()
        let model = makeModel(engine)
        await model.start()
        let id = model.compose(to: "z@x.test")!
        model.edit(id) { $0.subject = "s"; $0.to = nil; $0.cc = nil; $0.bcc = "hidden@x.test" }
        await model.send(id)
        recordNotEqual(model.draft(id)?.state, .sendBlocked(.noRecipient))
        recordEqual(engine.sentDrafts.map(\.bcc), ["hidden@x.test"])
    }
}

@MainActor
final class ModelActionTests {
    private let fixed = Date(timeIntervalSince1970: 5_000)
    private func make(folders: [MailFolder]? = nil) async -> (MailModel, ModelFakeEngine) {
        let engine = ModelFakeEngine()
        engine.accounts = [fakeAccount("a")]
        engine.folderList["a"] = folders ?? [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1"), fakeMessage("m2", flags: [.seen])])
        let fixed = fixed
        let model = MailModel(engine: engine, clock: { fixed })
        await model.start()
        return (model, engine)
    }
    private func stepArchiveRemovesTheRowClosesTheCardAndCountsAgain() async {
        let (model, engine) = await make()
        await model.open("m1")
        engine.unread["a"] = 7
        await model.archive("m1")
        recordEqual(engine.actionCalls, ["archive:m1"])
        recordEqual(model.summaries.map(\.id), ["m2"])
        recordTrue(model.cards.isEmpty)
        recordNil(model.selectedMessage)
        recordEqual(model.unread["a"], 7)
        recordNil(model.actionFailure(for: "m1"))
    }
    private func stepArchiveInTheAllFolderKeepsTheRowListed() async {
        let all = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox), MailFolder(id: "ALL", name: "All", role: .all)]
        let (model, engine) = await make(folders: all)
        await model.selectFolder("ALL")
        await model.archive("m1")
        recordEqual(engine.actionCalls, ["archive:m1"])
        recordEqual(model.summaries.map(\.id), ["m1", "m2"])
    }
    private func stepTrashSpamAndMoveEachAskTheEngineAndDropTheRow() async {
        let (model, engine) = await make()
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1"), fakeMessage("m2"), fakeMessage("m3")])
        await model.loadSelection()
        await model.trash("m1")
        await model.markSpam("m2")
        await model.move("m3", toFolder: "WORK")
        recordEqual(engine.actionCalls, ["trash:m1", "spam:m2", "move:m3>WORK"])
        recordTrue(model.summaries.isEmpty)
    }
    private func stepARefusedActionKeepsTheRowAndTheCardAndShowsTheHint() async {
        let (model, engine) = await make()
        await model.open("m1")
        engine.actionError = .provider(Hint(text: "mail.hint.rejected", detail: "NO read only"))
        await model.trash("m1")
        recordEqual(model.actionFailure(for: "m1"), Hint(text: "mail.hint.rejected", detail: "NO read only"))
        recordEqual(model.summaries.map(\.id), ["m1", "m2"])
        recordEqual(model.cards.map(\.id), ["m1"])
        engine.actionError = nil
        await model.trash("m1")
        recordNil(model.actionFailure(for: "m1"))
    }
    private func stepTheCardListsTheAttachmentsOfItsBodyAndLoadsOneOnDemand() async {
        let (model, engine) = await make()
        let info = MailAttachmentInfo(id: "a1", filename: "plan.pdf", mimeType: "application/pdf", sizeBytes: 3)
        engine.bodies["m1"] = MailMessageBody(text: "hi", attachments: [info])
        engine.attachmentData = Data("pdf".utf8)
        await model.open("m1")
        recordEqual(model.cards.first?.attachments, [info])
        let data = await model.attachmentData("m1", attachmentID: "a1")
        recordEqual(data, Data("pdf".utf8))
        recordEqual(engine.actionCalls, ["attachment:m1/a1"])
    }
    private func stepAFailedAttachmentDownloadGivesNoDataButAHint() async {
        let (model, engine) = await make()
        engine.actionError = .provider(Hint(text: "mail.hint.failed"))
        let data = await model.attachmentData("m1", attachmentID: "a1")
        recordNil(data)
        recordEqual(model.actionFailure(for: "m1"), Hint(text: "mail.hint.failed"))
    }
    private func stepTheConversationOfACardComesFromItsThread() async {
        let (model, engine) = await make()
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1", thread: "t9"), fakeMessage("m2")])
        await model.loadSelection()
        engine.threadMessages = [fakeMessage("m0", thread: "t9"), fakeMessage("m1", thread: "t9")]
        await model.open("m1", pin: true)
        await model.open("m2")
        await model.loadThread("m1")
        recordEqual(model.cards.first { $0.id == "m1" }?.conversation.map(\.id), ["m0", "m1"])
        recordEqual(model.cards.first { $0.id == "m2" }?.conversation, [])
        await model.loadThread("m2")
        recordEqual(engine.actionCalls, ["thread:m1/t9", "thread:m2/m2"])
    }
    private func stepAFailedThreadLoadLeavesTheCardAloneAndShowsTheHint() async {
        let (model, engine) = await make()
        await model.open("m1")
        engine.actionError = .provider(Hint(text: "mail.hint.failed"))
        await model.loadThread("m1")
        recordEqual(model.actionFailure(for: "m1"), Hint(text: "mail.hint.failed"))
        recordEqual(model.cards.first?.conversation, [])
    }
    private func newDraft(_ model: MailModel) -> UUID {
        let id = model.compose(to: "z@example.test")!
        model.edit(id) { $0.subject = "Plan" }
        return id
    }
    private func stepSavingWalksFromEditedThroughSavingToSavedWithTheTimeAndKeepsTheServerID() async {
        let (model, engine) = await make()
        let id = newDraft(model)
        recordEqual(model.draft(id)?.state, .edited)
        engine.holdSave = true
        let task = Task { await model.save(id) }
        await Task.yield()
        await Task.yield()
        recordEqual(model.draft(id)?.state, .saving)
        engine.holdSave = false
        engine.release()
        await task.value
        recordEqual(model.draft(id)?.state, .saved(fixed))
        recordEqual(model.draft(id)?.remoteID, "remote-1")
        engine.savedDraftID = "remote-2"
        model.edit(id) { $0.body = "more" }
        await model.save(id)
        recordEqual(engine.savedDrafts.map(\.replacing), [nil, "remote-1"])
        recordEqual(model.draft(id)?.remoteID, "remote-2")
    }
    private func stepAnEditWhileSavingKeepsTheDraftEditedSoTheNewTextIsSavedAgain() async {
        let (model, engine) = await make()
        let id = newDraft(model)
        engine.holdSave = true
        let task = Task { await model.save(id) }
        await Task.yield()
        await Task.yield()
        model.edit(id) { $0.body = "typed while saving" }
        engine.holdSave = false
        engine.release()
        await task.value
        recordEqual(model.draft(id)?.state, .edited)
        recordEqual(model.draft(id)?.remoteID, "remote-1")
    }
    private func stepAFailedSaveReturnsToEditedAndNamesTheFailure() async {
        let (model, engine) = await make()
        let id = newDraft(model)
        engine.actionError = .provider(Hint(text: "mail.hint.offline"))
        await model.save(id)
        recordEqual(model.draft(id)?.state, .edited)
        recordEqual(model.draft(id)?.saveFailure, Hint(text: "mail.hint.offline"))
        recordNil(model.draft(id)?.remoteID)
        engine.actionError = nil
        await model.save(id)
        recordNil(model.draft(id)?.saveFailure)
        recordEqual(model.draft(id)?.state, .saved(fixed))
    }
    private func stepDiscardingASavedDraftDeletesItOnTheServerAndAnUnsavedOneJustGoes() async {
        let (model, engine) = await make()
        let saved = newDraft(model)
        await model.save(saved)
        let unsaved = newDraft(model)
        await model.deleteDraft(unsaved)
        recordNil(model.draft(unsaved))
        recordFalse(engine.actionCalls.contains { $0.hasPrefix("deleteDraft") })
        await model.deleteDraft(saved)
        recordNil(model.draft(saved))
        recordEqual(engine.actionCalls.last, "deleteDraft:remote-1")
    }
    private func stepADraftThatCannotBeDeletedOnTheServerStaysWithTheFailure() async {
        let (model, engine) = await make()
        let id = newDraft(model)
        await model.save(id)
        engine.actionError = .provider(Hint(text: "mail.hint.failed"))
        await model.deleteDraft(id)
        recordNotNil(model.draft(id))
        recordEqual(model.draft(id)?.saveFailure, Hint(text: "mail.hint.failed"))
    }
    private func stepSendingASavedDraftGoesThroughTheDraftAndAnUnsavedOneThroughPlainSend() async {
        let (model, engine) = await make()
        let saved = newDraft(model)
        await model.save(saved)
        await model.send(saved)
        recordEqual(engine.sentFromDraft.map(\.id), ["remote-1"])
        recordEqual(engine.sentFromDraft.first?.draft.subject, "Plan")
        recordTrue(engine.sentDrafts.isEmpty)
        recordEqual(model.draft(saved)?.state, .sent)
        let plain = newDraft(model)
        await model.send(plain)
        recordEqual(engine.sentDrafts.count, 1)
        recordEqual(engine.sentFromDraft.count, 1)
    }
    private func stepOpeningAStoredDraftMakesACardLinkedToTheServerDraftOnlyOnce() async {
        let (model, engine) = await make()
        engine.storedDraft = MailStoredDraft(id: "d7", draft: EmailDraft(to: "a@x.test", subject: "Stored", body: "text"))
        let first = await model.editDraft("m1")
        let second = await model.editDraft("m1")
        recordEqual(first, second)
        recordEqual(model.drafts.count, 1)
        recordEqual(model.draft(first!)?.remoteID, "d7")
        recordEqual(model.draft(first!)?.draft.subject, "Stored")
        recordEqual(model.draft(first!)?.state, .idle)
    }
    private func stepAStoredDraftThatCannotBeLoadedMakesNoCardAndShowsTheHint() async {
        let (model, engine) = await make()
        engine.actionError = .provider(Hint(text: "mail.hint.failed"))
        let id = await model.editDraft("m1")
        recordNil(id)
        recordTrue(model.drafts.isEmpty)
        recordEqual(model.actionFailure(for: "m1"), Hint(text: "mail.hint.failed"))
    }
    func runTheModelActions() async throws {
        await stepArchiveRemovesTheRowClosesTheCardAndCountsAgain()
        await stepArchiveInTheAllFolderKeepsTheRowListed()
        await stepTrashSpamAndMoveEachAskTheEngineAndDropTheRow()
        await stepARefusedActionKeepsTheRowAndTheCardAndShowsTheHint()
        await stepTheCardListsTheAttachmentsOfItsBodyAndLoadsOneOnDemand()
        await stepAFailedAttachmentDownloadGivesNoDataButAHint()
        await stepTheConversationOfACardComesFromItsThread()
        await stepAFailedThreadLoadLeavesTheCardAloneAndShowsTheHint()
        await stepSavingWalksFromEditedThroughSavingToSavedWithTheTimeAndKeepsTheServerID()
        await stepAnEditWhileSavingKeepsTheDraftEditedSoTheNewTextIsSavedAgain()
        await stepAFailedSaveReturnsToEditedAndNamesTheFailure()
        await stepDiscardingASavedDraftDeletesItOnTheServerAndAnUnsavedOneJustGoes()
        await stepADraftThatCannotBeDeletedOnTheServerStaysWithTheFailure()
        await stepSendingASavedDraftGoesThroughTheDraftAndAnUnsavedOneThroughPlainSend()
        await stepOpeningAStoredDraftMakesACardLinkedToTheServerDraftOnlyOnce()
        await stepAStoredDraftThatCannotBeLoadedMakesNoCardAndShowsTheHint()
    }
}

@MainActor
final class ShellSweepTests {
    func runLanesAcrossWindowsAndDrags() throws {
        let g = try Fixture.geometry()
        let rules = AreaRules(minimum: g.minimum)
        let rest = LaneState(rest: g.laneRest)
        for window in [560.0, 640, 700, 800, 900, 1024, 1200, 1512, 2000] {
            var rows: [String] = []
            for lane in Lane.allCases {
                rows.append("\(lane.rawValue)=\(LaneLayout.widths(windowWidth: window, state: LaneLayout.toggleFold(lane: lane, state: rest), geometry: g, rules: rules).all)")
                rows.append("max=\(LaneLayout.widths(windowWidth: window, state: LaneLayout.toggleMaximize(lane: lane, state: rest), geometry: g, rules: rules).all)")
            }
            note("widths", "\(window) \(rows) \(LaneLayout.widths(windowWidth: window, state: rest, geometry: g, rules: rules, foldTrailing: true).all)")
        }
        let starts: [[Double]] = [[280, 896, 280], [56, 1120, 280], [280, 1120, 56], [56, 1344, 56], [400, 712, 400], [280, 500, 700], [700, 500, 280]]
        for start in starts {
            for lane in [Lane.leading, .trailing] {
                var state = LaneState(rest: g.laneRest)
                state.preferred = [start[0], 0, start[2]]
                state.folded = [start[0] <= g.laneFolded, false, start[2] <= g.laneFolded]
                var rows: [String] = []
                for proposed in stride(from: 0.0, through: 1100.0, by: 11) {
                    let next = LaneLayout.drag(lane: lane, proposed: proposed, start: start, state: state, geometry: g, rules: rules)
                    rows.append("\(proposed):\(next.preferred)\(next.folded)\(next.pinned)\(LaneLayout.widths(windowWidth: 1512, state: next, geometry: g, rules: rules).all)")
                }
                note("drag", "\(start) \(lane.rawValue) \(rows.joined(separator: ";"))")
            }
        }
        let center = LaneLayout.drag(lane: .center, proposed: 99, start: starts[0], state: rest, geometry: g, rules: rules)
        note("center", center)
        note("reset", LaneLayout.reset(rest: 280))
        note("fold", LaneLayout.toggleFold(lane: .center, state: LaneLayout.toggleMaximize(lane: .leading, state: rest)))
    }
    func runBlobOverTheWindow() throws {
        let g = try Fixture.geometry()
        for window in [Size(width: 1512, height: 982), Size(width: 800, height: 600)] {
            var rows: [String] = []
            for edge in Edge.allCases {
                for offset in [-50.0, 0, 16, 300, 640, 1600] {
                    let placement = BlobPlacement(edge: edge, offset: offset)
                    let menu = placement.menuOrigin(window: window, geometry: g)
                    rows.append("\(edge.rawValue)\(offset):\(placement.origin(window: window, geometry: g))\(menu.origin)\(menu.opensDownward)")
                }
            }
            note("origins", "\(window.width) \(rows.joined(separator: ";"))")
            var drops: [String] = []
            for x in stride(from: 0.0, through: window.width, by: 100) {
                for y in stride(from: 0.0, through: window.height, by: 100) {
                    for velocity in [Point(x: 0, y: 0), Point(x: 3000, y: 0), Point(x: -3000, y: 0), Point(x: 0, y: 3000), Point(x: 0, y: -3000)] {
                        let placement = BlobPlacement.settle(dropAt: Point(x: x, y: y), velocity: velocity, window: window, geometry: g)
                        drops.append("\(placement.edge.rawValue)\(placement.offset)")
                    }
                }
            }
            note("settle", "\(window.width) \(drops.joined(separator: ";"))")
        }
        let middle = Size(width: 1000, height: 1000)
        var edges: [String] = []
        for offset in stride(from: 0.0, through: 1000, by: 1) {
            let placement = BlobPlacement(edge: .leading, offset: offset)
            edges.append(placement.menuOrigin(window: middle, geometry: g).opensDownward ? "d" : "u")
        }
        note("menu-flip", edges.joined())
        var flips: [String] = []
        for height in stride(from: 300.0, through: 1300, by: 1) {
            let window = Size(width: 1000, height: height)
            flips.append(BlobPlacement(edge: .top, offset: 100).menuOrigin(window: window, geometry: g).opensDownward ? "d" : "u")
        }
        note("menu-height", flips.joined())
    }
    func runCardsAndValues() throws {
        for count in 0...9 { note("tops", "\(count) \(CardStack.tops(count: count))") }
        for depth in -1...8 { note("level", "\(depth) \(CardStack.levelIndex(depth: depth))") }
        let texts = ["", " 12 ", "1e3", "inf", "nan", "-4.5", "12px", " 7 px", "2em", "1.5em", "x em", "300ms", "0.5s", "5", "ms", "s", "10 s"]
        for text in texts {
            note("value", "\(text)|\(String(describing: ValueParsing.number(text)))|\(String(describing: ValueParsing.length(text)))|\(String(describing: ValueParsing.em(text, size: 16)))|\(String(describing: ValueParsing.duration(text)))")
        }
        let calls = ["rgba(1,2,3,0.5)", "rgba(1, 2, 3, 0.5)", "rgba(1,2,3)", "rgba(1,2,x,4)", "rgba(1,2,3,4", "rgb(255,0,128)", "rgb(255,0)", "rgb(1,2,3,4)", "rgb()", "rgb(1,,3)", "rgba(", "(1,2,3)"]
        for text in calls {
            note("args", "\(text)|\(String(describing: ValueParsing.arguments(text, function: "rgb")))|\(String(describing: ValueParsing.arguments(text, function: "rgba")))|\(String(describing: ValueParsing.color(text)))")
        }
        for text in ["#fff", "#FFF", "#abc", "\u{23}ff00ff", "#ff00ff80", "#ff", "#ffff", "#fffff", "#ggg", "#12345g", "#", "fff", " \u{23}000000 ", "#0000000", "#000000000"] {
            note("hex", "\(text)|\(String(describing: ValueParsing.color(text)))")
        }
        for text in ["{a}", "{}", "{ a }", "{a", "a}", " {long.name} ", "{{x}}", "{"] {
            note("alias", "\(text)|\(String(describing: ValueParsing.alias(text)))")
        }
        for text in ["", "a", "a,b", " a , b ", "a,,b", "rgba(1,2,3,4),b", "f(a,(b,c)),d", ",", "((a,b)),(c", "a)),b,c"] {
            note("split", "\(text)|\(ValueParsing.splitTopLevel(text))")
        }
        let shadows = ["0 0 0 1px #000", "inset 0 1px 2px rgba(0,0,0,0.2)", "0 1px 2px \u{23}000000", "1 2 3 4 #fff", "1 #fff", "1 2 3 4 5 #fff", "0 0 0 #fff", "0 0 4 1 {c}", "0 0 0 0 #000", "inset 0 0 0 2px #000", "0 0 1 2 nonsense", "0 0", "inset ", "2px 3px {shadow.color}"]
        for text in shadows {
            let layer = ValueParsing.shadowLayer(text) { _ in RGB(0.1, 0.2, 0.3, 0.4) }
            note("shadow", "\(text)|\(String(describing: layer))|\(String(describing: layer?.isContour))")
        }
    }
    func runTheThemeKnowsItsKeys() throws {
        let theme = try Fixture.theme()
        note("has", ThemeKey.all.map { theme.has($0) })
        note("has-no", theme.has(ThemeKey("nowhere")))
        let json = """
        {"color":{"themes":[{"id":"light"}],"tokens":[
        {"name":"a","value":"{b}"},{"name":"b","value":"{c}"},{"name":"c","value":"\u{23}102030"},{"name":"d","value":{"light":"\u{23}010203","dark":"rgb(4,5,6)"}},
        {"name":"e","value":{"light":"{a}"}}]},
        "type":{"families":{"sans":"Test Sans"},"groups":[{"family":"sans","styles":[{"name":"s1","fontSize":"12px","lineHeight":1.5,"fontWeight":600,"letterSpacing":"0.1em"},{"name":"s2","fontSize":10}]}]}}
        """
        let small = try TokenTheme(data: Data(json.utf8))
        for name in ["a", "b", "c", "d", "e", "none"] {
            note("alias", "\(name) \(small.color(ThemeKey(name), .light)) \(small.color(ThemeKey(name), .dark)) \(small.has(ThemeKey(name)))")
        }
        note("text", "\(String(describing: small.textStyle(TextKey("s1")))) \(String(describing: small.textStyle(TextKey("s2")))) \(small.length(ThemeKey("c")))")
        XCTAssertThrowsError(try TokenTheme(data: Data("[1]".utf8)))
    }
}

private struct ThrowingKeychain: KeychainPort {
    let base: FakeKeychain
    func put(_ value: String, at slot: KeySlot) throws { try base.put(value, at: slot) }
    func get(_ slot: KeySlot) throws -> String? { throw TestTimedOut() }
    func delete(_ slot: KeySlot) throws { try base.delete(slot) }
}

@MainActor
final class HubSweepTests {
    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }
    func runTheTruthFollowsItsInletAcrossARestart() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let first = try ScriptedRig.make(database: database, keychain: keychain)
        let a = try await first.connect("a@x")
        let b = try await first.connect("b@x")
        note("truth-none", first.hub.rules.truth(.mailboxes) == nil)
        first.hub.rules.setTruth(.mailboxes, a.id)
        note("truth-set", first.hub.rules.truth(.mailboxes) == a.id)
        let again = try ScriptedRig.make(database: database, provider: first.provider, keychain: keychain)
        note("truth-restart", again.hub.rules.truth(.mailboxes) == a.id)
        try await again.hub.setup.remove(b.id)
        note("truth-kept", again.hub.rules.truth(.mailboxes) == a.id)
        try await again.hub.setup.remove(a.id)
        note("truth-removed", again.hub.rules.truth(.mailboxes) == nil)
        let third = try ScriptedRig.make(database: database, provider: first.provider, keychain: keychain)
        note("truth-forgotten", third.hub.rules.truth(.mailboxes) == nil)
        note("inlets", third.hub.setup.inlets.count)
    }
    private func hub(_ database: DatabaseQueue, _ provider: FakeProvider, _ keychain: any KeychainPort, _ cadence: HandCadence) throws -> Hub {
        try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [ScriptedRig.mailOffer]), providers: [provider],
            keychain: keychain, cadence: cadence, cost: FakeCost(), catalog: .withMail, database: database))
    }
    func runALostKeychainMarksTheInletAndTheStateIsKept() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let first = try ScriptedRig.make(database: database, keychain: keychain)
        let inlet = try await first.connect("a@x")
        for (name, store) in [("empty", FakeKeychain() as any KeychainPort), ("throwing", ThrowingKeychain(base: keychain) as any KeychainPort)] {
            let cadence = HandCadence()
            let lost = try hub(database, first.provider, store, cadence)
            note(name + "-before", lost.setup.inlets.map(\.state))
            do {
                _ = try lost.access.port(MailTransport.self, for: inlet.id)
                XCTFail("port must throw")
            } catch {
                note(name + "-port", error)
            }
            note(name + "-state", lost.setup.inlets.map(\.state))
            note(name + "-renew", lost.setup.inlets[0].state.canRenew)
            await cadence.trigger(inlet.id, .mail)
            note(name + "-sync", lost.setup.report(for: inlet.id).map(\.ok))
            note(name + "-health", lost.setup.health(of: inlet.id))
            let back = try hub(database, first.provider, keychain, HandCadence())
            note(name + "-restart", back.setup.inlets.map(\.state))
        }
    }
    func runTheCountedCallsAndBytesOfEveryMailCall() async throws {
        let rig = try ScriptedRig.make()
        let inlet = try await rig.connect("a@x")
        let transport = try rig.hub.access.port(MailTransport.self, for: inlet.id)
        func mark(_ name: String) { note("cost-" + name, rig.hub.rules.cost(inlet.id, .all)) }
        rig.provider.mail.setBody(MailMessageBody(text: "abc", html: "<b>defg</b>"))
        _ = try await transport.fetchBody(messageID: "1")
        mark("body")
        rig.provider.mail.setBody(MailMessageBody(text: nil, html: "xy"))
        _ = try await transport.fetchBody(messageID: "1")
        mark("html")
        rig.provider.mail.setBody(MailMessageBody(text: "z", html: nil))
        _ = try await transport.fetchBody(messageID: "1")
        mark("text")
        _ = try await transport.listFolders()
        mark("folders")
        _ = try await transport.listMessages(folderID: "INBOX", query: nil, pageToken: nil, maxResults: 10)
        mark("list")
        try await transport.send(EmailDraft(to: "z@x.test", subject: "s", body: "b"))
        mark("send")
        try await transport.setFlags(messageID: "1", add: [.seen], remove: [])
        mark("flags")
        try await transport.archive(messageID: "1")
        try await transport.move(messageID: "1", toFolderID: "X")
        try await transport.trash(messageID: "1")
        try await transport.markSpam(messageID: "1")
        mark("moves")
        _ = try await transport.fetchAttachment(messageID: "1", attachmentID: "a")
        mark("attachment")
        _ = try await transport.fetchThread(messageID: "1", threadID: "t")
        _ = try await transport.saveDraft(EmailDraft(subject: "s", body: "b"), replacing: nil)
        _ = try await transport.fetchDraft(messageID: "1")
        try await transport.deleteDraft(id: "d")
        try await transport.sendDraft(id: "d")
        mark("drafts")
        note("calls", rig.provider.mail.calls)
        note("cost-other", rig.hub.rules.cost("other", .all))
    }
    func runAFailedRenewalSurvivesARestartAndAnOutageDoesNot() async throws {
        let red = try await scriptedGoogleRig(token: { (400, Data()) })
        let transport = try red.hub.access.port(MailTransport.self, for: red.inlet.id)
        _ = try? await transport.listFolders()
        await waitUntil { red.hub.setup.inlets[0].state.hint != nil }
        note("red-state", red.hub.setup.inlets[0].state)
        let restarted = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [red.offer]), providers: [red.provider],
            keychain: red.keychain, cadence: HandCadence(), cost: FakeCost(), catalog: .withMail, database: red.database))
        note("red-restart", restarted.setup.inlets.map(\.state))
        let outage = try await scriptedGoogleRig(token: { (503, Data()) })
        let other = try outage.hub.access.port(MailTransport.self, for: outage.inlet.id)
        _ = try? await other.listFolders()
        try await Task.sleep(for: .milliseconds(30))
        let again = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [outage.offer]), providers: [outage.provider],
            keychain: outage.keychain, cadence: HandCadence(), cost: FakeCost(), catalog: .withMail, database: outage.database))
        note("outage-restart", again.setup.inlets.map(\.state))
    }
    func runTheTokenIsRenewedWithinASixtySecondMargin() async throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        for advance in [3500.0, 3539, 3540, 3541, 3599, 3600, 3601, 7200] {
            let rig = try await scriptedGoogleRig(token: { (200, Data(#"{"access_token":"fresh","expires_in":3600}"#.utf8)) }, start: base, advance: advance)
            let before = GoogleStubNet.requests.count
            let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
            _ = try await transport.listFolders()
            let paths = GoogleStubNet.requests.dropFirst(before).map { $0.path }
            await waitUntil { (try? rig.keychain.get(KeySlot(inlet: rig.inlet.id, name: "accessToken"))) == "fresh" || advance < 3540 }
            note("margin-\(advance)", "\(paths) \(String(describing: try rig.keychain.get(KeySlot(inlet: rig.inlet.id, name: "accessToken"))))")
        }
    }
}

@MainActor
final class MailSweepTests {
    private func make(_ ids: [String], folders: [MailFolder]? = nil) -> (MailModel, ModelFakeEngine) {
        let engine = ModelFakeEngine()
        engine.accounts = ids.map { fakeAccount($0) }
        for id in ids {
            engine.folderList[id] = folders ?? [MailFolder(id: "SENT", name: "Sent", role: .sent), MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        }
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1"), fakeMessage("m2"), fakeMessage("m3", flags: [.seen])])
        return (MailModel(engine: engine, clock: { Date(timeIntervalSince1970: 5_000) }), engine)
    }
    private func look(_ model: MailModel) -> String {
        "\(model.selectedInlet ?? "-")|\(model.selectedFolder ?? "-")|\(model.summaries.map(\.id))|\(model.folders.map(\.id))|\(model.listState)|\(model.unread.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" })|\(model.cards.map(\.id))|\(model.selectedMessage ?? "-")"
    }
    func runAddressesSplitAndReduce() {
        let texts = ["", "a@x.test", "A <A@X.test>", "a@x.test, b@x.test", "\"Berg, Anna\" <anna@x.test>, bob@x.test", "x <a@x.test", "a>b<c", "<>", " <A@x> ,, ", "n <a@x.test>, \"q <z@x.test\", w", "a<b>c<d>"]
        for text in texts {
            let parts = MailAddresses.split(text)
            note("addresses", "\(text)|\(parts)|\(parts.map { MailAddresses.email($0) })|\(MailAddresses.email(text))")
        }
        note("plain", MailText.plain("<p>One</p><p>Two &amp; <b>three</b></p><style>x{}</style>"))
    }
    func runTheSelectionSurvivesTheLossOfAnAccount() async {
        let (model, engine) = make(["a", "b", "c", "d"])
        await model.start()
        note("start", look(model))
        await model.selectAccount("c")
        note("select", look(model))
        await model.selectAccount("zzz")
        note("select-unknown", look(model))
        engine.accounts = engine.accounts.filter { $0.id != "c" }
        await model.handle(.accountsChanged)
        note("remove-selected", look(model))
        engine.accounts = engine.accounts.filter { $0.id != "d" }
        await model.handle(.accountsChanged)
        note("remove-other", look(model))
        engine.accounts = engine.accounts.filter { $0.id != "a" }
        model.refreshAccounts()
        note("remove-first", look(model))
        engine.accounts = []
        await model.handle(.accountsChanged)
        note("remove-all", look(model))
        engine.accounts = [fakeAccount("e"), fakeAccount("f")]
        engine.folderList["e"] = [MailFolder(id: "X", name: "X", role: .other), MailFolder(id: "Y", name: "Y", role: .spam)]
        await model.handle(.accountsChanged)
        note("add", look(model))
        await model.start()
        note("restart", look(model))
        await model.refreshFolders()
        note("folders", look(model))
    }
    func runEventsReachTheListOnlyWhereTheyBelong() async {
        let (model, engine) = make(["a", "b"])
        await model.start()
        engine.mirror["aINBOX"] = [fakeMessage("n1"), fakeMessage("m1", flags: [.seen])]
        engine.mirror["bINBOX"] = [fakeMessage("o1")]
        engine.mirror["aSENT"] = [fakeMessage("s1")]
        engine.unread = ["a": 4, "b": 9]
        let events: [MailEngineEvent] = [
            .foldersChanged("b"), .foldersChanged("a"), .messagesChanged("b", folder: "INBOX"), .messagesChanged("a", folder: "SENT"),
            .messagesChanged("a", folder: "INBOX"), .newMail("b", count: 1), .newMail("a", count: 2), .outboxChanged,
            .syncFailed("b", Hint(text: "x")), .syncFailed("a", Hint(text: MailTextKey.offline.rawValue)), .syncFailed("a", Hint(text: "x"))
        ]
        for event in events {
            await model.handle(event)
            note("event", "\(event) \(look(model)) \(model.outbox.count)")
        }
        await model.selectFolder("SENT")
        engine.mirror["aSENT"] = [fakeMessage("s2"), fakeMessage("s1")]
        for event in [MailEngineEvent.newMail("a", count: 1), .messagesChanged("a", folder: "SENT")] {
            await model.handle(event)
            note("sent", "\(event) \(look(model))")
        }
        await model.search("s")
        await model.handle(.messagesChanged("a", folder: "SENT"))
        note("search-keeps", look(model))
        let settled = model.listState
        model.stop()
        note("stopped", settled)
    }
    func runTheCardsKeepTheLastOpenOneSelected() async {
        let (model, _) = make(["a"])
        await model.start()
        for id in ["m1", "m2", "m3"] { await model.open(id, pin: true) }
        note("opened", look(model))
        model.close("m3")
        note("close-selected", look(model))
        await model.open("m3", pin: true)
        model.close("m2")
        note("close-middle", look(model))
        await model.open("m2", pin: true)
        model.close("m1")
        note("close-first", look(model))
        model.close("none")
        model.close("m3")
        model.close("m2")
        note("close-all", look(model))
        model.setCardLimit(0)
        note("limit", model.cardLimit)
    }
    func runTheFoldersAreOrderedByRole() async {
        let roles: [MailFolderRole] = [.other, .trash, .spam, .archive, .all, .drafts, .sent, .starred, .inbox]
        let folders = roles.enumerated().map { MailFolder(id: "F\($0.offset)", name: "n\($0.offset)", role: $0.element) }
        let (model, _) = make(["a"], folders: folders)
        await model.start()
        note("order", model.sortedFolders.map(\.id))
        note("picked", model.selectedFolder ?? "-")
        let (plain, _) = make(["a"], folders: [MailFolder(id: "Z", name: "z", role: .other), MailFolder(id: "Y", name: "y", role: .trash)])
        await plain.start()
        note("no-inbox", "\(plain.sortedFolders.map(\.id)) \(plain.selectedFolder ?? "-")")
    }
}

@MainActor
final class GapTests {
    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }
    func runProbesPersistTheirOutcome() async throws {
        let database = try DatabaseQueue()
        let keychain = FakeKeychain()
        let rig = try ScriptedRig.make(database: database, keychain: keychain)
        let inlet = try await rig.connect("a@x")
        rig.provider.setAccepting(false)
        _ = try? await rig.hub.setup.probe(inlet.id)
        let failed = try ScriptedRig.make(database: database, provider: rig.provider, keychain: keychain)
        note("failed-restart", failed.hub.setup.inlets.map(\.state))
        rig.provider.setAccepting(true)
        _ = try await rig.hub.setup.probe(inlet.id)
        note("green", rig.hub.setup.inlets.map(\.state))
        let green = try ScriptedRig.make(database: database, provider: rig.provider, keychain: keychain)
        note("green-restart", green.hub.setup.inlets.map(\.state))
        let lostDatabase = try DatabaseQueue()
        let lostRig = try ScriptedRig.make(database: lostDatabase, keychain: keychain)
        let other = try await lostRig.connect("b@x")
        let lost = try ScriptedRig.make(database: lostDatabase, provider: lostRig.provider, keychain: FakeKeychain())
        do {
            _ = try await lost.hub.setup.probe(other.id)
            XCTFail("probe must throw")
        } catch {
            note("lost-probe", error)
        }
        note("lost-state", lost.hub.setup.inlets.map(\.state))
        let back = try ScriptedRig.make(database: lostDatabase, provider: lostRig.provider, keychain: keychain)
        note("lost-restart", back.hub.setup.inlets.map(\.state))
        do {
            _ = try await back.hub.setup.probe("nowhere")
        } catch {
            note("unknown-probe", error)
        }
    }
    func runTheSyncReportCountsItsItems() async throws {
        let rig = try ScriptedRig.make()
        let inlet = try await rig.connect("a@x")
        await rig.cadence.trigger(inlet.id, .mail)
        for await report in rig.cadence.reports {
            note("report", report)
            break
        }
        let other = try await rig.connect("b@x")
        note("second", other.id != inlet.id)
        await rig.cadence.trigger(other.id, .mail)
        for await report in rig.cadence.reports {
            note("report-two", report)
            break
        }
        await rig.cadence.trigger("nowhere", .mail)
        for await report in rig.cadence.reports {
            note("report-none", report)
            break
        }
    }
    func runAnExpiredSignInIsKeptThroughAFailingSync() async throws {
        let rig = try await scriptedGoogleRig(token: { (400, Data()) })
        await rig.cadence.trigger(rig.inlet.id, .mail)
        for await report in rig.cadence.reports {
            note("report", report)
            break
        }
        await waitUntil { rig.hub.setup.inlets[0].state.hint != nil }
        note("state", rig.hub.setup.inlets.map(\.state))
        note("log", rig.hub.setup.report(for: rig.inlet.id).map { "\($0.event) \($0.ok) \(String(describing: $0.kind))" })
        note("health", rig.hub.setup.health(of: rig.inlet.id))
    }
    func runAnUnwritableKeychainFailsTheRenewal() async throws {
        let keychain = FakeKeychain()
        let rig = try await scriptedGoogleRig(token: { (200, Data(#"{"access_token":"fresh","expires_in":3600}"#.utf8)) }, keychain: keychain)
        keychain.setFailing(true)
        let transport = try rig.hub.access.port(MailTransport.self, for: rig.inlet.id)
        _ = try await transport.listFolders()
        await waitUntil { rig.hub.setup.inlets[0].state.hint != nil }
        note("state", rig.hub.setup.inlets.map(\.state.hint?.text))
        let restarted = try Hub.make(HubConfiguration(
            person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [rig.offer]), providers: [rig.provider],
            keychain: keychain, cadence: HandCadence(), cost: FakeCost(), catalog: .withMail, database: rig.database))
        note("restart", restarted.setup.inlets.map(\.state.hint?.text))
    }
    func runAConnectionNeedsAUserAndTakesTheAddressAsDefault() {
        var values = IMAPProviderTests.gmx
        for username in ["", "  ", "other@gmx.example", " spaced "] {
            values["username"] = username
            values["name"] = "Jo\u{7}\nBerger"
            note("connection", (try? IMAPConnection(values: values)) as Any)
        }
        values["username"] = nil
        note("no-user", (try? IMAPConnection(values: values)) as Any)
    }
    func runTheReplyFollowsTheOwnAddress() async {
        for own in ["me@x.test", "ME@X.test", ""] {
            let engine = ModelFakeEngine()
            engine.accounts = [fakeAccount("a", address: own)]
            engine.folderList["a"] = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
            engine.pages[nil] = MailMessagePage(messages: [
                fakeMessage("mine", from: "Me <me@x.test>"), fakeMessage("theirs"), fakeMessage("blank", from: "")])
            let model = MailModel(engine: engine)
            await model.start()
            for id in ["mine", "theirs", "blank"] {
                for all in [false, true] {
                    if let draft = await model.reply(to: id, all: all) {
                        let card = model.draft(draft)?.draft
                        note("reply", "\(own)|\(id)|\(all)|\(String(describing: card?.to))|\(String(describing: card?.cc))")
                    }
                }
            }
        }
    }
    func runTheCardsStartCollapsedAndPagingNeedsASettledList() async {
        let engine = ModelFakeEngine()
        engine.accounts = [fakeAccount("a")]
        engine.folderList["a"] = [MailFolder(id: "INBOX", name: "Inbox", role: .inbox)]
        engine.pages[nil] = MailMessagePage(messages: [fakeMessage("m1")], nextPageToken: "t2")
        engine.pages["t2"] = MailMessagePage(messages: [fakeMessage("m2")])
        let model = MailModel(engine: engine)
        note("before", "\(model.canLoadMore)")
        await model.start()
        await model.open("m1")
        let card = model.cards[0]
        note("card", "\(card.quoteCollapsed) \(card.signatureCollapsed) \(card.remoteImagesAllowed)")
        note("settled", "\(model.canLoadMore) \(model.listState)")
        engine.pageError = .provider(Hint(text: "hint.x"))
        await model.loadSelection()
        note("failed", "\(model.canLoadMore) \(model.nextPageToken ?? "-") \(model.listState)")
        engine.pageError = .provider(Hint(text: MailTextKey.offline.rawValue))
        await model.loadSelection()
        note("offline", "\(model.canLoadMore) \(model.nextPageToken ?? "-") \(model.listState)")
        engine.pageError = nil
        engine.holdPages = true
        let task = Task { await model.loadSelection() }
        await Task.yield()
        await Task.yield()
        note("loading", "\(model.canLoadMore) \(model.nextPageToken ?? "-") \(model.listState)")
        engine.holdPages = false
        engine.release()
        await task.value
        note("after", "\(model.canLoadMore) \(model.listState)")
        await model.loadSelection()
        await model.handle(.syncFailed("a", Hint(text: "hint.x")))
        note("sync-failed", "\(model.canLoadMore) \(model.nextPageToken ?? "-") \(model.listState)")
    }
    func runAnEmptyGrantAndAGenericProbeFailureAreKept() async throws {
        let emptyDatabase = try DatabaseQueue()
        let emptyKeychain = FakeKeychain()
        let emptyProvider = FakeProvider(capabilities: [.mail], signIn: GivenSignIn(grant: Grant(values: [:])))
        let first = try ScriptedRig.make(database: emptyDatabase, provider: emptyProvider, keychain: emptyKeychain)
        let inlet = try await first.connect("a@x")
        let empty = try ScriptedRig.make(database: emptyDatabase, provider: emptyProvider, keychain: emptyKeychain)
        do {
            _ = try empty.hub.access.port(MailTransport.self, for: inlet.id)
            note("empty-port", "ok")
        } catch {
            note("empty-port", error)
        }
        note("empty-state", empty.hub.setup.inlets.map(\.state))
        let database = try DatabaseQueue()
        let working = Locked(true)
        let config = { (database: DatabaseQueue) in
            try Hub.make(HubConfiguration(
                person: Person(id: "p1", name: "P"), company: CompanySetup(offers: [IMAPProviderTests.offer]), providers: [IMAPProvider(probeRun: { _, _ in
                    if !working.with({ $0 }) { throw MailProbeError(step: .incoming, reason: .authenticationRejected("NO x")) }
                })], keychain: FakeKeychain(), cadence: HandCadence(), cost: FakeCost(), catalog: .withMail, database: database))
        }
        let hub = try config(database)
        let imap = try await hub.setup.add(IMAPProviderTests.offer, input: .fields(IMAPProviderTests.gmx))
        working.with { $0 = false }
        _ = try? await hub.setup.probe(imap.id)
        note("imap-failed", hub.setup.inlets.map(\.state.hint?.text))
        let restarted = try config(database)
        note("imap-restart", restarted.setup.inlets.map(\.state.hint?.text))
    }
    func runNewMailIsCountedOnlyWhenThereIsSome() async throws {
        let hub = HubDouble()
        let transport = hub.add("one")
        transport.folders = scriptedInbox
        let core = try MailCore(hub: hub, database: DatabaseQueue())
        var seen: [MailEngineEvent] = []
        let stream = core.events
        let collector = Task { for await event in stream { seen.append(event) } }
        defer { collector.cancel() }
        try await core.refreshFolders("one")
        transport.setTokenPage(nil, MailMessagePage(messages: [message("1"), message("2")]))
        hub.push(.syncFinished(.mail, "one"))
        _ = await eventually { core.lastSync("one", folder: "INBOX") != nil }
        let rounds: [(String, [MailMessageSummary])] = [
            ("same", [message("1"), message("2")]), ("seen", [message("1"), message("2"), message("3", seen: true)]),
            ("fresh", [message("4"), message("1"), message("2")]), ("two", [message("5"), message("6"), message("4")])]
        for (name, messages) in rounds {
            transport.setTokenPage(nil, MailMessagePage(messages: messages))
            let before = seen.count
            hub.push(.syncFinished(.mail, "one"))
            _ = await eventually { core.messages("one", folder: "INBOX").count >= messages.count || name == "same" }
            try await Task.sleep(for: .milliseconds(40))
            note("round", "\(name) \(seen.dropFirst(before)) \(core.unreadCount("one"))")
        }
    }
    func runTheShellModelStartsClosedAndTogglesGroups() throws {
        let model = ShellModel(directory: try Fixture.directory(), geometry: try Fixture.geometry(), window: Fixture.screen)
        note("start", "\(model.menuOpen) \(model.assistantOpen) \(model.hovering) \(model.openGroups.sorted()) \(model.phase) \(model.currentID)")
        let groups = try Fixture.directory().groups
        for group in groups {
            note("group", "\(group.id) \(model.isGroupOpen(group))")
            model.toggleGroup(group)
            note("opened", "\(group.id) \(model.isGroupOpen(group)) \(model.openGroups.sorted())")
            model.toggleGroup(group)
            note("closed", "\(group.id) \(model.isGroupOpen(group)) \(model.openGroups.sorted())")
        }
        model.toggleAssistant()
        model.setHovering(true)
        note("assistant", "\(model.assistantOpen) \(model.menuOpen) \(model.hovering) \(model.phase)")
        model.closeAssistant()
        model.toggleMenu()
        model.toggleAssistant()
        model.resize(Size(width: 900, height: 700))
        note("resized", "\(model.window) \(model.widths.all) \(model.blobOrigin) \(model.menuOpen) \(model.assistantOpen)")
        model.dropBlob(center: Point(x: 100, y: 600), velocity: Point(x: 0, y: 0))
        model.resetLane(.leading)
        model.toggleMaximize(.center)
        model.endLaneDrag()
        note("snapshot", model.snapshot)
    }
    func runShadowTokensResolveByMode() throws {
        let json = """
        {"color":{"themes":[{"id":"light"}],"tokens":[
        {"name":"c","value":"\u{23}102030"},
        {"name":"one","value":"0 1px 2px \u{23}aabbcc"},
        {"name":"two","value":"0 1px 2px \u{23}aabbcc, inset 0 0 0 1px {c}"},
        {"name":"none","value":" none "},
        {"name":"empty","value":""},
        {"name":"bad","value":"0 1px 2px nonsense"},
        {"name":"half","value":"0 1px 2px \u{23}aabbcc, nonsense"},
        {"name":"modes","value":{"light":"0 0 0 1px \u{23}000000","dark":"none"}}]},
        "type":{"families":{},"groups":[]}}
        """
        let theme = try TokenTheme(data: Data(json.utf8))
        for name in ["one", "two", "none", "empty", "bad", "half", "modes", "absent"] {
            note("shadow", "\(name) \(theme.shadow(ThemeKey(name), .light)) \(theme.shadow(ThemeKey(name), .dark))")
        }
    }
    func runTheTaskRaceEndsOnceAndExpires() async throws {
        let quick = try await Deadline.run(.seconds(5)) { 7 }
        note("quick", quick)
        do {
            _ = try await Deadline.run(.milliseconds(30)) { () -> Int in
                try await Task.sleep(for: .seconds(5))
                return 1
            }
        } catch {
            note("slow", error is DeadlineExpired)
        }
        do {
            _ = try await Deadline.run(.seconds(5)) { () -> Int in throw TestTimedOut() }
        } catch {
            note("throws", error is TestTimedOut)
        }
        let task = Task { try await Deadline.run(.seconds(5)) { () -> Int in
            try await Task.sleep(for: .seconds(5))
            return 2
        } }
        try await Task.sleep(for: .milliseconds(30))
        task.cancel()
        do {
            _ = try await task.value
        } catch {
            note("cancelled", error is CancellationError)
        }
    }
}

@MainActor
func step(_ name: String, _ body: () async throws -> Void) async throws {
    protocolStep.with { $0 = name }
    try await body()
}

final class WholeAppTests: XCTestCase {
    @MainActor
    func testTheWholeApp() async throws {
        protocolLog.with { $0 = [] }
        try await step("DesignTests.runTheShellGeometryReadsTheDeliveredSheet") { try DesignTests().runTheShellGeometryReadsTheDeliveredSheet() }
        try await step("ThemeTests.runRealSourceHasEveryGeneratedKey") { try ThemeTests().runRealSourceHasEveryGeneratedKey() }
        try await step("ThemeTests.runRemovedTokenIsMagentaAndListed") { try ThemeTests().runRemovedTokenIsMagentaAndListed() }
        try await step("ThemeTests.runValuesParse") { try ThemeTests().runValuesParse() }
        try await step("ThemeTests.runBrokenAliasesAreMagenta") { try ThemeTests().runBrokenAliasesAreMagenta() }
        try await step("ThemeTests.runShellMeasuresComeFromTheDataFile") { try ThemeTests().runShellMeasuresComeFromTheDataFile() }
        try await step("ThemeTests.runMissingMeasureFailsLoading") { try ThemeTests().runMissingMeasureFailsLoading() }
        try await step("SettingsTests.runTheSettingsWordsAreInTheCatalogAndTheTokenSheetCarriesItsStamp") { try SettingsTests().runTheSettingsWordsAreInTheCatalogAndTheTokenSheetCarriesItsStamp() }
        try await step("LayoutTests.runTheLanesFollowTheAccordionOfTheDeliveredShell") { try LayoutTests().runTheLanesFollowTheAccordionOfTheDeliveredShell() }
        try await step("BlobTests.runHomeSitsInTheStripAtTheMargin") { try BlobTests().runHomeSitsInTheStripAtTheMargin() }
        try await step("BlobTests.runThrowSettlesAtTheNearestEdge") { try BlobTests().runThrowSettlesAtTheNearestEdge() }
        try await step("BlobTests.runMenuOpensBelowAtTheTopAndAboveAtTheBottom") { try BlobTests().runMenuOpensBelowAtTheTopAndAboveAtTheBottom() }
        try await step("ShellModelTests.runDirectoryDrivesTheMenuAndSearch") { try ShellModelTests().runDirectoryDrivesTheMenuAndSearch() }
        try await step("ShellModelTests.runSelectClosesTheMenuAndKeepsLaneStatePerArea") { try ShellModelTests().runSelectClosesTheMenuAndKeepsLaneStatePerArea() }
        try await step("ShellModelTests.runAssistantExcludesTheMenuAndSnapshotRoundTrips") { try ShellModelTests().runAssistantExcludesTheMenuAndSnapshotRoundTrips() }
        try await step("HubTests.runStartsEmptyAndNothingThrows") { try HubTests().runStartsEmptyAndNothingThrows() }
        try await step("HubTests.runRejectedProbeLeavesNothingBehind") { try await HubTests().runRejectedProbeLeavesNothingBehind() }
        try await step("HubTests.runAcceptedProbeConnectsAndPortsFollowCapabilities") { try await HubTests().runAcceptedProbeConnectsAndPortsFollowCapabilities() }
        try await step("HubTests.runFourthMailAccountNeedsALargerLimit") { try await HubTests().runFourthMailAccountNeedsALargerLimit() }
        try await step("HubTests.runCadenceRunsOnePairOnceAndCountsTheCall") { try await HubTests().runCadenceRunsOnePairOnceAndCountsTheCall() }
        try await step("HubTests.runRemoveKeepsTheKeysOfTheOtherInlet") { try await HubTests().runRemoveKeepsTheKeysOfTheOtherInlet() }
        try await step("HubTests.runRemoveTurnsTheCadenceOfTheInletOff") { try await HubTests().runRemoveTurnsTheCadenceOfTheInletOff() }
        try await step("SetupFlowTests.runCancelDuringTheProbe") { try await SetupFlowTests().runCancelDuringTheProbe() }
        try await step("SetupFlowTests.runInletOfAMissingProvider") { try await SetupFlowTests().runInletOfAMissingProvider() }
        try await step("SetupFlowTests.runOneCorruptSettingRowStopsTheWholeHub") { try SetupFlowTests().runOneCorruptSettingRowStopsTheWholeHub() }
        try await step("IMAPProviderTests.runPresetGMXFillsServerAndPorts") { try IMAPProviderTests().runPresetGMXFillsServerAndPorts() }
        try await step("IMAPProviderTests.runPresetsWithoutGmailAndOutlook") { try IMAPProviderTests().runPresetsWithoutGmailAndOutlook() }
        try await step("IMAPProviderTests.runSignInRejectsNone") { try await IMAPProviderTests().runSignInRejectsNone() }
        try await step("IMAPProviderTests.runSignInChecksPasswordAndPortAndKeepsThePasswordInTheGrant") { try await IMAPProviderTests().runSignInChecksPasswordAndPortAndKeepsThePasswordInTheGrant() }
        try await step("IMAPProviderTests.runProbeIsGreenWhenTheRunSucceedsAndHandsOverTheAccount") { try await IMAPProviderTests().runProbeIsGreenWhenTheRunSucceedsAndHandsOverTheAccount() }
        try await step("IMAPProviderTests.runProbeNamesTheServerAnswerOfTheFailedStep") { try await IMAPProviderTests().runProbeNamesTheServerAnswerOfTheFailedStep() }
        try await step("IMAPProviderTests.runAdapterDeliversAMailTransportWithoutTouchingTheNetwork") { try IMAPProviderTests().runAdapterDeliversAMailTransportWithoutTouchingTheNetwork() }
        try await step("IMAPProviderTests.runHubStoresThePasswordInTheKeychainAfterAGreenProbe") { try await IMAPProviderTests().runHubStoresThePasswordInTheKeychainAfterAGreenProbe() }
        try await step("IMAPProviderTests.runHubKeepsNothingAfterARedProbe") { try await IMAPProviderTests().runHubKeepsNothingAfterARedProbe() }
        try await step("IMAPProviderTests.runSenderNameOfTheTransportIsTheFormValue") { try await IMAPProviderTests().runSenderNameOfTheTransportIsTheFormValue() }
        try await step("IMAPProviderTests.runAddressWithInnerSpaceIsRejected") { IMAPProviderTests().runAddressWithInnerSpaceIsRejected() }
        try await step("GoogleProviderTests.runGoogleProviderDeliversMailTransportAfterGreenProbe") { try await GoogleProviderTests().runGoogleProviderDeliversMailTransportAfterGreenProbe() }
        try await step("GoogleProviderTests.runRedProbeFailsAndLeavesNothingInTheKeychain") { try await GoogleProviderTests().runRedProbeFailsAndLeavesNothingInTheKeychain() }
        try await step("GoogleProviderTests.runRedLabelsProbeNamesTheStatus") { try await GoogleProviderTests().runRedLabelsProbeNamesTheStatus() }
        try await step("GoogleProviderTests.runClientConfigLoadsFromFile") { try GoogleProviderTests().runClientConfigLoadsFromFile() }
        try await step("GoogleRenewalTests.runGreenRenewalWritesTheNewGrantIntoTheSlotsOfThisInlet") { try await GoogleRenewalTests().runGreenRenewalWritesTheNewGrantIntoTheSlotsOfThisInlet() }
        try await step("GoogleRenewalTests.runRedRenewalMarksTheInletExpiredAndPortThrows") { try await GoogleRenewalTests().runRedRenewalMarksTheInletExpiredAndPortThrows() }
        try await step("GoogleRenewalTests.runServerOutageDuringRenewalKeepsTheInletConnected") { try await GoogleRenewalTests().runServerOutageDuringRenewalKeepsTheInletConnected() }
        try await step("GoogleRenewalTests.runSyncAfterServerOutageOnRenewalKeepsTheInletConnected") { try await GoogleRenewalTests().runSyncAfterServerOutageOnRenewalKeepsTheInletConnected() }
        try await step("RenewTests.runFailedInletIsRenewedInPlace") { try await RenewTests().runFailedInletIsRenewedInPlace() }
        try await step("RenewTests.runConnectedInletStillRefusesTheSameAccount") { try await RenewTests().runConnectedInletStillRefusesTheSameAccount() }
        try await step("FailureTests.runGmailKeepsStatusReasonTextAndBody") { FailureTests().runGmailKeepsStatusReasonTextAndBody() }
        try await step("FailureTests.runGmailTableOfTheGoogleErrorPage") { FailureTests().runGmailTableOfTheGoogleErrorPage() }
        try await step("FailureTests.runOAuthKeepsErrorAndDescription") { FailureTests().runOAuthKeepsErrorAndDescription() }
        try await step("FailureTests.runImapKeepsResponseCodeAndServerText") { FailureTests().runImapKeepsResponseCodeAndServerText() }
        try await step("FailureTests.runSmtpKeepsReplyCodeEnhancedCodeAndText") { FailureTests().runSmtpKeepsReplyCodeEnhancedCodeAndText() }
        try await step("FailureTests.runHealthFollowsTheDocumentedCases") { try await FailureTests().runHealthFollowsTheDocumentedCases() }
        try await step("FailureTests.runReportKeepsTheOriginalAcrossARestart") { try await FailureTests().runReportKeepsTheOriginalAcrossARestart() }
        try await step("FailureTests.runReportIsLimitedPerInlet") { try await FailureTests().runReportIsLimitedPerInlet() }
        try await step("FailureTests.runSignInDeadlineEndsWithTheSignInTimeout") { try await FailureTests().runSignInDeadlineEndsWithTheSignInTimeout() }
        try await step("AdapterTimerTests.runIntervalTriggersExactlyOnceAfterTheTick") { try await AdapterTimerTests().runIntervalTriggersExactlyOnceAfterTheTick() }
        try await step("AdapterTimerTests.runSecondTriggerDuringARunIsSkipped") { try await AdapterTimerTests().runSecondTriggerDuringARunIsSkipped() }
        try await step("AdapterTimerTests.runReplanningWithOffStopsTheTimer") { try await AdapterTimerTests().runReplanningWithOffStopsTheTimer() }
        try await step("AdapterCostTests.runSumsPerDayAndInlet") { try AdapterCostTests().runSumsPerDayAndInlet() }
        try await step("AdapterCostTests.runRowsAreKeptPerInletCapabilityAndDay") { try AdapterCostTests().runRowsAreKeptPerInletCapabilityAndDay() }
        try await step("AdapterCostTests.runSurvivesReopeningTheSameDatabase") { try AdapterCostTests().runSurvivesReopeningTheSameDatabase() }
        try await step("AdapterKeychainTests.runServiceNameFollowsPrefixAndInlet") { AdapterKeychainTests().runServiceNameFollowsPrefixAndInlet() }
        try await step("AdapterKeychainTests.runSlotsOfOneInletShareTheServiceAndDifferInAccount") { AdapterKeychainTests().runSlotsOfOneInletShareTheServiceAndDifferInAccount() }
        try await step("ModelTextTests.runPlainTextUsesTheSharedConverter") { ModelTextTests().runPlainTextUsesTheSharedConverter() }
        try await step("CatalogTests.runEveryStateOfTheMailModuleHasATextInTheCatalog") { try CatalogTests().runEveryStateOfTheMailModuleHasATextInTheCatalog() }
        try await step("CoreTests.runAccountsAndFoldersComeFromTheHub") { try await CoreTests().runAccountsAndFoldersComeFromTheHub() }
        try await step("CoreTests.runNotConnectedSurfacesAsHubError") { try await CoreTests().runNotConnectedSurfacesAsHubError() }
        try await step("CoreTests.runLoadPageFillsMirror") { try await CoreTests().runLoadPageFillsMirror() }
        try await step("CoreTests.runSendWithoutNetworkQueuesAndRetrySends") { try await CoreTests().runSendWithoutNetworkQueuesAndRetrySends() }
        try await step("CoreTests.runOutboxSurvivesAReopenedDatabase") { try await CoreTests().runOutboxSurvivesAReopenedDatabase() }
        try await step("CoreTests.runRejectionStaysFailedAndIsNotRetried") { try await CoreTests().runRejectionStaysFailedAndIsNotRetried() }
        try await step("CoreTests.runUnreadCountPerAccount") { try await CoreTests().runUnreadCountPerAccount() }
        try await step("CoreTests.runSyncFinishedBringsNewMailAndRetriesOutbox") { try await CoreTests().runSyncFinishedBringsNewMailAndRetriesOutbox() }
        try await step("CoreTests.runSyncFailureKeepsLastStateAndReports") { try await CoreTests().runSyncFailureKeepsLastStateAndReports() }
        try await step("CoreTests.runGmailHttpErrorsAreClassified") { CoreTests().runGmailHttpErrorsAreClassified() }
        try await step("CoreTests.runSendAgainAfterARejectionLeavesTheFailedItemInTheOutbox") { try await CoreTests().runSendAgainAfterARejectionLeavesTheFailedItemInTheOutbox() }
        try await step("CoreTests.runOutboxItemOfARemovedAccountWaitsForever") { try await CoreTests().runOutboxItemOfARemovedAccountWaitsForever() }
        try await step("CoreTests.runRejectedSignInIsShownAsExpiredSignIn") { try await CoreTests().runRejectedSignInIsShownAsExpiredSignIn() }
        try await step("CoreTests.runLocalSearchMatchesTheTextAsTyped") { try await CoreTests().runLocalSearchMatchesTheTextAsTyped() }
        try await step("CoreTests.runAMailSentFromTheOutboxIsGoneAfterAReopen") { try await CoreTests().runAMailSentFromTheOutboxIsGoneAfterAReopen() }
        try await step("CoreTests.runLocalSearchListsTheNewestHitsFirst") { try await CoreTests().runLocalSearchListsTheNewestHitsFirst() }
        try await step("CoreActionTests.runTheCoreActions") { try await CoreActionTests().runTheCoreActions() }
        try await step("CoreModelTests.runModelOverCoreShowsOfflineWhenTheNetworkDrops") { try await CoreModelTests().runModelOverCoreShowsOfflineWhenTheNetworkDrops() }
        try await step("AccountTests.runRemovingTheSelectedAccountLetsLoadMoreUseTheTokenOfTheOldOne") { await AccountTests().runRemovingTheSelectedAccountLetsLoadMoreUseTheTokenOfTheOldOne() }
        try await step("AccountTests.runRemovingTheOnlyAccountStillListsItsRows") { await AccountTests().runRemovingTheOnlyAccountStillListsItsRows() }
        try await step("AccountTests.runLoadMoreOfTheOldAccountLandsInTheNewAccountWhileItsFoldersLoad") { await AccountTests().runLoadMoreOfTheOldAccountLandsInTheNewAccountWhileItsFoldersLoad() }
        try await step("AccountTests.runOneRejectedLoadMoreEndsPagingUntilTheFolderIsSelectedAgain") { try await AccountTests().runOneRejectedLoadMoreEndsPagingUntilTheFolderIsSelectedAgain() }
        try await step("AccountTests.runRowsRemovedOnTheServerStayInTheListAfterASync") { try await AccountTests().runRowsRemovedOnTheServerStayInTheListAfterASync() }
        try await step("AccountTests.runAccountAddedLaterIsNotSelectedWhenNothingIsSelected") { await AccountTests().runAccountAddedLaterIsNotSelectedWhenNothingIsSelected() }
        try await step("SetupTests.runOffersDependOnTheGoogleConfiguration") { let item = SetupTests(); try item.runOffersDependOnTheGoogleConfiguration(); item.cleanup() }
        try await step("SetupTests.runAssemblyIsUsableWithoutAnyInlet") { let item = SetupTests(); try item.runAssemblyIsUsableWithoutAnyInlet(); item.cleanup() }
        try await step("SetupTests.runCadenceOfANewInletComesFromTheConfiguration") { let item = SetupTests(); try await item.runCadenceOfANewInletComesFromTheConfiguration(); item.cleanup() }
        try await step("SetupTests.runRenewalKeepsTheCadenceTheUserSet") { let item = SetupTests(); try await item.runRenewalKeepsTheCadenceTheUserSet(); item.cleanup() }
        try await step("SetupTests.runRemovedAccountTakesItsMirroredMailWithIt") { let item = SetupTests(); try await item.runRemovedAccountTakesItsMirroredMailWithIt(); item.cleanup() }
        try await step("MailModelTests.runListEmptyLoadingLoadedFailed") { await MailModelTests().runListEmptyLoadingLoadedFailed() }
        try await step("MailModelTests.runSearchWithoutHitsIsEmptySearch") { await MailModelTests().runSearchWithoutHitsIsEmptySearch() }
        try await step("MailModelTests.runFilterWithoutHitsIsNoFilterMatch") { await MailModelTests().runFilterWithoutHitsIsNoFilterMatch() }
        try await step("MailModelTests.runLoadMoreAppendsByPageToken") { await MailModelTests().runLoadMoreAppendsByPageToken() }
        try await step("MailModelTests.runSendWithoutSubjectIsBlocked") { await MailModelTests().runSendWithoutSubjectIsBlocked() }
        try await step("MailModelTests.runSendQueuedIsQueuedInOutbox") { await MailModelTests().runSendQueuedIsQueuedInOutbox() }
        try await step("MailModelTests.runSendSent") { await MailModelTests().runSendSent() }
        try await step("MailModelTests.runUnreadPerAccountAndTotal") { await MailModelTests().runUnreadPerAccountAndTotal() }
        try await step("MailModelTests.runSignInExpiredFromAccountState") { await MailModelTests().runSignInExpiredFromAccountState() }
        try await step("MailModelTests.runNotConnectedFromAccountState") { await MailModelTests().runNotConnectedFromAccountState() }
        try await step("MailModelTests.runContactFromSignatureYieldsCommand") { await MailModelTests().runContactFromSignatureYieldsCommand() }
        try await step("MailModelTests.runCardLimitDropsOldest") { await MailModelTests().runCardLimitDropsOldest() }
        try await step("MailModelTests.runOpenMarksReadAndFlagFailureKeepsHint") { await MailModelTests().runOpenMarksReadAndFlagFailureKeepsHint() }
        try await step("MailModelTests.runReplyAllBuildsDraft") { await MailModelTests().runReplyAllBuildsDraft() }
        try await step("MailModelTests.runOfflineKeepsLastSync") { await MailModelTests().runOfflineKeepsLastSync() }
        try await step("MailModelTests.runRowStatesAndThreadCount") { await MailModelTests().runRowStatesAndThreadCount() }
        try await step("MailModelTests.runSelectFolderChangesTheSelectionAndKeepsTheRole") { await MailModelTests().runSelectFolderChangesTheSelectionAndKeepsTheRole() }
        try await step("MailModelTests.runADraftWithOnlyBccCountsAsHavingARecipient") { await MailModelTests().runADraftWithOnlyBccCountsAsHavingARecipient() }
        try await step("ModelActionTests.runTheModelActions") { try await ModelActionTests().runTheModelActions() }
        try await step("ShellSweepTests.runLanesAcrossWindowsAndDrags") { try ShellSweepTests().runLanesAcrossWindowsAndDrags() }
        try await step("ShellSweepTests.runBlobOverTheWindow") { try ShellSweepTests().runBlobOverTheWindow() }
        try await step("ShellSweepTests.runCardsAndValues") { try ShellSweepTests().runCardsAndValues() }
        try await step("ShellSweepTests.runTheThemeKnowsItsKeys") { try ShellSweepTests().runTheThemeKnowsItsKeys() }
        try await step("HubSweepTests.runTheTruthFollowsItsInletAcrossARestart") { try await HubSweepTests().runTheTruthFollowsItsInletAcrossARestart() }
        try await step("HubSweepTests.runALostKeychainMarksTheInletAndTheStateIsKept") { try await HubSweepTests().runALostKeychainMarksTheInletAndTheStateIsKept() }
        try await step("HubSweepTests.runTheCountedCallsAndBytesOfEveryMailCall") { try await HubSweepTests().runTheCountedCallsAndBytesOfEveryMailCall() }
        try await step("HubSweepTests.runAFailedRenewalSurvivesARestartAndAnOutageDoesNot") { try await HubSweepTests().runAFailedRenewalSurvivesARestartAndAnOutageDoesNot() }
        try await step("HubSweepTests.runTheTokenIsRenewedWithinASixtySecondMargin") { try await HubSweepTests().runTheTokenIsRenewedWithinASixtySecondMargin() }
        try await step("MailSweepTests.runAddressesSplitAndReduce") { MailSweepTests().runAddressesSplitAndReduce() }
        try await step("MailSweepTests.runTheSelectionSurvivesTheLossOfAnAccount") { await MailSweepTests().runTheSelectionSurvivesTheLossOfAnAccount() }
        try await step("MailSweepTests.runEventsReachTheListOnlyWhereTheyBelong") { await MailSweepTests().runEventsReachTheListOnlyWhereTheyBelong() }
        try await step("MailSweepTests.runTheCardsKeepTheLastOpenOneSelected") { await MailSweepTests().runTheCardsKeepTheLastOpenOneSelected() }
        try await step("MailSweepTests.runTheFoldersAreOrderedByRole") { await MailSweepTests().runTheFoldersAreOrderedByRole() }
        try await step("GapTests.runProbesPersistTheirOutcome") { try await GapTests().runProbesPersistTheirOutcome() }
        try await step("GapTests.runTheSyncReportCountsItsItems") { try await GapTests().runTheSyncReportCountsItsItems() }
        try await step("GapTests.runAnExpiredSignInIsKeptThroughAFailingSync") { try await GapTests().runAnExpiredSignInIsKeptThroughAFailingSync() }
        try await step("GapTests.runAnUnwritableKeychainFailsTheRenewal") { try await GapTests().runAnUnwritableKeychainFailsTheRenewal() }
        try await step("GapTests.runAConnectionNeedsAUserAndTakesTheAddressAsDefault") { GapTests().runAConnectionNeedsAUserAndTakesTheAddressAsDefault() }
        try await step("GapTests.runTheReplyFollowsTheOwnAddress") { await GapTests().runTheReplyFollowsTheOwnAddress() }
        try await step("GapTests.runTheCardsStartCollapsedAndPagingNeedsASettledList") { await GapTests().runTheCardsStartCollapsedAndPagingNeedsASettledList() }
        try await step("GapTests.runNewMailIsCountedOnlyWhenThereIsSome") { try await GapTests().runNewMailIsCountedOnlyWhenThereIsSome() }
        try await step("GapTests.runTheShellModelStartsClosedAndTogglesGroups") { try GapTests().runTheShellModelStartsClosedAndTogglesGroups() }
        try await step("GapTests.runShadowTokensResolveByMode") { try GapTests().runShadowTokensResolveByMode() }
        try await step("GapTests.runTheTaskRaceEndsOnceAndExpires") { try await GapTests().runTheTaskRaceEndsOnceAndExpires() }
        try await step("GapTests.runAnEmptyGrantAndAGenericProbeFailureAreKept") { try await GapTests().runAnEmptyGrantAndAGenericProbeFailureAreKept() }
        try compareWithGolden()
    }
}

@MainActor
func compareWithGolden() throws {
    let golden = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("golden.txt")
    let text = protocolLog.with { $0 }.joined(separator: "\n") + "\n"
    if ProcessInfo.processInfo.environment["ALFA_GOLDEN"] == "write" {
        try text.write(to: golden, atomically: true, encoding: .utf8)
        return
    }
    let expected = try String(contentsOf: golden, encoding: .utf8)
    if text == expected { return }
    let now = text.split(separator: "\n", omittingEmptySubsequences: false)
    let old = expected.split(separator: "\n", omittingEmptySubsequences: false)
    let first = (0..<max(now.count, old.count)).first { $0 >= now.count || $0 >= old.count || now[$0] != old[$0] } ?? 0
    XCTFail("protocol differs from golden.txt at line \(first + 1): now \(first < now.count ? String(now[first]) : "<end>") / golden \(first < old.count ? String(old[first]) : "<end>")")
}