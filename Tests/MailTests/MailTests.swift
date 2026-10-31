import Core
import Design
import Foundation
import GRDB
@testable import Hub
import Shell
import Storage
import XCTest
@testable import Mail

private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func with<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

private final class ScriptedStream: ByteStreamPort, @unchecked Sendable {
    private let incoming: Locked<[Data]>
    let sent = Locked<[Data]>([])
    private let reply: @Sendable (String) -> [String]

    init(greeting: [String], reply: @escaping @Sendable (String) -> [String]) {
        incoming = Locked(greeting.map { Data(($0 + "\r\n").utf8) })
        self.reply = reply
    }

    func receive() async throws -> Data {
        if let next = incoming.with({ $0.isEmpty ? nil : $0.removeFirst() }) { return next }
        throw MailFailure.connectionClosed
    }

    func send(_ data: Data) async throws {
        sent.with { $0.append(data) }
        let text = String(decoding: data, as: UTF8.self)
        for line in text.components(separatedBy: "\r\n") where !line.isEmpty {
            let answers = reply(line)
            incoming.with { queue in queue.append(contentsOf: answers.map { Data(($0 + "\r\n").utf8) }) }
        }
    }

    func upgradeToTLS() async throws {}

    func close() {}
}

private final class TransportDouble: MailTransportPort, PurgePort, MirrorPort, EverywhereSearchPort, UnseenCountPort, SenderPort, SentCopyPort, @unchecked Sendable {
    let counts = Locked<[String: FolderCount]>([:])
    let wasSentFailure = Locked<(any Error)?>(nil)
    let filed = Locked<[String?]>([])
    let calls = Locked<[String]>([])
    let failure = Locked<(any Error)?>(nil)
    let wasSentAnswer = Locked(false)
    let drafts = Locked<[String: Draft]>([:])
    let corpus = Locked<[String: [MessageSummary]]>([:])
    let mirrorRanges = Locked<[MailboxRange]>(MailboxRange.allCases)
    let providesPreviews = Locked(false)
    let bodyHTML = Locked<String?>(nil)
    let startValue = Locked<String?>(nil)
    let searchTotals = Locked(true)
    let everywhereFolder = Locked<String?>(nil)
    let folderList = Locked<[Folder]?>(nil)
    let failingFolders = Locked<Set<String>>([])
    let failAfterChunks = Locked<Int?>(nil)
    let chunks = Locked<[Int]>([])
    let listings = Locked<[(since: Date?, limit: Int?)]>([])
    let serverFlags = Locked<[String: Set<Flag>]>([:])
    let cursors = Locked<[String?]>([])
    let knowns = Locked<[[String]]>([])
    let holds = Locked<Set<String>>([])
    let validity = Locked<String?>(nil)
    let failListing = Locked(false)
    let waiting = Locked<[(name: String, continuation: CheckedContinuation<Void, Never>)]>([])
    let saves = Locked(0)
    let lastFolderID = Locked<String?>(nil)
    let separateDraftIDs = Locked(false)
    let mirrorsDrafts = Locked(false)
    let draftIDs = Locked<[String: String]>([:])
    let sendDraftFailure = Locked<(any Error)?>(nil)
    let senderList = Locked<[Participant]>([])
    let prefix: String

    init(prefix: String = "1") {
        self.prefix = prefix
    }

    private func note(_ name: String) throws {
        calls.with { $0.append(name) }
        if let error = failure.with({ $0 }) { throw error }
    }

    func listFolders() async throws -> [Folder] {
        try note("listFolders")
        return folderList.with { $0 } ?? [Folder(id: "INBOX", name: "INBOX", role: .inbox),
                                          Folder(id: "Archive", name: "Archive", role: .archive),
                                          Folder(id: "Trash", name: "Trash", role: .trash)]
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        try note("listMessages")
        if failingFolders.with({ $0.contains(folderID) }) { throw MailFailure.timeout }
        let all = stored(folderID)
        let found = query.map { needle in all.filter { $0.subject.localizedCaseInsensitiveContains(needle) } } ?? all
        let start = pageToken.flatMap(Int.init) ?? 0
        let end = min(found.count, start + maxResults)
        return MessagePage(messages: Array(found[start..<end]), nextPageToken: end < found.count ? String(end) : nil,
                           total: searchTotals.with { $0 } ? found.count : nil)
    }

    func stored(_ folderID: String) -> [MessageSummary] {
        corpus.with { $0[folderID] } ?? [MessageSummary(
            id: prefix + ":1:" + folderID, threadID: "t", subject: "Hello", from: "Anna", fromRaw: "Anna <anna@example.com>",
            toRaw: "me@example.com", snippet: "snippet", flags: [], folderIDs: [folderID], messageIDHeader: "<h1@x>")]
    }

    func fetchBody(messageID: String) async throws -> MessageBody {
        try note("fetchBody")
        return MessageBody(text: "plain text", html: bodyHTML.with { $0 })
    }

    func send(_ draft: Draft) async throws {
        await hold("send")
        try note("send")
    }
    func setFlags(messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws { try note("setFlags") }
    func archive(messageID: String, folderID: String?) async throws {
        lastFolderID.with { $0 = folderID }
        try note("archive")
    }
    func move(messageID: String, toFolderID: String) async throws { try note("move") }
    func trash(messageID: String, folderID: String?) async throws { try note("trash") }
    func markSpam(messageID: String, folderID: String?) async throws { try note("markSpam") }
    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data { try note("attachment"); return Data([1]) }
    func fetchThread(messageID: String, threadID: String) async throws -> [MessageSummary] { try note("thread"); return [] }

    func saveDraft(_ draft: Draft, replacing draftID: String?, into folderID: String?) async throws -> SavedDraft {
        await hold("saveDraft")
        try note("saveDraft")
        let number = saves.with { count -> Int in
            count += 1
            return count
        }
        let mirrorID = prefix + ":\(8 + number):Drafts"
        let id = separateDraftIDs.with { $0 } ? (draftID ?? "draft:\(prefix):\(number)") : mirrorID
        drafts.with { $0[id] = draft }
        if mirrorsDrafts.with({ $0 }) {
            let replaced = draftID.map(mirrorID(ofDraft:))
            draftIDs.with { map in
                if let replaced { map[replaced] = nil }
                map[mirrorID] = id
            }
            corpus.with { corpus in
                var listed = (corpus["Drafts"] ?? []).filter { $0.id != replaced }
                listed.append(MessageSummary(id: mirrorID, threadID: "t", subject: draft.subject, from: "Me", fromRaw: "me@example.com",
                                             toRaw: draft.to ?? "", snippet: "s", receivedAt: Date(timeIntervalSince1970: 1_800_000_000),
                                             flags: [.seen, .draft], folderIDs: ["Drafts"],
                                             messageIDHeader: "<\(mirrorID)@x>"))
                corpus["Drafts"] = listed
            }
        }
        return SavedDraft(id: id, mirrorID: mirrorID)
    }

    func fetchDraft(messageID: String) async throws -> StoredDraft {
        try note("fetchDraft")
        let id = draftIDs.with { $0[messageID] } ?? (separateDraftIDs.with { $0 } ? "draft:" + messageID : messageID)
        return StoredDraft(id: id, draft: drafts.with { $0[id] } ?? Draft(subject: "", body: ""))
    }

    func deleteDraft(id: String) async throws {
        await hold("deleteDraft")
        try note("deleteDraft")
        removeServerDraft(id)
    }

    func sendDraft(id: String) async throws {
        await hold("sendDraft")
        try note("sendDraft")
        if let error = sendDraftFailure.with({ $0 }) { throw error }
        removeServerDraft(id)
    }

    private func mirrorID(ofDraft id: String) -> String {
        draftIDs.with { $0.first { $0.value == id }?.key } ?? (id.hasPrefix("draft:") ? String(id.dropFirst("draft:".count)) : id)
    }

    private func removeServerDraft(_ id: String) {
        guard mirrorsDrafts.with({ $0 }) else { return }
        let gone = mirrorID(ofDraft: id)
        draftIDs.with { $0[gone] = nil }
        corpus.with { $0["Drafts"]?.removeAll { $0.id == gone } }
    }
    func wasSent(messageID: String, in folderID: String?) async throws -> Bool {
        await hold("wasSent")
        try note("wasSent")
        if let error = wasSentFailure.with({ $0 }) { throw error }
        return wasSentAnswer.with { $0 }
    }

    var filesSentCopy: Bool { true }

    func fileSent(_ draft: Draft, into folderID: String?) async throws {
        try note("fileSent")
        filed.with { $0.append(folderID) }
    }
    var ranges: [MailboxRange] { mirrorRanges.with { $0 } }
    var fillsPreviews: Bool { providesPreviews.with { $0 } }

    func offersEverywhere(in folders: [Folder]) -> Bool {
        everywhereFolder.with { wanted in wanted.map { id in folders.contains { $0.id == id } } ?? false }
    }

    func unseen(folderID: String) async throws -> FolderCount? {
        try note("unseen")
        return counts.with { $0[folderID] }
    }

    func startCursor() async throws -> String? {
        try note("startCursor")
        return startValue.with { $0 }
    }

    func searchEverywhere(query: String, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        try note("searchEverywhere:" + query + ":" + (pageToken ?? ""))
        let all = corpus.with { $0.filter { $0.key != "Trash" && $0.key != "Spam" }.values.flatMap { $0 } }
        let found = MirrorEngine.sorted(all.filter { $0.subject.localizedCaseInsensitiveContains(query) })
        let start = pageToken.flatMap(Int.init) ?? 0
        let end = min(found.count, start + maxResults)
        return MessagePage(messages: Array(found[start..<end]), nextPageToken: end < found.count ? String(end) : nil,
                           total: found.count)
    }

    private func hold(_ name: String) async {
        guard holds.with({ $0.contains(name) }) else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiting.with { $0.append((name, continuation)) }
        }
    }

    func release() {
        holds.with { $0 = [] }
        let pending = waiting.with { queue in
            defer { queue = [] }
            return queue
        }
        pending.forEach { $0.continuation.resume() }
    }

    func release(only name: String) {
        holds.with { $0 = $0.subtracting([name]) }
        let pending = waiting.with { queue -> [CheckedContinuation<Void, Never>] in
            let mine = queue.filter { $0.name == name }.map(\.continuation)
            queue.removeAll { $0.name == name }
            return mine
        }
        pending.forEach { $0.resume() }
    }

    func listIDs(folderID: String, since: Date?, limit: Int?) async throws -> MirrorListing {
        try note("listIDs")
        if failListing.with({ $0 }) { throw MailFailure.timeout }
        listings.with { $0.append((since, limit)) }
        await hold("listIDs")
        let all = stored(folderID)
        let inside = all.filter { message in since.map { (message.receivedAt ?? .distantFuture) >= $0 } ?? true }
        let wanted = limit.map { Array(inside.prefix($0)) } ?? inside
        return MirrorListing(ids: wanted.map(\.id), hasOlder: wanted.count < all.count, validity: validity.with { $0 })
    }

    func fetchSummaries(folderID: String, ids: [String]) async throws -> [MessageSummary] {
        try note("fetchSummaries")
        await hold("fetchSummaries")
        let done = chunks.with { list -> Int in
            list.append(ids.count)
            return list.count
        }
        if let limit = failAfterChunks.with({ $0 }), done > limit { throw MailFailure.timeout }
        let all = stored(folderID)
        let wanted = Set(ids)
        return all.filter { wanted.contains($0.id) }
    }

    func refreshFlags(folderID: String, known: [String], cursor: String?) async throws -> FlagRefresh {
        try note("refreshFlags")
        await hold("refreshFlags")
        cursors.with { $0.append(cursor) }
        knowns.with { $0.append(known) }
        let overrides = serverFlags.with { $0 }
        return FlagRefresh(flags: overrides.filter { known.contains($0.key) }, cursor: "c\(cursors.with { $0.count })")
    }

    func senders() async throws -> [Participant] { senderList.with { $0 } }

    func supportsPurge() async throws -> Bool { true }
    func purge(messageID: String) async throws { try note("purge") }
}

@MainActor
private final class FakeAccess: AccessPort {
    var transport: (any MailTransportPort)?
    var transports: [Inlet.ID: any MailTransportPort] = [:]
    var connected = true
    var records = [Inlet(id: "a", provider: "imap", capabilities: [.mail], owner: .company, title: "A",
                         account: "me@example.com", state: .connected(probed: Date()))]
    private var stocks: [String: Any] = [:]
    private var listeners: [AsyncStream<InletEvent>.Continuation] = []
    let reported = Locked<[RunProgress]>([])
    let tracks = Locked<[Capability]>([])
    let open = Locked<Int>(0)

    func track<T>(_ inlet: Inlet.ID, _ capability: Capability, body: @MainActor (SyncReporter) async -> T) async -> T {
        tracks.with { $0.append(capability) }
        open.with { $0 += 1 }
        defer { open.with { $0 -= 1 } }
        let sink = reported
        return await body(SyncReporter { progress in sink.with { $0.append(progress) } })
    }

    func stock<T: Item>(_ kind: DataKind, as type: T.Type) -> StockState<T> {
        let key = kind.rawValue
        if let existing = stocks[key] as? StockState<T> { return existing }
        let made = StockState<T> {}
        stocks[key] = made
        return made
    }

    func port<P>(_ port: P.Type, for inlet: Inlet.ID) throws(HubFailure) -> P {
        guard connected, let typed = (transports[inlet] ?? transport) as? P else { throw .notConnected(inlet) }
        return typed
    }

    func inlets(for capability: Capability) -> [Inlet] { records.filter { $0.capabilities.contains(capability) } }
    func configured(for capability: Capability) -> [Inlet] { inlets(for: capability) }
    func classify(_ error: any Error, inlet: Inlet.ID) -> Classification { FailureEngine.classify(error) }

    var events: AsyncStream<InletEvent> {
        let (stream, continuation) = AsyncStream<InletEvent>.makeStream()
        listeners.append(continuation)
        return stream
    }

    func emit(_ event: InletEvent) { listeners.forEach { $0.yield(event) } }
}

@MainActor
private struct Rig {
    let access = FakeAccess()
    let transport = TransportDouble()
    let database: SQLiteStore
    let events = Broadcast<MailboxEvent>()
    let outbox: OutboxStore
    let mailbox: MailboxStore
    let chosen: Locked<MailboxRange>

    init(range: MailboxRange = .standard, now: @escaping @Sendable () -> Date = { Date() }) throws {
        let chosen = Locked(range)
        self.chosen = chosen
        database = try SQLiteStore.inMemory()
        access.transport = transport
        outbox = OutboxStore(access: access, database: database, events: events)
        mailbox = MailboxStore(access: access, database: database, outbox: outbox, events: events, now: now,
                               range: { _ in chosen.with { $0 } })
    }

    func fill(_ folder: String, count: Int, from start: Date, step: TimeInterval = -3_600, subject: String = "Note",
              flags: Set<Flag> = [.seen]) {
        let messages = (0..<count).map { index in
            MessageSummary(id: "1:\(index):" + folder, threadID: "t\(index)", subject: subject + " \(index)", from: "Anna",
                           fromRaw: "Anna <anna@example.com>", toRaw: "me@example.com", snippet: "s",
                           receivedAt: start.addingTimeInterval(Double(index) * step), flags: flags, folderIDs: [folder],
                           messageIDHeader: "<m\(index)@x>")
        }
        transport.corpus.with { $0[folder] = messages }
    }

    func addMailbox(_ id: Inlet.ID, prefix: String) -> TransportDouble {
        let other = TransportDouble(prefix: prefix)
        access.transports[id] = other
        access.records.append(Inlet(id: id, provider: "imap", capabilities: [.mail], owner: .company, title: id.uppercased(),
                                    account: id + "@example.com", state: .connected(probed: Date())))
        return other
    }
}

final class MailTests: XCTestCase {
    private func parse(_ text: String) throws -> IMAPResponse {
        try IMAPResponseParser.parse(Data(text.utf8))
    }

    private func fetched(_ text: String) throws -> IMAPFetched {
        guard case .data(let values) = try parse(text), let fetched = try IMAPFetched.parse(values) else {
            throw MailFailure.malformedResponse(text)
        }
        return fetched
    }

    func testDraftKeepsHTMLAndMessageIDThroughEncoding() throws {
        let draft = Draft(to: "a@b.de", subject: "S", body: "plain",
                          attachments: [Attachment(filename: "f.txt", mimeType: "text/plain", data: Data([1, 2]))],
                          bodyHTML: "<p>html</p>", messageID: "abc")
        let decoded = try JSONDecoder().decode(Draft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(decoded, draft)
        XCTAssertEqual(decoded.bodyHTML, "<p>html</p>")
        XCTAssertEqual(decoded.messageID, "abc")
        let old = Data(#"{"subject":"S","body":"b"}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(Draft.self, from: old).attachments, [])
    }

    func testBoundaryComesFromTheMessageIDNotFromTheSubject() throws {
        let account = Account(id: "a", displayName: "Me", address: "me@example.com",
                              incoming: ServerSettings(), outgoing: ServerSettings())
        let draft = Draft(to: "x@example.com", subject: "Same", body: "b", attachments: [Attachment(filename: "a.txt", mimeType: "text/plain", data: Data([1]))])
        let one = try MessageEngine.build(draft, account: account, messageID: "11111111-aaaa-bbbb-cccc-000000000001")
        let again = try MessageEngine.build(draft, account: account, messageID: "11111111-aaaa-bbbb-cccc-000000000001")
        let other = try MessageEngine.build(draft, account: account, messageID: "22222222-aaaa-bbbb-cccc-000000000002")
        let text = String(decoding: one.data, as: UTF8.self)
        XCTAssertTrue(text.contains("boundary=\"mixed_11111111aaaabbbbcccc000000000001\""))
        XCTAssertEqual(String(decoding: again.data, as: UTF8.self).components(separatedBy: "boundary=").dropFirst().first,
                       text.components(separatedBy: "boundary=").dropFirst().first)
        XCTAssertNotEqual(one.data, other.data)
        XCTAssertFalse(text.contains("alfa_boundary"))
    }

    func testDraftKeepsItsSenderAndOldRowsHaveNone() throws {
        let draft = Draft(to: "a@b.de", subject: "S", body: "b", from: Participant(name: "J\u{F6}rg", address: "j@x.de"))
        let decoded = try JSONDecoder().decode(Draft.self, from: JSONEncoder().encode(draft))
        XCTAssertEqual(decoded.from?.address, "j@x.de")
        XCTAssertEqual(decoded.from?.name, "J\u{F6}rg")
        XCTAssertNil(try JSONDecoder().decode(Draft.self, from: Data(#"{"subject":"S","body":"b"}"#.utf8)).from)
    }

    func testFromHeaderCarriesTheEncodedNameInBothBuilders() throws {
        let account = Account(id: "a", displayName: "Konto", address: "me@example.com",
                              incoming: ServerSettings(), outgoing: ServerSettings())
        let draft = Draft(to: "x@example.com", subject: "S", body: "b",
                          from: Participant(name: "J\u{F6}rg M\u{FC}ller", address: "alias@example.com"))
        let built = try MessageEngine.build(draft, account: account)
        let text = String(decoding: built.data, as: UTF8.self)
        XCTAssertEqual(built.sender, "alias@example.com")
        let line = try XCTUnwrap(text.components(separatedBy: "\r\n").first { $0.hasPrefix("From:") })
        XCTAssertTrue(line.hasPrefix("From: =?UTF-8?B?"))
        XCTAssertTrue(line.hasSuffix("<alias@example.com>"))
        let raw = String(decoding: MessageEngine.buildRaw(draft, domain: "d"), as: UTF8.self)
        XCTAssertTrue(raw.hasPrefix("From: =?UTF-8?B?"))
        XCTAssertEqual(MessageEngine.sender(line.replacingOccurrences(of: "From: ", with: ""))?.name, "J\u{F6}rg M\u{FC}ller")
        let plain = try MessageEngine.build(Draft(to: "x@example.com", subject: "S", body: "b"), account: account)
        XCTAssertTrue(String(decoding: plain.data, as: UTF8.self).contains("From: Konto <me@example.com>"))
    }

    func testSendersPutTheAccountFirstAndTheChosenNameOverridesAll() {
        let stored = [Participant(name: "Alias", address: "shop@example.com"), Participant(name: "Ich", address: "ME@example.com")]
        let plain = SenderEngine.merged(account: "me@example.com", chosen: "", profile: "Profil", stored: stored)
        XCTAssertEqual(plain.map(\.address), ["me@example.com", "shop@example.com"])
        XCTAssertEqual(plain.map(\.name), ["Ich", "Alias"])
        let named = SenderEngine.merged(account: "me@example.com", chosen: " Neu ", profile: "Profil", stored: stored)
        XCTAssertEqual(named.map(\.name), ["Neu", "Neu"])
        let bare = SenderEngine.merged(account: "me@example.com", chosen: "", profile: "Profil", stored: [])
        XCTAssertEqual(bare, [Participant(id: 0, name: "Profil", address: "me@example.com")])
        XCTAssertEqual(SenderEngine.receiving(plain, headers: ["x@y.de", "Shop <SHOP@example.com>"])?.address, "shop@example.com")
        XCTAssertNil(SenderEngine.receiving(plain, headers: ["x@y.de"]))
    }

    @MainActor
    func testRepliesAndForwardsComeFromTheAddressTheMailWasSentTo() async throws {
        let rig = try Rig()
        rig.transport.senderList.with { $0 = [Participant(name: "Me", address: "me@example.com"), Participant(name: "Shop", address: "shop@example.com")] }
        rig.transport.corpus.with {
            $0["INBOX"] = [MessageSummary(id: "1:1:INBOX", threadID: "t", subject: "Hi", from: "Anna", fromRaw: "Anna <anna@example.com>",
                                          toRaw: "Team <shop@example.com>, bob@example.com", snippet: "s", flags: [], folderIDs: ["INBOX"],
                                          messageIDHeader: "<h1@x>")]
        }
        _ = await rig.mailbox.senders("a")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let repliedID = await state.reply(to: "1:1:INBOX", all: true)
        let replied = try XCTUnwrap(repliedID)
        XCTAssertEqual(state.draft(replied)?.draft.from?.address, "shop@example.com")
        XCTAssertEqual(state.draft(replied)?.draft.from?.name, "Shop")
        XCTAssertEqual(state.draft(replied)?.draft.cc, "bob@example.com")
        let forwardedID = await state.forward("1:1:INBOX")
        let forwarded = try XCTUnwrap(forwardedID)
        XCTAssertEqual(state.draft(forwarded)?.draft.from?.address, "shop@example.com")
        let fresh = try XCTUnwrap(state.compose())
        XCTAssertEqual(state.draft(fresh)?.draft.from?.address, "me@example.com")
    }

    @MainActor
    func testTheQuoteLineUsesTheTextsAndLocaleTheAppHandsIn() async throws {
        func quote(_ locale: String) async throws -> (dated: String, undated: String) {
            let rig = try Rig()
            rig.transport.corpus.with {
                $0["INBOX"] = [MessageSummary(id: "1:1:INBOX", threadID: "t", subject: "Hi", from: "Anna", fromRaw: "Anna <anna@example.com>",
                                              toRaw: "me@example.com", snippet: "s", receivedAt: Date(timeIntervalSince1970: 1_800_000_000),
                                              flags: [], folderIDs: ["INBOX"], messageIDHeader: "<h1@x>"),
                               MessageSummary(id: "1:2:INBOX", threadID: "u", subject: "Ho", from: "Bea", fromRaw: "Bea <bea@example.com>",
                                              toRaw: "me@example.com", snippet: "s", flags: [], folderIDs: ["INBOX"], messageIDHeader: "<h2@x>")]
            }
            let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                                   quoteTexts: { QuoteTexts(dated: "Le {1}, {2} a ecrit :", undated: "{1} a ecrit :", locale: Locale(identifier: locale)) })
            await state.start()
            let datedID = await state.reply(to: "1:1:INBOX")
            let undatedID = await state.reply(to: "1:2:INBOX")
            let dated = try XCTUnwrap(datedID), undated = try XCTUnwrap(undatedID)
            return (try XCTUnwrap(state.draft(dated)?.draft.body), try XCTUnwrap(state.draft(undated)?.draft.body))
        }
        let english = try await quote("en_US")
        let german = try await quote("de_DE")
        XCTAssertTrue(english.dated.hasPrefix("\n\nLe ") && english.dated.contains(", Anna a ecrit :\n> "))
        XCTAssertNotEqual(english.dated, german.dated)
        XCTAssertTrue(english.undated.hasPrefix("\n\nBea a ecrit :\n> "))
    }

    @MainActor
    func testRepliesGoToTheReplyToAddressAndASecondReplyReopensTheFirstDraft() async throws {
        let rig = try Rig()
        rig.transport.corpus.with {
            $0["INBOX"] = [MessageSummary(id: "1:1:INBOX", threadID: "t", subject: "Form", from: "Site", fromRaw: "Site <noreply@site.test>",
                                          toRaw: "me@example.com", replyToRaw: "Kim <kim@guest.test>", snippet: "s", flags: [],
                                          folderIDs: ["INBOX"], messageIDHeader: "<h1@x>")]
        }
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let firstID = await state.reply(to: "1:1:INBOX")
        let first = try XCTUnwrap(firstID)
        XCTAssertEqual(state.draft(first)?.draft.to, "Kim <kim@guest.test>")
        let secondID = await state.reply(to: "1:1:INBOX")
        XCTAssertEqual(secondID, first)
        XCTAssertEqual(state.drafts.count, 1)
    }

    @MainActor
    func testSendingWithoutSubjectNamesTheSubjectAndSuccessSaysSent() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.to = "x@y.de" }
        await state.send(id)
        XCTAssertEqual(state.toast?.kind, .subjectMissing)
        state.edit(id) { $0.to = nil; $0.subject = "s" }
        state.refuseSend(id)
        XCTAssertEqual(state.toast?.kind, .recipientMissing)
        state.edit(id) { $0.to = "x@y.de" }
        await state.send(id)
        XCTAssertEqual(state.toast?.kind, .outboxSent)
    }

    @MainActor
    func testChangingTheSenderAcrossMailboxesMovesTheDraftAndDeletesTheOldOne() async throws {
        let rig = try Rig()
        let other = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.addRecipient(id, .to, entry: "x@y.de")
        state.edit(id) {
            $0.subject = "S"
            $0.receiptTo = "me@example.com"
        }
        await state.save(id)
        XCTAssertNotNil(state.draft(id)?.remoteID)
        await state.setFrom(id, inlet: "b")
        let moved = try XCTUnwrap(state.draft(id))
        XCTAssertEqual(moved.inlet, "b")
        XCTAssertNil(moved.remoteID)
        XCTAssertNil(moved.mirrorID)
        XCTAssertEqual(moved.draft.from?.address, "b@example.com")
        XCTAssertEqual(moved.draft.receiptTo, "b@example.com")
        XCTAssertTrue(rig.transport.calls.with { $0.contains("deleteDraft") })
        XCTAssertFalse(other.calls.with { $0.contains("deleteDraft") })
        XCTAssertEqual(state.selectedInlet, "b")
        XCTAssertEqual(state.frontRef, .draft(id))
        await state.refreshSenders()
        XCTAssertEqual(state.senderChoices.map(\.inlet), ["a", "b"])
        rig.access.records[1].state = .failed(Hint(text: "x"))
        await state.refreshAccounts()
        XCTAssertEqual(state.senderChoices.map(\.inlet), ["a"])
    }

    @MainActor
    func testEditsDuringASaveLeadToOneFollowUpSaveOfTheSameProviderDraft() async throws {
        let rig = try Rig()
        rig.transport.separateDraftIDs.with { $0 = true }
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .milliseconds(10), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "First" }
        rig.transport.holds.with { $0 = ["saveDraft"] }
        let first = Task { await state.save(id) }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        state.edit(id) { $0.subject = "Second" }
        XCTAssertEqual(state.draft(id)?.state, .saving)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(rig.transport.waiting.with { $0.count }, 1)
        rig.transport.release()
        await first.value
        guard case .saved = state.draft(id)?.state else { return XCTFail() }
        XCTAssertEqual(rig.transport.saves.with { $0 }, 2)
        XCTAssertEqual(rig.transport.drafts.with { Array($0.keys) }, [try XCTUnwrap(state.draft(id)?.remoteID)])
        XCTAssertEqual(rig.transport.drafts.with { $0.values.first?.subject }, "Second")
    }

    @MainActor
    func testChangingTheSenderDuringASaveKeepsTheOldMailboxDraftOffTheMovedCard() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "S" }
        rig.transport.holds.with { $0 = ["saveDraft"] }
        let saving = Task { await state.save(id) }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        let moving = Task { await state.setFrom(id, inlet: "b") }
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(state.draft(id)?.inlet, "a")
        rig.transport.release()
        await saving.value
        await moving.value
        let moved = try XCTUnwrap(state.draft(id))
        XCTAssertEqual(moved.inlet, "b")
        XCTAssertNil(moved.remoteID)
        XCTAssertNil(moved.mirrorID)
        XCTAssertEqual(moved.state, .edited)
        XCTAssertTrue(rig.transport.calls.with { $0.contains("deleteDraft") })
    }

    @MainActor
    private func failedSend() async throws -> (rig: Rig, state: InboxState, id: UUID, item: OutboxItem) {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.addRecipient(id, .to, entry: "x@y.de")
        state.edit(id) { $0.subject = "S" }
        rig.transport.failure.with { $0 = MailFailure.smtpRejected(550, "5.1.1 no such user") }
        await state.send(id)
        rig.transport.failure.with { $0 = nil }
        guard case .sendFailed = state.draft(id)?.state, let item = rig.outbox.outbox.first else {
            XCTFail()
            throw MailFailure.timeout
        }
        return (rig, state, id, item)
    }

    @MainActor
    func testAnOutboxMailThatIsBeingCheckedIsNeitherSavedAsADraftNorDiscarded() async throws {
        let (rig, state, id, item) = try await failedSend()
        rig.transport.holds.with { $0 = ["wasSent"] }
        let retry = Task { @MainActor in await rig.outbox.resend(item.id, item.draft, draftID: nil) }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        XCTAssertEqual(rig.outbox.outbox.first?.state, .checking)
        XCTAssertFalse(rig.outbox.discard(item.id))
        await state.save(id)
        XCTAssertEqual(rig.transport.saves.with { $0 }, 0)
        XCTAssertEqual(state.draft(id)?.state, .queuedInOutbox)
        XCTAssertEqual(state.draft(id)?.outboxID, item.id)
        await state.handle(.outboxChanged)
        await state.discardQueued(item.id.uuidString)
        XCTAssertEqual(state.draft(id)?.outboxID, item.id)
        XCTAssertEqual(rig.outbox.outbox.count, 1)
        rig.transport.release()
        _ = await retry.value
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertTrue(rig.transport.calls.with { $0.contains("send") })
        XCTAssertEqual(rig.transport.saves.with { $0 }, 0)
    }

    @MainActor
    func testAnOutboxMailThatStartsSendingDuringASaveKeepsItsPlaceAndLeavesNoSecondCopy() async throws {
        let (rig, state, id, item) = try await failedSend()
        rig.transport.holds.with { $0 = ["saveDraft"] }
        let saving = Task { @MainActor in await state.save(id) }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        rig.transport.holds.with { $0 = ["saveDraft", "wasSent"] }
        let retry = Task { @MainActor in await rig.outbox.resend(item.id, item.draft, draftID: nil) }
        try await wait { rig.transport.waiting.with { $0.count } == 2 }
        rig.transport.release(only: "saveDraft")
        await saving.value
        XCTAssertEqual(state.draft(id)?.state, .queuedInOutbox)
        XCTAssertEqual(state.draft(id)?.outboxID, item.id)
        XCTAssertNil(state.draft(id)?.remoteID)
        XCTAssertEqual(rig.outbox.outbox.count, 1)
        XCTAssertTrue(rig.transport.calls.with { $0.contains("deleteDraft") })
        rig.transport.release()
        _ = await retry.value
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
    }

    @MainActor
    func testAFailedMoveToAnotherSenderDropsTheQueuedSendInsteadOfSendingFromTheOldMailbox() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.addRecipient(id, .to, entry: "x@y.de")
        state.edit(id) { $0.subject = "S" }
        await state.save(id)
        XCTAssertNotNil(state.draft(id)?.remoteID)
        rig.transport.holds.with { $0 = ["deleteDraft"] }
        let moving = Task { await state.setFrom(id, inlet: "b") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        await state.send(id)
        rig.transport.failure.with { $0 = MailFailure.timeout }
        rig.transport.release()
        await moving.value
        let kept = try XCTUnwrap(state.draft(id))
        XCTAssertEqual(kept.inlet, "a")
        XCTAssertNotNil(kept.remoteID)
        XCTAssertNotNil(kept.saveFailure)
        XCTAssertFalse([DraftState.sending, .sent, .queuedInOutbox].contains(kept.state))
        XCTAssertFalse(rig.transport.calls.with { $0.contains("send") || $0.contains("sendDraft") })
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
    }

    @MainActor
    func testADraftWithOnlyCcOrBccCanBeSent() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "s" }
        XCTAssertEqual(state.draft(id)?.canSend, false)
        state.edit(id) { $0.bcc = "x@y.de" }
        XCTAssertEqual(state.draft(id)?.canSend, true)
        state.edit(id) { $0.bcc = nil; $0.cc = "x@y.de" }
        XCTAssertEqual(state.draft(id)?.canSend, true)
        await state.send(id)
        XCTAssertEqual(state.draft(id)?.state, .sent)
    }

    func testTheQuoteHeadNamesTheSenderWithALocalDate() throws {
        let date = Date(timeIntervalSince1970: 1_793_347_200)
        let berlin = try XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        let head = Quoting.attribution("Anna", at: date, dated: "Am {1} schrieb {2}:", undated: "{1} schrieb:",
                                       locale: Locale(identifier: "de_DE"), timeZone: berlin)
        XCTAssertTrue(head.hasPrefix("Am 30. Okt. 2026"))
        XCTAssertTrue(head.hasSuffix(" schrieb Anna:"))
        XCTAssertFalse(head.contains("Z"))
        XCTAssertTrue(Quoting.isAttribution(head))
        XCTAssertEqual(Quoting.attribution("Anna", at: nil, dated: "Am {1} schrieb {2}:", undated: "{1} schrieb:"), "Anna schrieb:")
    }

    func testSignatureIsPlacedBelowOrAboveTheQuoteAndSwappedInPlace() {
        let quote = "\n\nAnna, 2026-10-30\n> Hi"
        var below = Draft(subject: "Re: x", body: quote)
        below.resign(to: MailboxSignature(text: "Jonas\nStudio"))
        XCTAssertEqual(below.body, quote + "\n\nJonas\nStudio")
        var above = Draft(subject: "Re: x", body: quote)
        above.resign(to: MailboxSignature(text: "Jonas", aboveQuote: true))
        XCTAssertEqual(above.body, "\n\nJonas" + quote)
        above.resign(to: MailboxSignature(text: "Lea", aboveQuote: true))
        XCTAssertEqual(above.body, "\n\nLea" + quote)
        XCTAssertEqual(above.signed, "Lea")
        above.resign(to: nil)
        XCTAssertEqual(above.body, quote)
        XCTAssertNil(above.signed)
        var fresh = Draft(subject: "", body: "")
        fresh.resign(to: MailboxSignature(text: "Jonas"))
        XCTAssertEqual(fresh.body, "\n\nJonas")
        XCTAssertEqual(fresh.unsignedBody, "")
        fresh.resign(to: nil)
        XCTAssertEqual(fresh.body, "")
    }

    func testSwappingTheSignatureKeepsTheRichTextAround() {
        var draft = Draft(subject: "", body: "Hi\n\nJonas", bodyHTML: "<div><b>Hi</b></div><div><br></div><div>Jonas</div>", signed: "Jonas")
        draft.resign(to: MailboxSignature(text: "Lea & Co"))
        XCTAssertEqual(draft.body, "Hi\n\nLea & Co")
        XCTAssertEqual(draft.bodyHTML, "<div><b>Hi</b></div><div><br></div><div>Lea &amp; Co</div>")
        draft.signatureOff = true
        draft.resign(to: nil)
        XCTAssertEqual(draft.body, "Hi")
        XCTAssertEqual(draft.bodyHTML, "<div><b>Hi</b></div>")
        draft.signatureOff = false
        draft.resign(to: MailboxSignature(text: "Lea"))
        XCTAssertEqual(draft.bodyHTML, "<div><b>Hi</b></div><div><br></div><div>Lea</div>")
    }

    func testSwapIsSkippedWhenTheSignatureWasEdited() {
        let html = "<div><b>Hi</b></div><div><b>Jonas</b></div>"
        var draft = Draft(subject: "", body: "Hi\nJonas", bodyHTML: html, signed: "Jonas")
        draft.resign(to: MailboxSignature(text: "Lea"))
        XCTAssertEqual(draft.body, "Hi\nJonas")
        XCTAssertEqual(draft.bodyHTML, html)
        XCTAssertEqual(draft.signed, "Jonas")
    }

    func testSignatureRespectsTheNewMailSwitchAndTheNoneChoice() {
        var draft = Draft(subject: "", body: "")
        draft.resign(to: MailboxSignature(text: "Jonas", onNew: false))
        XCTAssertEqual(draft.body, "")
        draft.resign(to: MailboxSignature(text: "Jonas", onNew: false), explicit: true)
        XCTAssertEqual(draft.body, "\n\nJonas")
        draft.bodyHTML = "<div><br></div><div><br></div><div>Jonas</div>"
        draft.signatureOff = true
        draft.resign(to: MailboxSignature(text: "Jonas"))
        XCTAssertEqual(draft.body, "")
        XCTAssertEqual(draft.bodyHTML, "<div><br></div>")
        draft.resign(to: MailboxSignature(text: "Jonas"))
        XCTAssertEqual(draft.body, "")
    }

    @MainActor
    func testSignatureIsInsertedIntoNewDraftsAndSwappedWhenTheMailboxChanges() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "2")
        let signatures = ["a": MailboxSignature(text: "Anna"), "b": MailboxSignature(text: "Bert")]
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(), signatures: { signatures[$0] })
        await state.start()
        let id = try XCTUnwrap(state.compose())
        XCTAssertEqual(state.draft(id)?.draft.body, "\n\nAnna")
        XCTAssertTrue(state.signatureApplied(id))
        XCTAssertEqual(state.signatureName(id), "Anna")
        XCTAssertNotNil(state.compose())
        await state.setFrom(id, inlet: "b")
        XCTAssertEqual(state.draft(id)?.draft.body, "\n\nBert")
        state.useSignature(id, false)
        XCTAssertEqual(state.draft(id)?.draft.body, "")
        XCTAssertFalse(state.signatureApplied(id))
        state.useSignature(id, true)
        XCTAssertEqual(state.draft(id)?.draft.body, "\n\nBert")
    }

    func testRawBuilderForGmailUsesTheSameBuilder() {
        let draft = Draft(to: "x@example.com", subject: "Gr\u{FC}\u{DF}e", body: "line", inReplyTo: "ref@x",
                          bodyHTML: "<b>x</b>", messageID: "m1")
        let text = String(decoding: MessageEngine.buildRaw(draft, domain: "mail.gmail.com"), as: UTF8.self)
        XCTAssertTrue(text.contains("Message-ID: <m1@mail.gmail.com>"))
        XCTAssertTrue(text.contains("In-Reply-To: <ref@x>"))
        XCTAssertTrue(text.contains("multipart/alternative; boundary=\"alt_m1\""))
        XCTAssertTrue(text.contains("Subject: =?UTF-8?B?"))
        XCTAssertFalse(text.contains("From:"))
    }

    func testRichTextBecomesHTMLOnlyWhenFormatted() {
        XCTAssertNil(RichTextEngine.html([RichParagraph(runs: [RichRun("plain")]), RichParagraph(runs: [])]))
        let html = RichTextEngine.html([
            RichParagraph(runs: [RichRun("a<b", bold: true), RichRun(" & "), RichRun("x", italic: true, underline: true)]),
            RichParagraph(runs: []),
            RichParagraph(list: .bullet, runs: [RichRun("one")]),
            RichParagraph(list: .bullet, runs: [RichRun("site", link: "https://x.de/?a=1&b=\"2\"")]),
            RichParagraph(list: .number, runs: [RichRun("first")]),
            RichParagraph(runs: [RichRun("end")]),
        ])
        XCTAssertEqual(html, "<div><b>a&lt;b</b> &amp; <i><u>x</u></i></div><div><br></div><ul><li>one</li>"
            + "<li><a href=\"https://x.de/?a=1&amp;b=&quot;2&quot;\">site</a></li></ul><ol><li>first</li></ol><div>end</div>")
        XCTAssertEqual(RichTextEngine.html([RichParagraph(list: .number, runs: [RichRun("x")])]), "<ol><li>x</li></ol>")
        XCTAssertEqual(RichTextEngine.marker(.bullet, position: 3), "\u{2022} ")
        XCTAssertEqual(RichTextEngine.marker(.number, position: 3), "3. ")
        let draft = CommandEngine.commands(front: .draft(canSend: true), stackCount: 1, fanned: false, hasFiles: true, confirmDiscard: false,
                                           canFold: false, sendLabelled: false, formatting: true)
        XCTAssertEqual(draft.footLeft.map(\.id), ["attachFile", "fromProject", "format"])
        XCTAssertEqual(draft.footLeft.last?.accent, true)
        XCTAssertEqual(SlotRouter.route(.format, front: .draft(UUID())), .toggleFormat)
        XCTAssertNil(SlotRouter.route(.format, front: nil))
    }

    func testReadReceiptHeaderOnlyWhenAsked() throws {
        let account = Account(id: "a", displayName: "Me", address: "me@example.com", incoming: ServerSettings(), outgoing: ServerSettings())
        let plain = Draft(to: "x@example.com", subject: "s", body: "b")
        var asked = plain
        asked.receiptTo = "me@example.com"
        let header = "Disposition-Notification-To: <me@example.com>"
        XCTAssertFalse(String(decoding: try MessageEngine.build(plain, account: account).data, as: UTF8.self).contains("Disposition"))
        XCTAssertTrue(String(decoding: try MessageEngine.build(asked, account: account).data, as: UTF8.self).contains(header))
        XCTAssertTrue(String(decoding: MessageEngine.buildRaw(asked, domain: "d"), as: UTF8.self).contains(header))
        XCTAssertFalse(String(decoding: MessageEngine.buildRaw(plain, domain: "d"), as: UTF8.self).contains("Disposition"))
        XCTAssertEqual(MessageEngine.receiptAddress(" <me@example.com> "), "me@example.com")
        XCTAssertNil(MessageEngine.receiptAddress("<>"))
        XCTAssertNil(MessageEngine.receiptAddress(nil))
        XCTAssertEqual(try JSONDecoder().decode(Draft.self, from: JSONEncoder().encode(asked)).receiptTo, "me@example.com")
    }

    @MainActor
    func testReceiptToggleUsesTheDraftMailbox() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        XCTAssertFalse(state.asksReceipt(id))
        state.toggleReceipt(id)
        XCTAssertTrue(state.asksReceipt(id))
        XCTAssertEqual(state.drafts.first { $0.id == id }?.draft.receiptTo, state.selectedAccount?.account)
        XCTAssertEqual(MenuEngine.draftMore(receipt: true), [.item(.laterSend), .item(.receipt, checked: true), .separator, .item(.print)])
        state.toggleReceipt(id)
        XCTAssertFalse(state.asksReceipt(id))
    }

    func testBuilderRejectsMissingRecipientsExceptForDrafts() throws {
        let account = Account(id: "a", displayName: "", address: "me@example.com", incoming: ServerSettings(), outgoing: ServerSettings())
        XCTAssertThrowsError(try MessageEngine.build(Draft(subject: "s", body: "b"), account: account)) {
            XCTAssertEqual($0 as? MailFailure, .noRecipients)
        }
        XCTAssertNoThrow(try MessageEngine.build(Draft(subject: "s", body: "b"), account: account, asDraft: true))
    }

    func testAddressListSplitsOnCommaAndSemicolonRespectingQuotes() {
        let list = "\"Gray, Terry\" <gray@cac.washington.edu>, plain@example.com; Other <o@example.org>"
        XCTAssertEqual(AddressListParser.split(list).count, 3)
        XCTAssertEqual(AddressListParser.parseMailbox("\"Gray, Terry\" <gray@x.org>")?.name, "Gray, Terry")
        XCTAssertNil(AddressListParser.parseMailbox("not an address"))
        XCTAssertEqual(AddressEngine.email("A <Foo@Bar.de>"), "foo@bar.de")
    }

    func testResponseParsing() throws {
        XCTAssertEqual(try parse("a001 OK LOGIN completed"), .tagged(tag: "a001", status: .ok, code: nil, text: "LOGIN completed"))
        XCTAssertEqual(try parse("a002 NO [AUTHENTICATIONFAILED] Invalid credentials"),
                       .tagged(tag: "a002", status: .no, code: IMAPResponseCode(name: "AUTHENTICATIONFAILED", values: []),
                               text: "Invalid credentials"))
        XCTAssertEqual(try parse("+ Ready"), .continuation("Ready"))
        XCTAssertEqual(try parse("* SEARCH 2 84"), .data([.atom("SEARCH"), .number(2), .number(84)]))
        XCTAssertEqual(IMAPResponseParser.literalSize(endingLine: Data("* 1 FETCH (BODY[TEXT] {342}".utf8)), 342)
        XCTAssertNil(IMAPResponseParser.literalSize(endingLine: Data("* 1 EXISTS".utf8)))
        let literal = try fetched("* 1 FETCH (BODY[TEXT] {11}\r\nHello World UID 4)")
        XCTAssertEqual(literal.sections["TEXT"], Data("Hello World".utf8))
        XCTAssertEqual(literal.uid, 4)
        XCTAssertEqual(try fetched("* 1 FETCH (BODY[TEXT] {9}\r\nHello Wor UID 5)").sections["TEXT"], Data("Hello Wor".utf8))
    }

    func testEnvelopeAndBodyStructure() throws {
        let raw = "* 12 FETCH (FLAGS (\\Seen) INTERNALDATE \"17-Jul-1996 02:44:25 -0700\" RFC822.SIZE 4286 ENVELOPE (\"Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\" \"IMAP4rev1 WG mtg\" ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((NIL NIL \"imap\" \"cac.washington.edu\")) ((NIL NIL \"minutes\" \"CNRI.Reston.VA.US\") (\"John Klensin\" NIL \"KLENSIN\" \"MIT.EDU\")) NIL NIL \"<B27397@cac.washington.edu>\"))"
        let result = try fetched(raw)
        XCTAssertEqual(result.flags, ["\\seen"])
        XCTAssertEqual(result.envelope?.from.first?.display, "Terry Gray")
        XCTAssertEqual(result.envelope?.cc.count, 2)
        XCTAssertEqual(result.internalDate, Date(timeIntervalSince1970: 837_596_665))
        XCTAssertEqual(result.envelope?.date.flatMap(DateEngine.parseMessageDate), Date(timeIntervalSince1970: 837_595_405))
        let nested = "* 3 FETCH (BODYSTRUCTURE ((\"TEXT\" \"HTML\" (\"CHARSET\" \"utf-8\") NIL NIL \"QUOTED-PRINTABLE\" 20 1 NIL NIL NIL)(\"APPLICATION\" \"PDF\" (\"NAME\" \"a.pdf\") NIL NIL \"BASE64\" 100 NIL (\"ATTACHMENT\" (\"FILENAME\" \"a.pdf\")) NIL) \"MIXED\" (\"BOUNDARY\" \"x\") NIL NIL))"
        let structure = try XCTUnwrap(try fetched(nested).structure)
        XCTAssertEqual(structure.firstHTML?.section, "1")
        XCTAssertNil(structure.firstPlainText)
        XCTAssertEqual(structure.attachments.first?.filename, "a.pdf")
        let single = try XCTUnwrap(try fetched("* 1 FETCH (BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"UTF-8\") NIL NIL \"7BIT\" 3028 92))").structure)
        XCTAssertEqual(single.section, "1")
        XCTAssertEqual(single.firstPlainText?.section, "1")
    }

    func testFolderNamesAndEncodedWords() {
        XCTAssertEqual(IMAPFolderNameCodec.decode("~peter/mail/&U,BTFw-/&ZeVnLIqe-"), "~peter/mail/\u{53F0}\u{5317}/\u{65E5}\u{672C}\u{8A9E}")
        XCTAssertEqual(IMAPFolderNameCodec.encode("Entw\u{FC}rfe & mehr"), "Entw&APw-rfe &- mehr")
        XCTAssertEqual(IMAPFolderNameCodec.encode("~ peter"), "~ peter")
        XCTAssertEqual(MIME.decodeEncodedWords("=?ISO-8859-1?Q?a?= b"), "a b")
        XCTAssertEqual(MIME.decodeEncodedWords("=?UTF-8?Q?Keld_J=C3=B8rn_Simonsen?= <keld@dkuug.dk>"), "Keld J\u{F8}rn Simonsen <keld@dkuug.dk>")
        XCTAssertEqual(String(decoding: MIME.decodeQuotedPrintable(Data("Caf=C3=A9 =\r\nzu".utf8)), as: UTF8.self), "Caf\u{E9} zu")
        XCTAssertEqual(MIME.resolveExtended([("filename*", "UTF-8''%E2%82%AC%20rates.txt")])["filename"], "\u{20AC} rates.txt")
        XCTAssertEqual(MIME.resolveExtended([("filename*0*", "utf-8''long%20"), ("filename*1*", "name.txt")])["filename"], "long name.txt")
        XCTAssertEqual(MIME.parseHeaders(Data("Subject: one\r\n two\r\nFrom: a@b.c\r\n\r\nbody".utf8)).first?.value, "one two")
    }

    func testSMTPPieces() throws {
        XCTAssertEqual(SMTPDotStuffing.apply(Data("Hi\r\n.hidden\r\n..two\r\n.".utf8)), Data("Hi\r\n..hidden\r\n...two\r\n..\r\n.\r\n".utf8))
        let reply = try SMTPReply.assemble(["250-smtp.example.com greets", "250-SIZE 14680064", "250 STARTTLS"])
        XCTAssertEqual(reply.code, 250)
        XCTAssertEqual(reply.lines.count, 3)
        XCTAssertThrowsError(try SMTPReply.parseLine("xx"))
    }

    func testFailureClassification() {
        XCTAssertEqual(FailureEngine.classify(MailFailure.authenticationRejected("NO [AUTHENTICATIONFAILED] bad")).kind, .signIn)
        XCTAssertEqual(FailureEngine.classify(MailFailure.timeout).kind, .transient)
        XCTAssertEqual(FailureEngine.classify(MailFailure.smtpRejected(451, "4.3.0 try later")).kind, .transient)
        XCTAssertEqual(FailureEngine.classify(MailFailure.smtpRejected(535, "5.7.8 bad")).kind, .signIn)
        XCTAssertEqual(FailureEngine.classify(MailFailure.recipientRejected("x@y", 550, "5.1.1 no")).original.extra["recipient"], "x@y")
        XCTAssertEqual(FailureEngine.classify(MailFailure.messageNotFound("1")).kind, .rejected)
    }

    func testConnectionValuesAreValidated() throws {
        let base = ["address": "jo@example.test", "password": "pw", "incomingHost": "imap.example.test", "outgoingHost": "smtp.example.test"]
        let connection = try ConnectionEngine(values: base)
        XCTAssertEqual(connection.incoming.port, 993)
        XCTAssertEqual(connection.outgoing.port, 465)
        XCTAssertEqual(connection.username, "jo@example.test")
        XCTAssertThrowsError(try ConnectionEngine(values: base.merging(["incomingSecurity": "none"]) { $1 })) {
            XCTAssertEqual($0 as? ConnectionFailure, .insecure(field: "incomingSecurity"))
        }
        XCTAssertThrowsError(try ConnectionEngine(values: base.merging(["outgoingPort": "70000"]) { $1 }))
        XCTAssertThrowsError(try ConnectionEngine(values: base.merging(["address": "nope"]) { $1 }))
        XCTAssertEqual(try ConnectionEngine(values: connection.values), connection)
    }

    func testProviderOffersPresetsInOrder() {
        let access = IMAPAccess()
        XCTAssertEqual(access.presets.map(\.id), ["ionos", "gmx", "webde", "icloud", "fastmail", "generic"])
        XCTAssertEqual(access.presets.first?.values["incomingHost"], "imap.ionos.de")
        XCTAssertEqual(access.presets.last?.values["incomingSecurity"], "ssl")
        XCTAssertEqual(access.offers(personal: .company).count, 6)
    }

    func testProbeMapsFailuresToHints() async throws {
        let inlet = Inlet(id: "a", provider: "imap", capabilities: [.mail], owner: .company, title: "t")
        let grant = Grant(values: ["address": "jo@example.test", "password": "pw", "incomingHost": "h", "outgoingHost": "s"])
        let accepted = try await ConnectionCheck(run: { _, _ in }).probe(inlet, grant)
        XCTAssertNil(accepted.rejection)
        let refused = try await ConnectionCheck(run: { _, _ in
            throw ProbeFailure(step: .incoming, reason: .authenticationRejected("NO"))
        }).probe(inlet, grant)
        XCTAssertEqual(refused.rejection?.text, "hint.imap.login.rejected")
        let down = try await ConnectionCheck(run: { _, _ in
            throw ProbeFailure(step: .outgoing, reason: .timeout)
        }).probe(inlet, grant)
        XCTAssertEqual(down.rejection?.text, "hint.smtp.connection.timeout")
        XCTAssertEqual(down.rejection?.kind, .transient)
        let invalid = try await ConnectionCheck(run: { _, _ in }).probe(inlet, Grant(values: [:]))
        XCTAssertEqual(invalid.rejection?.text, "hint.imap.fields.invalid")
    }

    func testScriptedIMAPSessionLogsInAndLists() async throws {
        let stream = ScriptedStream(greeting: ["* OK [CAPABILITY IMAP4rev1 AUTH=PLAIN] ready"]) { line in
            let tag = line.split(separator: " ").first.map(String.init) ?? ""
            if line.contains("AUTHENTICATE") { return ["+ "] }
            if line.hasSuffix("=") || !line.contains(" ") { return ["\(tag) OK done"] }
            if line.contains("LIST") { return ["* LIST (\\HasNoChildren) \"/\" \"INBOX\"", "\(tag) OK done"] }
            return ["\(tag) OK done"]
        }
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
        let session = try await IMAPClient.open(settings: settings, opener: { _, _, _ in stream })
        let capability = await session.has("AUTH=PLAIN")
        XCTAssertTrue(capability)
    }

    private func scriptedServer(capabilities: String = "", _ answer: @escaping @Sendable (String, String) -> [String]?) -> ScriptedStream {
        let last = Locked("")
        return ScriptedStream(greeting: ["* OK ready"]) { line in
            let tag = line.split(separator: " ").first.map(String.init) ?? ""
            if !line.contains(" ") { return [last.with { $0 } + " OK done"] }
            last.with { $0 = tag }
            if line.contains("AUTHENTICATE") { return ["+ "] }
            if line.hasSuffix("CAPABILITY") { return ["* CAPABILITY IMAP4rev1 AUTH=PLAIN UIDPLUS" + capabilities, "\(tag) OK done"] }
            return answer(tag, line) ?? ["\(tag) OK done"]
        }
    }

    func testIMAPSessionAsksForCapabilitiesAndAnswersTheContinuation() async throws {
        let stream = scriptedServer { _, _ in nil }
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
        let session = try await IMAPClient.open(settings: settings, opener: { _, _, _ in stream })
        let plain = await session.has("AUTH=PLAIN")
        XCTAssertTrue(plain)
        try await session.authenticate(user: "u", secret: "s")
        let uidplus = await session.has("UIDPLUS")
        XCTAssertTrue(uidplus)
        let wire = stream.sent.with { $0.map { String(decoding: $0, as: UTF8.self) }.joined() }
        XCTAssertTrue(wire.contains(Data("\0u\0s".utf8).base64EncodedString()))
    }

    func testWasSentSearchesTheFolderItIsGiven() async throws {
        let selected = Locked("")
        let stream = scriptedServer { tag, line in
            if line.contains("EXAMINE") {
                selected.with { $0 = line }
                return ["* OK [UIDVALIDITY 7] ok", "\(tag) OK done"]
            }
            if line.contains("SEARCH") {
                return [selected.with { $0.hasSuffix("\"Sent\"") } ? "* SEARCH 5" : "* SEARCH", "\(tag) OK done"]
            }
            return nil
        }
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
        let account = Account(id: "a", displayName: "Me", address: "me@example.com", incoming: settings, outgoing: settings)
        let client = IMAPSMTPClient(account: account, password: { "s" }, opener: { _, _, _ in stream })
        let sent = try await client.wasSent(messageID: "<m@x>", in: "Sent")
        XCTAssertTrue(sent)
        do {
            _ = try await client.wasSent(messageID: "<m@x>", in: nil)
            XCTFail("expected folderNotFound")
        } catch MailFailure.folderNotFound {
        }
    }

    func testListAsksForSpecialUseOnlyWhenTheServerAdvertisesIt() async throws {
        let seen = Locked<[String]>([])
        let stream = scriptedServer(capabilities: " SPECIAL-USE") { tag, line in
            if line.contains("LIST") {
                seen.with { $0.append(line) }
                return ["* LIST (\\HasNoChildren \\Junk) \"/\" \"Spamverdacht\"", "\(tag) OK done"]
            }
            return nil
        }
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
        let account = Account(id: "a", displayName: "Me", address: "me@example.com", incoming: settings, outgoing: settings)
        let client = IMAPSMTPClient(account: account, password: { "s" }, opener: { _, _, _ in stream })
        let folders = try await client.listFolders()
        XCTAssertEqual(folders.map(\.role), [.spam])
        XCTAssertTrue(seen.with { $0 }.allSatisfy { $0.contains("RETURN (SPECIAL-USE)") })
    }

    private func listed(_ rows: [(String, String)]) -> [IMAPListEntry] {
        rows.map { attributes, path in
            IMAPListEntry(attributes: Set(attributes.split(separator: " ").map { $0.lowercased() }), delimiter: "/", path: path)
        }
    }

    func testRolesFollowAttributeThenProviderNames() {
        let gmx = listed([("", "INBOX"), ("", "Gesendet"), ("", "Entw\u{FC}rfe"), ("", "Spamverdacht"), ("", "Papierkorb"),
                          ("", "OUTBOX"), ("", "Kunden")])
        XCTAssertEqual(IMAPListEntry.roles(gmx), [.inbox, .sent, .drafts, .spam, .trash, .other, .other])
        let outlook = listed([("", "Junk Email"), ("", "Deleted Items"), ("", "Sent Items"), ("", "Archive")])
        XCTAssertEqual(IMAPListEntry.roles(outlook), [.spam, .trash, .sent, .archive])
        let ionos = listed([("", "Gesendete Objekte")])
        XCTAssertEqual(IMAPListEntry.roles(ionos), [.sent])
        let icloud = listed([("", "Deleted Messages"), ("", "Sent Messages")])
        XCTAssertEqual(IMAPListEntry.roles(icloud), [.trash, .sent])
    }

    func testEachRoleIsHeldByExactlyOneFolderAndTheAttributeWins() {
        let rows = listed([("", "Sent"), ("\\Sent", "Versendet"), ("", "Gesendet"), ("", "Trash"), ("", "Papierkorb")])
        XCTAssertEqual(IMAPListEntry.roles(rows), [.other, .sent, .other, .trash, .other])
    }

    @MainActor
    func testFoldersThatVanishLeaveNoRowsBehind() async throws {
        let rig = try Rig()
        rig.transport.folderList.with {
            $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Old", name: "Old", role: .other)]
        }
        rig.fill("Old", count: 2, from: Date())
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "Old")
        XCTAssertEqual(rig.mailbox.messages("a", folder: "Old").count, 2)
        rig.transport.folderList.with { $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox)] }
        try await rig.mailbox.refreshFolders("a")
        XCTAssertEqual(rig.mailbox.messages("a", folder: "Old").count, 0)
        XCTAssertNil(rig.mailbox.lastSync("a", folder: "Old"))
        XCTAssertNil(rig.mailbox.cursor("a", MailboxStore.reachKey("Old")))
    }

    @MainActor
    func testArchiveSendsTheResolvedFolderToTheTransport() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        try await rig.mailbox.archive("a", messageID: "1:1:INBOX")
        XCTAssertEqual(rig.transport.lastFolderID.with { $0 }, "Archive")
    }

    func testSMTPSessionSendsWithDotStuffing() async throws {
        let stream = ScriptedStream(greeting: ["220 hi"]) { line in
            if line.hasPrefix("EHLO") { return ["250-h", "250 AUTH PLAIN"] }
            if line.hasPrefix("AUTH") { return ["235 ok"] }
            if line.hasPrefix("MAIL") || line.hasPrefix("RCPT") { return ["250 ok"] }
            if line == "DATA" { return ["354 go"] }
            if line == "." { return ["250 queued"] }
            if line == "QUIT" { return ["221 bye"] }
            return []
        }
        let settings = ServerSettings(host: "h", port: 465, security: .ssl, username: "u")
        let session = try await SMTPSession.open(settings: settings, opener: { _, _, _ in stream })
        try await session.authenticate(user: "u", secret: "s")
        try await session.send(from: "a@b.c", recipients: ["d@e.f"], message: Data("Hi\r\n.x\r\n".utf8))
        let wire = stream.sent.with { $0.map { String(decoding: $0, as: UTF8.self) }.joined() }
        XCTAssertTrue(wire.contains("..x"))
    }

    private func oauthIMAP(capabilities: String, continuation: Bool = false, fail: Bool = false) -> ScriptedStream {
        let last = Locked("")
        let payload = XOAuth2Engine.initialResponse(user: "u@x", token: "tok")
        return ScriptedStream(greeting: ["* OK ready"]) { line in
            let tag = line.split(separator: " ").first.map(String.init) ?? ""
            if line == payload {
                let tagged = last.with { $0 }
                return fail ? ["+ eyJzdGF0dXMiOiI0MDEifQ==", "\(tagged) NO AUTHENTICATE failed"] : ["\(tagged) OK done"]
            }
            last.with { $0 = tag }
            if line.hasSuffix("CAPABILITY") { return ["* CAPABILITY IMAP4rev1 " + capabilities, "\(tag) OK done"] }
            if line.contains("AUTHENTICATE XOAUTH2 ") { return fail ? ["+ err", "\(tag) NO AUTHENTICATE failed"] : ["\(tag) OK done"] }
            if line.contains("AUTHENTICATE XOAUTH2") { return ["+ "] }
            return ["\(tag) OK done"]
        }
    }

    private func wire(_ stream: ScriptedStream) -> String {
        stream.sent.with { $0.map { String(decoding: $0, as: UTF8.self) }.joined() }
    }

    func testXOAuth2PayloadHoldsTheUserAndTheBearerToken() {
        let decoded = Data(base64Encoded: XOAuth2Engine.initialResponse(user: "me@outlook.com", token: "abc"))
        XCTAssertEqual(decoded.map { String(decoding: $0, as: UTF8.self) }, "user=me@outlook.com\u{01}auth=Bearer abc\u{01}\u{01}")
    }

    func testIMAPSessionSendsXOAuth2AsInitialResponseWhenTheServerAllowsIt() async throws {
        let stream = oauthIMAP(capabilities: "AUTH=XOAUTH2 SASL-IR")
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
        let session = try await IMAPClient.open(settings: settings, opener: { _, _, _ in stream })
        try await session.authenticate(user: "u@x", credential: .accessToken("tok"))
        XCTAssertTrue(wire(stream).contains("AUTHENTICATE XOAUTH2 " + XOAuth2Engine.initialResponse(user: "u@x", token: "tok")))
    }

    func testIMAPSessionSendsXOAuth2AfterTheContinuationWithoutInitialResponse() async throws {
        let stream = oauthIMAP(capabilities: "AUTH=XOAUTH2")
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
        let session = try await IMAPClient.open(settings: settings, opener: { _, _, _ in stream })
        try await session.authenticate(user: "u@x", credential: .accessToken("tok"))
        let text = wire(stream)
        XCTAssertTrue(text.contains("AUTHENTICATE XOAUTH2\r\n"))
        XCTAssertTrue(text.contains(XOAuth2Engine.initialResponse(user: "u@x", token: "tok") + "\r\n"))
    }

    func testIMAPXOAuth2RejectionAnswersTheErrorChallengeAndReportsTheRejection() async throws {
        for capabilities in ["AUTH=XOAUTH2", "AUTH=XOAUTH2 SASL-IR"] {
            let stream = oauthIMAP(capabilities: capabilities, fail: true)
            let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
            let session = try await IMAPClient.open(settings: settings, opener: { _, _, _ in stream })
            do {
                try await session.authenticate(user: "u@x", credential: .accessToken("tok"))
                XCTFail("expected a rejection")
            } catch MailFailure.authenticationRejected {
                XCTAssertTrue(wire(stream).hasSuffix("\r\n\r\n"))
            }
        }
    }

    func testIMAPXOAuth2NeedsTheCapabilityAndPasswordsStayOnPlain() async throws {
        let stream = oauthIMAP(capabilities: "AUTH=PLAIN")
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
        let session = try await IMAPClient.open(settings: settings, opener: { _, _, _ in stream })
        do {
            try await session.authenticate(user: "u@x", credential: .accessToken("tok"))
            XCTFail("expected unsupported")
        } catch MailFailure.unsupportedAuthentication {
            XCTAssertFalse(wire(stream).contains("AUTHENTICATE"))
        }
    }

    func testSMTPSessionAuthenticatesWithXOAuth2() async throws {
        let stream = ScriptedStream(greeting: ["220 hi"]) { line in
            if line.hasPrefix("EHLO") { return ["250-h", "250 AUTH LOGIN XOAUTH2"] }
            if line.hasPrefix("AUTH XOAUTH2 ") { return ["235 ok"] }
            return []
        }
        let settings = ServerSettings(host: "h", port: 465, security: .ssl, username: "u")
        let session = try await SMTPSession.open(settings: settings, opener: { _, _, _ in stream })
        try await session.authenticate(user: "u@x", credential: .accessToken("tok"))
        XCTAssertTrue(wire(stream).contains("AUTH XOAUTH2 " + XOAuth2Engine.initialResponse(user: "u@x", token: "tok")))
    }

    func testSMTPXOAuth2RejectionAnswersTheErrorChallenge() async throws {
        let stream = ScriptedStream(greeting: ["220 hi"]) { line in
            if line.hasPrefix("EHLO") { return ["250-h", "250 AUTH XOAUTH2"] }
            if line.hasPrefix("AUTH XOAUTH2 ") { return ["334 eyJzdGF0dXMiOiI0MDEifQ==", "535 5.7.3 Authentication unsuccessful"] }
            return []
        }
        let settings = ServerSettings(host: "h", port: 465, security: .ssl, username: "u")
        let session = try await SMTPSession.open(settings: settings, opener: { _, _, _ in stream })
        do {
            try await session.authenticate(user: "u@x", credential: .accessToken("tok"))
            XCTFail("expected a rejection")
        } catch MailFailure.authenticationRejected(let text) {
            XCTAssertTrue(text.hasPrefix("535"))
            XCTAssertTrue(wire(stream).hasSuffix("\r\n\r\n"))
        }
    }

    func testSMTPXOAuth2NeedsTheMechanism() async throws {
        let stream = ScriptedStream(greeting: ["220 hi"]) { line in
            line.hasPrefix("EHLO") ? ["250-h", "250 AUTH PLAIN LOGIN"] : []
        }
        let settings = ServerSettings(host: "h", port: 465, security: .ssl, username: "u")
        let session = try await SMTPSession.open(settings: settings, opener: { _, _, _ in stream })
        do {
            try await session.authenticate(user: "u@x", credential: .accessToken("tok"))
            XCTFail("expected unsupported")
        } catch MailFailure.unsupportedAuthentication {
            XCTAssertFalse(wire(stream).contains("AUTH PLAIN"))
        }
    }

    func testConnectionCheckAuthenticatesBothServersWithTheToken() async throws {
        let incoming = oauthIMAP(capabilities: "AUTH=XOAUTH2 SASL-IR")
        let outgoing = ScriptedStream(greeting: ["220 hi"]) { line in
            if line.hasPrefix("EHLO") { return ["250-h", "250-STARTTLS", "250 AUTH XOAUTH2"] }
            if line == "STARTTLS" { return ["220 go"] }
            if line.hasPrefix("AUTH XOAUTH2 ") { return ["235 ok"] }
            if line == "QUIT" { return ["221 bye"] }
            return []
        }
        let endpoints = OAuthMailEndpoints(incomingHost: "imap.test", incomingPort: 993, outgoingHost: "smtp.test", outgoingPort: 587)
        try await ConnectionCheck.probe(
            account: endpoints.account(id: "a", address: "u@x", name: "U"), credential: .accessToken("tok"),
            opener: { host, _, _ in host == "imap.test" ? incoming : outgoing })
        XCTAssertTrue(wire(incoming).contains("AUTHENTICATE XOAUTH2"))
        XCTAssertTrue(wire(outgoing).contains("AUTH XOAUTH2"))
    }

    func testConnectionCheckRefusesAnEmptyToken() async {
        let endpoints = OAuthMailEndpoints(incomingHost: "imap.test", incomingPort: 993, outgoingHost: "smtp.test", outgoingPort: 587)
        do {
            try await ConnectionCheck.probe(account: endpoints.account(id: "a", address: "u@x", name: "U"), credential: .accessToken(""))
            XCTFail("expected a failure")
        } catch let failure as ProbeFailure {
            XCTAssertEqual(failure, ProbeFailure(step: .incoming, reason: .credentialsMissing))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testOAuthEndpointsBuildImplicitTLSIncomingAndStartTLSOutgoing() {
        let endpoints = OAuthMailEndpoints(incomingHost: "i", incomingPort: 993, outgoingHost: "o", outgoingPort: 587)
        let account = endpoints.account(id: "a", address: "me@x", name: "Me")
        XCTAssertEqual(account.incoming, ServerSettings(host: "i", port: 993, security: .ssl, username: "me@x"))
        XCTAssertEqual(account.outgoing, ServerSettings(host: "o", port: 587, security: .starttls, username: "me@x"))
        XCTAssertEqual(account.displayName, "Me")
    }

    func testTheClientAsksForAFreshTokenOnEveryConnection() async throws {
        let counter = Locked(0)
        let stream = oauthIMAP(capabilities: "AUTH=XOAUTH2 SASL-IR")
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u@x")
        let account = Account(id: "a", displayName: "", address: "u@x", incoming: settings, outgoing: settings)
        let client = IMAPSMTPClient(
            account: account, credential: {
                counter.with { $0 += 1 }
                return .accessToken("tok")
            }, opener: { _, _, _ in stream })
        _ = try? await client.listFolders()
        XCTAssertEqual(counter.with { $0 }, 1)
        XCTAssertTrue(wire(stream).contains("AUTHENTICATE XOAUTH2"))
    }

    func testSizeRejectionsBecomeTooLarge() {
        XCTAssertTrue(DeliveryEngine.tooLarge(Original(provider: "smtp", status: 552, code: "5.3.4")))
        XCTAssertTrue(DeliveryEngine.tooLarge(Original(provider: "smtp", status: 550, code: "5.2.3")))
        XCTAssertTrue(DeliveryEngine.tooLarge(Original(provider: "gmail", status: 413)))
        XCTAssertFalse(DeliveryEngine.tooLarge(Original(provider: "smtp", status: 550, code: "5.1.1")))
        let attachment = Attachment(filename: "a", mimeType: "application/pdf", data: Data(count: 300))
        XCTAssertEqual(MessageEngine.encodedSize(Draft(subject: "", body: "ab", attachments: [attachment])), 2 + 400 + 10)
    }

    func testHTMLEngine() {
        let blocked = HTMLEngine.blockingImages(#"<p>a</p><IMG alt="x" src="https://t.co/p.png"><img src="cid:logo"><img src='http://x/y.gif'>"#,
                                                label: "Bild <blockiert>")
        XCTAssertEqual(blocked, #"<p>a</p><span class="alfa-blocked">Bild &lt;blockiert&gt;</span><img src="cid:logo"><span class="alfa-blocked">Bild &lt;blockiert&gt;</span>"#)
        XCTAssertEqual(HTMLEngine.plain("<p>Caf&eacute; &amp; <b>Tee</b></p><style>x{}</style><br>zu"), "Caf\u{E9} & Tee\n\nzu")
        XCTAssertEqual(HTMLEngine.navigation(scheme: "javascript", linkActivated: true, mainFrame: true), .cancel)
        XCTAssertEqual(HTMLEngine.navigation(scheme: "https", linkActivated: true, mainFrame: true), .open)
        XCTAssertEqual(HTMLEngine.navigation(scheme: nil, linkActivated: false, mainFrame: true), .allow)
        let png = Data([0x89, 0x50, 0x00])
        XCTAssertEqual(HTMLEngine.mimeType(of: png), "image/png")
        let source = HTMLEngine.inlineSource("cid:<logo>", in: ["logo": "data:image/png;base64," + png.base64EncodedString()])
        XCTAssertEqual(source, .embedded(png, mime: "image/png"))
        XCTAssertEqual(HTMLEngine.inlineSource("cid:att", in: ["att": "2"]), .attachment("2"))
    }

    func testHTMLPlainKeepsParagraphsListsBreaksAndLinks() {
        XCTAssertEqual(HTMLEngine.plain("<p>One</p><p>Two</p>"), "One\n\nTwo")
        XCTAssertEqual(HTMLEngine.plain("<div>a</div><div><br></div><div>b</div>"), "a\n\nb")
        XCTAssertEqual(HTMLEngine.plain("a<br>b<br><br>c"), "a\nb\n\nc")
        XCTAssertEqual(HTMLEngine.plain("<ul><li>x</li><li>y</li></ul>"), "\u{2022} x\n\u{2022} y")
        XCTAssertEqual(HTMLEngine.plain("<ol><li>x</li><li>y<ul><li>z</li></ul></li></ol>"), "1. x\n2. y\n  \u{2022} z")
        XCTAssertEqual(HTMLEngine.plain("<p>wrapped\n    line\ttext</p>\n\n\n<p>next</p>"), "wrapped line text\n\nnext")
        XCTAssertEqual(HTMLEngine.plain("<a href=\"https://x.de/a?b=1&amp;c=2\">Click</a>"), "Click (https://x.de/a?b=1&c=2)")
        XCTAssertEqual(HTMLEngine.plain("<a href=\"https://x.de\">https://x.de/</a>"), "https://x.de/")
        XCTAssertEqual(HTMLEngine.plain("<a href=\"mailto:a@x.de\">a@x.de</a>"), "a@x.de")
        XCTAssertEqual(HTMLEngine.plain("<div style=\"display:none\">hidden<div>deep</div></div><p>shown</p>"), "shown")
        XCTAssertEqual(HTMLEngine.plain("<table><tr><td>A</td><td>B</td></tr><tr><td>C</td></tr></table>"), "A B\nC")
        XCTAssertEqual(HTMLEngine.plain("<pre>a\n  b</pre>"), "a\n  b")
        XCTAssertEqual(HTMLEngine.plain("x<!-- c --><script>var a = '<p>';</script>y&zwnj;&nbsp;z"), "xy z")
        XCTAssertEqual(HTMLEngine.plain("<p>Hi</p><blockquote>q1<blockquote>q2</blockquote>q3</blockquote><p>end</p>"),
                       "Hi\n\n> q1\n> > q2\n>\n> q3\n\nend")
    }

    func testHTMLPlainJoinsInlineBoxesAndCollapsedGaps() {
        XCTAssertEqual(HTMLEngine.plain("<span>2</span><span>0</span> GB"), "20 GB")
        XCTAssertEqual(HTMLEngine.plain("<div style=\"display:inline-block\">2</div><div style=\"display:inline-block\">0</div> GB"), "20 GB")
        XCTAssertEqual(HTMLEngine.plain("<div style=\"font-size:0\"><span>2</span>\n  <span>0</span><span> GB</span></div>"), "20 GB")
        XCTAssertEqual(HTMLEngine.plain("<div style=\"display:inline\">a</div><div>b</div><p>c</p>"), "a\nb\n\nc")
        XCTAssertEqual(HTMLEngine.plain("<div>a</div><div>b</div>"), "a\nb")
        XCTAssertEqual(HTMLEngine.plain("<div style=\"font-size:0.8em\"><b>Hi</b> <b>there</b></div>"), "Hi there")
    }

    func testHTMLPartsFoldTheQuoteLikeTheTextRule() {
        let gmail = "<div dir=\"ltr\">Hello<br></div><br><div class=\"gmail_quote\"><div class=\"gmail_attr\">On Tue, 20 Oct 2026 at 10:00, Anna &lt;anna@x.de&gt; wrote:<br></div><blockquote class=\"gmail_quote\" style=\"margin:0\"><div>old text</div><blockquote class=\"gmail_quote\"><div>older</div></blockquote></blockquote></div>"
        let folded = HTMLEngine.parts(gmail)
        XCTAssertTrue(folded.body.contains("Hello"))
        XCTAssertFalse(folded.body.contains("old text"))
        XCTAssertEqual(folded.quote?.text, "On Tue, 20 Oct 2026 at 10:00, Anna <anna@x.de> wrote:\n> old text\n> > older")
        XCTAssertEqual(folded.quote?.lines, 3)
        let apple = "<div>Hi</div><div><br></div><div>On 20 Oct 2026, at 10:00, Anna <a href=\"mailto:a@x.de\">a@x.de</a> wrote:</div><blockquote type=\"cite\"><div>old</div></blockquote>"
        let cited = HTMLEngine.parts(apple)
        XCTAssertFalse(cited.body.contains("wrote"))
        XCTAssertEqual(cited.quote?.text, "On 20 Oct 2026, at 10:00, Anna a@x.de wrote:\n> old")
        let inline = HTMLEngine.parts("<p>On Mon Anna wrote:</p><blockquote type=\"cite\">q</blockquote><p>my answer below</p>")
        XCTAssertNil(inline.quote)
        let newsletter = HTMLEngine.parts("<p>Intro</p><blockquote>What customers say</blockquote>")
        XCTAssertNil(newsletter.quote)
        let forward = HTMLEngine.parts("<p>FYI</p><div class=\"gmail_quote\">---------- Forwarded message ---------<br>From: A</div>")
        XCTAssertNil(forward.quote)
        let outlook = HTMLEngine.parts("<p>Reply</p><div id=\"appendonsend\"></div><hr><div id=\"divRplyFwdMsg\"><b>From:</b> A</div><div>old body</div>")
        XCTAssertFalse(outlook.body.contains("old body"))
        XCTAssertFalse(outlook.body.contains("<hr"))
        XCTAssertEqual(outlook.quote?.text, "From: A\nold body")
        XCTAssertEqual(HTMLEngine.parts("<p>plain</p>").body, "<p>plain</p>")
    }

    func testHTMLPartsFindAndBlockRemoteContent() {
        let remote = "<p>x</p><img src=\"https://t.example/p.gif\" alt=\"a\"><td background=\"//t.example/b.png\"><div style=\"background:url('http://t.example/c.png') red;color:blue\"></div><style>@import url(https://f.example/x.css); .a{background:url(https://t.example/d.png)}</style><link rel=\"stylesheet\" href=\"https://f.example/y.css\"><script src=\"https://s.example/z.js\"></script>"
        let parts = HTMLEngine.parts(remote)
        XCTAssertTrue(parts.remote)
        XCTAssertFalse(parts.blockedBody.contains("example"))
        XCTAssertTrue(parts.blockedBody.contains("alt=\"a\""))
        XCTAssertTrue(parts.blockedBody.contains("color:blue"))
        XCTAssertEqual(parts.body, remote)
        let local = "<p>x</p><img src=\"cid:logo\"><img src=\"data:image/png;base64,AAAA\"><a href=\"https://x.de\">l</a>"
        let safe = HTMLEngine.parts(local)
        XCTAssertFalse(safe.remote)
        XCTAssertEqual(safe.blockedBody, local)
        let card = OpenMessage(inlet: "a", summary: MessageSummary(id: "1", subject: "S", from: "B"), content: .html(remote, inlineImages: [:]),
                               htmlParts: parts)
        XCTAssertTrue(card.remoteImagesBlocked(loadRemote: false))
        XCTAssertFalse(card.remoteImagesBlocked(loadRemote: true))
        let plain = OpenMessage(inlet: "a", summary: MessageSummary(id: "1", subject: "S", from: "B"), content: .html(local, inlineImages: [:]),
                                htmlParts: safe)
        XCTAssertFalse(plain.remoteImagesBlocked(loadRemote: false))
    }

    func testQuotingKeepsAttributionOnOneLineAndHandlesDividers() {
        let wrapped = Quoting.split("Hi\n\nOn Tue, 20 Oct 2026 at 10:00, Anna\n<anna@x.de> wrote:\n> old\n> > older")
        XCTAssertEqual(wrapped.body, "Hi")
        XCTAssertEqual(wrapped.quote?.text, "On Tue, 20 Oct 2026 at 10:00, Anna <anna@x.de> wrote:\n> old\n> > older")
        XCTAssertEqual(wrapped.quote?.lines, 3)
        let german = Quoting.split("Ja\nAm 20.10.2026 um 10:00 Uhr schrieb Anna <a@x.de>:\n\n> alt")
        XCTAssertEqual(german.body, "Ja")
        XCTAssertEqual(german.quote?.lines, 2)
        let outlook = Quoting.split("Thanks\n\n-----Original Message-----\nFrom: A\nSent: x\n\nold")
        XCTAssertEqual(outlook.body, "Thanks")
        XCTAssertEqual(outlook.quote?.lines, 4)
        let rule = Quoting.split("Danke\n________________________________\nVon: A\nGesendet: x\nalt")
        XCTAssertEqual(rule.body, "Danke")
        XCTAssertEqual(rule.quote?.lines, 4)
        let none = Quoting.split("Von: ich\nkeine Zitate")
        XCTAssertNil(none.quote)
        XCTAssertEqual(none.body, "Von: ich\nkeine Zitate")
        XCTAssertNil(Quoting.split("-----Zwischenstrich-----\ntext").quote)
    }

    func testFlowedTextAndPartialDecoding() {
        XCTAssertEqual(MIME.unflow("Hello wor \nld again\n-- \nSig", delSp: false), "Hello wor ld again\n-- \nSig")
        XCTAssertEqual(MIME.unflow("Hello wor \nld", delSp: true), "Hello world")
        XCTAssertEqual(MIME.unflow("> aaa \n> bbb\n>\n> ccc\n\n d", delSp: false), "> aaa bbb\n>\n> ccc\n\nd")
        XCTAssertEqual(FlowedEngine.text(Data("a \nb".utf8), contentType: "text/plain; charset=utf-8; format=flowed; delsp=yes"), "ab")
        XCTAssertEqual(FlowedEngine.text(Data("a \nb".utf8), contentType: "text/plain"), "a \nb")
        XCTAssertEqual(FlowedEngine.text(Data([0x47, 0x72, 0xFC, 0xDF, 0x65]), contentType: "text/plain; charset=\"ISO-8859-1\""), "Gr\u{FC}\u{DF}e")
        XCTAssertEqual(FlowedEngine.text(Data([0x80, 0x20, 0x35]), contentType: "text/html; charset=windows-1252"), "\u{20AC} 5")
        XCTAssertEqual(MIME.decodeBase64(Data("SGVsbG8gd29ybGQ".utf8)), Data("Hello world".utf8))
        XCTAssertEqual(MIME.decodeBase64(Data("SGVsbG8gd29ybGQhX".utf8)), Data("Hello world!".utf8))
        let cut = Data([0x61, 0x62, 0xC3])
        XCTAssertEqual(MIME.truncatedString(from: cut, charset: "utf-8"), "ab")
        XCTAssertEqual(MIME.truncatedString(from: Data([0x61, 0xC3, 0xA9]), charset: "utf-8"), "a\u{E9}")
        XCTAssertEqual(MIME.truncatedString(from: Data([0x61, 0xE9]), charset: "iso-8859-1"), "a\u{E9}")
    }

    func testLinkEngineMarksWebAndMailAddressesOnly() {
        let text = LinkEngine.attributed("see https://example.com/a and mail me@x.de or call 030 123456")
        let links = text.runs.compactMap { $0.link?.absoluteString }
        XCTAssertEqual(links, ["https://example.com/a", "mailto:me@x.de"])
    }

    func testAttachmentMenuOffersPrintAndPDFOnlyForPrintableTypes() {
        XCTAssertEqual(MenuEngine.attachment(name: "plan.PDF"),
                       [.item(.preview), .item(.print), .item(.pdf), .separator, .item(.otherProject), .item(.saveAs)])
        XCTAssertEqual(MenuEngine.attachment(name: "model.dwg"), [.item(.preview), .separator, .item(.otherProject), .item(.saveAs)])
        XCTAssertEqual(MenuEngine.attachment(name: "noext"), [.item(.preview), .separator, .item(.otherProject), .item(.saveAs)])
        XCTAssertEqual(MenuEngine.attachment(name: "noext", project: false), [.item(.preview), .separator, .item(.saveAs)])
    }

    func testIMAPSummariesCarryAPreviewFetchedOncePerBodySection() async throws {
        let seen = Locked<[String]>([])
        let envelope = "ENVELOPE (\"Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\" \"Kaese\" ((\"T\" NIL \"g\" \"x.test\")) ((\"T\" NIL \"g\" \"x.test\")) ((\"T\" NIL \"g\" \"x.test\")) ((NIL NIL \"me\" \"x.test\")) NIL NIL NIL \"<B1@x.test>\")"
        let structure = "BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"UTF-8\") NIL NIL \"QUOTED-PRINTABLE\" 10 1)"
        let stream = scriptedServer { tag, line in
            seen.with { $0.append(line) }
            if line.contains("EXAMINE") { return ["* OK [UIDVALIDITY 7] ok", "\(tag) OK done"] }
            if line.contains("BODY.PEEK[1]") {
                return ["* 1 FETCH (UID 5 BODY[1]<0> {28}\r\nHallo Welt, sch=C3=B6n da=C3)", "\(tag) OK done"]
            }
            if line.contains("FETCH") {
                return ["* 1 FETCH (UID 5 FLAGS (\\Seen) INTERNALDATE \"17-Jul-1996 02:44:25 -0700\" RFC822.SIZE 1 \(envelope) \(structure))",
                        "* 2 FETCH (UID 6 FLAGS () INTERNALDATE \"17-Jul-1996 02:44:25 -0700\" RFC822.SIZE 1 \(envelope) \(structure))",
                        "\(tag) OK done"]
            }
            return nil
        }
        let found = try await imapClient(stream).fetchSummaries(folderID: "INBOX", ids: ["7:5:INBOX", "7:6:INBOX"])
        XCTAssertEqual(found.first { $0.id == "7:5:INBOX" }?.snippet, "Hallo Welt, sch\u{F6}n da")
        XCTAssertEqual(found.first { $0.id == "7:6:INBOX" }?.snippet, IMAPSMTPClient.previewEmpty)
        let fetches = seen.with { $0.filter { $0.contains("BODY.PEEK[1]") } }
        XCTAssertEqual(fetches.count, 1)
        XCTAssertTrue(fetches[0].contains("<0.4096>"))
        XCTAssertEqual(PreviewEngine.text(IMAPSMTPClient.previewEmpty), "")
        XCTAssertEqual(IMAPSMTPClient.snippet("<style>p{}</style><p>Hallo</p><p>Welt</p>", html: true), "Hallo\n\nWelt")
    }

    func testIMAPPreviewFallsBackToTheWholeHTMLAndLeavesFailedFetchesOpen() async throws {
        let envelope = "ENVELOPE (NIL \"News\" ((\"T\" NIL \"g\" \"x.test\")) NIL NIL ((NIL NIL \"me\" \"x.test\")) NIL NIL NIL \"<N1@x.test>\")"
        let structure = "BODYSTRUCTURE ((\"TEXT\" \"PLAIN\" (\"CHARSET\" \"UTF-8\") NIL NIL \"7BIT\" 4 1)(\"TEXT\" \"HTML\" (\"CHARSET\" \"UTF-8\") NIL NIL \"7BIT\" 40000 1) \"ALTERNATIVE\")"
        let head = "* 1 FETCH (UID 5 FLAGS () INTERNALDATE \"17-Jul-1996 02:44:25 -0700\" RFC822.SIZE 1 \(envelope) \(structure))"
        let failing = Locked(false)
        let stream = scriptedServer { tag, line in
            if line.contains("EXAMINE") { return ["* OK [UIDVALIDITY 7] ok", "\(tag) OK done"] }
            if line.contains("BODY.PEEK[1]") {
                return failing.with { $0 } ? ["\(tag) NO busy"] : ["* 1 FETCH (UID 5 BODY[1]<0> {4}\r\n     )", "\(tag) OK done"]
            }
            if line.contains("BODY.PEEK[2]<0.16384>") { return ["* 1 FETCH (UID 5 BODY[2]<0> {9}\r\n<style>p{ )", "\(tag) OK done"] }
            if line.contains("BODY.PEEK[2]<0.131072>") {
                return ["* 1 FETCH (UID 5 BODY[2]<0> {30}\r\n<style>p{}</style><p>Hallo</p> )", "\(tag) OK done"]
            }
            if line.contains("FETCH") { return [head, "\(tag) OK done"] }
            return nil
        }
        let client = imapClient(stream)
        let found = try await client.fetchSummaries(folderID: "INBOX", ids: ["7:5:INBOX"])
        XCTAssertEqual(found.first?.snippet, "Hallo")
        failing.with { $0 = true }
        let failed = try await client.fetchSummaries(folderID: "INBOX", ids: ["7:5:INBOX"])
        XCTAssertEqual(failed.first?.snippet, "")
    }

    func testNamesQuotesAndLabels() {
        XCTAssertEqual(PersonName.display("\"Gray, Terry\" <g@x.org>").name, "Gray, Terry")
        XCTAssertEqual(PersonName.display("\"lach@x.de\" <lach@x.de>").name, "")
        XCTAssertEqual(PersonName.display("lach@x.de <lach@x.de>").address, "lach@x.de")
        XCTAssertEqual(PersonName.middle("abcdefghij", limit: 5).count, 5)
        let split = Quoting.split("Hi\n\nOn Monday Anna wrote:\n> old\n> older")
        XCTAssertEqual(split.body, "Hi")
        XCTAssertEqual(split.quote?.lines, 3)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(DateLabel.of(nil, now: now), .none)
        XCTAssertEqual(DateLabel.of(now.addingTimeInterval(-86_400), now: now), .yesterday)
        XCTAssertEqual(ToastKind.bulkRead(count: 1, read: false).key, "mail.toast.bulkRead.unread.one")
        XCTAssertEqual(RecipientEngine.format(RecipientEngine.parse("A <a@x.de>, b@y.de")), "\"A\" <a@x.de>, b@y.de")
    }

    func testDateLabelNamesTheYearAndUpcomingDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        func day(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9) throws -> Date {
            try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
        }
        let now = try day(2026, 10, 31, 12)
        let lastYear = try day(2025, 12, 31)
        XCTAssertEqual(DateLabel.of(lastYear, now: now, calendar: calendar), .day(lastYear, withYear: true))
        let earlier = try day(2026, 10, 8)
        XCTAssertEqual(DateLabel.of(earlier, now: now, calendar: calendar), .day(earlier, withYear: false))
        XCTAssertEqual(DateLabel.of(try day(2026, 11, 1, 0), now: now, calendar: calendar), .upcoming(days: 1))
        XCTAssertEqual(DateLabel.of(try day(2026, 11, 3, 23), now: now, calendar: calendar), .upcoming(days: 3))
        XCTAssertEqual(DateLabel.of(try day(2026, 11, 6), now: now, calendar: calendar), .upcoming(days: 6))
        let later = try day(2026, 11, 7)
        XCTAssertEqual(DateLabel.of(later, now: now, calendar: calendar), .day(later, withYear: false))
        let nextYear = try day(2027, 1, 2)
        XCTAssertEqual(DateLabel.of(nextYear, now: now, calendar: calendar), .day(nextYear, withYear: true))
        let today = try day(2026, 10, 31, 7)
        XCTAssertEqual(DateLabel.of(today, now: now, calendar: calendar), .time(today))
        let yesterday = try day(2026, 10, 30, 22)
        XCTAssertEqual(DateLabel.of(yesterday, now: now, calendar: calendar), .yesterday)
        let weekday = try day(2026, 10, 27)
        XCTAssertEqual(DateLabel.of(weekday, now: now, calendar: calendar), .weekday(weekday))
    }

    func testMenusOfferOnlyHandledActions() {
        let removed = ["note", "template"]
        XCTAssertTrue(Set(Action.allCases.map(\.rawValue)).isDisjoint(with: removed))
        let lines = MenuEngine.row(unread: true, draft: false) + MenuEngine.readingMore(starred: false, original: true)
            + MenuEngine.attachment(name: "a.pdf")
        XCTAssertFalse(lines.isEmpty)
        let router = SlotRouter.route(.send, front: .draft(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
        XCTAssertEqual(router, .send(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
        XCTAssertEqual(SlotRouter.route(.reply, front: .message("m")), .message(.reply, "m"))
        XCTAssertNil(SlotRouter.route(.send, front: nil))
    }

    func testCommandsFollowTheFront() {
        let reading = CommandEngine.commands(front: .message(hasCopy: false), stackCount: 1, fanned: false, hasFiles: false,
                                             confirmDiscard: false, canFold: true, sendLabelled: false)
        XCTAssertEqual(reading.state, .reading)
        XCTAssertTrue(reading.main.first { $0.id == "replyAll" }?.off == true)
        XCTAssertNil(reading.footLeft.first { $0.id == "toProject" })
        let withFiles = CommandEngine.commands(front: .message(hasCopy: false), stackCount: 1, fanned: false, hasFiles: true,
                                               confirmDiscard: false, canFold: true, sendLabelled: false)
        XCTAssertEqual(withFiles.footLeft.first { $0.id == "toProject" }?.off, false)
        let bare = CommandEngine.commands(front: .draft(canSend: true), stackCount: 1, fanned: false, hasFiles: false,
                                          confirmDiscard: false, canFold: false, sendLabelled: false)
        XCTAssertEqual(bare.footLeft.map(\.id), ["attachFile", "format"])
        XCTAssertEqual(reading.fold.count, 1)
        let confirm = CommandEngine.commands(front: .draft(canSend: true), stackCount: 1, fanned: false, hasFiles: true,
                                             confirmDiscard: true, canFold: true, sendLabelled: true)
        XCTAssertEqual(confirm.state, .confirm)
        XCTAssertTrue(confirm.fold.isEmpty && confirm.fan.isEmpty)
        let draft = CommandEngine.commands(front: .draft(canSend: false), stackCount: 1, fanned: false, hasFiles: true,
                                           confirmDiscard: false, canFold: false, sendLabelled: true)
        XCTAssertEqual(draft.footLeft.map(\.id), ["attachFile", "fromProject", "format"])
        XCTAssertTrue(draft.footRight.last?.off == true)
    }

    @MainActor
    func testMailboxStoreLoadsPageAndKeepsItInTheMirror() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        XCTAssertEqual(rig.mailbox.folders("a").map(\.id), ["INBOX", "Archive", "Trash", Folder.starredID])
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 1)
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").first?.subject, "Hello")
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 1)
        XCTAssertNotNil(rig.mailbox.lastSync("a", folder: "INBOX"))
        XCTAssertEqual(rig.mailbox.searchLocal("a", query: "Hell").count, 1)
        let hits = await rig.mailbox.searchOpen("a", query: "Hello", excluding: ["Trash"])
        XCTAssertEqual(hits.count, 1)
        try await rig.mailbox.setFlags("a", messageID: "1:1:INBOX", add: [.seen], remove: [])
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 0)
    }

    @MainActor
    func testMirrorFetchesAgainOnlyStoredMessagesWithoutPreviewWhenTheTransportFillsPreviews() async throws {
        let rig = try Rig()
        let bare = MessageSummary(id: "1:1:INBOX", threadID: "t", subject: "Hello", from: "Anna", fromRaw: "Anna <anna@example.com>",
                                  toRaw: "me@example.com", snippet: "", flags: [], folderIDs: ["INBOX"], messageIDHeader: "<h1@x>")
        rig.transport.corpus.with { $0["INBOX"] = [bare] }
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.chunks.with { $0 }, [1])
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.chunks.with { $0 }, [1])
        rig.transport.providesPreviews.with { $0 = true }
        var filled = bare
        filled.snippet = "Hallo Welt"
        rig.transport.corpus.with { $0["INBOX"] = [filled] }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.chunks.with { $0 }, [1, 1])
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").first?.snippet, "Hallo Welt")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.chunks.with { $0 }, [1, 1])
    }

    @MainActor
    func testMailboxStoreMapsFailuresAndMovesMessages() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let landed = try await rig.mailbox.archive("a", messageID: "1:1:INBOX")
        XCTAssertEqual(landed, "1:1:Archive")
        XCTAssertTrue(rig.mailbox.messages("a", folder: "INBOX").isEmpty)
        rig.transport.failure.with { $0 = MailFailure.timeout }
        do {
            _ = try await rig.mailbox.body("a", messageID: "x")
            XCTFail()
        } catch {
            guard case .provider(let hint) = error else { return XCTFail() }
            XCTAssertEqual(hint.text, MessageTextKey.offline.rawValue)
        }
        rig.access.connected = false
        do {
            _ = try await rig.mailbox.body("a", messageID: "x")
            XCTFail()
        } catch {
            XCTAssertEqual(error, .notConnected("a"))
        }
    }

    @MainActor
    func testBodyIsKeptLocallyAndReadOffline() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let first = try await rig.mailbox.body("a", messageID: "1:1:INBOX")
        XCTAssertEqual(first.text, "plain text")
        rig.transport.failure.with { $0 = MailFailure.timeout }
        rig.access.connected = false
        let again = try await rig.mailbox.body("a", messageID: "1:1:INBOX")
        XCTAssertEqual(again, first)
        XCTAssertEqual(rig.transport.calls.with { $0.filter { $0 == "fetchBody" }.count }, 1)
    }

    @MainActor
    func testKeptBodyIsDroppedWithItsMessage() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        _ = try await rig.mailbox.body("a", messageID: "1:1:INBOX")
        XCTAssertNotNil(rig.mailbox.keptBody("a", messageID: "1:1:INBOX"))
        try await rig.mailbox.archive("a", messageID: "1:1:INBOX")
        XCTAssertNil(rig.mailbox.keptBody("a", messageID: "1:1:INBOX"))
    }

    @MainActor
    func testFolderListWithoutStarredGainsLocalStarredFolderOfFlaggedMail() async throws {
        let rig = try Rig()
        rig.fill("INBOX", count: 3, from: Date(), flags: [.seen])
        var inbox = rig.transport.corpus.with { $0["INBOX"] } ?? []
        inbox[1].flags.insert(.flagged)
        rig.transport.corpus.with { $0["INBOX"] = inbox }
        try await rig.mailbox.refreshFolders("a")
        XCTAssertEqual(rig.mailbox.folders("a").last, Folder(id: Folder.starredID, name: "", role: .starred))
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.messages("a", folder: Folder.starredID).map(\.id), ["1:1:INBOX"])
        try await rig.mailbox.refresh("a", folder: Folder.starredID)
        XCTAssertFalse(rig.mailbox.canLoadOlder("a", folder: Folder.starredID))
        let hits = try await rig.mailbox.search("a", folder: Folder.starredID, query: "Note 1", scope: .here, continuation: nil)
        XCTAssertEqual(hits.messages.map(\.id), ["1:1:INBOX"])
        let none = try await rig.mailbox.search("a", folder: Folder.starredID, query: "Note 0", scope: .here, continuation: nil)
        XCTAssertTrue(none.messages.isEmpty)
    }

    @MainActor
    func testStarredFolderIsNotAddedWhenServerHasOne() async throws {
        let rig = try Rig()
        rig.transport.folderList.with { $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "STARRED", name: "S", role: .starred)] }
        try await rig.mailbox.refreshFolders("a")
        XCTAssertEqual(rig.mailbox.folders("a").map(\.id), ["INBOX", "STARRED"])
    }

    @MainActor
    func testOutboxQueuesOnTransientFailureAndSendsAfterSync() async throws {
        let rig = try Rig()
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        let outcome = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b", bodyHTML: "<p>b</p>"))
        guard case .queued(let id) = outcome else { return XCTFail() }
        XCTAssertEqual(rig.outbox.outbox.count, 1)
        let reopened = OutboxStore(access: rig.access, database: rig.database, events: rig.events)
        XCTAssertEqual(reopened.outbox.first?.draft.bodyHTML, "<p>b</p>")
        XCTAssertEqual(reopened.outbox.first?.messageID, rig.outbox.outbox.first?.messageID)
        rig.transport.failure.with { $0 = nil }
        await rig.outbox.pass("a")
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertTrue(rig.transport.calls.with { $0.contains("send") })
        XCTAssertNil(OutboxStore(access: rig.access, database: rig.database, events: rig.events).outbox.first { $0.id == id })
    }

    @MainActor
    func testOutboxRejectionStaysFailedUntilResent() async throws {
        let rig = try Rig()
        rig.transport.failure.with { $0 = MailFailure.smtpRejected(550, "5.1.1 no such user") }
        guard case .queued(let id) = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b")) else {
            return XCTFail()
        }
        guard case .failed = rig.outbox.outbox.first?.state else { return XCTFail() }
        rig.transport.failure.with { $0 = nil }
        let outcome = await rig.outbox.resend(id, Draft(to: "x@y.de", subject: "s", body: "fixed"), draftID: nil)
        XCTAssertEqual(outcome, .sent)
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
    }

    @MainActor
    func testSendingASavedDraftShowsTheNewMirrorRowAtOnceAndLeavesNoRowAfterwards() async throws {
        let (rig, _) = try await draftRig(count: 3, separateIDs: true)
        rig.transport.holds.with { $0 = ["sendDraft"] }
        let sending = Task { @MainActor in
            await rig.outbox.sendDraft("a", draftID: "draft:1:0:Drafts", mirrorID: "1:0:Drafts", Draft(to: "x@y.de", subject: "s", body: "b"))
        }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        XCTAssertEqual(rig.mailbox.draftIDs("a"), ["1:1:Drafts", "1:2:Drafts", "1:9:Drafts"])
        rig.transport.release()
        let outcome = await sending.value
        XCTAssertEqual(outcome, .sent)
        XCTAssertEqual(rig.mailbox.draftIDs("a"), ["1:1:Drafts", "1:2:Drafts"])
    }

    @MainActor
    func testSendingAPlannedMailNowSwapsAndThenDropsItsMirrorRow() async throws {
        let (rig, _) = try await draftRig(count: 3, separateIDs: true)
        let id = rig.outbox.plan("a", Draft(to: "x@y.de", subject: "s", body: "b"), draftID: "draft:1:0:Drafts",
                                 mirrorID: "1:0:Drafts", at: Date().addingTimeInterval(3_600))
        rig.transport.holds.with { $0 = ["sendDraft"] }
        let sending = Task { @MainActor in await rig.outbox.sendNow(id) }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        XCTAssertEqual(rig.mailbox.draftIDs("a"), ["1:1:Drafts", "1:2:Drafts", "1:9:Drafts"])
        rig.transport.release()
        let outcome = await sending.value
        XCTAssertEqual(outcome, .sent)
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertEqual(rig.mailbox.draftIDs("a"), ["1:1:Drafts", "1:2:Drafts"])
    }

    @MainActor
    func testATransientFailureAfterSavingKeepsExactlyOneMirrorRowUntilTheRetrySends() async throws {
        let (rig, _) = try await draftRig(count: 3, separateIDs: true)
        rig.transport.sendDraftFailure.with { $0 = MailFailure.connectionClosed }
        let outcome = await rig.outbox.sendDraft("a", draftID: "draft:1:0:Drafts", mirrorID: "1:0:Drafts",
                                                 Draft(to: "x@y.de", subject: "s", body: "b"))
        guard case .queued = outcome else { return XCTFail() }
        XCTAssertEqual(rig.mailbox.draftIDs("a"), ["1:1:Drafts", "1:2:Drafts", "1:9:Drafts"])
        XCTAssertEqual(rig.outbox.outbox.first?.mirrorID, "1:9:Drafts")
        rig.transport.sendDraftFailure.with { $0 = MailFailure.connectionClosed }
        await rig.outbox.pass("a")
        XCTAssertEqual(rig.mailbox.draftIDs("a"), ["1:1:Drafts", "1:2:Drafts", "1:10:Drafts"])
        rig.transport.sendDraftFailure.with { $0 = nil }
        await rig.outbox.pass("a")
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertEqual(rig.mailbox.draftIDs("a"), ["1:1:Drafts", "1:2:Drafts"])
    }

    @MainActor
    func testOutboxVerifiesBeforeResending() async throws {
        let rig = try Rig()
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        _ = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b"))
        rig.transport.failure.with { $0 = nil }
        rig.transport.wasSentAnswer.with { $0 = true }
        rig.transport.calls.with { $0 = [] }
        await rig.outbox.pass("a")
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertFalse(rig.transport.calls.with { $0.contains("send") })
    }

    @MainActor
    func testASentMailIsFiledIntoTheSentFolderOnlyAfterSmtpSucceeds() async throws {
        let rig = try Rig()
        rig.transport.folderList.with { $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Sent", name: "Sent", role: .sent)] }
        try await rig.mailbox.refreshFolders("a")
        rig.transport.failure.with { $0 = MailFailure.smtpRejected(550, "5.1.1 no such user") }
        _ = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b"))
        XCTAssertTrue(rig.transport.filed.with { $0.isEmpty })
        rig.transport.failure.with { $0 = nil }
        let outcome = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b"))
        XCTAssertEqual(outcome, .sent)
        XCTAssertEqual(rig.transport.filed.with { $0 }, ["Sent"])
    }

    @MainActor
    func testAnUncheckableSentFolderLeavesTheMailUnverifiedUntilTheUserConfirms() async throws {
        let rig = try Rig()
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        _ = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b"))
        rig.transport.failure.with { $0 = nil }
        rig.transport.wasSentFailure.with { $0 = MailFailure.folderNotFound("sent") }
        rig.transport.calls.with { $0 = [] }
        await rig.outbox.pass("a")
        guard case .unverified = rig.outbox.outbox.first?.state, let id = rig.outbox.outbox.first?.id else { return XCTFail() }
        XCTAssertFalse(rig.transport.calls.with { $0.contains("send") })
        let reopened = OutboxStore(access: rig.access, database: rig.database, events: rig.events)
        guard case .unverified = reopened.outbox.first?.state else { return XCTFail() }
        await rig.outbox.pass("a")
        XCTAssertEqual(rig.outbox.outbox.count, 1)
        await rig.outbox.confirm(id)
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertTrue(rig.transport.calls.with { $0.contains("send") })
    }

    @MainActor
    func testTheOutboxFolderListsQueuedMailAndLeavesWhenItIsEmpty() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        XCTAssertFalse(state.folderRows.contains { $0.folder.role == .outbox })
        rig.transport.failure.with { $0 = MailFailure.smtpRejected(550, "5.1.1 no such user") }
        _ = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "Offer", body: "b"))
        await state.handle(.outboxChanged)
        let entry = state.folderRows.first { $0.folder.role == .outbox }
        XCTAssertEqual(entry?.count, 1)
        XCTAssertEqual(entry?.attention, true)
        XCTAssertEqual(state.unsent("a"), 1)
        await state.selectFolder(Folder.outboxID)
        let rows = state.rowPresentations
        XCTAssertEqual(rows.map(\.subject), ["Offer"])
        guard case .failed = rows.first?.outbox else { return XCTFail() }
        state.openQueued(rows[0].id)
        XCTAssertEqual(state.drafts.first?.draft.subject, "Offer")
        XCTAssertNotNil(state.drafts.first?.outboxID)
        await state.discardQueued(rows[0].id)
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertNotEqual(state.selectedFolder, Folder.outboxID)
        XCTAssertFalse(state.folderRows.contains { $0.folder.role == .outbox })
    }

    @MainActor
    func testQueuedMailLeavesEvenWhenTheMirrorPassFails() async throws {
        let rig = try Rig()
        let stock = rig.access.stock(.mailboxes, as: Mailbox.self)
        stock.apply(inlet: "a", records: [Mailbox(id: "a/INBOX", inlet: "a", name: "INBOX", role: "inbox")], at: Date())
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        guard case .queued = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b")) else { return XCTFail() }
        rig.transport.failure.with { $0 = nil }
        rig.transport.failListing.with { $0 = true }
        let events = rig.events.stream
        rig.access.emit(.syncFinished(.mail, "a"))
        for await event in events {
            if case .syncFailed("a", _) = event { break }
        }
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertTrue(rig.transport.calls.with { $0.contains("send") })
    }

    @MainActor
    func testSyncEventsFillFoldersAndRemovalPurges() async throws {
        let rig = try Rig()
        let stock = rig.access.stock(.mailboxes, as: Mailbox.self)
        stock.apply(inlet: "a", records: [Mailbox(id: "a/INBOX", inlet: "a", name: "INBOX", role: "inbox")], at: Date())
        try await Task.sleep(for: .milliseconds(100))
        rig.access.emit(.syncFinished(.mail, "a"))
        for _ in 0..<50 where rig.mailbox.messages("a", folder: "INBOX").isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(rig.mailbox.folders("a").map(\.id), ["INBOX", Folder.starredID])
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 1)
        rig.access.emit(.inletRemoved("a"))
        for _ in 0..<50 where !rig.mailbox.folders("a").isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertTrue(rig.mailbox.folders("a").isEmpty)
    }

    @MainActor
    func testPurgeNeedsTheCapabilityCheck() async throws {
        let rig = try Rig()
        XCTAssertFalse(rig.mailbox.canPurge("a"))
        await rig.mailbox.checkPurge("a")
        XCTAssertTrue(rig.mailbox.canPurge("a"))
    }

    @MainActor
    func testInboxStateReadsRepliesAndSends() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        XCTAssertEqual(state.selectedFolder, "INBOX")
        XCTAssertEqual(state.rows.count, 1)
        XCTAssertEqual(state.listState, .loaded)
        await state.open("1:1:INBOX")
        XCTAssertEqual(state.card("1:1:INBOX")?.content, .text("plain text"))
        XCTAssertEqual(state.summary("1:1:INBOX")?.flags.contains(.seen), true)
        XCTAssertEqual(state.frontRef, .message("1:1:INBOX"))
        let replied = await state.reply(to: "1:1:INBOX")
        let id = try XCTUnwrap(replied)
        let draft = try XCTUnwrap(state.draft(id))
        XCTAssertEqual(draft.draft.subject, "Re: Hello")
        XCTAssertEqual(draft.draft.to, "Anna <anna@example.com>")
        XCTAssertTrue(draft.draft.body.contains("> plain text"))
        await state.send(id)
        XCTAssertEqual(state.draft(id)?.state, .sent)
        XCTAssertEqual(state.rowPresentations.first?.initials, "A")
    }

    @MainActor
    func testReadingFoldsTheQuoteOfAnHTMLMessageAndAsksForRemoteImagesOnlyWhenThereAreAny() async throws {
        let rig = try Rig()
        rig.transport.bodyHTML.with {
            $0 = "<p>Danke</p><img src=\"https://t.example/p.gif\"><div class=\"gmail_quote\"><div class=\"gmail_attr\">On Mon, Anna wrote:</div><blockquote>alt</blockquote></div>"
        }
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        await state.open("1:1:INBOX")
        let card = try XCTUnwrap(state.card("1:1:INBOX"))
        XCTAssertTrue(card.remoteImagesBlocked(loadRemote: false))
        state.allowRemoteImages("1:1:INBOX")
        XCTAssertFalse(try XCTUnwrap(state.card("1:1:INBOX")).remoteImagesBlocked(loadRemote: false))
        let item = try XCTUnwrap(state.thread("1:1:INBOX").first)
        XCTAssertEqual(item.html?.contains("alt"), false)
        XCTAssertEqual(item.blockedHTML?.contains("t.example"), false)
        XCTAssertEqual(item.quote?.text, "On Mon, Anna wrote:\n> alt")
        XCTAssertFalse(item.quoteOpen)
        state.toggleQuote("1:1:INBOX", message: "1:1:INBOX")
        XCTAssertEqual(state.thread("1:1:INBOX").first?.quoteOpen, true)
    }

    @MainActor
    func testComposeReusesOnlyABlankDraftOfTheOpenMailbox() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        XCTAssertEqual(state.draft(id)?.inlet, "a")
        XCTAssertEqual(state.compose(), id)
        await state.setFrom(id, inlet: "b")
        XCTAssertEqual(state.selectedInlet, "b")
        XCTAssertTrue(state.swapAccount("a"))
        let other = try XCTUnwrap(state.compose())
        XCTAssertNotEqual(other, id)
        XCTAssertEqual(state.draft(id)?.inlet, "b")
        XCTAssertEqual(state.draft(other)?.inlet, "a")
    }

    @MainActor
    func testSwapAccountRefusesTheOpenAndUnknownMailbox() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        XCTAssertFalse(state.swapAccount("a"))
        XCTAssertFalse(state.swapAccount("z"))
        XCTAssertEqual(state.selectedInlet, "a")
        XCTAssertTrue(state.swapAccount("b"))
        XCTAssertEqual(state.selectedInlet, "b")
    }

    @MainActor
    func testRecipientsSkipBlankEntriesAndSavedDraftsSettle() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.addRecipient(id, .to, entry: "  ")
        XCTAssertEqual(state.draft(id)?.people(.to).count, 0)
        state.addRecipient(id, .to, entry: "a@x.de")
        XCTAssertEqual(state.draft(id)?.people(.to).map(\.address), ["a@x.de"])
        await state.save(id)
        guard case .saved = state.draft(id)?.state else { return XCTFail() }
    }

    @MainActor
    func testQueuedDraftTurnsSentWhenTheOutboxDelivers() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.to = "x@y.de"; $0.subject = "s" }
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        await state.send(id)
        XCTAssertEqual(state.draft(id)?.state, .queuedInOutbox)
        rig.transport.failure.with { $0 = nil }
        await rig.outbox.pass("a")
        for _ in 0..<50 where state.draft(id)?.state != .sent { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(state.draft(id)?.state, .sent)
    }

    @MainActor
    func testClosingAQueuedDraftNamesTheOutbox() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.to = "x@y.de"; $0.subject = "s" }
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        await state.send(id)
        XCTAssertEqual(state.draft(id)?.state, .queuedInOutbox)
        await state.closeDraft(id)
        XCTAssertEqual(state.toast?.kind, .inOutbox)
        XCTAssertFalse(state.toast?.undoable ?? true)
    }

    @MainActor
    func testOnlyTheUncheckableSentFolderShowsTheMasterCheckFailedTextAndARejectionShowsItsReason() async throws {
        let rig = try Rig()
        rig.transport.failure.with { $0 = MailFailure.smtpRejected(550, "5.1.1 no such user") }
        _ = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b"))
        let rejected = try XCTUnwrap(rig.outbox.outbox.first?.state)
        guard case .failed = rejected else { return XCTFail() }
        XCTAssertTrue([MessageTextKey.rejected.rawValue, MessageTextKey.failed.rawValue].contains(rejected.key))
        XCTAssertTrue(rejected.needsAttention)
        XCTAssertTrue(rejected.offersRowActions)
        let other = try Rig()
        other.transport.failure.with { $0 = MailFailure.connectionClosed }
        _ = await other.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b"))
        other.transport.failure.with { $0 = nil }
        other.transport.wasSentFailure.with { $0 = MailFailure.folderNotFound("sent") }
        await other.outbox.pass("a")
        let unverified = try XCTUnwrap(other.outbox.outbox.first?.state)
        guard case .unverified = unverified else { return XCTFail() }
        XCTAssertEqual(unverified.key, "mail.outbox.state.failed")
        XCTAssertTrue(unverified.needsAttention)
        XCTAssertFalse(unverified.offersRowActions)
        XCTAssertFalse(OutboxState.checking.needsAttention)
        XCTAssertFalse(OutboxState.checking.offersRowActions)
        XCTAssertEqual(OutboxState.failed(Hint(text: MessageTextKey.tooLarge.rawValue)).key, MessageTextKey.tooLarge.rawValue)
        let catalog = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources/mail.localizable.json")
        let file = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any])
        let texts = try XCTUnwrap(file["keys"] as? [String: [String: String]])
        XCTAssertEqual(texts[unverified.key]?["de"], "Nicht gesendet · Prüfung fehlgeschlagen")
        XCTAssertNil(texts["mail.outbox.state.unverified"])
        XCTAssertNotEqual(texts[rejected.key]?["de"], texts[unverified.key]?["de"])
        XCTAssertEqual(ToastKind.notSentInDrafts.actionKey, "mail.draft.failed.act")
        XCTAssertTrue(ToastKind.notSentInDrafts.failed)
    }

    @MainActor
    func testSavingAFailedSendAsDraftRemovesItFromTheOutboxSoTheMailCannotGoOutTwice() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.to = "x@y.de"; $0.subject = "s" }
        rig.transport.failure.with { $0 = MailFailure.smtpRejected(550, "5.1.1 no such user") }
        await state.send(id)
        guard case .sendFailed = state.draft(id)?.state else { return XCTFail() }
        let rowID = try XCTUnwrap(rig.outbox.outbox.first?.id.uuidString)
        rig.transport.failure.with { $0 = nil }
        rig.transport.calls.with { $0 = [] }
        await state.closeDraft(id)
        XCTAssertEqual(state.toast?.kind, .notSentInDrafts)
        XCTAssertTrue(rig.outbox.outbox.isEmpty)
        XCTAssertTrue(state.outbox.isEmpty)
        XCTAssertNil(state.draft(id)?.outboxID)
        await state.resendQueued(rowID)
        await rig.outbox.pass("a")
        XCTAssertFalse(rig.transport.calls.with { $0.contains("send") || $0.contains("sendDraft") })
    }

    @MainActor
    func testATypingPauseSavesTheDraftAtTheProviderAndKeepsALocalCopy() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .milliseconds(30), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "Hello" }
        XCTAssertEqual(rig.outbox.keptDrafts.map(\.id), [id])
        for _ in 0..<100 { if case .saved = state.draft(id)?.state { break }; try await Task.sleep(for: .milliseconds(20)) }
        guard case .saved = state.draft(id)?.state else { return XCTFail() }
        XCTAssertNotNil(state.draft(id)?.remoteID)
        XCTAssertEqual(rig.outbox.keptDrafts.first?.remoteID, state.draft(id)?.remoteID)
    }

    @MainActor
    func testKeptDraftsComeBackAsOpenCardsAndGoWhenSentOrDiscarded() async throws {
        let rig = try Rig()
        let first = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await first.start()
        let id = try XCTUnwrap(first.compose())
        first.edit(id) { $0.subject = "Keep me"; $0.to = "x@y.de" }
        let second = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                                autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await second.start()
        XCTAssertEqual(second.draft(id)?.draft.subject, "Keep me")
        XCTAssertEqual(second.draft(id)?.inlet, "a")
        XCTAssertTrue(second.stack.contains(.draft(id)))
        await second.deleteDraft(id)
        XCTAssertTrue(rig.outbox.keptDrafts.isEmpty)
        let third = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await third.start()
        XCTAssertNil(third.draft(id))
    }

    @MainActor
    func testSendingDropsTheLocalCopy() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.to = "x@y.de"; $0.subject = "s" }
        XCTAssertEqual(rig.outbox.keptDrafts.count, 1)
        await state.send(id)
        XCTAssertTrue(rig.outbox.keptDrafts.isEmpty)
    }

    @MainActor
    func testFlushingOnQuitSavesPendingDraftsWithinTheLimit() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "Pending" }
        await state.flushDrafts(within: .seconds(5))
        guard case .saved = state.draft(id)?.state else { return XCTFail() }
        XCTAssertNotNil(rig.outbox.keptDrafts.first?.remoteID)
    }

    @MainActor
    func testNewMailMergesOnlyIntoTheOpenInbox() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        try await Task.sleep(for: .milliseconds(100))
        state.summaries = []
        rig.events.emit(.newMail("a", count: 1))
        for _ in 0..<50 where state.rows.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(state.rows.map(\.id), ["1:1:INBOX"])
        await state.selectFolder("Archive")
        try await Task.sleep(for: .milliseconds(100))
        state.summaries = []
        rig.events.emit(.newMail("a", count: 1))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(state.rows.isEmpty)
    }

    @MainActor
    func testCrossSearchLeavesOutTrashAndSpam() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        try await rig.mailbox.refresh("a", folder: "Archive")
        try await rig.mailbox.refresh("a", folder: "Trash")
        await state.type("Hello")
        XCTAssertEqual(Set(state.crossHits.map(\.id)), ["1:1:INBOX", "1:1:Archive"])
    }

    @MainActor
    func testRepeatedInboxLoadAnnouncesNoNewMail() async throws {
        let rig = try Rig()
        let events = rig.events.stream
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        rig.events.emit(.syncFinished("end"))
        var seen: [MailboxEvent] = []
        for await event in events {
            if event == .syncFinished("end") { break }
            seen.append(event)
        }
        XCTAssertFalse(seen.contains { if case .newMail = $0 { true } else { false } })
        XCTAssertEqual(seen.filter { $0 == .messagesChanged("a", folder: "INBOX") }.count, 3)
    }

    @MainActor
    func testSwitchingMailboxParksItsStackAndStartsInTheInbox() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        await state.open("1:1:INBOX")
        let id = try XCTUnwrap(state.compose())
        await state.selectFolder("Archive")
        await state.setSearching(true)
        state.openOverview(true)
        await state.selectAccount("a")
        XCTAssertEqual(state.selectedFolder, "Archive")
        XCTAssertTrue(state.searching)
        await state.selectAccount("b")
        XCTAssertEqual(state.selectedInlet, "b")
        XCTAssertEqual(state.stackCount, 0)
        XCTAssertEqual(state.selectedFolder, "INBOX")
        XCTAssertFalse(state.searching)
        XCTAssertFalse(state.overview.open)
        XCTAssertEqual(state.rows.map(\.id), ["2:1:INBOX"])
        await state.open("2:1:INBOX")
        XCTAssertEqual(state.stackCount, 1)
        XCTAssertNotNil(state.cards.first { $0.inlet == "a" && $0.id == "1:1:INBOX" })
        state.close("2:1:INBOX")
        XCTAssertNil(state.selectedMessage)
        await state.selectAccount("a")
        XCTAssertEqual(state.stackCount, 2)
        XCTAssertEqual(state.frontRef, .draft(id))
        XCTAssertEqual(state.selectedFolder, "INBOX")
        XCTAssertEqual(state.selectedMessage, "1:1:INBOX")
    }

    @MainActor
    func testSameMessageIDInTwoMailboxesStaysApart() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "1")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        await state.open("1:1:INBOX", pin: true)
        XCTAssertEqual(state.card("1:1:INBOX")?.inlet, "a")
        await state.selectAccount("b")
        XCTAssertNil(state.card("1:1:INBOX"))
        await state.open("1:1:INBOX")
        XCTAssertEqual(state.card("1:1:INBOX")?.inlet, "b")
        XCTAssertEqual(state.cards.filter { $0.id == "1:1:INBOX" }.map(\.inlet).sorted(), ["a", "b"])
        XCTAssertEqual(state.card("1:1:INBOX")?.content, .text("plain text"))
        state.toggleRecipients("1:1:INBOX")
        XCTAssertEqual(state.card("1:1:INBOX")?.recipientsExpanded, true)
        XCTAssertEqual(state.cards.first { $0.inlet == "a" }?.recipientsExpanded, false)
        state.close("1:1:INBOX")
        XCTAssertNil(state.card("1:1:INBOX"))
        XCTAssertEqual(state.cards.map(\.inlet), ["a"])
        await state.selectAccount("a")
        XCTAssertEqual(state.card("1:1:INBOX")?.inlet, "a")
        XCTAssertEqual(state.frontRef, .message("1:1:INBOX"))
        state.drop("1:1:INBOX", in: "b")
        XCTAssertEqual(state.card("1:1:INBOX")?.inlet, "a")
        XCTAssertEqual(state.stackCount, 1)
    }

    @MainActor
    func testTrimmingAndPreviewsLeaveParkedMailboxesAlone() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let parked = (0..<Tokens.Count.stackMaxCards).map { index in
            OpenMessage(inlet: "b", summary: MessageSummary(id: "2:\(index):INBOX", subject: "S", from: "B"), content: .text(""))
        }
        state.cards = parked
        state.parked["b"] = ParkedMailbox(stack: parked.map { .message($0.id) })
        await state.open("1:1:INBOX")
        XCTAssertEqual(state.cards.filter { $0.inlet == "b" }.count, Tokens.Count.stackMaxCards)
        XCTAssertEqual(state.stackOrder, [.message("1:1:INBOX")])
        await state.selectAccount("b")
        XCTAssertEqual(state.stackCount, Tokens.Count.stackMaxCards)
    }

    @MainActor
    func testRemovingTheOpenMailboxRestoresTheNextAndDropsItsCards() async throws {
        let rig = try Rig()
        let second = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        await state.open("1:1:INBOX", pin: true)
        await state.selectAccount("b")
        await state.open("2:1:INBOX")
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "Kept" }
        rig.access.records.removeAll { $0.id == "b" }
        await state.refreshAccounts()
        XCTAssertEqual(state.selectedInlet, "a")
        XCTAssertEqual(state.stackOrder, [.message("1:1:INBOX")])
        XCTAssertTrue(state.cards.allSatisfy { $0.inlet == "a" })
        XCTAssertNil(state.draft(id))
        XCTAssertTrue(second.calls.with { $0.contains("saveDraft") })
        XCTAssertTrue(state.parked.isEmpty)
    }

    func testMailboxInitialsComeFromTheAddress() {
        let inlet = { (title: String, account: String) in
            Inlet(id: "x", provider: "imap", capabilities: [.mail], owner: .company, title: title, account: account, state: .created)
        }
        XCTAssertEqual(inlet("Arbeit", "info@brenner.de").mailboxInitials, "IB")
        XCTAssertEqual(inlet("", "plain").mailboxInitials, "P")
        XCTAssertEqual(inlet(" Werk ", "").mailboxInitials, "W")
        XCTAssertEqual(inlet("", "").mailboxInitials, "")
        XCTAssertEqual(inlet(" Werk ", "").ownName, "Werk")
    }

    @MainActor
    func testInboxStateArchiveGivesUndoToast() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        await state.archive("1:1:INBOX", undoable: true)
        XCTAssertTrue(state.rows.isEmpty)
        XCTAssertEqual(state.toast?.kind, .archived)
        XCTAssertEqual(state.toast?.undoable, true)
        await state.undoToast()
        XCTAssertNil(state.toast)
        XCTAssertTrue(rig.transport.calls.with { $0.contains("move") })
    }

    @MainActor
    func testArchivingTheOpenMailSelectsTheNextAndFailureBringsTheRowBack() async throws {
        let rig = try Rig()
        rig.fill("INBOX", count: 3, from: Date())
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        XCTAssertEqual(state.rows.map(\.id), ["1:0:INBOX", "1:1:INBOX", "1:2:INBOX"])
        await state.open("1:1:INBOX")
        await state.archive("1:1:INBOX")
        XCTAssertEqual(state.rows.map(\.id), ["1:0:INBOX", "1:2:INBOX"])
        XCTAssertEqual(state.selectedMessage, "1:2:INBOX")
        XCTAssertEqual(state.toast?.kind, .archived)
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        await state.trash("1:0:INBOX")
        XCTAssertEqual(state.rows.map(\.id), ["1:0:INBOX", "1:2:INBOX"])
        XCTAssertEqual(state.toast?.kind, .deleteFailed)
    }

    @MainActor
    func testBulkArchiveReportsPartialFailureAndKeepsThoseRows() async throws {
        let rig = try Rig()
        rig.fill("INBOX", count: 3, from: Date())
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        state.pickAllToggle()
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        await state.bulk(.archive)
        XCTAssertEqual(state.rows.count, 3)
        XCTAssertEqual(state.toast?.kind, .archiveFailed)
        XCTAssertTrue(state.picked.isEmpty)
    }

    @MainActor
    func testShiftPickSelectsTheRangeAndThreadRowsNameEveryone() async throws {
        let rig = try Rig()
        rig.fill("INBOX", count: 4, from: Date())
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        state.pick("1:0:INBOX")
        state.pickRange(to: "1:2:INBOX")
        XCTAssertEqual(Set(state.picked), ["1:0:INBOX", "1:1:INBOX", "1:2:INBOX"])
        let one = MessageSummary(id: "a", threadID: "t", subject: "S", from: "Anna", receivedAt: Date(), flags: [], folderIDs: ["INBOX"])
        let two = MessageSummary(id: "b", threadID: "t", subject: "S", from: "Ben", receivedAt: Date(), flags: [], folderIDs: ["INBOX"])
        XCTAssertEqual(InboxState.participants(in: [two, one, one])["t"], ["Ben", "Anna"])
    }

    @MainActor
    func testMovesUseTheServerFolderNotTheLocalStarredFolder() {
        let mail = MessageSummary(id: "a", threadID: "t", subject: "S", from: "Anna", receivedAt: Date(), flags: [], folderIDs: ["INBOX"])
        XCTAssertEqual(InboxState.serverFolder(Folder.starredID, of: mail), "INBOX")
        XCTAssertEqual(InboxState.serverFolder("Archive", of: mail), "Archive")
        XCTAssertNil(InboxState.serverFolder(nil, of: mail))
    }

    @MainActor
    func testMoveOffersOtherMailFoldersAndUndoes() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        XCTAssertEqual(state.moveTargets("1:1:INBOX").map(\.id), ["Archive", "Trash"])
        XCTAssertFalse(state.offersOriginal)
        await state.move("1:1:INBOX", to: "Archive")
        XCTAssertTrue(state.rows.isEmpty)
        XCTAssertEqual(state.toast?.kind, .moved)
        XCTAssertEqual(state.toast?.undoable, true)
        XCTAssertTrue(MenuEngine.readingMore(starred: false, original: false).contains(.item(.move)))
        XCTAssertFalse(MenuEngine.readingMore(starred: false, original: false).contains(.item(.original)))
        XCTAssertTrue(MenuEngine.readingMore(starred: false, original: true).contains(.item(.original)))
    }

    @MainActor
    func testContactsPersistAndSuggest() throws {
        let suite = "mail.tests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let contacts = ContactState(defaults: defaults)
        XCTAssertEqual(contacts.save(name: "Ann", address: "ann@x.de"), .contactSaved("Ann"))
        XCTAssertEqual(contacts.save(name: "Ann", address: "ANN@x.de"), .contactExists("Ann"))
        XCTAssertEqual(ContactState(defaults: defaults).items.count, 1)
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testWithMailRegistersTheTransportPort() {
        let registry = PortRegistry().withMail()
        XCTAssertNotNil(registry.spec(for: (any MailTransportPort).self))
    }

    func testListWindowHoldsPlaceForRowsNotLoaded() {
        XCTAssertEqual(ListWindowEngine.spacer(count: 200, window: 60), 140 * Tokens.Size.mailRowEstimate)
        XCTAssertEqual(ListWindowEngine.spacer(count: 40, window: 60), 0)
        XCTAssertEqual(ListWindowEngine.spacer(count: 60, window: 60), 0)
        XCTAssertEqual(ListWindowEngine.remaining(content: 10_000, offset: 1_000, container: 600, spacer: 4_000), 4_400)
        XCTAssertLessThan(ListWindowEngine.remaining(content: 10_000, offset: 9_400, container: 600, spacer: 4_000), 0)
    }

    private static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    private func mirrored(_ range: MailboxRange = .days30) throws -> Rig {
        try Rig(range: range, now: { MailTests.epoch })
    }

    @MainActor
    private func started(_ rig: Rig) async -> InboxState {
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        return state
    }

    @MainActor
    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<100 where !condition() { try await Task.sleep(for: .milliseconds(20)) }
    }

    func testRangeHasFourStepsAndResolvesToWhatTheMailboxOffers() {
        XCTAssertEqual(MailboxRange.allCases, [.days30, .days90, .year, .all])
        XCTAssertEqual(MailboxRange.standard, .days30)
        XCTAssertNil(MailboxRange.all.cutoff(from: Self.epoch))
        XCTAssertEqual(MailboxRange.days90.cutoff(from: Self.epoch), Self.epoch.addingTimeInterval(-90 * 86_400))
        XCTAssertEqual(MailboxRange.all.resolved(in: [.days30, .year]), .days30)
        XCTAssertEqual(MailboxRange.year.resolved(in: [.days30, .year]), .year)
        XCTAssertEqual(MailboxRange.all.resolved(in: [.year, .all]), .all)
        XCTAssertEqual(MailboxRange.days30.resolved(in: [.year]), .year)
    }

    func testMirrorEnginePlansByIdsAndOrdersByDateThenId() {
        let plan = MirrorEngine.plan(stored: ["a", "b", "c"], listed: ["d", "b", "a"])
        XCTAssertEqual(plan, MirrorEngine.Plan(gone: ["c"], unknown: ["d"], known: ["b", "a"]))
        func message(_ id: String, _ date: Date?) -> MessageSummary {
            MessageSummary(id: id, subject: id, from: "", receivedAt: date)
        }
        let order = MirrorEngine.sorted([message("a", nil), message("b", Self.epoch), message("c", Self.epoch),
                                         message("d", Self.epoch.addingTimeInterval(5)), message("e", nil)])
        XCTAssertEqual(order.map(\.id), ["d", "c", "b", "e", "a"])
        XCTAssertEqual(MirrorEngine.chunks(Array(0..<5), size: 2), [[0, 1], [2, 3], [4]])
        XCTAssertEqual(MirrorEngine.cutoff(.days30, reach: Self.epoch.addingTimeInterval(-86_400 * 40), now: Self.epoch),
                       Self.epoch.addingTimeInterval(-86_400 * 40))
        XCTAssertNil(MirrorEngine.cutoff(.all, reach: Self.epoch, now: Self.epoch))
        XCTAssertEqual(UIDSetEngine.text([9, 5, 6, 7, 1, 1]), "1,5:7,9")
    }

    @MainActor
    func testPassFetchesTheRangeInChunksAndAnnouncesEachChunk() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 1_000, from: Self.epoch)
        let events = rig.events.stream
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 721)
        XCTAssertEqual(rig.transport.chunks.with { $0 }, [200, 200, 200, 121])
        XCTAssertEqual(rig.transport.listings.with { $0.first?.since }, Self.epoch.addingTimeInterval(-30 * 86_400))
        rig.events.emit(.syncFinished("end"))
        var changed = 0
        for await event in events {
            if event == .syncFinished("end") { break }
            if event == .messagesChanged("a", folder: "INBOX") { changed += 1 }
        }
        XCTAssertGreaterThanOrEqual(changed, 5)
        XCTAssertTrue(rig.mailbox.canLoadOlder("a", folder: "INBOX"))
        let ids = rig.mailbox.messages("a", folder: "INBOX").map(\.id)
        XCTAssertEqual(ids.first, "1:0:INBOX")
        XCTAssertEqual(ids.last, "1:720:INBOX")
    }

    @MainActor
    func testLaterPassFetchesOnlyUnknownIdsDropsGoneOnesAndKeepsOrder() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 200, from: Self.epoch)
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertFalse(rig.mailbox.canLoadOlder("a", folder: "INBOX"))
        var current = rig.transport.corpus.with { $0["INBOX"] ?? [] }
        let fresh = MessageSummary(id: "1:new:INBOX", threadID: "n", subject: "New", from: "Ben", receivedAt: Self.epoch.addingTimeInterval(60),
                                   flags: [], folderIDs: ["INBOX"])
        current.insert(fresh, at: 0)
        current.remove(at: 4)
        rig.transport.corpus.with { $0["INBOX"] = current }
        rig.transport.chunks.with { $0 = [] }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let page = rig.mailbox.messages("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.chunks.with { $0 }, [1])
        XCTAssertEqual(page.count, 200)
        XCTAssertEqual(page.first?.id, "1:new:INBOX")
        XCTAssertFalse(page.contains { $0.id == "1:3:INBOX" })
        XCTAssertEqual(page.map(\.id), MirrorEngine.sorted(page).map(\.id))
        try await rig.mailbox.loadOlder("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.chunks.with { $0 }, [1])
    }

    @MainActor
    func testIdsDecideNotDatesTiesNilDatesAndMovedOldMailStay() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        func message(_ id: Int, _ date: Date?) -> MessageSummary {
            MessageSummary(id: "1:\(id):INBOX", threadID: "t", subject: "S\(id)", from: "A", receivedAt: date, flags: [.seen],
                           folderIDs: ["INBOX"])
        }
        let tie = Self.epoch.addingTimeInterval(-100)
        rig.transport.corpus.with {
            $0["INBOX"] = [message(5, tie), message(4, tie), message(3, tie), message(9, Self.epoch.addingTimeInterval(-20 * 86_400)),
                           message(2, nil)]
        }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let first = rig.mailbox.messages("a", folder: "INBOX")
        XCTAssertEqual(first.map(\.id), ["1:5:INBOX", "1:4:INBOX", "1:3:INBOX", "1:9:INBOX", "1:2:INBOX"])
        rig.transport.chunks.with { $0 = [] }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let second = rig.mailbox.messages("a", folder: "INBOX")
        XCTAssertEqual(second.map(\.id), first.map(\.id))
        XCTAssertTrue(rig.transport.chunks.with { $0.isEmpty })
    }

    @MainActor
    func testFailedPassKeepsEveryChunkFetchedBeforeTheFailure() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 450, from: Self.epoch)
        rig.transport.failAfterChunks.with { $0 = 2 }
        do {
            try await rig.mailbox.refresh("a", folder: "INBOX")
            XCTFail("must throw")
        } catch {
            guard case .provider = error else { return XCTFail() }
        }
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 400)
        XCTAssertNotNil(rig.mailbox.lastSync("a", folder: "INBOX"))
        rig.transport.failAfterChunks.with { $0 = nil }
        rig.transport.chunks.with { $0 = [] }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let rest = rig.mailbox.messages("a", folder: "INBOX")
        XCTAssertEqual(rest.count, 450)
        XCTAssertEqual(rig.transport.chunks.with { $0 }, [50])
    }

    @MainActor
    func testOnePassPerFolderAtATimeAndRequestsDuringItShareOneFollowUpPass() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 10, from: Self.epoch)
        rig.transport.holds.with { $0 = ["refreshFlags"] }
        let one = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        rig.fill("INBOX", count: 11, from: Self.epoch)
        let two = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        let three = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(rig.transport.listings.with { $0.count }, 1)
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 10)
        rig.transport.release()
        try await one.value
        try await two.value
        try await three.value
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 11)
        XCTAssertEqual(rig.transport.listings.with { $0.count }, 2)
    }

    @MainActor
    func testPassNeverOverwritesChangesMadeWhileItRuns() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 5, from: Self.epoch, flags: [])
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let ids = rig.mailbox.messages("a", folder: "INBOX").map(\.id)
        rig.transport.serverFlags.with { flags in ids.forEach { flags[$0] = [] } }
        rig.transport.holds.with { $0 = ["refreshFlags"] }
        let running = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        try await rig.mailbox.setFlags("a", messageID: ids[0], add: [.seen], remove: [])
        try await rig.mailbox.archive("a", messageID: ids[1])
        rig.transport.release()
        _ = try await running.value
        let after = rig.mailbox.messages("a", folder: "INBOX")
        XCTAssertEqual(after.count, 4)
        XCTAssertTrue(try XCTUnwrap(after.first { $0.id == ids[0] }).flags.contains(.seen))
        XCTAssertFalse(after.contains { $0.id == ids[1] })
    }

    @MainActor
    func testFlagRefreshAppliesServerFlagsAndPassesTheStoredCursorBack() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 3, from: Self.epoch, flags: [])
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 3)
        rig.transport.serverFlags.with { $0["1:1:INBOX"] = [.seen] }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 2)
        XCTAssertEqual(rig.transport.cursors.with { $0 }, [nil, "c1"])
    }

    @MainActor
    func testSyncOfOneMailboxDoesNotWaitForALongPassOfAnother() async throws {
        let rig = try mirrored()
        let other = rig.addMailbox("b", prefix: "2")
        rig.fill("INBOX", count: 5, from: Self.epoch)
        let stock = rig.access.stock(.mailboxes, as: Mailbox.self)
        stock.apply(inlet: "a", records: [Mailbox(id: "a/INBOX", inlet: "a", name: "INBOX", role: "inbox")], at: Date())
        stock.apply(inlet: "b", records: [Mailbox(id: "b/INBOX", inlet: "b", name: "INBOX", role: "inbox")], at: Date())
        try await Task.sleep(for: .milliseconds(100))
        rig.transport.holds.with { $0 = ["listIDs"] }
        rig.access.emit(.syncFinished(.mail, "a"))
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        rig.access.emit(.syncFinished(.mail, "b"))
        try await wait { !rig.mailbox.messages("b", folder: "INBOX").isEmpty }
        XCTAssertEqual(rig.mailbox.messages("b", folder: "INBOX").count, 1)
        XCTAssertTrue(rig.mailbox.messages("a", folder: "INBOX").isEmpty)
        XCTAssertEqual(other.calls.with { $0.filter { $0 == "listIDs" }.count }, 1)
        rig.transport.release()
        try await wait { !rig.mailbox.messages("a", folder: "INBOX").isEmpty }
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 5)
    }

    @MainActor
    func testOlderExtendsTheMirrorByFiveHundredIdsAndKeepsItOnLaterPasses() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 2_000, from: Self.epoch)
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 721)
        try await rig.mailbox.loadOlder("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 1_221)
        XCTAssertEqual(rig.transport.listings.with { $0.last?.limit }, 1_221)
        XCTAssertTrue(rig.mailbox.canLoadOlder("a", folder: "INBOX"))
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let page = rig.mailbox.messages("a", folder: "INBOX")
        XCTAssertEqual(page.count, 1_221)
        XCTAssertEqual(rig.transport.listings.with { $0.last?.since }, Self.epoch.addingTimeInterval(-1_220 * 3_600))
    }

    @MainActor
    func testChangingTheRangeStartsANewPassAndPrunesWhatFellOut() async throws {
        let rig = try mirrored(.year)
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 400, from: Self.epoch, step: -86_400)
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 366)
        rig.chosen.with { $0 = .days30 }
        let before = rig.transport.listings.with { $0.count }
        await rig.mailbox.rangeChanged("a")
        XCTAssertEqual(rig.transport.listings.with { $0.count }, before + 1)
        XCTAssertEqual(rig.transport.listings.with { $0.last?.since }, Self.epoch.addingTimeInterval(-30 * 86_400))
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 31)
        rig.chosen.with { $0 = .all }
        await rig.mailbox.rangeChanged("a")
        XCTAssertNil(rig.transport.listings.with { $0.last?.since })
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 400)
        XCTAssertFalse(rig.mailbox.canLoadOlder("a", folder: "INBOX"))
    }

    @MainActor
    func testAttachmentsAreKeptOnDiskAndLeaveWithTheirMailOrAccount() async throws {
        let rig = try mirrored(.year)
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let setting = Locked(MailStoreSettings(attachments: true))
        let store = MailboxStore(access: rig.access, database: rig.database, outbox: rig.outbox, events: rig.events,
                                 now: { Self.epoch }, range: { _ in rig.chosen.with { $0 } },
                                 attachmentBase: base, attachmentSettings: { setting.with { $0 } })
        try await store.refreshFolders("a")
        rig.transport.corpus.with {
            $0["INBOX"] = (0..<40).map { index in
                MessageSummary(id: "1:\(index):INBOX", threadID: "t\(index)", subject: "N \(index)", from: "Anna",
                               fromRaw: "Anna <anna@example.com>", toRaw: "me@example.com", snippet: "s",
                               receivedAt: Self.epoch.addingTimeInterval(Double(index) * -86_400), flags: [.seen], folderIDs: ["INBOX"],
                               attachmentCount: 1,
                               attachments: [AttachmentInfo(id: "2", filename: "a.pdf", mimeType: "application/pdf", sizeBytes: 1)],
                               messageIDHeader: "<m\(index)@x>")
            }
        }
        try await store.refresh("a", folder: "INBOX")
        await store.storeAttachments("a")
        XCTAssertEqual(store.attachments.files().count, 40)
        let fetched = { rig.transport.calls.with { $0.filter { $0 == "attachment" }.count } }
        XCTAssertEqual(fetched(), 40)
        let served = try await store.attachment("a", messageID: "1:3:INBOX", attachmentID: "2")
        XCTAssertEqual(served, Data([1]))
        XCTAssertEqual(fetched(), 40)
        let root = try XCTUnwrap(store.attachments.root())
        let outside = try XCTUnwrap(store.attachments.files().first { $0.message == "1:39:INBOX" })
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent(outside.path).path))
        rig.chosen.with { $0 = .days30 }
        await store.rangeChanged("a")
        XCTAssertEqual(store.attachments.files().count, 31)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(outside.path).path))
        XCTAssertEqual(store.messages("a", folder: "INBOX").count, 31)
        try await store.trash("a", messageID: "1:1:INBOX")
        XCTAssertEqual(store.attachments.files().count, 30)
        XCTAssertFalse(store.attachments.files().contains { $0.message == "1:1:INBOX" })
        setting.with { $0.attachments = false }
        await store.settleAttachments()
        XCTAssertTrue(store.attachments.files().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        setting.with { $0.attachments = true }
        await store.settleAttachments()
        try await wait { store.attachments.files().count == 30 }
        XCTAssertEqual(store.attachments.files().count, 30)
        rig.access.emit(.inletRemoved("a"))
        try await wait { store.attachments.files().isEmpty }
        XCTAssertTrue(store.attachments.files().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(AttachmentFileEngine.inletDirectory("a")).path))
    }

    @MainActor
    func testRangeChangeWaitsForARunningPassAndThenRunsItsOwn() async throws {
        let rig = try mirrored(.year)
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 400, from: Self.epoch, step: -86_400)
        try await rig.mailbox.refresh("a", folder: "INBOX")
        rig.transport.holds.with { $0 = ["listIDs"] }
        let running = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        rig.chosen.with { $0 = .days30 }
        let change = Task { @MainActor in await rig.mailbox.rangeChanged("a") }
        try await Task.sleep(for: .milliseconds(50))
        rig.transport.release()
        _ = try await running.value
        await change.value
        XCTAssertEqual(rig.transport.listings.with { $0.last?.since }, Self.epoch.addingTimeInterval(-30 * 86_400))
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 31)
    }

    @MainActor
    func testChunkEventsReloadOffTheMainActorAtMostAFewTimesAndPresentOnlyTheWindow() async throws {
        let rig = try mirrored(.year)
        rig.fill("INBOX", count: 1_000, from: Self.epoch, step: -60)
        let events = rig.events.stream
        let state = await started(rig)
        try await wait { state.summaries.count == 1_000 && state.reloadTask == nil }
        XCTAssertEqual(state.summaries.count, 1_000)
        rig.events.emit(.syncFinished("end"))
        var changed = 0
        for await event in events {
            if event == .syncFinished("end") { break }
            if event == .messagesChanged("a", folder: "INBOX") { changed += 1 }
        }
        XCTAssertGreaterThanOrEqual(changed, 6)
        XCTAssertGreaterThan(state.mirrorSerial, 0)
        XCTAssertLessThan(state.mirrorSerial, changed)
        let off = await rig.mailbox.cached("a", folder: "INBOX")
        XCTAssertEqual(off.map(\.id), rig.mailbox.messages("a", folder: "INBOX").map(\.id))
        let window = state.rowWindow(limit: 11)
        XCTAssertEqual(window.items.count, 11)
        XCTAssertEqual(window.total, 1_000)
        XCTAssertEqual(window.items.map(\.id), state.rows.prefix(11).map(\.id))
        XCTAssertEqual(state.rowWindow(limit: 0).items.count, 0)
        XCTAssertEqual(state.rowWindow(limit: 0).total, 1_000)
    }

    @MainActor
    func testPassDeletesOnlyAfterTheReplacementsAreStoredAndRefusesSuspiciousWipes() async throws {
        let clock = Locked(Self.epoch)
        let rig = try Rig(range: .days30, now: { clock.with { $0 } })
        try await rig.mailbox.refreshFolders("a")
        func stored() -> Set<String> { Set(rig.mailbox.messages("a", folder: "INBOX").map(\.id)) }
        func refusals(_ store: MailboxStore) async throws -> Int {
            let events = rig.events.stream
            try await store.refresh("a", folder: "INBOX")
            rig.events.emit(.syncFinished("end"))
            var count = 0
            for await event in events {
                if event == .syncFinished("end") { break }
                if event == .refused("a", folder: "INBOX") { count += 1 }
            }
            return count
        }
        rig.fill("INBOX", count: 30, from: Self.epoch)
        rig.transport.validity.with { $0 = "1" }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let old = stored()
        XCTAssertEqual(old.count, 30)
        let replacements = (0..<25).map { index in
            MessageSummary(id: "2:\(index):INBOX", threadID: "n\(index)", subject: "New", from: "A",
                           receivedAt: Self.epoch.addingTimeInterval(-Double(index) * 3_600), flags: [.seen], folderIDs: ["INBOX"])
        }
        rig.transport.corpus.with { $0["INBOX"] = replacements }
        rig.transport.validity.with { $0 = "2" }
        rig.transport.failAfterChunks.with { $0 = 0 }
        do {
            try await rig.mailbox.refresh("a", folder: "INBOX")
            XCTFail("must throw")
        } catch {
            guard case .provider = error else { return XCTFail() }
        }
        XCTAssertEqual(stored(), old)
        rig.transport.failAfterChunks.with { $0 = nil }
        rig.transport.corpus.with { $0["INBOX"] = [] }
        rig.transport.validity.with { $0 = "3" }
        let first = try await refusals(rig.mailbox)
        XCTAssertEqual(first, 1)
        XCTAssertEqual(stored(), old)
        let again = try await refusals(rig.mailbox)
        XCTAssertEqual(again, 0)
        XCTAssertEqual(stored(), old)
        rig.transport.corpus.with { $0["INBOX"] = replacements }
        rig.transport.validity.with { $0 = "2" }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(stored(), Set(replacements.map(\.id)))
        rig.transport.corpus.with { $0["INBOX"] = [] }
        let empty = try await refusals(rig.mailbox)
        XCTAssertEqual(empty, 1)
        XCTAssertEqual(stored().count, 25)
        let restarted = MailboxStore(access: rig.access, database: rig.database, outbox: rig.outbox, events: rig.events,
                                     now: { clock.with { $0 } }, range: { _ in .days30 })
        let confirmed = try await refusals(restarted)
        XCTAssertEqual(confirmed, 0)
        XCTAssertTrue(stored().isEmpty)
        rig.fill("INBOX", count: 25, from: Self.epoch)
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(stored().count, 25)
        clock.with { $0 = Self.epoch.addingTimeInterval(2 * 365 * 86_400) }
        let late = try await refusals(rig.mailbox)
        XCTAssertEqual(late, 1)
        XCTAssertEqual(stored().count, 25)
        clock.with { $0 = Self.epoch }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(stored().count, 25)
    }

    @MainActor
    func testRefusedWipeKeepsTheListAndReportsOnce() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 25, from: Self.epoch)
        let state = await started(rig)
        XCTAssertEqual(state.summaries.count, 25)
        rig.transport.corpus.with { $0["INBOX"] = [] }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        try await wait { state.toast?.kind == .mirrorRefused }
        XCTAssertEqual(state.toast?.kind, .mirrorRefused)
        XCTAssertEqual(state.summaries.count, 25)
        XCTAssertEqual(state.listState, .loaded)
    }

    @MainActor
    func testOlderOfferSurvivesARestart() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 800, from: Self.epoch)
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertTrue(rig.mailbox.canLoadOlder("a", folder: "INBOX"))
        let restarted = MailboxStore(access: rig.access, database: rig.database, outbox: rig.outbox, events: rig.events,
                                     now: { Self.epoch }, range: { _ in .days30 })
        XCTAssertTrue(restarted.canLoadOlder("a", folder: "INBOX"))
        rig.fill("INBOX", count: 10, from: Self.epoch)
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let again = MailboxStore(access: rig.access, database: rig.database, outbox: rig.outbox, events: rig.events,
                                 now: { Self.epoch }, range: { _ in .days30 })
        XCTAssertFalse(again.canLoadOlder("a", folder: "INBOX"))
    }

    @MainActor
    func testNarrowingTheRangeOnAnIdleFolderDropsTheRowsOutsideItWithoutRefusal() async throws {
        let rig = try mirrored(.all)
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 30, from: Self.epoch.addingTimeInterval(-90 * 86_400))
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").count, 30)
        let events = rig.events.stream
        rig.chosen.with { $0 = .days30 }
        await rig.mailbox.rangeChanged("a")
        XCTAssertTrue(rig.mailbox.messages("a", folder: "INBOX").isEmpty)
        rig.events.emit(.syncFinished("end"))
        var failed = false
        for await event in events {
            if event == .syncFinished("end") { break }
            if case .syncFailed = event { failed = true }
        }
        XCTAssertFalse(failed)
    }

    @MainActor
    func testRangeChangeShowsTheLoadingStateAndReportsAFailure() async throws {
        let rig = try mirrored(.year)
        rig.fill("INBOX", count: 40, from: Self.epoch, step: -86_400)
        let state = await started(rig)
        XCTAssertEqual(state.phase, .settled)
        let events = rig.events.stream
        rig.chosen.with { $0 = .days30 }
        rig.transport.holds.with { $0 = ["listIDs"] }
        let change = Task { @MainActor in await state.rangeChanged("a") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        XCTAssertEqual(state.phase, .loading)
        rig.transport.failure.with { $0 = MailFailure.timeout }
        rig.transport.release()
        await change.value
        try await wait { state.phase != .settled }
        XCTAssertNotEqual(state.phase, .loading)
        XCTAssertNotEqual(state.phase, .settled)
        rig.events.emit(.syncFinished("end"))
        var failed = false
        for await event in events {
            if event == .syncFinished("end") { break }
            if case .syncFailed("a", _) = event { failed = true }
        }
        XCTAssertTrue(failed)
        rig.transport.failure.with { $0 = nil }
        await state.rangeChanged("a")
        XCTAssertEqual(state.phase, .settled)
    }

    @MainActor
    func testRemovingAMailboxCancelsItsRunningPassBeforePurging() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 450, from: Self.epoch)
        rig.transport.holds.with { $0 = ["fetchSummaries"] }
        let running = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        rig.access.emit(.inletRemoved("a"))
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(rig.mailbox.passes.isEmpty)
        rig.transport.release()
        _ = try await running.value
        try await wait { rig.mailbox.passes.isEmpty }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(rig.mailbox.messages("a", folder: "INBOX").isEmpty)
        XCTAssertNil(rig.mailbox.lastSync("a", folder: "INBOX"))
        XCTAssertEqual(rig.transport.chunks.with { $0.count }, 1)
    }

    @MainActor
    func testOfferingFollowsWhatEachTransportCanDo() async throws {
        let imap = try mirrored()
        XCTAssertEqual(imap.mailbox.ranges("a"), MailboxRange.allCases)
        XCTAssertFalse(imap.mailbox.canSearchEverywhere("a"))
        try await imap.mailbox.refreshFolders("a")
        XCTAssertTrue(imap.mailbox.canSearchEverywhere("a"))
        XCTAssertFalse(imap.mailbox.canLoadOlder("a", folder: "INBOX"))
        imap.fill("INBOX", count: 800, from: Self.epoch)
        try await imap.mailbox.refresh("a", folder: "INBOX")
        XCTAssertTrue(imap.mailbox.canLoadOlder("a", folder: "INBOX"))
        let gmail = try mirrored()
        gmail.transport.everywhereFolder.with { $0 = "ALL" }
        gmail.transport.folderList.with { $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox)] }
        try await gmail.mailbox.refreshFolders("a")
        XCTAssertFalse(gmail.mailbox.canSearchEverywhere("a"))
        gmail.transport.folderList.with { $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "ALL", name: "ALL", role: .all)] }
        try await gmail.mailbox.refreshFolders("a")
        XCTAssertTrue(gmail.mailbox.canSearchEverywhere("a"))
        gmail.transport.folderList.with { $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox)] }
        try await gmail.mailbox.refreshFolders("a")
        XCTAssertFalse(gmail.mailbox.canSearchEverywhere("a"))
        let lost = try mirrored()
        lost.access.connected = false
        XCTAssertEqual(lost.mailbox.ranges("a"), [])
        XCTAssertFalse(lost.mailbox.canSearchEverywhere("a"))
        let bare = try Rig()
        bare.access.transport = SingleFolderDouble()
        try await bare.mailbox.refreshFolders("a")
        XCTAssertEqual(bare.mailbox.ranges("a"), [])
        XCTAssertFalse(bare.mailbox.canSearchEverywhere("a"))
        XCTAssertFalse(bare.mailbox.canLoadOlder("a", folder: "INBOX"))
        do {
            try await bare.mailbox.refresh("a", folder: "INBOX")
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error, .capabilityMissing("a", .mail))
        }
        let mirror = try mirrored()
        let state = await started(mirror)
        XCTAssertTrue(state.offersScope)
        XCTAssertEqual(state.scope, .all)
        state.searchScope = .here
        XCTAssertEqual(state.scope, .here)
    }

    @MainActor
    func testMeteredMailForwardsOnlyWhatTheBaseCanDo() async throws {
        struct NoCost: CostPort { func book(_ item: CostItem) {} }
        let meter = CostMeter(inlet: "a", capability: .mail, cost: NoCost(), clock: { Date() })
        let plain = TransportDouble()
        plain.mirrorRanges.with { $0 = [] }
        XCTAssertEqual(MeteredMail(base: plain, meter: meter).ranges, [])
        XCTAssertFalse(MeteredMail(base: plain, meter: meter).offersEverywhere(in: [Folder(id: "Archive", name: "A")]))
        plain.mirrorRanges.with { $0 = MailboxRange.allCases }
        plain.everywhereFolder.with { $0 = "Archive" }
        plain.corpus.with { $0["INBOX"] = [MessageSummary(id: "x", subject: "s", from: "f", receivedAt: Self.epoch)] }
        let metered = MeteredMail(base: plain, meter: meter)
        XCTAssertEqual(metered.ranges, MailboxRange.allCases)
        XCTAssertTrue(metered.offersEverywhere(in: [Folder(id: "Archive", name: "A")]))
        XCTAssertFalse(metered.offersEverywhere(in: [Folder(id: "INBOX", name: "I")]))
        let listing = try await metered.listIDs(folderID: "INBOX", since: nil, limit: nil)
        XCTAssertEqual(listing.ids, ["x"])
        let summaries = try await metered.fetchSummaries(folderID: "INBOX", ids: ["x"])
        XCTAssertEqual(summaries.count, 1)
        let refreshed = try await metered.refreshFlags(folderID: "INBOX", known: ["x"], cursor: nil)
        XCTAssertEqual(refreshed.cursor, "c1")
        let hits = try await metered.searchEverywhere(query: "s", pageToken: nil, maxResults: 10)
        XCTAssertEqual(hits.messages.count, 1)
        let bare = MeteredMail(base: SingleFolderDouble(), meter: meter)
        do {
            _ = try await bare.listIDs(folderID: "INBOX", since: nil, limit: nil)
            XCTFail("must throw")
        } catch {
            XCTAssertEqual(error as? MailFailure, .unsupportedCapability("mirror"))
        }
    }

    @MainActor
    func testInboxFollowsTheMirrorSortedAndDropsWhatItLost() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 4, from: Self.epoch)
        let state = await started(rig)
        XCTAssertEqual(state.summaries.map(\.id), ["1:0:INBOX", "1:1:INBOX", "1:2:INBOX", "1:3:INBOX"])
        var current = rig.transport.corpus.with { $0["INBOX"] ?? [] }
        current.remove(at: 0)
        current.insert(MessageSummary(id: "1:old:INBOX", threadID: "o", subject: "Old", from: "A",
                                      receivedAt: Self.epoch.addingTimeInterval(-90 * 60), flags: [], folderIDs: ["INBOX"]), at: 0)
        rig.transport.corpus.with { $0["INBOX"] = current }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        try await wait { state.summaries.first?.id != "1:0:INBOX" }
        XCTAssertEqual(state.summaries.map(\.id), ["1:1:INBOX", "1:old:INBOX", "1:2:INBOX", "1:3:INBOX"])
    }

    @MainActor
    func testShortListStillOffersOlderMailAndLoadsIt() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 5, from: Self.epoch)
        let far = (0..<20).map { index in
            MessageSummary(id: "1:far\(index):INBOX", threadID: "f", subject: "Far", from: "A",
                           receivedAt: Self.epoch.addingTimeInterval(-Double(100 + index) * 86_400), flags: [.seen], folderIDs: ["INBOX"])
        }
        rig.transport.corpus.with { $0["INBOX", default: []] += far }
        let state = await started(rig)
        XCTAssertEqual(state.summaries.count, 5)
        XCTAssertEqual(state.listTail, .older)
        await state.loadTail()
        XCTAssertEqual(state.summaries.count, 25)
        XCTAssertNil(state.listTail)
        XCTAssertEqual(state.summaries.map(\.id), MirrorEngine.sorted(state.summaries).map(\.id))
    }

    @MainActor
    func testFailingOlderLoadKeepsTheListAndShowsAToast() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 1_000, from: Self.epoch)
        let state = await started(rig)
        XCTAssertEqual(state.summaries.count, 721)
        XCTAssertEqual(state.listTail, .older)
        rig.transport.failure.with { $0 = MailFailure.timeout }
        await state.loadTail()
        XCTAssertEqual(state.summaries.count, 721)
        XCTAssertEqual(state.toast?.kind, .olderFailed)
        XCTAssertEqual(state.listState, .loaded)
        rig.transport.failure.with { $0 = nil }
        await state.loadTail()
        XCTAssertEqual(state.summaries.count, 1_000)
        XCTAssertNil(state.listTail)
    }

    @MainActor
    func testOpeningOfflineShowsOneReadToastWithRetryAndRetryLoadsTheBody() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 3, from: Self.epoch, flags: [])
        let state = await started(rig)
        let id = "1:0:INBOX"
        rig.transport.failure.with { $0 = MailFailure.timeout }
        await state.open(id)
        XCTAssertEqual(state.toast?.kind, .readFailed)
        XCTAssertEqual(state.toast?.undoable, true)
        XCTAssertFalse(state.summary(id)?.flags.contains(.seen) ?? true)
        rig.transport.failure.with { $0 = nil }
        await state.undoToast()
        XCTAssertNil(state.toast)
        XCTAssertEqual(state.card(id)?.content, .text("plain text"))
        XCTAssertEqual(state.card(id)?.bodyFailed, false)
    }

    @MainActor
    func testAFailedBodyMarksTheCardUntilARetryLoadsIt() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 3, from: Self.epoch, flags: [])
        let state = await started(rig)
        let id = "1:0:INBOX"
        rig.transport.failure.with { $0 = MailFailure.timeout }
        await state.open(id)
        XCTAssertEqual(state.card(id)?.bodyFailed, true)
        rig.transport.failure.with { $0 = nil }
        state.retryBody(id)
        for _ in 0..<50 where state.card(id)?.bodyFailed == true { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(state.card(id)?.bodyFailed, false)
        XCTAssertEqual(state.card(id)?.content, .text("plain text"))
    }

    @MainActor
    func testARowShowsWhetherTheMessageWasAnswered() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 2, from: Self.epoch, flags: [.answered])
        let state = await started(rig)
        let window = state.rowWindow(limit: 10)
        XCTAssertFalse(window.items.isEmpty)
        XCTAssertTrue(window.items.allSatisfy(\.answered))
    }

    @MainActor
    func testOpeningOnlineMarksReadWithoutAToast() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 3, from: Self.epoch, flags: [])
        let state = await started(rig)
        await state.open("1:0:INBOX")
        XCTAssertNil(state.toast)
        XCTAssertTrue(state.summary("1:0:INBOX")?.flags.contains(.seen) ?? false)
    }

    @MainActor
    func testExplicitFlagFailuresNameTheirOwnKindAndOfferRetry() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 3, from: Self.epoch, flags: [])
        let state = await started(rig)
        rig.transport.failure.with { $0 = MailFailure.timeout }
        await state.setStarred("1:0:INBOX", true)
        XCTAssertEqual(state.toast?.kind, .flagFailed)
        XCTAssertEqual(state.toast?.undoable, true)
        await state.setRead("1:0:INBOX", true)
        XCTAssertEqual(state.toast?.kind, .readFailed)
        await state.setRead("1:0:INBOX", false)
        XCTAssertEqual(state.toast?.kind, .flagFailed)
        await state.setRead("1:0:INBOX", true)
        rig.transport.failure.with { $0 = nil }
        await state.undoToast()
        XCTAssertTrue(state.summary("1:0:INBOX")?.flags.contains(.seen) ?? false)
    }

    @MainActor
    func testBulkReadCountsOnlySuccessesAndNeverReportsSuccessWhenAllFail() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 3, from: Self.epoch, flags: [])
        let state = await started(rig)
        let ids = state.summaries.map(\.id)
        ids.forEach { state.pick($0) }
        rig.transport.failure.with { $0 = MailFailure.timeout }
        await state.bulk(.read)
        XCTAssertEqual(state.toast?.kind, .flagFailed)
        XCTAssertTrue(state.picked.isEmpty)
        XCTAssertTrue(state.summaries.allSatisfy { !$0.flags.contains(.seen) })
        rig.transport.failure.with { $0 = nil }
        ids.forEach { state.pick($0) }
        await state.bulk(.read)
        XCTAssertEqual(state.toast?.kind, .bulkRead(count: 3, read: true))
        XCTAssertTrue(state.summaries.allSatisfy { $0.flags.contains(.seen) })
    }

    @MainActor
    func testSearchPagesPerFolderSkipsFailingFoldersAndKeepsScopesApart() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 150, from: Self.epoch, subject: "Offer")
        rig.fill("Archive", count: 20, from: Self.epoch.addingTimeInterval(-500_000), subject: "Offer")
        rig.fill("Trash", count: 5, from: Self.epoch, subject: "Offer")
        let all = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: nil)
        XCTAssertEqual(all.messages.count, 120)
        XCTAssertFalse(all.messages.contains { $0.folderIDs.contains("Trash") })
        XCTAssertEqual(all.messages.map(\.id), MirrorEngine.sorted(all.messages).map(\.id))
        XCTAssertEqual(all.continuation, SearchContinuation(tokens: ["INBOX": "100"]))
        let rest = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: all.continuation)
        XCTAssertEqual(rest.messages.count, 50)
        XCTAssertNil(rest.continuation)
        let here = try await rig.mailbox.search("a", folder: "Archive", query: "offer", scope: .here, continuation: all.continuation)
        XCTAssertEqual(here.messages.count, 20)
        XCTAssertNil(here.continuation)
        let hereFirst = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .here, continuation: nil)
        XCTAssertEqual(hereFirst.continuation, SearchContinuation(tokens: ["INBOX": "100"]))
        XCTAssertTrue(rig.mailbox.messages("a", folder: "INBOX").isEmpty)
        rig.transport.failingFolders.with { $0 = ["Archive"] }
        let partial = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: nil)
        XCTAssertEqual(partial.skipped, ["Archive"])
        XCTAssertEqual(partial.messages.count, 100)
        rig.transport.failingFolders.with { $0 = ["Archive", "INBOX"] }
        do {
            _ = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: nil)
            XCTFail("must throw")
        } catch {
            guard case .provider = error else { return XCTFail() }
        }
    }

    @MainActor
    func testSearchEverywhereUsesOneQueryAndItsOwnToken() async throws {
        let rig = try Rig()
        rig.transport.everywhereFolder.with { $0 = "Archive" }
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 150, from: Self.epoch, subject: "Offer")
        rig.fill("Spam", count: 3, from: Self.epoch, subject: "Offer")
        let first = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: nil)
        XCTAssertEqual(first.messages.count, 100)
        XCTAssertEqual(first.continuation, SearchContinuation(tokens: ["*": "100"]))
        let second = try await rig.mailbox.search("a", folder: "Archive", query: "offer", scope: .all, continuation: first.continuation)
        XCTAssertEqual(second.messages.count, 50)
        XCTAssertNil(second.continuation)
        XCTAssertEqual(rig.transport.calls.with { $0.filter { $0.hasPrefix("searchEverywhere") } },
                       ["searchEverywhere:offer:", "searchEverywhere:offer:100"])
        XCTAssertFalse(rig.transport.calls.with { $0.contains("listMessages") })
    }

    @MainActor
    func testSubmittedSearchPagesResultsAndLiveTypingStaysLocal() async throws {
        let rig = try Rig(range: .year, now: { MailTests.epoch })
        rig.fill("INBOX", count: 150, from: Self.epoch, subject: "Offer")
        rig.fill("Archive", count: 3, from: Self.epoch.addingTimeInterval(-9_000_000), subject: "Offer")
        let state = await started(rig)
        XCTAssertTrue(state.offersScope)
        await state.submit("offer")
        XCTAssertEqual(state.summaries.count, 103)
        XCTAssertEqual(state.listTail, .moreResults)
        await state.loadTail()
        XCTAssertEqual(state.summaries.count, 153)
        XCTAssertEqual(state.summaries.map(\.id), MirrorEngine.sorted(state.summaries).map(\.id))
        XCTAssertNil(state.listTail)
        let before = rig.transport.calls.with { $0.count }
        await state.type("offer 1")
        XCTAssertEqual(rig.transport.calls.with { $0.count }, before)
        XCTAssertFalse(state.crossHits.isEmpty)
        await state.toggleScope()
        XCTAssertEqual(state.scope, .here)
        XCTAssertEqual(state.summaries.count, 100)
        XCTAssertEqual(state.listTail, .moreResults)
        rig.transport.failingFolders.with { $0 = ["INBOX"] }
        await state.loadTail()
        XCTAssertEqual(state.toast?.kind, .moreFailed)
        XCTAssertEqual(state.summaries.count, 100)
    }

    @MainActor
    func testPartialSearchTellsWhichFoldersWereSkipped() async throws {
        let rig = try Rig()
        rig.fill("INBOX", count: 3, from: Self.epoch, subject: "Offer")
        let state = await started(rig)
        rig.transport.failingFolders.with { $0 = ["Archive"] }
        await state.submit("offer")
        XCTAssertEqual(state.toast?.kind, .searchPartial)
        XCTAssertEqual(state.summaries.count, 3)
    }

    func testIMAPListsIdsNewestFirstSinceADateAndKnowsOfOlderMail() async throws {
        let seen = Locked<[String]>([])
        let stream = scriptedServer { tag, line in
            seen.with { $0.append(line) }
            if line.contains("EXAMINE") { return ["* OK [UIDVALIDITY 7] ok", "\(tag) OK done"] }
            if line.contains("BEFORE") { return ["* SEARCH 1 2", "\(tag) OK done"] }
            if line.contains("SEARCH") { return ["* SEARCH 5 6 7", "\(tag) OK done"] }
            return nil
        }
        let client = imapClient(stream)
        XCTAssertEqual(client.ranges, MailboxRange.allCases)
        let listing = try await client.listIDs(folderID: "INBOX", since: Self.epoch, limit: nil)
        XCTAssertEqual(listing.ids, ["7:7:INBOX", "7:6:INBOX", "7:5:INBOX"])
        XCTAssertTrue(listing.hasOlder)
        let wire = seen.with { $0.joined(separator: "\n") }
        XCTAssertTrue(wire.contains("UID SEARCH UNDELETED SINCE 14-Jan-2027"))
        XCTAssertTrue(wire.contains("UID SEARCH UNDELETED BEFORE 14-Jan-2027"))
        let limited = try await client.listIDs(folderID: "INBOX", since: nil, limit: 2)
        XCTAssertEqual(limited.ids, ["7:7:INBOX", "7:6:INBOX"])
        XCTAssertTrue(limited.hasOlder)
        let everything = try await client.listIDs(folderID: "INBOX", since: nil, limit: nil)
        XCTAssertEqual(everything.ids.count, 3)
        XCTAssertFalse(everything.hasOlder)
    }

    func testIMAPCountsOlderMailWithESEARCHWhenTheServerHasIt() async throws {
        let seen = Locked<[String]>([])
        let stream = scriptedServer(capabilities: " ESEARCH") { tag, line in
            seen.with { $0.append(line) }
            if line.contains("EXAMINE") { return ["* OK [UIDVALIDITY 7] ok", "\(tag) OK done"] }
            if line.contains("RETURN (COUNT)") { return ["* ESEARCH (TAG \"\(tag)\") UID COUNT 0", "\(tag) OK done"] }
            if line.contains("SEARCH") { return ["* SEARCH 5", "\(tag) OK done"] }
            return nil
        }
        let listing = try await imapClient(stream).listIDs(folderID: "INBOX", since: Self.epoch, limit: nil)
        XCTAssertEqual(listing.ids, ["7:5:INBOX"])
        XCTAssertFalse(listing.hasOlder)
        XCTAssertTrue(seen.with { $0.joined().contains("UID SEARCH RETURN (COUNT) UNDELETED BEFORE 14-Jan-2027") })
    }

    func testIMAPFetchesSummariesForGivenIdsAndFlagsForKnownOnes() async throws {
        let seen = Locked<[String]>([])
        let envelope = "ENVELOPE (\"Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\" \"IMAP4rev1 WG mtg\" ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((NIL NIL \"imap\" \"cac.washington.edu\")) NIL NIL NIL \"<B27397@cac.washington.edu>\")"
        let stream = scriptedServer { tag, line in
            seen.with { $0.append(line) }
            if line.contains("EXAMINE") { return ["* OK [UIDVALIDITY 7] ok", "\(tag) OK done"] }
            if line.contains("FETCH") && line.contains("ENVELOPE") {
                return ["* 1 FETCH (UID 5 FLAGS (\\Seen) INTERNALDATE \"17-Jul-1996 02:44:25 -0700\" RFC822.SIZE 4286 \(envelope) BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"US-ASCII\") NIL NIL \"7BIT\" 10 1))",
                        "\(tag) OK done"]
            }
            if line.contains("FETCH") {
                return ["* 1 FETCH (UID 5 FLAGS (\\Seen \\Flagged))", "* 2 FETCH (UID 6 FLAGS ())", "\(tag) OK done"]
            }
            return nil
        }
        let client = imapClient(stream)
        let found = try await client.fetchSummaries(folderID: "INBOX", ids: ["7:5:INBOX", "7:6:INBOX", "8:9:INBOX"])
        XCTAssertEqual(found.map(\.id), ["7:5:INBOX"])
        XCTAssertEqual(found.first?.subject, "IMAP4rev1 WG mtg")
        let refreshed = try await client.refreshFlags(folderID: "INBOX", known: ["7:5:INBOX", "7:6:INBOX", "7:9:INBOX", "8:1:INBOX"],
                                                      cursor: "ignored")
        XCTAssertEqual(refreshed.flags, ["7:5:INBOX": [.seen, .flagged], "7:6:INBOX": []])
        XCTAssertNil(refreshed.cursor)
        let wire = seen.with { $0.joined(separator: "\n") }
        XCTAssertTrue(wire.contains("UID FETCH 5:6 (UID FLAGS INTERNALDATE"))
        XCTAssertTrue(wire.contains("UID FETCH 5:6,9 (UID FLAGS)"))
    }

    @MainActor
    func testBogusDatesNeverBecomeTheReachOrANegativeCutoff() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 800, from: Self.epoch)
        let bogus = MessageSummary(id: "1:bogus:INBOX", threadID: "b", subject: "Bogus", from: "A",
                                   receivedAt: Date(timeIntervalSince1970: -5_000), flags: [.seen], folderIDs: ["INBOX"])
        rig.transport.corpus.with { $0["INBOX", default: []].append(bogus) }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        try await rig.mailbox.loadOlder("a", folder: "INBOX")
        XCTAssertTrue(rig.mailbox.messages("a", folder: "INBOX").contains { $0.id == "1:bogus:INBOX" })
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let since = try XCTUnwrap(rig.transport.listings.with { $0.last?.since })
        XCTAssertGreaterThanOrEqual(since, MailboxRange.earliest)
        XCTAssertEqual(since, Self.epoch.addingTimeInterval(-799 * 3_600))
        XCTAssertEqual(MirrorEngine.cutoff(.days30, reach: Date(timeIntervalSince1970: -5_000), now: Self.epoch), MailboxRange.earliest)
    }

    @MainActor
    func testFlagsAreRefreshedForEveryKnownMessageNotJustTheNewest() async throws {
        let rig = try mirrored(.year)
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 2_500, from: Self.epoch, flags: [.seen])
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 0)
        rig.transport.serverFlags.with { $0["1:2499:INBOX"] = [] }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 1)
        XCTAssertEqual(rig.transport.knowns.with { $0.last?.count }, 2_500)
    }

    @MainActor
    func testTheHistoryCursorIsReadBeforeTheFirstPassListsAnythingAndCoversFetchedMail() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 5, from: Self.epoch)
        rig.transport.startValue.with { $0 = "s7" }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let order = rig.transport.calls.with { $0.filter { ["startCursor", "listIDs", "fetchSummaries", "refreshFlags"].contains($0) } }
        XCTAssertEqual(order, ["startCursor", "listIDs", "fetchSummaries", "refreshFlags"])
        XCTAssertEqual(rig.transport.cursors.with { $0 }, ["s7"])
        XCTAssertEqual(rig.transport.knowns.with { $0.first?.count }, 5)
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.cursors.with { $0 }, ["s7", "c1"])
        XCTAssertEqual(rig.transport.calls.with { $0.filter { $0 == "startCursor" }.count }, 2)
    }

    @MainActor
    func testAPassSkipsListingWhenTheHistoryCursorIsUnchanged() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 5, from: Self.epoch)
        rig.transport.startValue.with { $0 = "s7" }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        rig.transport.startValue.with { $0 = "c1" }
        let before = rig.transport.calls.with { $0.filter { ["listIDs", "fetchSummaries", "refreshFlags"].contains($0) }.count }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.calls.with { $0.filter { ["listIDs", "fetchSummaries", "refreshFlags"].contains($0) }.count }, before)
        XCTAssertNotNil(rig.mailbox.lastSync("a", folder: "INBOX"))
        rig.transport.startValue.with { $0 = "c9" }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.transport.calls.with { $0.filter { $0 == "listIDs" }.count }, 2)
    }

    @MainActor
    func testTheServerUnseenCountReplacesTheRangeCountAndFollowsLocalReads() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 3, from: Self.epoch, flags: [])
        rig.transport.counts.with { $0["INBOX"] = FolderCount(unseen: 9, total: 40) }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 9)
        XCTAssertEqual(rig.mailbox.unseenCount("a", folder: "INBOX"), 9)
        let id = try XCTUnwrap(rig.mailbox.messages("a", folder: "INBOX").first?.id)
        try await rig.mailbox.setFlags("a", messageID: id, add: [.seen], remove: [])
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 8)
        rig.transport.counts.with { $0["INBOX"] = nil }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        XCTAssertEqual(rig.mailbox.unreadCount("a"), 8)
        rig.transport.counts.with { $0 = [:] }
        XCTAssertNil(rig.mailbox.unseenCount("a", folder: "Nowhere"))
    }

    @MainActor
    func testSpamAndArchiveCountsComeFromTheServerWithoutMirroringThoseFolders() async throws {
        let rig = try mirrored()
        rig.transport.folderList.with {
            $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Spam", name: "Spam", role: .spam),
                  Folder(id: "Archive", name: "Archive", role: .archive)]
        }
        try await rig.mailbox.refreshFolders("a")
        rig.transport.counts.with { $0["Spam"] = FolderCount(unseen: 4, total: 10) }
        await rig.mailbox.countUnmirrored("a")
        XCTAssertEqual(rig.mailbox.unseenCount("a", folder: "Spam"), 4)
        XCTAssertNil(rig.mailbox.unseenCount("a", folder: "Archive"))
        XCTAssertTrue(rig.mailbox.messages("a", folder: "Spam").isEmpty)
        let state = await started(rig)
        XCTAssertEqual(state.folderRows.first { $0.folder.role == .spam }?.count, 0)
    }

    @MainActor
    func testAPassReportsHowManyMessagesAreFetchedUntilItEnds() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 5, from: Self.epoch)
        XCTAssertNil(rig.mailbox.progress("a", folder: "INBOX"))
        rig.transport.holds.with { $0 = ["fetchSummaries"] }
        let running = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        XCTAssertEqual(rig.mailbox.progress("a", folder: "INBOX"), SyncProgress(done: 0, total: 5))
        rig.transport.release()
        try await running.value
        XCTAssertNil(rig.mailbox.progress("a", folder: "INBOX"))
    }

    @MainActor
    func testEveryMirrorPassRunsTrackedAndReportsTheSumOverTheFoldersFetchingAtOnce() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 5, from: Self.epoch)
        rig.fill("Archive", count: 3, from: Self.epoch)
        rig.transport.holds.with { $0 = ["fetchSummaries"] }
        let inbox = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        rig.transport.holds.with { $0 = [] }
        try await rig.mailbox.refresh("a", folder: "Archive")
        XCTAssertEqual(rig.access.open.with { $0 }, 1)
        XCTAssertEqual(rig.access.reported.with { $0.map(\.total).max() }, 8)
        XCTAssertEqual(rig.access.reported.with { $0.last }, RunProgress(done: 3, total: 8))
        rig.transport.release()
        try await inbox.value
        XCTAssertEqual(rig.access.reported.with { $0.last }, RunProgress(done: 8, total: 8))
        XCTAssertEqual(rig.access.reported.with { $0.map(\.done) }, rig.access.reported.with { $0.map(\.done) }.sorted())
        XCTAssertEqual(rig.access.open.with { $0 }, 0)
        XCTAssertEqual(Set(rig.access.tracks.with { $0 }), [.mail])
        rig.transport.holds.with { $0 = ["fetchSummaries"] }
        rig.fill("INBOX", count: 7, from: Self.epoch)
        let again = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "INBOX") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        XCTAssertEqual(rig.access.reported.with { $0.last }, RunProgress(done: 0, total: 2))
        rig.transport.release()
        try await again.value
    }

    @MainActor
    func testTheLoadingPlaceholderCarriesTheFetchProgress() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 5, from: Self.epoch)
        rig.transport.holds.with { $0 = ["fetchSummaries"] }
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        let starting = Task { @MainActor in await state.start() }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        XCTAssertEqual(state.emptyKind, .loading(progress: SyncProgress(done: 0, total: 5)))
        rig.transport.release()
        await starting.value
        XCTAssertNil(state.emptyKind)
    }

    func testCountEngineKeepsTheServerCountAndFollowsLocalChanges() {
        let text = CountEngine.encode(FolderCount(unseen: 9, total: 40), local: 3)
        XCTAssertEqual(text, "9 40 3")
        let cached = try? XCTUnwrap(CountEngine.decode(text))
        XCTAssertEqual(cached?.count, FolderCount(unseen: 9, total: 40))
        XCTAssertEqual(cached.map { CountEngine.shown($0, local: 1) }, 7)
        XCTAssertEqual(cached.map { CountEngine.shown($0, local: 0) }, 6)
        XCTAssertEqual(cached.map { CountEngine.shown($0, local: 6) }, 12)
        XCTAssertEqual(CountEngine.shown(CountEngine.Cached(count: FolderCount(unseen: 1, total: 2), local: 5), local: 0), 0)
        XCTAssertNil(CountEngine.decode("9 40"))
        XCTAssertNil(CountEngine.decode("a b c"))
        XCTAssertNil(CountEngine.decode("-1 4 0"))
    }

    func testIMAPAsksStatusForTheUnseenAndTotalCounts() async throws {
        let seen = Locked<[String]>([])
        let stream = scriptedServer { tag, line in
            seen.with { $0.append(line) }
            if line.contains("STATUS \"Spam\"") { return ["* STATUS \"Spam\" (MESSAGES 231 UNSEEN 4)", "\(tag) OK done"] }
            if line.contains("STATUS") { return ["\(tag) NO nothing"] }
            return nil
        }
        let client = imapClient(stream)
        let found = try await client.unseen(folderID: "Spam")
        XCTAssertEqual(found, FolderCount(unseen: 4, total: 231))
        XCTAssertTrue(seen.with { $0.joined().contains("STATUS \"Spam\" (UNSEEN MESSAGES)") })
        do {
            _ = try await client.unseen(folderID: "Gone")
            XCTFail()
        } catch {}
    }

    @MainActor
    func testTheDraftsBadgeCountsEveryDraftOfTheFolderNotJustOpenedOnes() async throws {
        let rig = try mirrored()
        rig.transport.folderList.with {
            $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Drafts", name: "Drafts", role: .drafts)]
        }
        try await rig.mailbox.refreshFolders("a")
        rig.fill("Drafts", count: 14, from: Self.epoch)
        try await rig.mailbox.refresh("a", folder: "Drafts")
        XCTAssertEqual(rig.mailbox.draftIDs("a").count, 14)
        let state = await started(rig)
        XCTAssertEqual(state.folderRows.first { $0.folder.role == .drafts }?.count, 14)
    }

    @MainActor
    func testDraftsBadgeFollowsSavingDeletingAndSendingAtOnceAndKeepsTheMirroredTotal() async throws {
        let rig = try mirrored()
        rig.transport.folderList.with {
            $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Drafts", name: "Drafts", role: .drafts)]
        }
        try await rig.mailbox.refreshFolders("a")
        rig.fill("Drafts", count: 9, from: Self.epoch)
        try await rig.mailbox.refresh("a", folder: "Drafts")
        let state = await started(rig)
        func badge() -> Int? { state.folderRows.first { $0.folder.role == .drafts }?.count }
        XCTAssertEqual(badge(), 9)
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "Neu" }
        await state.save(id)
        XCTAssertEqual(badge(), 10)
        state.edit(id) { $0.subject = "Neu 2" }
        await state.save(id)
        XCTAssertEqual(badge(), 10)
        await state.deleteDraft(id)
        XCTAssertEqual(badge(), 9)
        let opened = await state.editDraft("1:0:Drafts")
        let mirroredID = try XCTUnwrap(opened)
        XCTAssertEqual(badge(), 9)
        await state.deleteDraft(mirroredID)
        XCTAssertEqual(badge(), 8)
        rig.fill("Drafts", count: 8, from: Self.epoch)
        rig.transport.corpus.with { $0["Drafts"]?.removeAll { $0.id == "1:0:Drafts" } }
        try await rig.mailbox.refresh("a", folder: "Drafts")
        state.refreshCounts()
        XCTAssertEqual(badge(), 7)
        XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
    }

    @MainActor
    func testSendingAMirroredDraftTakesItOutOfTheBadge() async throws {
        let rig = try mirrored()
        rig.transport.folderList.with {
            $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Drafts", name: "Drafts", role: .drafts)]
        }
        try await rig.mailbox.refreshFolders("a")
        rig.fill("Drafts", count: 3, from: Self.epoch)
        try await rig.mailbox.refresh("a", folder: "Drafts")
        let state = await started(rig)
        let opened = await state.editDraft("1:0:Drafts")
        let id = try XCTUnwrap(opened)
        state.edit(id) {
            $0.to = "x@y.de"
            $0.subject = "S"
        }
        XCTAssertEqual(state.folderRows.first { $0.folder.role == .drafts }?.count, 3)
        await state.send(id)
        XCTAssertEqual(state.draft(id)?.state, .sent)
        XCTAssertEqual(state.folderRows.first { $0.folder.role == .drafts }?.count, 2)
    }

    @MainActor
    private func draftRig(count: Int, separateIDs: Bool) async throws -> (rig: Rig, state: InboxState) {
        let rig = try mirrored()
        rig.transport.folderList.with {
            $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Drafts", name: "Drafts", role: .drafts)]
        }
        rig.transport.separateDraftIDs.with { $0 = separateIDs }
        rig.transport.mirrorsDrafts.with { $0 = true }
        try await rig.mailbox.refreshFolders("a")
        rig.fill("Drafts", count: count, from: Self.epoch)
        try await rig.mailbox.refresh("a", folder: "Drafts")
        return (rig, await started(rig))
    }

    @MainActor
    private func mirrorPass(_ rig: Rig, _ state: InboxState) async throws {
        try await rig.mailbox.refresh("a", folder: "Drafts")
        state.refreshCounts()
    }

    @MainActor
    private func draftBadge(_ state: InboxState) -> Int? {
        state.folderRows.first { $0.folder.role == .drafts }?.count
    }

    @MainActor
    func testOpeningAMirroredDraftKeepsTheBadgeWhenDraftIDAndMirrorIDDiffer() async throws {
        for separate in [false, true] {
            let (_, state) = try await draftRig(count: 9, separateIDs: separate)
            let editing = await state.editDraft("1:0:Drafts")
            let opened = try XCTUnwrap(editing)
            let card = try XCTUnwrap(state.draft(opened))
            XCTAssertEqual(card.mirrorID, "1:0:Drafts")
            XCTAssertEqual(card.remoteID, separate ? "draft:1:0:Drafts" : "1:0:Drafts")
            XCTAssertEqual(draftBadge(state), 9)
            let again = await state.editDraft("1:0:Drafts")
            XCTAssertEqual(again, opened)
            XCTAssertEqual(draftBadge(state), 9)
        }
    }

    @MainActor
    func testSavingANewDraftCountsOnceBeforeAndAfterTheMirrorPassWhenIDsDiffer() async throws {
        for separate in [false, true] {
            let (rig, state) = try await draftRig(count: 9, separateIDs: separate)
            let id = try XCTUnwrap(state.compose())
            state.edit(id) { $0.subject = "Neu" }
            await state.save(id)
            XCTAssertEqual(draftBadge(state), 10)
            XCTAssertNotEqual(state.draft(id)?.remoteID == state.draft(id)?.mirrorID, separate)
            try await mirrorPass(rig, state)
            XCTAssertEqual(rig.mailbox.draftIDs("a").count, 10)
            XCTAssertEqual(draftBadge(state), 10)
            state.edit(id) { $0.subject = "Neu 2" }
            await state.save(id)
            XCTAssertEqual(draftBadge(state), 10)
            try await mirrorPass(rig, state)
            XCTAssertEqual(rig.mailbox.draftIDs("a").count, 10)
            XCTAssertEqual(draftBadge(state), 10)
            XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
        }
    }

    @MainActor
    func testSavingAgainWithANewIDDropsTheReplacedOneFromTheBadgeAtOnce() async throws {
        let (rig, state) = try await draftRig(count: 9, separateIDs: false)
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "Neu" }
        await state.save(id)
        let first = try XCTUnwrap(state.draft(id)?.remoteID)
        try await mirrorPass(rig, state)
        XCTAssertEqual(draftBadge(state), 10)
        state.edit(id) { $0.subject = "Neu 2" }
        await state.save(id)
        let second = try XCTUnwrap(state.draft(id)?.remoteID)
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(rig.mailbox.draftIDs("a").contains(first))
        XCTAssertTrue(rig.mailbox.draftIDs("a").contains(second))
        XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
        XCTAssertEqual(draftBadge(state), 10)
        try await mirrorPass(rig, state)
        XCTAssertEqual(rig.mailbox.draftIDs("a"), Set((0..<9).map { "1:\($0):Drafts" } + [second]))
        XCTAssertEqual(draftBadge(state), 10)
        XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
    }

    @MainActor
    func testSavingADraftPutsItsRowIntoTheMirrorAndSwapsTheOldOneWithoutAPass() async throws {
        for separate in [false, true] {
            let (rig, state) = try await draftRig(count: 3, separateIDs: separate)
            await state.selectFolder("Drafts")
            let listed = rig.transport.listings.with { $0.count }
            let id = try XCTUnwrap(state.compose())
            state.edit(id) {
                $0.to = "x@y.de"
                $0.subject = "Neu"
                $0.body = "Erster Text"
            }
            await state.save(id)
            let first = try XCTUnwrap(state.draft(id)?.mirrorID)
            let row = try XCTUnwrap(rig.mailbox.messages("a", folder: "Drafts").first { $0.id == first })
            XCTAssertEqual(row.subject, "Neu")
            XCTAssertEqual(row.toRaw, "x@y.de")
            XCTAssertEqual(row.snippet, "Erster Text")
            XCTAssertEqual(row.receivedAt, Self.epoch)
            XCTAssertTrue(row.flags.contains(.draft))
            state.edit(id) {
                $0.to = nil
                $0.bcc = "h@x.de"
                $0.subject = "Neu 2"
            }
            await state.save(id)
            let second = try XCTUnwrap(state.draft(id)?.mirrorID)
            XCTAssertNotEqual(first, second)
            let rows = rig.mailbox.messages("a", folder: "Drafts")
            XCTAssertEqual(rows.count, 4)
            XCTAssertFalse(rows.contains { $0.id == first })
            XCTAssertEqual(rows.first { $0.id == second }?.bccRaw, "h@x.de")
            try await wait { state.rows.contains { $0.id == second } }
            XCTAssertEqual(state.rows.count, 4)
            XCTAssertFalse(state.rows.contains { $0.id == first })
            XCTAssertEqual(rig.transport.listings.with { $0.count }, listed)
            let shown = state.rowPresentations.first { $0.id == second }
            XCTAssertEqual(shown?.sender, "h@x.de")
            XCTAssertEqual(shown?.subject, "Neu 2")
        }
    }

    @MainActor
    func testADraftSavedWhileAMirrorPassRunsSurvivesThatPass() async throws {
        let (rig, state) = try await draftRig(count: 3, separateIDs: false)
        rig.transport.mirrorsDrafts.with { $0 = false }
        rig.transport.holds.with { $0 = ["listIDs"] }
        let pass = Task { @MainActor in try await rig.mailbox.refresh("a", folder: "Drafts") }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.subject = "Neu" }
        await state.save(id)
        let saved = try XCTUnwrap(state.draft(id)?.mirrorID)
        rig.transport.release()
        try await pass.value
        XCTAssertTrue(rig.mailbox.draftIDs("a").contains(saved))
        XCTAssertEqual(rig.mailbox.draftIDs("a").count, 4)
    }

    @MainActor
    func testTheMirrorKeepsTheBccHeaderOfAMessage() throws {
        let envelope = "* 5 FETCH (UID 5 FLAGS (\\Draft) ENVELOPE (NIL \"Nur Bcc\" ((NIL NIL \"me\" \"x.test\")) ((NIL NIL \"me\" \"x.test\")) ((NIL NIL \"me\" \"x.test\")) NIL NIL ((\"Hans\" NIL \"h\" \"x.test\")) NIL \"<d@x.test>\"))"
        let summary = IMAPSMTPClient.summary(try fetched(envelope), uid: 5, folder: "Drafts", uidValidity: 1)
        XCTAssertEqual(summary.bccRaw, "Hans <h@x.test>")
        XCTAssertEqual(summary.toRaw, "")
        XCTAssertEqual(InboxState.recipients(InboxState.addressed(summary, card: nil)), "Hans")
        let kept = Draft(to: nil, bcc: "Hans <h@x.test>", subject: "s", body: "b")
        XCTAssertEqual(MirrorEngine.draftRow("d", kept, folder: "Drafts", account: "me@x.test", thread: "", at: Self.epoch).bccRaw,
                       "Hans <h@x.test>")
    }

    @MainActor
    func testTheStoreRoundTripsTheBccHeader() async throws {
        let rig = try mirrored()
        try rig.mailbox.upsert("a", "INBOX", [MessageSummary(id: "1:7:INBOX", subject: "s", from: "Me", bccRaw: "Cora <c@x.de>")])
        XCTAssertEqual(rig.mailbox.messages("a", folder: "INBOX").first?.bccRaw, "Cora <c@x.de>")
    }

    @MainActor
    func testDeletingDraftsLeavesTheBadgeRightBeforeAndAfterTheMirrorPassWhenIDsDiffer() async throws {
        for separate in [false, true] {
            let (rig, state) = try await draftRig(count: 9, separateIDs: separate)
            let id = try XCTUnwrap(state.compose())
            state.edit(id) { $0.subject = "Neu" }
            await state.save(id)
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 10)
            await state.deleteDraft(id)
            XCTAssertEqual(draftBadge(state), 9)
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 9)
            let editing = await state.editDraft("1:0:Drafts")
            let opened = try XCTUnwrap(editing)
            await state.deleteDraft(opened)
            XCTAssertEqual(draftBadge(state), 8)
            XCTAssertEqual(state.goneDrafts["a"], ["1:0:Drafts"])
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 8)
            XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
        }
    }

    @MainActor
    func testSendingDraftsLeavesTheBadgeRightBeforeAndAfterTheMirrorPassWhenIDsDiffer() async throws {
        for separate in [false, true] {
            let (rig, state) = try await draftRig(count: 3, separateIDs: separate)
            let fresh = try XCTUnwrap(state.compose())
            state.edit(fresh) {
                $0.to = "x@y.de"
                $0.subject = "Neu"
            }
            await state.save(fresh)
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 4)
            await state.send(fresh)
            XCTAssertEqual(state.draft(fresh)?.state, .sent)
            XCTAssertEqual(draftBadge(state), 3)
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 3)
            let editing = await state.editDraft("1:0:Drafts")
            let opened = try XCTUnwrap(editing)
            state.edit(opened) {
                $0.to = "x@y.de"
                $0.subject = "S"
            }
            XCTAssertEqual(draftBadge(state), 3)
            await state.send(opened)
            XCTAssertEqual(draftBadge(state), 2)
            XCTAssertEqual(rig.mailbox.draftIDs("a").count, 2)
            XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 2)
            XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
        }
    }

    @MainActor
    func testAFailedSendAfterTheOutboxSavedAgainKeepsTheBadgeRightAfterTheMirrorPass() async throws {
        for separate in [false, true] {
            let (rig, state) = try await draftRig(count: 3, separateIDs: separate)
            let fresh = try XCTUnwrap(state.compose())
            state.edit(fresh) {
                $0.to = "x@y.de"
                $0.subject = "Neu"
            }
            await state.save(fresh)
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 4)
            let before = try XCTUnwrap(state.draft(fresh)?.mirrorID)
            rig.transport.sendDraftFailure.with { $0 = MailFailure.smtpRejected(550, "no") }
            await state.send(fresh)
            guard case .sendFailed = state.draft(fresh)?.state else { return XCTFail() }
            let after = try XCTUnwrap(state.draft(fresh)?.mirrorID)
            XCTAssertNotEqual(before, after)
            XCTAssertEqual(state.goneDrafts["a"], [before])
            XCTAssertEqual(draftBadge(state), 4)
            try await mirrorPass(rig, state)
            XCTAssertEqual(rig.mailbox.draftIDs("a").count, 4)
            XCTAssertEqual(draftBadge(state), 4)
            XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
        }
    }

    @MainActor
    func testTheDraftsBadgeIgnoresFailedSavesAndDeletesWhileOffline() async throws {
        for separate in [false, true] {
            let (rig, state) = try await draftRig(count: 9, separateIDs: separate)
            let editing = await state.editDraft("1:0:Drafts")
            let opened = try XCTUnwrap(editing)
            let fresh = try XCTUnwrap(state.compose())
            state.edit(fresh) { $0.subject = "Neu" }
            XCTAssertEqual(draftBadge(state), 9)
            rig.transport.failure.with { $0 = MailFailure.timeout }
            await state.save(fresh)
            XCTAssertNotNil(state.draft(fresh)?.saveFailure)
            XCTAssertNil(state.draft(fresh)?.mirrorID)
            XCTAssertEqual(draftBadge(state), 9)
            await state.deleteDraft(opened)
            XCTAssertNotNil(state.draft(opened))
            XCTAssertEqual(draftBadge(state), 9)
            XCTAssertTrue(state.goneDrafts["a"]?.isEmpty ?? true)
            rig.transport.failure.with { $0 = nil }
            await state.save(fresh)
            XCTAssertEqual(draftBadge(state), 10)
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 10)
        }
    }

    @MainActor
    func testTheDraftsBadgeIsKeptPerMailboxAcrossAnAccountSwitch() async throws {
        for separate in [false, true] {
            let (rig, state) = try await draftRig(count: 4, separateIDs: separate)
            let other = rig.addMailbox("b", prefix: "2")
            other.separateDraftIDs.with { $0 = separate }
            other.mirrorsDrafts.with { $0 = true }
            other.folderList.with {
                $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Drafts", name: "Drafts", role: .drafts)]
            }
            await state.refreshAccounts()
            state.refreshCounts()
            let first = try XCTUnwrap(state.compose())
            state.edit(first) { $0.subject = "A" }
            await state.save(first)
            XCTAssertEqual(state.draftBadge("a"), 5)
            XCTAssertEqual(state.draftBadge("b"), 0)
            await state.selectAccount("b")
            let second = try XCTUnwrap(state.compose())
            state.edit(second) { $0.subject = "B" }
            await state.save(second)
            XCTAssertEqual(state.draftBadge("a"), 5)
            XCTAssertEqual(state.draftBadge("b"), 1)
            XCTAssertEqual(state.draft(second)?.inlet, "b")
            XCTAssertTrue(other.calls.with { $0.contains("saveDraft") })
            await state.deleteDraft(second)
            XCTAssertEqual(state.draftBadge("a"), 5)
            XCTAssertEqual(state.draftBadge("b"), 0)
            await state.selectAccount("a")
            try await mirrorPass(rig, state)
            XCTAssertEqual(draftBadge(state), 5)
            XCTAssertEqual(state.draftBadge("b"), 0)
        }
    }

    @MainActor
    func testTilesToggleClearsTheHoveredTileAndFollowTheTypedText() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 3, from: Self.epoch)
        let state = await started(rig)
        XCTAssertTrue(state.offersTiles)
        XCTAssertFalse(state.tiles)
        state.aimTile("1:0:INBOX")
        XCTAssertEqual(state.tileHot, "1:0:INBOX")
        state.aimTile(nil)
        XCTAssertNil(state.tileHot)
        state.aimTile("1:1:INBOX")
        state.toggleTiles()
        XCTAssertTrue(state.tiles)
        XCTAssertNil(state.tileHot)
        state.toggleTiles()
        XCTAssertFalse(state.tiles)
        await state.type("Note 1")
        XCTAssertFalse(state.offersTiles)
        await state.type("")
        XCTAssertTrue(state.offersTiles)
    }

    @MainActor
    func testTilesAreNotOfferedOfflineWithoutRows() async throws {
        let rig = try mirrored()
        try await rig.mailbox.refreshFolders("a")
        rig.transport.failure.with { $0 = MailFailure.timeout }
        let state = await started(rig)
        guard case .offline = state.listState else { return XCTFail() }
        XCTAssertNil(state.emptyKind)
        XCTAssertFalse(state.offersTiles)
    }

    @MainActor
    func testComposeIsOfferedOnlyWhereMailIsWritten() async throws {
        let rig = try mirrored()
        let roles: [(FolderRole, Bool)] = [(.inbox, true), (.sent, true), (.drafts, true), (.all, true), (.archive, false),
                                           (.trash, false), (.spam, false), (.starred, false), (.other, false)]
        rig.transport.folderList.with { $0 = roles.map { Folder(id: $0.0.rawValue, name: $0.0.rawValue, role: $0.0) } }
        let state = await started(rig)
        for (role, offered) in roles {
            await state.selectFolder(role.rawValue)
            XCTAssertEqual(state.offersCompose, offered, role.rawValue)
        }
    }

    @MainActor
    func testEmptyKindNamesWhyTheListIsEmpty() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 0, from: Self.epoch)
        let state = await started(rig)
        XCTAssertEqual(state.emptyKind, .empty(folder: state.currentFolderName))
        rig.fill("INBOX", count: 3, from: Self.epoch)
        await state.loadSelection()
        XCTAssertNil(state.emptyKind)
        state.setFilter(.unread)
        XCTAssertEqual(state.emptyKind, .noFilterMatch)
        state.setFilter(.all)
        await state.submit("zzz")
        XCTAssertEqual(state.emptyKind, .noResults(query: "zzz", folder: state.currentFolderName))
    }

    @MainActor
    func testUnsavedOutboxIsCountedAndSavedAgain() async throws {
        let rig = try mirrored()
        let state = await started(rig)
        XCTAssertEqual(state.outboxUnsaved, 0)
        try rig.database.write { try $0.execute(sql: "ALTER TABLE mail_outbox RENAME TO mail_outbox_away") }
        rig.transport.failure.with { $0 = MailFailure.connectionClosed }
        guard case .queued = await rig.outbox.send("a", Draft(to: "x@y.de", subject: "s", body: "b")) else { return XCTFail() }
        XCTAssertEqual(state.outboxUnsaved, 1)
        state.resaveOutbox()
        XCTAssertEqual(state.outboxUnsaved, 1)
        try rig.database.write { try $0.execute(sql: "ALTER TABLE mail_outbox_away RENAME TO mail_outbox") }
        state.resaveOutbox()
        XCTAssertEqual(state.outboxUnsaved, 0)
        let saved = try rig.database.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mail_outbox") }
        XCTAssertEqual(saved, 1)
    }

    @MainActor
    func testFailedMovesPostTheirOwnKindAndRetryFinishesThem() async throws {
        let rig = try mirrored()
        rig.transport.folderList.with {
            $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Archive", name: "Archive", role: .archive),
                  Folder(id: "Trash", name: "Trash", role: .trash), Folder(id: "Spam", name: "Spam", role: .spam),
                  Folder(id: "Work", name: "Work", role: .other)]
        }
        rig.fill("INBOX", count: 6, from: Self.epoch, flags: [.seen])
        let state = await started(rig)
        let cases: [(ToastKind, (String) async -> Void)] = [
            (.archiveFailed, { await state.archive($0) }),
            (.deleteFailed, { await state.trash($0) }),
            (.moveFailed, { await state.markSpam($0) }),
            (.moveFailed, { await state.move($0, to: "Work") })
        ]
        for (index, entry) in cases.enumerated() {
            let id = "1:\(index):INBOX"
            rig.transport.failure.with { $0 = MailFailure.timeout }
            await entry.1(id)
            XCTAssertEqual(state.toast?.kind, entry.0)
            XCTAssertEqual(state.toast?.undoable, true)
            XCTAssertTrue(state.summaries.contains { $0.id == id })
            rig.transport.failure.with { $0 = nil }
            await state.undoToast()
            XCTAssertFalse(state.summaries.contains { $0.id == id })
        }
    }

    @MainActor
    func testFailedPurgeThreadAndAttachmentPostTheirKinds() async throws {
        let rig = try mirrored()
        rig.transport.folderList.with {
            $0 = [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Trash", name: "Trash", role: .trash)]
        }
        try await rig.mailbox.refreshFolders("a")
        rig.fill("Trash", count: 2, from: Self.epoch)
        await rig.mailbox.checkPurge("a")
        let state = await started(rig)
        await state.selectFolder("Trash")
        rig.transport.failure.with { $0 = MailFailure.timeout }
        await state.purge("1:0:Trash")
        XCTAssertEqual(state.toast?.kind, .deleteFailed)
        XCTAssertEqual(state.toast?.undoable, true)
        rig.transport.failure.with { $0 = nil }
        await state.undoToast()
        XCTAssertEqual(state.toast?.kind, .purged)
        XCTAssertFalse(state.summaries.contains { $0.id == "1:0:Trash" })
        rig.transport.failure.with { $0 = MailFailure.timeout }
        await state.loadThread("1:1:Trash")
        XCTAssertEqual(state.toast?.kind, .threadFailed)
        XCTAssertEqual(state.toast?.undoable, true)
        rig.transport.failure.with { $0 = nil }
        rig.transport.calls.with { $0 = [] }
        await state.undoToast()
        XCTAssertEqual(rig.transport.calls.with { $0.filter { $0 == "thread" }.count }, 1)
        XCTAssertNil(state.toast)
        rig.transport.failure.with { $0 = MailFailure.timeout }
        let data = await state.attachmentData("1:1:Trash", attachmentID: "x")
        XCTAssertNil(data)
        XCTAssertEqual(state.toast?.kind, .attachmentFailed)
        XCTAssertEqual(state.toast?.undoable, false)
    }

    @MainActor
    func testLoadingTheTailRunsOnceWhileItIsLoading() async throws {
        let rig = try mirrored()
        rig.fill("INBOX", count: 1_000, from: Self.epoch)
        let state = await started(rig)
        XCTAssertEqual(state.listTail, .older)
        let before = rig.transport.listings.with { $0.count }
        rig.transport.holds.with { $0 = ["listIDs"] }
        let first = Task { @MainActor in await state.loadTail() }
        try await wait { rig.transport.waiting.with { $0.count } == 1 }
        XCTAssertEqual(state.phase, .loadingMore)
        XCTAssertEqual(state.listTail, .older)
        let second = Task { @MainActor in await state.loadTail() }
        await second.value
        XCTAssertEqual(rig.transport.listings.with { $0.count }, before + 1)
        rig.transport.release()
        await first.value
        XCTAssertEqual(rig.transport.listings.with { $0.count }, before + 1)
        XCTAssertEqual(state.phase, .settled)
    }

    func testPreviewTextDropsQuotesSignaturesAndAttributionLines() {
        XCTAssertEqual(PreviewEngine.text("Danke dir!\n> > alter Text\n> noch mehr"), "Danke dir!")
        XCTAssertEqual(PreviewEngine.text("Passt so.\n\nAm Mi., 28. Okt. 2026 um 10:00 schrieb Anna <anna@example.com>:\n> Hallo"), "Passt so.")
        XCTAssertEqual(PreviewEngine.text("Passt so. Am Mi., 28. Okt. 2026 um 10:00 schrieb Anna <a@b.de>: > > > > Hallo"), "Passt so.")
        XCTAssertEqual(PreviewEngine.text("On Mon, Oct 26, 2026 at 9:00 AM Bob <b@x.com> wrote: > hi"), "")
        XCTAssertEqual(PreviewEngine.text("Bis morgen\n-- \nMax Muster\nStudio"), "Bis morgen")
        XCTAssertEqual(PreviewEngine.text("Bis morgen\n--\nMax"), "Bis morgen")
        XCTAssertEqual(PreviewEngine.text("Bis morgen \u{2014} > > > >"), "Bis morgen")
        XCTAssertEqual(PreviewEngine.text("Gesendet von meinem iPhone"), "")
        XCTAssertEqual(PreviewEngine.text("Zeile eins\r\n  Zeile   zwei  "), "Zeile eins Zeile zwei")
        XCTAssertEqual(PreviewEngine.text("Wir sehen uns am Montag, Anna schrieb nichts"), "Wir sehen uns am Montag, Anna schrieb nichts")
        XCTAssertEqual(PreviewEngine.text("Am Montag schrieb mir der Kunde: bitte melden Sie sich"), "Am Montag schrieb mir der Kunde: bitte melden Sie sich")
        XCTAssertEqual(PreviewEngine.text("Gesendet von Anna Muster am Montag"), "Gesendet von Anna Muster am Montag")
    }

    func testDraftHeaderShowsPhaseStatusAndNeverMissingFieldHints() {
        var draft = OpenDraft(id: UUID(), inlet: "a", draft: Draft(subject: "", body: ""), state: .idle, outboxID: nil, remoteID: nil, saveFailure: nil)
        XCTAssertNil(draft.status)
        draft.state = .saving
        XCTAssertEqual(draft.status, .saving)
        draft.state = .saved(Date())
        XCTAssertEqual(draft.status, .saved)
        draft.state = .queuedInOutbox
        XCTAssertEqual(draft.status, .outbox)
        draft.state = .sending
        XCTAssertEqual(draft.status, .sending)
        draft.state = .sendFailed(Hint(text: "x"))
        XCTAssertEqual(draft.status, .sendFailed)
        draft.state = .edited
        draft.saveFailure = Hint(text: "x")
        XCTAssertEqual(draft.status, .notSaved)
        XCTAssertFalse(draft.saveNeedsSignIn)
        draft.saveFailure = Hint(text: Hint.signInExpiredText)
        XCTAssertTrue(draft.saveNeedsSignIn)
    }

    @MainActor
    func testSkippedFoldersAreRetriedWhenMoreResultsAreLoaded() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 150, from: Self.epoch, subject: "Offer")
        rig.fill("Archive", count: 20, from: Self.epoch.addingTimeInterval(-500_000), subject: "Offer")
        rig.transport.failingFolders.with { $0 = ["Archive"] }
        let first = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: nil)
        XCTAssertEqual(first.skipped, ["Archive"])
        XCTAssertEqual(first.continuation, SearchContinuation(tokens: ["INBOX": "100", "Archive": ""]))
        XCTAssertNil(first.total)
        rig.transport.failingFolders.with { $0 = [] }
        let second = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: first.continuation)
        XCTAssertEqual(second.messages.count, 70)
        XCTAssertTrue(second.skipped.isEmpty)
        XCTAssertNil(second.continuation)
    }

    @MainActor
    func testSearchHeaderCountUsesTheServersTotalWhenTheProviderGivesOne() async throws {
        let rig = try Rig(range: .year, now: { MailTests.epoch })
        rig.fill("INBOX", count: 150, from: Self.epoch, subject: "Offer")
        rig.fill("Archive", count: 3, from: Self.epoch.addingTimeInterval(-9_000_000), subject: "Offer")
        let state = await started(rig)
        let direct = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: nil)
        XCTAssertEqual(direct.total, 153)
        XCTAssertEqual(state.resultCount(loaded: 7), 7)
        await state.submit("offer")
        XCTAssertEqual(state.summaries.count, 103)
        XCTAssertEqual(state.resultCount(loaded: state.summaries.count), 153)
        await state.loadTail()
        XCTAssertEqual(state.resultCount(loaded: state.summaries.count), 153)
        state.filter = .unread
        XCTAssertEqual(state.resultCount(loaded: 4), 4)
        state.filter = .all
        await state.type("offer 1")
        XCTAssertEqual(state.resultCount(loaded: 9), 9)
        await state.submit("")
        XCTAssertEqual(state.resultCount(loaded: 5), 5)
        rig.transport.searchTotals.with { $0 = false }
        await state.submit("offer")
        XCTAssertEqual(state.resultCount(loaded: state.summaries.count), state.summaries.count)
    }

    @MainActor
    func testEverywhereSearchReportsItsTotal() async throws {
        let rig = try Rig()
        rig.transport.everywhereFolder.with { $0 = "Archive" }
        try await rig.mailbox.refreshFolders("a")
        rig.fill("INBOX", count: 150, from: Self.epoch, subject: "Offer")
        let page = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: nil)
        XCTAssertEqual(page.total, 150)
        let next = try await rig.mailbox.search("a", folder: "INBOX", query: "offer", scope: .all, continuation: page.continuation)
        XCTAssertEqual(next.messages.count, 50)
    }

    @MainActor
    func testFolderSwitchAndAccountSwitchShowTheLoadingPlaceholderUntilTheOffMainReadLands() async throws {
        let rig = try mirrored()
        let other = rig.addMailbox("b", prefix: "2")
        rig.fill("INBOX", count: 3, from: Self.epoch)
        rig.fill("Archive", count: 2, from: Self.epoch)
        let state = await started(rig)
        try await rig.mailbox.refreshFolders("b")
        try await rig.mailbox.refresh("b", folder: "INBOX")
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(other.calls.with { $0.filter { $0 == "listIDs" }.count }, 1)
        XCTAssertEqual(state.summaries.map(\.id), ["1:0:INBOX", "1:1:INBOX", "1:2:INBOX"])
        let gate = DispatchSemaphore(value: 0)
        let held = DispatchSemaphore(value: 0)
        let database = rig.database
        try await Task.sleep(for: .milliseconds(300))
        Thread.detachNewThread {
            try? database.write { _ in
                held.signal()
                _ = gate.wait(timeout: .now() + 5)
            }
        }
        Self.block(on: held)
        let switching = Task { @MainActor in await state.selectFolder("Archive") }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(state.selectedFolder, "Archive")
        XCTAssertTrue(state.summaries.isEmpty)
        XCTAssertEqual(state.listState, .loading)
        gate.signal()
        await switching.value
        XCTAssertEqual(state.summaries.map(\.id), ["1:0:Archive", "1:1:Archive"])
        XCTAssertTrue(state.swapAccount("b"))
        XCTAssertTrue(state.summaries.isEmpty)
        XCTAssertEqual(state.phase, .loading)
        XCTAssertEqual(state.listState, .loading)
        try await wait { state.phase == .settled }
        XCTAssertEqual(state.summaries.map(\.id), ["2:1:INBOX"])
    }

    @MainActor
    func testThreeThousandMessagesAreReadOffMainAndPresentedInAWindow() async throws {
        let rig = try mirrored(.all)
        rig.fill("INBOX", count: 3_000, from: Self.epoch, step: -3_000)
        let state = await started(rig)
        try await wait { state.summaries.count == 3_000 && state.reloadTask == nil }
        XCTAssertEqual(state.summaries.count, 3_000)
        let began = Date()
        let direct = rig.mailbox.messages("a", folder: "INBOX")
        let blocking = Date().timeIntervalSince(began)
        XCTAssertEqual(direct.count, 3_000)
        XCTAssertGreaterThan(blocking, 0.005)
        let ticks = Locked<Double>(0)
        let running = Locked(true)
        let ticker = Task { @MainActor in
            while running.with({ $0 }) {
                let start = Date()
                try? await Task.sleep(for: .milliseconds(1))
                ticks.with { $0 = max($0, Date().timeIntervalSince(start)) }
            }
        }
        try await Task.sleep(for: .milliseconds(20))
        ticks.with { $0 = 0 }
        let read = await rig.mailbox.cached("a", folder: "INBOX")
        running.with { $0 = false }
        await ticker.value
        XCTAssertEqual(read.count, 3_000)
        XCTAssertLessThan(ticks.with { $0 }, blocking * 0.75)
        let shown = Date()
        let window = state.rowWindow(limit: 61)
        let building = Date().timeIntervalSince(shown)
        XCTAssertEqual(window.items.count, 61)
        XCTAssertEqual(window.total, 3_000)
        XCTAssertLessThan(building, 0.1)
    }

    func testIMAPReadsASearchReplyLargerThanOneMebibyte() async throws {
        let uids = Array(1...190_000)
        let reply = "* SEARCH " + uids.map(String.init).joined(separator: " ")
        XCTAssertGreaterThan(reply.utf8.count, 1_048_576)
        let stream = scriptedServer { tag, line in
            if line.contains("EXAMINE") { return ["* OK [UIDVALIDITY 7] ok", "\(tag) OK done"] }
            if line.contains("SEARCH") { return [reply, "\(tag) OK done"] }
            return nil
        }
        let listing = try await imapClient(stream).listIDs(folderID: "INBOX", since: nil, limit: 3)
        XCTAssertEqual(listing.ids, ["7:190000:INBOX", "7:189999:INBOX", "7:189998:INBOX"])
        XCTAssertTrue(listing.hasOlder)
    }

    func testIMAPSearchFallsBackWithoutCharsetWhenTheServerRefusesIt() async throws {
        let seen = Locked<[String]>([])
        let envelope = "ENVELOPE (\"Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\" \"Kaese\" ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((\"Terry Gray\" NIL \"gray\" \"cac.washington.edu\")) ((NIL NIL \"imap\" \"cac.washington.edu\")) NIL NIL NIL \"<B1@cac.washington.edu>\")"
        let stream = scriptedServer { tag, line in
            seen.with { $0.append(line) }
            if line.contains("EXAMINE") { return ["* OK [UIDVALIDITY 7] ok", "\(tag) OK done"] }
            if line.contains("SEARCH"), line.contains("CHARSET") { return ["\(tag) NO [BADCHARSET (US-ASCII)] charset not supported"] }
            if line.contains("SEARCH") { return line.hasSuffix("}") ? ["+ go", "* SEARCH 5 6"] : ["* SEARCH 5 6", "\(tag) OK done"] }
            if line.contains("FETCH") {
                return ["* 1 FETCH (UID 5 FLAGS (\\Seen) INTERNALDATE \"17-Jul-1996 02:44:25 -0700\" RFC822.SIZE 1 \(envelope) BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"US-ASCII\") NIL NIL \"7BIT\" 10 1))",
                        "\(tag) OK done"]
            }
            return nil
        }
        let page = try await imapClient(stream).listMessages(folderID: "INBOX", query: "K\u{E4}se", pageToken: nil, maxResults: 10)
        XCTAssertEqual(page.total, 2)
        XCTAssertFalse(page.messages.isEmpty)
        let searches = seen.with { $0.filter { $0.contains("SEARCH") } }
        XCTAssertEqual(searches.count, 2)
        XCTAssertTrue(searches[0].contains("CHARSET UTF-8"))
        XCTAssertFalse(searches[1].contains("CHARSET"))
    }

    @MainActor
    func testUIDValidityChangeEndToEndOverTheScriptedIMAPServer() async throws {
        let validity = Locked(7)
        let uids = Locked<[Int]>(Array(1...25))
        let envelope = { @Sendable (uid: Int) in
            "ENVELOPE (\"Fri, 15 Jan 2027 08:00:00 +0000\" \"S\(uid)\" ((\"A\" NIL \"a\" \"x.test\")) ((\"A\" NIL \"a\" \"x.test\")) ((\"A\" NIL \"a\" \"x.test\")) ((NIL NIL \"me\" \"x.test\")) NIL NIL NIL \"<m\(uid)@x.test>\")"
        }
        let stream = scriptedServer { tag, line in
            if line.contains("LIST") { return ["* LIST (\\HasNoChildren) \"/\" \"INBOX\"", "\(tag) OK done"] }
            if line.contains("EXAMINE") { return ["* OK [UIDVALIDITY \(validity.with { $0 })] ok", "\(tag) OK done"] }
            if line.contains("SEARCH") {
                if line.contains("BEFORE") { return ["* SEARCH", "\(tag) OK done"] }
                return ["* SEARCH " + uids.with { $0 }.map(String.init).joined(separator: " "), "\(tag) OK done"]
            }
            if line.contains("FETCH") {
                let listed = uids.with { $0 }
                if line.contains("ENVELOPE") {
                    return listed.enumerated().map { index, uid in
                        "* \(index + 1) FETCH (UID \(uid) FLAGS (\\Seen) INTERNALDATE \"15-Jan-2027 08:00:00 +0000\" RFC822.SIZE 1 \(envelope(uid)) BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"US-ASCII\") NIL NIL \"7BIT\" 10 1))"
                    } + ["\(tag) OK done"]
                }
                return listed.enumerated().map { "* \($0.offset + 1) FETCH (UID \($0.element) FLAGS (\\Seen))" } + ["\(tag) OK done"]
            }
            return nil
        }
        let rig = try Rig(range: .days30, now: { MailTests.epoch })
        rig.access.transport = imapClient(stream)
        try await rig.mailbox.refreshFolders("a")
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let first = Set(rig.mailbox.messages("a", folder: "INBOX").map(\.id))
        XCTAssertEqual(first.count, 25)
        XCTAssertTrue(first.allSatisfy { $0.hasPrefix("7:") })
        validity.with { $0 = 8 }
        try await rig.mailbox.refresh("a", folder: "INBOX")
        let second = Set(rig.mailbox.messages("a", folder: "INBOX").map(\.id))
        XCTAssertEqual(second.count, 25)
        XCTAssertTrue(second.allSatisfy { $0.hasPrefix("8:") })
        validity.with { $0 = 9 }
        uids.with { $0 = [] }
        let events = rig.events.stream
        try await rig.mailbox.refresh("a", folder: "INBOX")
        rig.events.emit(.syncFinished("end"))
        var refused = 0
        for await event in events {
            if event == .syncFinished("end") { break }
            if event == .refused("a", folder: "INBOX") { refused += 1 }
        }
        XCTAssertEqual(refused, 1)
        XCTAssertEqual(Set(rig.mailbox.messages("a", folder: "INBOX").map(\.id)), second)
    }

    private static func block(on semaphore: DispatchSemaphore) {
        semaphore.wait()
    }

    private func imapClient(_ stream: ScriptedStream) -> IMAPSMTPClient {
        let settings = ServerSettings(host: "h", port: 993, security: .ssl, username: "u")
        let account = Account(id: "a", displayName: "Me", address: "me@example.com", incoming: settings, outgoing: settings)
        return IMAPSMTPClient(account: account, password: { "s" }, opener: { _, _, _ in stream })
    }
}

private final class SingleFolderDouble: MailTransportPort, @unchecked Sendable {
    func listFolders() async throws -> [Folder] { [Folder(id: "INBOX", name: "INBOX", role: .inbox)] }
    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        MessagePage(messages: [])
    }
    func fetchBody(messageID: String) async throws -> MessageBody { MessageBody(text: nil, html: nil) }
    func send(_ draft: Draft) async throws {}
    func setFlags(messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws {}
    func archive(messageID: String, folderID: String?) async throws {}
    func move(messageID: String, toFolderID: String) async throws {}
    func trash(messageID: String, folderID: String?) async throws {}
    func markSpam(messageID: String, folderID: String?) async throws {}
    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data { Data() }
    func fetchThread(messageID: String, threadID: String) async throws -> [MessageSummary] { [] }
    func saveDraft(_ draft: Draft, replacing draftID: String?, into folderID: String?) async throws -> SavedDraft { SavedDraft(id: "") }
    func fetchDraft(messageID: String) async throws -> StoredDraft { StoredDraft(id: messageID, draft: Draft(subject: "", body: "")) }
    func deleteDraft(id: String) async throws {}
    func sendDraft(id: String) async throws {}
    func wasSent(messageID: String, in folderID: String?) async throws -> Bool { false }
}

extension MailTests {
    func testMailtoLinkOpensDraftInsteadOfSystemMail() {
        XCTAssertEqual(HTMLEngine.navigation(scheme: "mailto", linkActivated: true, mainFrame: true), .compose)
        let target = HTMLEngine.mailto("mailto:anna@x.de?subject=Hallo%20Welt&cc=b@x.de&body=Text")
        XCTAssertEqual(target, MailtoTarget(to: "anna@x.de", cc: "b@x.de", subject: "Hallo Welt", body: "Text"))
        XCTAssertEqual(HTMLEngine.mailto("mailto:?to=c@x.de")?.to, "c@x.de")
        XCTAssertNil(HTMLEngine.mailto("https://x.de"))
    }

    @MainActor
    func testSignatureSplitsAfterDelimiter() {
        let split = InboxState.signatureSplit("Hallo\n\n-- \nAnna\nMuster GmbH")
        XCTAssertEqual(split.body, "Hallo")
        XCTAssertEqual(split.signature?.text, "Anna\nMuster GmbH")
        XCTAssertEqual(split.signature?.lines, 2)
        XCTAssertNil(InboxState.signatureSplit("Hallo\nohne Signatur").signature)
        XCTAssertNil(InboxState.signatureSplit("-- \nAnna").signature)
    }

    func testMeasureScriptScalesWideContent() {
        XCTAssertTrue(HTMLEngine.measureScript.contains("scale("))
    }
}

struct DiscoveryFake: DiscoveryPort {
    var documents: [String: String] = [:]
    var records: [String: [Data]] = [:]

    func document(_ url: URL) async -> Data? { documents[url.absoluteString].map { Data($0.utf8) } }
    func records(_ name: String, type: UInt16) async -> [Data] { records[name + "/" + String(type)] ?? [] }
}

extension MailTests {
    static func config(incoming: String, outgoing: String, user: String = "%EMAILADDRESS%") -> String {
        """
        <clientConfig version="1.1"><emailProvider id="x">
        <incomingServer type="pop3"><hostname>pop.x</hostname><port>995</port><socketType>SSL</socketType>
        <username>\(user)</username><authentication>password-cleartext</authentication></incomingServer>
        <incomingServer type="imap"><hostname>\(incoming)</hostname><port>993</port><socketType>plain</socketType>
        <username>\(user)</username><authentication>password-cleartext</authentication></incomingServer>
        <incomingServer type="imap"><hostname>\(incoming)</hostname><port>993</port><socketType>SSL</socketType>
        <username>\(user)</username><authentication>OAuth2</authentication><authentication>password-cleartext</authentication></incomingServer>
        <outgoingServer type="smtp"><hostname>\(outgoing)</hostname><port>587</port><socketType>STARTTLS</socketType>
        <username>\(user)</username><authentication>password-cleartext</authentication></outgoingServer>
        </emailProvider></clientConfig>
        """
    }

    static func name(_ host: String) -> [UInt8] {
        host.split(separator: ".").flatMap { [UInt8($0.utf8.count)] + Array($0.utf8) } + [0]
    }

    func testAutoconfigTakesFirstSecureIMAPAndSMTPWithPassword() {
        let found = AutoconfigEngine.servers(Data(Self.config(incoming: "imap.%EMAILDOMAIN%", outgoing: "smtp.x").utf8),
                                             address: "anna@beispiel.de")
        XCTAssertEqual(found?.incoming, ServerTemplate(host: "imap.beispiel.de", port: 993, security: .ssl))
        XCTAssertEqual(found?.outgoing, ServerTemplate(host: "smtp.x", port: 587, security: .starttls))
        XCTAssertNil(found?.username)
        let local = AutoconfigEngine.servers(Data(Self.config(incoming: "i.x", outgoing: "s.x", user: "%EMAILLOCALPART%").utf8),
                                             address: "anna@beispiel.de")
        XCTAssertEqual(local?.username, "anna")
        XCTAssertEqual(local?.values[ConnectionField.username], "anna")
        XCTAssertNil(AutoconfigEngine.servers(Data("<clientConfig/>".utf8), address: "a@b.de"))
        XCTAssertNil(AutoconfigEngine.servers(Data("kein xml".utf8), address: "a@b.de"))
    }

    func testDNSRecordsDecodeMailExchangerAndService() {
        let mx = DNSRecordEngine.mailExchanger(Data([0, 10] + Self.name("MX01.Kundenserver.de")))
        XCTAssertEqual(mx?.preference, 10)
        XCTAssertEqual(mx?.host, "mx01.kundenserver.de")
        let srv = DNSRecordEngine.service(Data([0, 0, 0, 1, 3, 225] + Self.name("imap.fastmail.com")))
        XCTAssertEqual(srv, SRVRecord(priority: 0, weight: 1, port: 993, target: "imap.fastmail.com"))
        XCTAssertEqual(DNSRecordEngine.service(Data([0, 0, 0, 0, 0, 0, 0]))?.target, "")
        XCTAssertNil(DNSRecordEngine.mailExchanger(Data([0, 10, 5, 97])))
        XCTAssertNil(DNSRecordEngine.service(Data([0, 0, 0, 0, 0, 0, 0xC0, 12])))
    }

    func testDiscoveryDomainAndBases() {
        XCTAssertEqual(DiscoveryEngine.domain(of: "Anna@Beispiel.DE"), "beispiel.de")
        XCTAssertNil(DiscoveryEngine.domain(of: "anna@localhost"))
        XCTAssertNil(DiscoveryEngine.domain(of: "@beispiel.de"))
        XCTAssertNil(DiscoveryEngine.domain(of: "anna@bei/spiel.de"))
        XCTAssertNil(DiscoveryEngine.domain(of: "a@b@c.de"))
        XCTAssertEqual(DiscoveryEngine.bases(of: "mx01.kundenserver.de"), ["kundenserver.de"])
        XCTAssertEqual(DiscoveryEngine.bases(of: "in1-smtp.messagingengine.com"), ["messagingengine.com"])
        XCTAssertEqual(DiscoveryEngine.bases(of: "a.mail.example.co.uk"), ["mail.example.co.uk", "co.uk"])
        XCTAssertEqual(DiscoveryEngine.ownURLs(domain: "b.de", address: "a@b.de").map(\.absoluteString), [
            "https://autoconfig.b.de/mail/config-v1.1.xml?emailaddress=a@b.de",
            "https://b.de/.well-known/autoconfig/mail/config-v1.1.xml"
        ])
    }

    func testDiscoveryPrefersProviderThenSRVRecordsThenDirectoryThenMailExchanger() async {
        let own = "https://autoconfig.b.de/mail/config-v1.1.xml?emailaddress=a@b.de"
        let directory = DiscoveryEngine.directory + "b.de"
        let srv = { (port: Int, host: String) in [Data([0, 0, 0, 0, UInt8(port >> 8), UInt8(port & 255)] + Self.name(host))] }
        var fake = DiscoveryFake(documents: [own: Self.config(incoming: "own.b.de", outgoing: "own.b.de"),
                                             directory: Self.config(incoming: "db.b.de", outgoing: "db.b.de")],
                                 records: ["_imaps._tcp.b.de/33": srv(993, "srv.b.de"),
                                           "_submission._tcp.b.de/33": srv(587, "srv.b.de")])
        var found = await DiscoveryEngine.servers(for: " a@b.de ", using: fake)
        XCTAssertEqual(found?.incoming.host, "own.b.de")
        fake.documents[own] = nil
        found = await DiscoveryEngine.servers(for: "a@b.de", using: fake)
        XCTAssertEqual(found?.incoming, ServerTemplate(host: "srv.b.de", port: 993, security: .ssl))
        XCTAssertEqual(found?.outgoing, ServerTemplate(host: "srv.b.de", port: 587, security: .starttls))
        fake.records["_submission._tcp.b.de/33"] = nil
        found = await DiscoveryEngine.servers(for: "a@b.de", using: fake)
        XCTAssertEqual(found?.incoming.host, "db.b.de")
        fake.documents[directory] = nil
        fake.records["b.de/15"] = [Data([0, 20] + Self.name("mx2.other.net")), Data([0, 5] + Self.name("mx1.hoster.net"))]
        fake.documents[DiscoveryEngine.directory + "hoster.net"] = Self.config(incoming: "imap.hoster.net", outgoing: "smtp.hoster.net")
        let values = await DiscoveryEngine.choices(for: "a@b.de", using: fake).first ?? [:]
        XCTAssertEqual(values[ConnectionField.incomingHost], "imap.hoster.net")
        XCTAssertEqual(values[ConnectionField.outgoingPort], "587")
        XCTAssertEqual(values[ConnectionField.outgoingSecurity], "starttls")
        let pop = await DiscoveryEngine.choices(for: "a@b.de", using: fake).last ?? [:]
        XCTAssertEqual(pop[ConnectionField.incomingHost], "pop.x")
        XCTAssertEqual(pop[ConnectionField.incomingPort], "995")
        XCTAssertEqual(pop[ConnectionField.incomingProtocol], "pop3")
        XCTAssertEqual(pop[ConnectionField.outgoingHost], "smtp.hoster.net")
        fake.records["b.de/15"] = nil
        let none = await DiscoveryEngine.choices(for: "a@b.de", using: fake)
        XCTAssertTrue(none.isEmpty)
    }
}

extension MailTests {
    @MainActor
    func testHeldSendCanBeRecalledAndGoesOutAfterTheHold() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60), sendHold: .milliseconds(300))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.to = "x@y.de"; $0.subject = "s" }
        await state.send(id)
        XCTAssertEqual(state.draft(id)?.state, .sending)
        XCTAssertEqual(state.toast?.kind, .outboxSent)
        XCTAssertEqual(state.toast?.undoable, true)
        XCTAssertFalse(state.stackOrder.contains(.draft(id)))
        XCTAssertEqual(rig.outbox.keptDrafts.count, 1)
        await state.undoToast()
        XCTAssertEqual(state.draft(id)?.state, .edited)
        XCTAssertTrue(state.stackOrder.contains(.draft(id)))
        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(state.draft(id)?.state, .edited)
        await state.send(id)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertEqual(state.draft(id)?.state, .sent)
        XCTAssertTrue(rig.outbox.keptDrafts.isEmpty)
    }

    @MainActor
    func testQuittingSendsAHeldMailAtOnce() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState(),
                               autosavePause: .seconds(60), autosaveInterval: .seconds(60), sendHold: .seconds(60))
        await state.start()
        let id = try XCTUnwrap(state.compose())
        state.edit(id) { $0.to = "x@y.de"; $0.subject = "s" }
        await state.send(id)
        XCTAssertEqual(state.draft(id)?.state, .sending)
        await state.flushDrafts(within: .seconds(5))
        XCTAssertEqual(state.draft(id)?.state, .sent)
        await state.undoToast()
        XCTAssertEqual(state.draft(id)?.state, .sent)
    }
}

private final class POPServer: @unchecked Sendable {
    let mails = Locked<[(uid: String, raw: String)]>([])
    let deleted = Locked<[String]>([])
    let wire = Locked<[String]>([])

    func stream(offersSTLS: Bool = false) -> ScriptedStream {
        let pending = Locked<[Int]>([])
        return ScriptedStream(greeting: ["+OK ready"]) { [self] line in
            wire.with { $0.append(line) }
            let words = line.split(separator: " ").map(String.init)
            let current = mails.with { $0 }
            switch words.first?.uppercased() ?? "" {
            case "CAPA": return ["+OK", "TOP", "UIDL", "USER", "SASL PLAIN"] + (offersSTLS ? ["STLS"] : []) + ["."]
            case "STLS": return ["+OK begin TLS"]
            case "AUTH": return words.last == Data("\0u@x.de\0pw".utf8).base64EncodedString() ? ["+OK in"] : ["-ERR denied"]
            case "UIDL": return ["+OK"] + current.enumerated().map { "\($0.offset + 1) \($0.element.uid)" } + ["."]
            case "RETR":
                guard let number = Int(words[1]), number <= current.count else { return ["-ERR no"] }
                let lines = current[number - 1].raw.components(separatedBy: "\r\n").map { $0.hasPrefix(".") ? "." + $0 : $0 }
                return ["+OK"] + lines + ["."]
            case "DELE":
                if let number = Int(words[1]) { pending.with { $0.append(number) } }
                return ["+OK"]
            case "QUIT":
                let numbers = pending.with { $0 }
                let gone = numbers.compactMap { current.indices.contains($0 - 1) ? current[$0 - 1].uid : nil }
                deleted.with { $0 += gone }
                mails.with { list in list.removeAll { gone.contains($0.uid) } }
                return ["+OK bye"]
            default: return ["-ERR unknown"]
            }
        }
    }
}

extension MailTests {
    static let outlookShaped = [
        "From: =?UTF-8?Q?J=C3=BCrgen_M=C3=BCller?= <j@x.de>", "To: Anna <a@y.de>, b@y.de",
        "Subject: =?UTF-8?B?UHLDvGZ1bmc=?=", "Date: Thu, 29 Oct 2026 10:00:00 +0100", "Message-ID: <m1@x.de>",
        "MIME-Version: 1.0", "Content-Type: multipart/mixed; boundary=\"outer\"", "",
        "preamble", "--outer", "Content-Type: multipart/related; boundary=rel", "",
        "--rel", "Content-Type: multipart/alternative; boundary=\"alt\"", "",
        "--alt", "Content-Type: text/plain; charset=utf-8", "Content-Transfer-Encoding: quoted-printable", "",
        "Gr=C3=BC=C3=9Fe aus K=C3=B6ln", "--alt", "Content-Type: text/html; charset=utf-8", "Content-Transfer-Encoding: base64", "",
        Data("<p>Grüße <img src=\"cid:pic1\"></p>".utf8).base64EncodedString(), "--alt--", "",
        "--rel", "Content-Type: image/png", "Content-ID: <pic1>", "Content-Transfer-Encoding: base64", "Content-Disposition: inline", "",
        Data([137, 80, 78, 71]).base64EncodedString(), "--rel--",
        "--outer", "Content-Type: application/pdf; name=\"x.pdf\"", "Content-Transfer-Encoding: base64",
        "Content-Disposition: attachment; filename*=UTF-8''R%C3%A9sum%C3%A9.pdf", "",
        Data("PDFDATA".utf8).base64EncodedString(), "--outer--", ""
    ].joined(separator: "\r\n")

    func testRawMessageReadsAForeignMultipartLikeIMAP() {
        let parsed = RawMessageEngine.parse(Data(Self.outlookShaped.utf8))
        let body = RawMessageEngine.body(parsed)
        XCTAssertEqual(body.text, "Grüße aus Köln")
        XCTAssertEqual(body.html, "<p>Grüße <img src=\"cid:pic1\"></p>")
        XCTAssertEqual(body.inlineImages["pic1"], "data:image/png;base64," + Data([137, 80, 78, 71]).base64EncodedString())
        XCTAssertEqual(body.attachments, [AttachmentInfo(id: "2", filename: "Résumé.pdf", mimeType: "application/pdf",
                                                         sizeBytes: Data("PDFDATA".utf8).base64EncodedString().utf8.count)])
        XCTAssertEqual(parsed.data(parsed.root.attachments[0]), Data("PDFDATA".utf8))
        XCTAssertEqual(parsed.root.leaves.map(\.section), ["1.1.1", "1.1.2", "1.2", "2"])
        let summary = RawMessageEngine.summary(parsed, id: "u1", folder: "INBOX", flags: [], received: nil)
        XCTAssertEqual(summary.subject, "Prüfung")
        XCTAssertEqual(summary.from, "Jürgen Müller")
        XCTAssertEqual(summary.toRaw, "Anna <a@y.de>, b@y.de")
        XCTAssertEqual(summary.snippet, "Grüße aus Köln")
        XCTAssertEqual(summary.attachmentCount, 1)
        XCTAssertEqual(summary.receivedAt, DateEngine.parseMessageDate("Thu, 29 Oct 2026 10:00:00 +0100"))
        let plain = RawMessageEngine.parse(Data("Subject: s\n\nnur Text\n".utf8))
        XCTAssertEqual(plain.root.section, "1")
        XCTAssertEqual(RawMessageEngine.body(plain).text, "nur Text\n")
    }

    func testInlineFilesCountAsAttachmentsAndHTMLOnlyMailHasAPreview() throws {
        let apple = [
            "Subject: Plan", "Content-Type: multipart/mixed; boundary=m", "",
            "--m", "Content-Type: text/plain; charset=utf-8", "", "Anbei der Plan",
            "--m", "Content-Type: application/pdf; name=plan.pdf", "Content-Disposition: inline; filename=plan.pdf",
            "Content-Transfer-Encoding: base64", "", Data("PDF".utf8).base64EncodedString(),
            "--m", "Content-Type: image/jpeg; name=foto.jpg", "Content-ID: <foto1>", "Content-Disposition: inline; filename=foto.jpg",
            "Content-Transfer-Encoding: base64", "", Data([1, 2]).base64EncodedString(), "--m--", ""
        ].joined(separator: "\r\n")
        let parsed = RawMessageEngine.parse(Data(apple.utf8))
        XCTAssertEqual(RawMessageEngine.body(parsed).text, "Anbei der Plan")
        XCTAssertEqual(RawMessageEngine.body(parsed).attachments.map(\.filename), ["plan.pdf", "foto.jpg"])
        XCTAssertEqual(RawMessageEngine.summary(parsed, id: "u", folder: "INBOX", flags: [], received: nil).attachmentCount, 2)
        let unreferenced = Self.outlookShaped.replacingOccurrences(of: Data("<p>Grüße <img src=\"cid:pic1\"></p>".utf8).base64EncodedString(),
                                                                   with: Data("<p>Grüße</p>".utf8).base64EncodedString())
        let shown = RawMessageEngine.parse(Data(unreferenced.utf8))
        XCTAssertEqual(RawMessageEngine.body(shown).attachments.map(\.mimeType), ["image/png", "application/pdf"])
        let structure = try XCTUnwrap(try fetched(
            "* 3 FETCH (BODYSTRUCTURE ((\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 20 1 NIL NIL NIL)(\"APPLICATION\" \"PDF\" (\"NAME\" \"a.pdf\") NIL NIL \"BASE64\" 100 NIL (\"INLINE\" (\"FILENAME\" \"a.pdf\")) NIL) \"MIXED\" (\"BOUNDARY\" \"x\") NIL NIL))").structure)
        XCTAssertEqual(structure.attachments.map(\.filename), ["a.pdf"])
        XCTAssertEqual(structure.firstPlainText?.section, "1")
        let letter = RawMessageEngine.parse(Data("Subject: News\r\nContent-Type: text/html; charset=utf-8\r\n\r\n<style>p{}</style><p>Neue Ausgabe</p>".utf8))
        XCTAssertEqual(RawMessageEngine.summary(letter, id: "n", folder: "INBOX", flags: [], received: nil).snippet, "Neue Ausgabe")
        XCTAssertTrue(RawMessageEngine.body(letter).attachments.isEmpty)
    }

    func testATextPartOfTheBodyKindStaysTheBodyAndOnlyASecondNamedOneIsAnAttachment() throws {
        let lone = RawMessageEngine.parse(Data([
            "Subject: s", "Content-Type: text/plain; charset=utf-8", "Content-Disposition: inline; filename=note.txt", "", "Inhalt"
        ].joined(separator: "\r\n").utf8))
        XCTAssertEqual(RawMessageEngine.body(lone).text, "Inhalt")
        XCTAssertTrue(RawMessageEngine.body(lone).attachments.isEmpty)
        XCTAssertTrue(lone.root.attachments.isEmpty)
        let loneHTML = RawMessageEngine.parse(Data([
            "Subject: s", "Content-Type: text/html; charset=utf-8", "Content-Disposition: inline; filename=page.html", "", "<p>x</p>"
        ].joined(separator: "\r\n").utf8))
        XCTAssertEqual(RawMessageEngine.body(loneHTML).html, "<p>x</p>")
        XCTAssertTrue(RawMessageEngine.body(loneHTML).attachments.isEmpty)
        let second = RawMessageEngine.parse(Data([
            "Subject: s", "Content-Type: multipart/mixed; boundary=m", "",
            "--m", "Content-Type: text/plain; charset=utf-8", "", "Haupttext",
            "--m", "Content-Type: text/plain; charset=utf-8", "Content-Disposition: inline; filename=notes.txt", "", "Notizen",
            "--m", "Content-Type: text/plain; charset=utf-8", "", "Weiterer Teil ohne Namen",
            "--m", "Content-Type: text/plain; charset=utf-8", "Content-Disposition: attachment", "", "Anhang",
            "--m--", ""
        ].joined(separator: "\r\n").utf8))
        XCTAssertEqual(RawMessageEngine.body(second).text, "Haupttext")
        XCTAssertEqual(RawMessageEngine.body(second).attachments.map(\.id), ["2", "4"])
        let named = try fetched(
            "* 3 FETCH (BODYSTRUCTURE ((\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 20 1 NIL (\"INLINE\" (\"FILENAME\" \"a.txt\")) NIL)(\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 20 1 NIL (\"INLINE\" (\"FILENAME\" \"b.txt\")) NIL) \"MIXED\" (\"BOUNDARY\" \"x\") NIL NIL))")
        XCTAssertEqual(named.structure?.firstPlainText?.section, "1")
        XCTAssertEqual(named.structure?.attachments.map(\.filename), ["b.txt"])
    }

    func testATextPartWithOnlyANameIsAnAttachmentAndNeverTheBody() throws {
        let log = RawMessageEngine.parse(Data([
            "Subject: s", "Content-Type: text/plain; name=\"log.txt\"; charset=utf-8", "", "Zeile"
        ].joined(separator: "\r\n").utf8))
        XCTAssertNil(log.root.firstPlainText)
        XCTAssertNil(RawMessageEngine.body(log).text)
        XCTAssertEqual(RawMessageEngine.body(log).attachments.map(\.filename), ["log.txt"])
        let beside = RawMessageEngine.parse(Data([
            "Subject: s", "Content-Type: multipart/mixed; boundary=m", "",
            "--m", "Content-Type: text/html; charset=utf-8", "", "<p>Hallo</p>",
            "--m", "Content-Type: text/plain; name=\"log.txt\"; charset=utf-8", "", "Zeile",
            "--m", "Content-Type: text/plain; charset=utf-8", "Content-Disposition: inline; filename=notes.txt", "", "Notizen",
            "--m--", ""
        ].joined(separator: "\r\n").utf8))
        XCTAssertNil(beside.root.firstPlainText)
        XCTAssertEqual(beside.root.firstHTML?.section, "1")
        XCTAssertEqual(RawMessageEngine.body(beside).attachments.map(\.filename), ["log.txt", "notes.txt"])
        let imap = try XCTUnwrap(try fetched(
            "* 3 FETCH (BODYSTRUCTURE ((\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\" \"NAME\" \"log.txt\") NIL NIL \"7BIT\" 20 1 NIL NIL NIL)(\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 20 1 NIL NIL NIL) \"MIXED\" (\"BOUNDARY\" \"x\") NIL NIL))").structure)
        XCTAssertEqual(imap.firstPlainText?.section, "2")
        XCTAssertEqual(imap.attachments.map(\.filename), ["log.txt"])
        let alone = try XCTUnwrap(try fetched(
            "* 3 FETCH (BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"utf-8\" \"NAME\" \"log.txt\") NIL NIL \"7BIT\" 20 1))").structure)
        XCTAssertNil(alone.firstPlainText)
        XCTAssertEqual(alone.attachments.map(\.filename), ["log.txt"])
    }

    func testAnInlineImageIsHiddenOnlyWhenItWasActuallyEmbeddedAndTheHTMLDrawsIt() throws {
        let structure = try XCTUnwrap(try fetched(
            "* 3 FETCH (BODYSTRUCTURE ((\"TEXT\" \"HTML\" (\"CHARSET\" \"utf-8\") NIL NIL \"7BIT\" 20 1 NIL NIL NIL)(\"IMAGE\" \"PNG\" NIL \"<Pic1>\" NIL \"BASE64\" 100 NIL (\"INLINE\" (\"FILENAME\" \"p.png\")) NIL) \"RELATED\" (\"BOUNDARY\" \"x\") NIL NIL))").structure)
        let html = "<img src=\"cid:pic1\">"
        XCTAssertEqual(structure.inlineContentIDs, ["pic1"])
        XCTAssertTrue(structure.attachments(html: html, embedded: ["pic1"]).isEmpty)
        XCTAssertEqual(structure.attachments(html: html, embedded: []).map(\.filename), ["p.png"])
        XCTAssertEqual(structure.attachments(html: html, embedded: ["other"]).map(\.filename), ["p.png"])
        XCTAssertEqual(structure.attachments(html: "<p>x</p>", embedded: ["pic1"]).map(\.filename), ["p.png"])
        XCTAssertTrue(structure.attachments.isEmpty)
    }

    func testInlineReferencesReadTheSchemeAndTheAddressInAnyCase() {
        let found = HTMLEngine.inlineReferences("<IMG SRC=\"CID:Pic1\"><img src='Cid:<A@X.de>'><img src=cid:%3CB%40x.de%3E><p>cidx</p>")
        XCTAssertEqual(found, ["pic1", "a@x.de", "b@x.de"])
        XCTAssertTrue(HTMLEngine.inlineReferences("<p>kein Bild</p>").isEmpty)
    }

    func testDraftPreviewDropsTheOwnSignatureWhereverItSitsAndKeepsTheRestOtherwise() {
        let signature = "-- \nGruß\nAnna Berger"
        XCTAssertEqual(PreviewEngine.draft("Hallo Welt Gruß Anna Berger", signature: signature), "Hallo Welt")
        XCTAssertEqual(PreviewEngine.draft("Hallo Gruß Anna Berger Danke", signature: signature), "Hallo Danke")
        XCTAssertEqual(PreviewEngine.draft("Hallo Gruß Anna", signature: signature), "Hallo")
        XCTAssertEqual(PreviewEngine.draft("Gruß", signature: signature), "")
        XCTAssertEqual(PreviewEngine.draft("Hallo Welt Gruß", signature: signature), "Hallo Welt Gruß")
        XCTAssertEqual(PreviewEngine.draft("Hallo Welt", signature: signature), "Hallo Welt")
        XCTAssertEqual(PreviewEngine.draft("Hallo Welt Gruß Anna Berger", signature: nil), "Hallo Welt Gruß Anna Berger")
        XCTAssertEqual(PreviewEngine.draft("Hallo Welt", signature: "-- "), "Hallo Welt")
        XCTAssertEqual(PreviewEngine.draft("", signature: signature), "")
    }

    @MainActor
    func testADraftOnlyToCcOrBccIsNamedAfterItsFirstAddresseeInsteadOfNewMessage() async throws {
        let rig = try Rig()
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        XCTAssertEqual(state.draft(id)?.addressees.isEmpty, true)
        state.edit(id) { $0.bcc = "b@x.de" }
        XCTAssertEqual(state.draft(id)?.addressees.map(\.address), ["b@x.de"])
        state.edit(id) { $0.cc = "Cora <c@x.de>, d@x.de" }
        XCTAssertEqual(state.draft(id)?.addressees.map(\.address), ["c@x.de", "d@x.de"])
        state.edit(id) { $0.to = "a@x.de" }
        XCTAssertEqual(state.draft(id)?.addressees.map(\.address), ["a@x.de"])
        let ccOnly = MessageSummary(id: "m", subject: "s", from: "Me", ccRaw: "Cora <c@x.de>")
        XCTAssertEqual(InboxState.recipients(InboxState.addressed(ccOnly, card: nil)), "Cora")
        let none = MessageSummary(id: "n", subject: "s", from: "Me")
        XCTAssertEqual(InboxState.addressed(none, card: nil), "")
        state.edit(id) { $0.to = nil; $0.cc = nil }
        XCTAssertEqual(InboxState.recipients(InboxState.addressed(none, card: state.draft(id))), "b@x.de")
        XCTAssertEqual(InboxState.addressed(ccOnly, card: state.draft(id)), "Cora <c@x.de>")
    }

    func testStructuralPartsOfSignedEncryptedAndReportMailsAreNoAttachments() {
        let signed = RawMessageEngine.parse(Data([
            "Subject: s", "Content-Type: multipart/signed; protocol=\"application/pgp-signature\"; boundary=m", "",
            "--m", "Content-Type: text/plain; charset=utf-8", "", "Text",
            "--m", "Content-Type: application/pgp-signature", "", "SIG", "--m--", ""
        ].joined(separator: "\r\n").utf8))
        XCTAssertTrue(signed.root.attachments.isEmpty)
        let encrypted = RawMessageEngine.parse(Data([
            "Subject: s", "Content-Type: multipart/encrypted; protocol=\"application/pgp-encrypted\"; boundary=m", "",
            "--m", "Content-Type: application/pgp-encrypted", "", "Version: 1",
            "--m", "Content-Type: application/octet-stream; name=encrypted.asc", "", "DATA", "--m--", ""
        ].joined(separator: "\r\n").utf8))
        XCTAssertEqual(encrypted.root.attachments.map(\.filename), ["encrypted.asc"])
        let report = RawMessageEngine.parse(Data([
            "Subject: s", "Content-Type: multipart/report; report-type=delivery-status; boundary=m", "",
            "--m", "Content-Type: text/plain; charset=utf-8", "", "Zustellung gescheitert",
            "--m", "Content-Type: message/delivery-status", "", "Final-Recipient: rfc822; x@y.de",
            "--m", "Content-Type: text/rfc822-headers", "", "Subject: s", "--m--", ""
        ].joined(separator: "\r\n").utf8))
        XCTAssertTrue(report.root.attachments.isEmpty)
        XCTAssertEqual(RawMessageEngine.summary(report, id: "r", folder: "INBOX", flags: [], received: nil).attachmentCount, 0)
    }

    func testListAndOpenedMessageCountInlineImagesTheSameWayAndReadWrittenVariantsOfTheContentID() {
        func mail(_ html: String) -> RawMessageEngine.Parsed {
            RawMessageEngine.parse(Data([
                "Subject: s", "Content-Type: multipart/related; boundary=r", "",
                "--r", "Content-Type: text/html; charset=utf-8", "", html,
                "--r", "Content-Type: image/png", "Content-ID: <pic@1>", "Content-Disposition: inline", "Content-Transfer-Encoding: base64", "",
                Data([1]).base64EncodedString(),
                "--r", "Content-Type: image/png", "Content-ID: <two@x>", "Content-Disposition: inline", "Content-Transfer-Encoding: base64", "",
                Data([2]).base64EncodedString(), "--r--", ""
            ].joined(separator: "\r\n").utf8))
        }
        let written = mail("<img src=\"cid:pic%401\"><img src='CID:<two@x>'>")
        XCTAssertEqual(written.root.attachments.count, 0)
        XCTAssertEqual(RawMessageEngine.body(written).attachments.count, 0)
        XCTAssertEqual(RawMessageEngine.summary(written, id: "w", folder: "INBOX", flags: [], received: nil).attachmentCount, 0)
        let encodedBrackets = mail("<img src=\"cid:%3Ctwo%40x%3E\"><img src=cid:pic@1>")
        XCTAssertEqual(RawMessageEngine.body(encodedBrackets).attachments.count, 0)
        let missing = mail("<p>kein Bild</p>")
        XCTAssertEqual(missing.root.attachments.count, 0)
        XCTAssertEqual(RawMessageEngine.body(missing).attachments.count, 2)
        let partial = mail("<img src=\"cid:pic%401\">")
        XCTAssertEqual(RawMessageEngine.body(partial).attachments.map(\.id), ["3"])
    }

    func testRawMessageReadsBackWhatALFASends() throws {
        let account = Account(id: "a", displayName: "Anna", address: "a@x.de",
                              incoming: ServerSettings(host: "h"), outgoing: ServerSettings(host: "h"))
        let draft = Draft(to: "b@y.de", subject: "Grüße", body: "Hallo Welt", attachments: [
            Attachment(filename: "plan.pdf", mimeType: "application/pdf", data: Data(repeating: 7, count: 3_000))
        ], bodyHTML: "<p>Hallo <b>Welt</b></p>")
        let built = try MessageEngine.build(draft, account: account, messageID: "id1")
        let parsed = RawMessageEngine.parse(built.data)
        let body = RawMessageEngine.body(parsed)
        XCTAssertEqual(body.text?.trimmingCharacters(in: .whitespacesAndNewlines), "Hallo Welt")
        XCTAssertEqual(body.html?.trimmingCharacters(in: .whitespacesAndNewlines), "<p>Hallo <b>Welt</b></p>")
        XCTAssertEqual(body.attachments.map(\.filename), ["plan.pdf"])
        XCTAssertEqual(parsed.data(parsed.root.attachments[0]), Data(repeating: 7, count: 3_000))
        XCTAssertEqual(RawMessageEngine.summary(parsed, id: "x", folder: "f", flags: [], received: nil).subject, "Grüße")
    }

    func testPOPSessionLogsInListsAndUndoesDotStuffing() async throws {
        let server = POPServer()
        server.mails.with { $0 = [("a1", "Subject: eins\r\n\r\nx"), ("b2", "Subject: zwei\r\n\r\n.punkt\r\n..zwei")] }
        let settings = ServerSettings(host: "pop", port: 995, security: .ssl, username: "u@x.de")
        let session = try await POPSession.open(settings: settings, opener: { _, _, _ in server.stream() })
        try await session.authenticate(user: "u@x.de", secret: "pw")
        let listed = try await session.identifiers()
        XCTAssertEqual(listed.map(\.uid), ["a1", "b2"])
        let awaited1 = try await session.retrieve(2)
        XCTAssertEqual(String(decoding: awaited1, as: UTF8.self), "Subject: zwei\r\n\r\n.punkt\r\n..zwei\r\n")
        await session.quit()
        let denied = try await POPSession.open(settings: settings, opener: { _, _, _ in server.stream() })
        do {
            try await denied.authenticate(user: "u@x.de", secret: "falsch")
            XCTFail("accepted")
        } catch MailFailure.authenticationRejected {}
        let explicit = ServerSettings(host: "pop", port: 110, security: .starttls, username: "u@x.de")
        do {
            _ = try await POPSession.open(settings: explicit, opener: { _, _, _ in server.stream() })
            XCTFail("opened without STLS")
        } catch MailFailure.tlsUnavailable {}
        _ = try await POPSession.open(settings: explicit, opener: { _, _, _ in server.stream(offersSTLS: true) })
    }

    func testPOPMailboxKeepsMailLocallyAndRemovesServerCopiesByTheSetting() async throws {
        let server = POPServer()
        server.mails.with { $0 = [("a1", Self.outlookShaped), ("b2", "Subject: zwei\r\nFrom: b@y.de\r\n\r\nTag")] }
        let database = try SQLiteStore.inMemory()
        let clock = Locked(Date(timeIntervalSince1970: 1_800_000_000))
        let account = Account(id: "p", displayName: "P", address: "u@x.de",
                              incoming: ServerSettings(host: "pop", port: 995, security: .ssl, username: "u@x.de"),
                              outgoing: ServerSettings(host: "smtp", port: 465, security: .ssl, username: "u@x.de"),
                              incomingProtocol: .pop3)
        let smtp = ScriptedStream(greeting: ["220 ready"]) { line in
            if line.hasPrefix("EHLO") { return ["250-h", "250 AUTH PLAIN"] }
            if line.hasPrefix("AUTH") { return ["235 ok"] }
            if line.hasPrefix("MAIL") || line.hasPrefix("RCPT") { return ["250 ok"] }
            if line == "DATA" { return ["354 go"] }
            if line == "." { return ["250 queued"] }
            if line == "QUIT" { return ["221 bye"] }
            return []
        }
        let pop = POPSMTPClient(account: account, database: database, password: { "pw" },
                                opener: { host, _, _ in host == "smtp" ? smtp : server.stream() }, now: { clock.with { $0 } })
        XCTAssertTrue(pop.inboxOnly)
        let listing = try await pop.listIDs(folderID: POPSMTPClient.inboxID, since: nil, limit: nil)
        XCTAssertEqual(listing.ids, ["b2", "a1"])
        let summaries = try await pop.fetchSummaries(folderID: POPSMTPClient.inboxID, ids: listing.ids)
        XCTAssertEqual(summaries.map(\.subject), ["zwei", "Prüfung"])
        let awaited2 = try await pop.fetchBody(messageID: "a1").text
        XCTAssertEqual(awaited2, "Grüße aus Köln")
        let awaited3 = try await pop.fetchAttachment(messageID: "a1", attachmentID: "2")
        XCTAssertEqual(awaited3, Data("PDFDATA".utf8))
        try await pop.setFlags(messageID: "b2", add: [.seen, .flagged], remove: [])
        let awaited4 = try await pop.refreshFlags(folderID: POPSMTPClient.inboxID, known: ["a1", "b2"], cursor: nil).flags
        XCTAssertEqual(awaited4,
                       ["a1": [], "b2": [.seen, .flagged]])
        try await pop.expire(.keep, now: clock.with { $0 })
        try await pop.trash(messageID: "a1", folderID: nil)
        let awaited5 = try await pop.listIDs(folderID: POPSMTPClient.inboxID, since: nil, limit: nil).ids
        XCTAssertEqual(awaited5, ["b2"])
        let inTrash = try await pop.listIDs(folderID: POPSMTPClient.trashID, since: nil, limit: nil).ids
        XCTAssertEqual(inTrash, ["a1"])
        try await pop.move(messageID: "a1", toFolderID: POPSMTPClient.inboxID)
        let restored = try await pop.listIDs(folderID: POPSMTPClient.inboxID, since: nil, limit: nil).ids
        XCTAssertEqual(restored, ["b2", "a1"])
        try await pop.trash(messageID: "a1", folderID: nil)
        XCTAssertTrue(server.deleted.with { $0 }.isEmpty)
        try await pop.expire(.deleted, now: clock.with { $0 })
        XCTAssertEqual(server.deleted.with { $0 }, ["a1"])
        try await pop.expire(.day, now: clock.with { $0 }.addingTimeInterval(3_600))
        XCTAssertEqual(server.deleted.with { $0 }, ["a1"])
        try await pop.expire(.day, now: clock.with { $0 }.addingTimeInterval(90_000))
        XCTAssertEqual(server.deleted.with { $0 }, ["a1", "b2"])
        let awaited6 = try await pop.fetchBody(messageID: "b2").text
        XCTAssertEqual(awaited6, "Tag\r\n")
        let awaited7 = try await pop.listIDs(folderID: POPSMTPClient.inboxID, since: nil, limit: nil).ids
        XCTAssertEqual(awaited7, ["b2"])
        try await pop.send(Draft(to: "c@z.de", subject: "Antwort", body: "ok", messageID: "s1"))
        let awaited8 = try await pop.listIDs(folderID: POPSMTPClient.sentID, since: nil, limit: nil).ids
        XCTAssertEqual(awaited8, ["sent:s1"])
        let wasSent = try await pop.wasSent(messageID: "s1", in: nil)
        XCTAssertTrue(wasSent)
        let saved = try await pop.saveDraft(Draft(to: "d@z.de", subject: "Entwurf", body: "halb", receiptTo: "u@x.de"),
                                            replacing: nil, into: nil)
        let again = try await pop.saveDraft(Draft(to: "d@z.de", subject: "Entwurf 2", body: "fast"), replacing: saved.id, into: nil)
        let awaited9 = try await pop.listIDs(folderID: POPSMTPClient.draftsID, since: nil, limit: nil).ids
        XCTAssertEqual(awaited9, [again.id])
        let stored = try await pop.fetchDraft(messageID: again.id)
        XCTAssertEqual(stored.draft.subject, "Entwurf 2")
        XCTAssertEqual(stored.draft.to, "d@z.de")
        XCTAssertEqual(stored.draft.body.trimmingCharacters(in: .whitespacesAndNewlines), "fast")
        try await pop.deleteDraft(id: again.id)
        let awaited10 = try await pop.listIDs(folderID: POPSMTPClient.draftsID, since: nil, limit: nil).ids.isEmpty
        XCTAssertTrue(awaited10)
        try await pop.trash(messageID: "a1", folderID: nil)
        let emptied = try await pop.listIDs(folderID: POPSMTPClient.trashID, since: nil, limit: nil).ids
        XCTAssertTrue(emptied.isEmpty)
        do {
            try await pop.archive(messageID: "b2", folderID: nil)
            XCTFail("archived")
        } catch MailFailure.unsupportedCapability {}
    }

    @MainActor
    func testPOPMailboxSyncsThroughTheStoreAndHidesFolderActions() async throws {
        let rig = try Rig()
        let server = POPServer()
        server.mails.with { $0 = [("a1", "Subject: eins\r\nFrom: Anna <a@y.de>\r\nDate: Thu, 29 Oct 2026 10:00:00 +0100\r\n\r\nHallo")] }
        let account = Account(id: "a", displayName: "A", address: "u@x.de",
                              incoming: ServerSettings(host: "pop", port: 995, security: .ssl, username: "u@x.de"),
                              outgoing: ServerSettings(host: "smtp", port: 465, security: .ssl, username: "u@x.de"),
                              incomingProtocol: .pop3)
        rig.access.transport = POPSMTPClient(account: account, database: rig.database, password: { "pw" },
                                             opener: { _, _, _ in server.stream() })
        try await rig.mailbox.refreshFolders("a")
        XCTAssertEqual(rig.mailbox.folders("a").map(\.role).filter { $0 != .starred }, [.inbox, .drafts, .sent, .trash])
        try await rig.mailbox.refresh("a", folder: POPSMTPClient.inboxID)
        let cached = await rig.mailbox.cached("a", folder: POPSMTPClient.inboxID)
        XCTAssertEqual(cached.map(\.subject), ["eins"])
        XCTAssertTrue(rig.mailbox.inboxOnly("a"))
        XCTAssertEqual(MenuEngine.row(unread: true, draft: false, folders: false),
                       [.item(.reply), .item(.forward), .separator, .item(.markRead), .separator, .item(.trash)])
        XCTAssertFalse(MenuEngine.readingMore(starred: false, original: true, folders: false).contains(.item(.spam)))
        XCTAssertEqual(MenuEngine.readingMore(starred: false, original: false, folders: false), [.item(.star), .item(.markUnread)])
        XCTAssertEqual(MenuEngine.readingMore(starred: false, original: false, unread: true, folders: false), [.item(.star), .item(.markRead)])
        XCTAssertEqual(MenuEngine.readingMore(starred: true, original: true, folders: true, spam: false),
                       [.item(.unstar), .item(.markUnread), .item(.move), .separator, .item(.original)])
        let commands = CommandEngine.commands(front: .message(hasCopy: false), stackCount: 1, fanned: false, hasFiles: false,
                                              confirmDiscard: false, canFold: false, sendLabelled: false, folders: false)
        XCTAssertFalse(commands.main.contains { $0.action == .archive })
    }

    func testAccountKindTravelsFromDiscoveryToTheAccount() throws {
        let pop = """
            <clientConfig><emailProvider id="x"><incomingServer type="pop3"><hostname>pop.x.de</hostname><port>995</port>
            <socketType>SSL</socketType><username>%EMAILADDRESS%</username><authentication>password-cleartext</authentication>
            </incomingServer><outgoingServer type="smtp"><hostname>smtp.x.de</hostname><port>465</port><socketType>SSL</socketType>
            <authentication>password-cleartext</authentication></outgoingServer></emailProvider></clientConfig>
            """
        var values = try XCTUnwrap(AutoconfigEngine.servers(Data(pop.utf8), address: "a@x.de")).values
        XCTAssertEqual(values[ConnectionField.incomingProtocol], "pop3")
        values[ConnectionField.address] = "a@x.de"
        values[ConnectionField.password] = "pw"
        values[ConnectionField.incomingPort] = nil
        let connection = try ConnectionEngine(values: values)
        XCTAssertEqual(connection.account(id: "i").incomingProtocol, .pop3)
        XCTAssertEqual(connection.incoming.port, 995)
        XCTAssertEqual(connection.values[ConnectionField.incomingProtocol], "pop3")
        values[ConnectionField.incomingProtocol] = "imap"
        XCTAssertNil(try ConnectionEngine(values: values).values[ConnectionField.incomingProtocol])
        values[ConnectionField.incomingProtocol] = "exchange"
        XCTAssertThrowsError(try ConnectionEngine(values: values))
        XCTAssertEqual(ProviderPresets.choices(for: ConnectionField.incomingProtocol), ["imap", "pop3"])
        XCTAssertEqual(ProviderPresets.choiceKey(field: ConnectionField.incomingProtocol, option: "pop3"), "settings.protocol.pop3")
    }
}

@MainActor
private final class Setting {
    var value = MailStoreSettings(attachments: true)
    var cap: Int?
}

final class AttachmentFileTests: XCTestCase {
    private static let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    private func directory() throws -> URL {
        let base = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? NSTemporaryDirectory(), isDirectory: true)
        let made = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: made, withIntermediateDirectories: true)
        return made
    }

    private func file(_ message: String, size: Int, day: Int?, stored: Double = 0) -> StoredAttachment {
        StoredAttachment(inlet: "a", message: message, attachment: "1", path: message, size: size,
                         receivedAt: day.map { Self.epoch.addingTimeInterval(Double($0) * 86_400) },
                         storedAt: Self.epoch.addingTimeInterval(stored))
    }

    func testEvictionTakesTheOldestMailFirstUntilTheCapHolds() {
        let files = [file("new", size: 4, day: 3), file("old", size: 4, day: 1), file("mid", size: 4, day: 2)]
        XCTAssertEqual(AttachmentFileEngine.evictions(files, limit: 12), [])
        XCTAssertEqual(AttachmentFileEngine.evictions(files, limit: 8).map(\.message), ["old"])
        XCTAssertEqual(AttachmentFileEngine.evictions(files, limit: 7).map(\.message), ["old", "mid"])
        XCTAssertEqual(AttachmentFileEngine.evictions(files, limit: 0).map(\.message), ["old", "mid", "new"])
        XCTAssertEqual(AttachmentFileEngine.evictions(files, limit: nil), [])
        XCTAssertEqual(AttachmentFileEngine.total(files), 12)
    }

    func testEvictionOrdersEqualDatesByStoreTimeAndFallsBackToStoreTimeWithoutDate() {
        let files = [file("b", size: 5, day: 1, stored: 20), file("a", size: 5, day: 1, stored: 10), file("c", size: 5, day: nil, stored: 3)]
        XCTAssertEqual(AttachmentFileEngine.oldestFirst(files).map(\.message), ["c", "a", "b"])
        XCTAssertEqual(AttachmentFileEngine.evictions(files, limit: 10).map(\.message), ["c"])
    }

    func testAnIncomingFileIsRefusedWhenItWouldBeTheFirstToGo() {
        let files = [file("mid", size: 4, day: 2), file("new", size: 4, day: 3)]
        let older = file("old", size: 4, day: 1)
        let newer = file("newest", size: 4, day: 4)
        let huge = file("huge", size: 20, day: 9)
        XCTAssertFalse(AttachmentFileEngine.admits(older, among: files, limit: 10))
        XCTAssertTrue(AttachmentFileEngine.admits(newer, among: files, limit: 10))
        XCTAssertFalse(AttachmentFileEngine.admits(huge, among: files, limit: 10))
        XCTAssertTrue(AttachmentFileEngine.admits(older, among: files, limit: nil))
        XCTAssertTrue(AttachmentFileEngine.admits(older, among: files, limit: 12))
    }

    func testPathsAreStableDistinctAndSafe() {
        let one = AttachmentFileEngine.relativePath(inlet: "a", message: "1:2:INBOX", attachment: "2", filename: "Plan.pdf")
        XCTAssertEqual(one, AttachmentFileEngine.relativePath(inlet: "a", message: "1:2:INBOX", attachment: "2", filename: "Plan.pdf"))
        XCTAssertNotEqual(one, AttachmentFileEngine.relativePath(inlet: "a", message: "1:2:INBOX", attachment: "3", filename: "Plan.pdf"))
        XCTAssertNotEqual(one, AttachmentFileEngine.relativePath(inlet: "b", message: "1:2:INBOX", attachment: "2", filename: "Plan.pdf"))
        XCTAssertTrue(one.hasPrefix(AttachmentFileEngine.inletDirectory("a") + "/"))
        XCTAssertTrue(one.hasSuffix("/Plan.pdf"))
        XCTAssertEqual(AttachmentFileEngine.safeName("../a/b:c\\d.txt"), "_a_b_c_d.txt")
        XCTAssertEqual(AttachmentFileEngine.safeName("..."), AttachmentFileEngine.fallbackName)
        XCTAssertEqual(AttachmentFileEngine.safeName("   "), AttachmentFileEngine.fallbackName)
        let long = AttachmentFileEngine.safeName(String(repeating: "\u{E4}", count: 200) + ".pdf")
        XCTAssertLessThanOrEqual(long.utf8.count, AttachmentFileEngine.nameLimit)
        XCTAssertTrue(long.hasSuffix(".pdf"))
    }

    @MainActor
    private func rig(_ setting: Setting, base: URL) throws -> (store: AttachmentFileStore, database: SQLiteStore) {
        let database = try SQLiteStore.inMemory()
        let store = AttachmentFileStore(database: database, base: base, now: { Self.epoch }, settings: { setting.value },
                                        cap: { _ in setting.cap },
                                        resolve: { URL(fileURLWithPath: String(decoding: $0, as: UTF8.self), isDirectory: true) })
        return (store, database)
    }

    @MainActor
    private func mail(_ database: SQLiteStore, _ id: String, inlet: String = "a", day: Int) throws {
        let summary = MessageSummary(id: id, threadID: "t", subject: "S", from: "A", fromRaw: "a@x.de", toRaw: "me@x.de", snippet: "s",
                                     receivedAt: Self.epoch.addingTimeInterval(Double(day) * 86_400), flags: [.seen], folderIDs: ["INBOX"],
                                     attachmentCount: 1, messageIDHeader: "<\(id)>")
        try database.write { db in try MailboxStore.insert(db, inlet: inlet, folder: "INBOX", summary) }
    }

    @MainActor
    func testStoredBytesAreServedFromDiskAndNothingIsStoredWhileOff() async throws {
        let base = try directory()
        defer { try? FileManager.default.removeItem(at: base) }
        let setting = Setting()
        let (store, _) = try rig(setting, base: base)
        setting.value.attachments = false
        let refused = await store.store(Data([1, 2, 3]), inlet: "a", message: "m1", attachment: "2", filename: "a.pdf", receivedAt: Self.epoch)
        XCTAssertFalse(refused)
        XCTAssertTrue(store.files().isEmpty)
        setting.value.attachments = true
        let kept = await store.store(Data([1, 2, 3]), inlet: "a", message: "m1", attachment: "2", filename: "a.pdf", receivedAt: Self.epoch)
        XCTAssertTrue(kept)
        let entry = try XCTUnwrap(store.files().first)
        let url = try XCTUnwrap(store.root()).appendingPathComponent(entry.path)
        XCTAssertEqual(try Data(contentsOf: url), Data([1, 2, 3]))
        let served = await store.data("a", message: "m1", attachment: "2")
        XCTAssertEqual(served, Data([1, 2, 3]))
        let missing = await store.data("a", message: "m1", attachment: "9")
        XCTAssertNil(missing)
        try FileManager.default.removeItem(at: url)
        let lost = await store.data("a", message: "m1", attachment: "2")
        XCTAssertNil(lost)
        XCTAssertTrue(store.files().isEmpty)
    }

    @MainActor
    func testTheCapEvictsTheOldestFilesAndKeepsTheMailRows() async throws {
        let base = try directory()
        defer { try? FileManager.default.removeItem(at: base) }
        let setting = Setting()
        setting.cap = 10
        let (store, database) = try rig(setting, base: base)
        for (index, name) in ["m1", "m2", "m3"].enumerated() {
            try mail(database, name, day: index + 1)
            let kept = await store.store(Data(repeating: 7, count: 4), inlet: "a", message: name, attachment: "1", filename: "f.bin",
                                         receivedAt: Self.epoch.addingTimeInterval(Double(index + 1) * 86_400))
            XCTAssertTrue(kept)
        }
        XCTAssertEqual(Set(store.files().map(\.message)), ["m2", "m3"])
        let gone = await store.data("a", message: "m1", attachment: "1")
        XCTAssertNil(gone)
        let survivor = await store.data("a", message: "m3", attachment: "1")
        XCTAssertNotNil(survivor)
        let rows = try database.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM mail_message") }
        XCTAssertEqual(rows, 3)
        let older = await store.store(Data(repeating: 7, count: 4), inlet: "a", message: "m0", attachment: "1", filename: "f.bin",
                                      receivedAt: Self.epoch)
        XCTAssertFalse(older)
        XCTAssertEqual(Set(store.files().map(\.message)), ["m2", "m3"])
        setting.cap = 4
        store.enforce()
        XCTAssertEqual(store.files().map(\.message), ["m3"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.root()?.path ?? "").count, 1)
    }

    @MainActor
    func testFilesGoWhenTheirMailLeavesTheMirrorOrTheAccountIsRemoved() async throws {
        let base = try directory()
        defer { try? FileManager.default.removeItem(at: base) }
        let setting = Setting()
        let (store, database) = try rig(setting, base: base)
        try mail(database, "m1", day: 1)
        try mail(database, "m2", day: 2)
        try mail(database, "o1", inlet: "b", day: 1)
        for (inlet, name) in [("a", "m1"), ("a", "m2"), ("b", "o1")] {
            let kept = await store.store(Data([1]), inlet: inlet, message: name, attachment: "1", filename: "f.bin", receivedAt: Self.epoch)
            XCTAssertTrue(kept)
        }
        let root = try XCTUnwrap(store.root())
        let first = try XCTUnwrap(store.files().first { $0.message == "m1" })
        try database.write { db in try db.execute(sql: "DELETE FROM mail_message WHERE inlet = 'a' AND id = 'm1'") }
        store.sweep("a")
        XCTAssertEqual(Set(store.files().map(\.message)), ["m2", "o1"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(first.path).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(first.path).deletingLastPathComponent().path))
        store.removeInlet("a")
        XCTAssertEqual(store.files().map(\.message), ["o1"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(AttachmentFileEngine.inletDirectory("a")).path))
        let other = await store.data("b", message: "o1", attachment: "1")
        XCTAssertNotNil(other)
        store.removeAll()
        XCTAssertTrue(store.files().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    @MainActor
    func testMovingTheFolderCarriesTheFilesAndSwitchesTheRoot() async throws {
        let base = try directory()
        let target = try directory()
        defer {
            try? FileManager.default.removeItem(at: base)
            try? FileManager.default.removeItem(at: target)
        }
        let bookmark = Data(target.path.utf8)
        let setting = Setting()
        let (store, _) = try rig(setting, base: base)
        let kept = await store.store(Data([5, 6]), inlet: "a", message: "m1", attachment: "1", filename: "f.bin", receivedAt: Self.epoch)
        XCTAssertTrue(kept)
        let before = try XCTUnwrap(store.root())
        let moved = await store.move(to: bookmark) { setting.value.folder = bookmark }
        XCTAssertTrue(moved)
        let after = try XCTUnwrap(store.root())
        XCTAssertNotEqual(before.standardizedFileURL, after.standardizedFileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: before.path))
        let served = await store.data("a", message: "m1", attachment: "1")
        XCTAssertEqual(served, Data([5, 6]))
        let back = await store.move(to: nil) { setting.value.folder = nil }
        XCTAssertTrue(back)
        XCTAssertEqual(try XCTUnwrap(store.root()).standardizedFileURL, before.standardizedFileURL)
        let again = await store.data("a", message: "m1", attachment: "1")
        XCTAssertEqual(again, Data([5, 6]))
    }

    func testAFolderBookmarkResolvesBackToItsFolder() throws {
        let target = try directory()
        defer { try? FileManager.default.removeItem(at: target) }
        guard let bookmark = AttachmentFolder.bookmark(for: target) else { throw XCTSkip("bookmarks need the app environment") }
        XCTAssertEqual(AttachmentFolder.url(for: bookmark)?.standardizedFileURL.resolvingSymlinksInPath(),
                       target.standardizedFileURL.resolvingSymlinksInPath())
    }
}
