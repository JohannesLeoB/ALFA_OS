import Core
import Design
import Foundation
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

private final class TransportDouble: MailTransportPort, PurgePort, @unchecked Sendable {
    let calls = Locked<[String]>([])
    let failure = Locked<(any Error)?>(nil)
    let wasSentAnswer = Locked(false)
    let drafts = Locked<[String: Draft]>([:])
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
        return [Folder(id: "INBOX", name: "INBOX", role: .inbox), Folder(id: "Archive", name: "Archive", role: .archive),
                Folder(id: "Trash", name: "Trash", role: .trash)]
    }

    func listMessages(folderID: String, query: String?, pageToken: String?, maxResults: Int) async throws -> MessagePage {
        try note("listMessages")
        let message = MessageSummary(id: prefix + ":1:" + folderID, threadID: "t", subject: "Hello", from: "Anna",
                                     fromRaw: "Anna <anna@example.com>", toRaw: "me@example.com",
                                     snippet: "snippet", flags: [], folderIDs: [folderID], messageIDHeader: "<h1@x>")
        return MessagePage(messages: [message])
    }

    func fetchBody(messageID: String) async throws -> MessageBody {
        try note("fetchBody")
        return MessageBody(text: "plain text", html: nil)
    }

    func send(_ draft: Draft) async throws { try note("send") }
    func setFlags(messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws { try note("setFlags") }
    func archive(messageID: String) async throws { try note("archive") }
    func move(messageID: String, toFolderID: String) async throws { try note("move") }
    func trash(messageID: String) async throws { try note("trash") }
    func markSpam(messageID: String) async throws { try note("markSpam") }
    func fetchAttachment(messageID: String, attachmentID: String) async throws -> Data { try note("attachment"); return Data([1]) }
    func fetchThread(messageID: String, threadID: String) async throws -> [MessageSummary] { try note("thread"); return [] }

    func saveDraft(_ draft: Draft, replacing draftID: String?) async throws -> String {
        try note("saveDraft")
        let id = prefix + ":9:Drafts"
        drafts.with { $0[id] = draft }
        return id
    }

    func fetchDraft(messageID: String) async throws -> StoredDraft {
        try note("fetchDraft")
        return StoredDraft(id: messageID, draft: drafts.with { $0[messageID] } ?? Draft(subject: "", body: ""))
    }

    func deleteDraft(id: String) async throws { try note("deleteDraft") }
    func sendDraft(id: String) async throws { try note("sendDraft") }
    func wasSent(messageID: String) async throws -> Bool { try note("wasSent"); return wasSentAnswer.with { $0 } }
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

    init() throws {
        database = try SQLiteStore.inMemory()
        access.transport = transport
        outbox = OutboxStore(access: access, database: database, events: events)
        mailbox = MailboxStore(access: access, database: database, outbox: outbox, events: events)
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
        XCTAssertEqual(structure.attachments.first?.filename, "a.pdf")
        let single = try XCTUnwrap(try fetched("* 1 FETCH (BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"UTF-8\") NIL NIL \"7BIT\" 3028 92))").structure)
        XCTAssertEqual(single.section, "1")
    }

    func testFolderNamesAndEncodedWords() {
        XCTAssertEqual(IMAPFolderNameCodec.decode("~peter/mail/&U,BTFw-/&ZeVnLIqe-"), "~peter/mail/\u{53F0}\u{5317}/\u{65E5}\u{672C}\u{8A9E}")
        XCTAssertEqual(IMAPFolderNameCodec.encode("Entw\u{FC}rfe & mehr"), "Entw&APw-rfe &- mehr")
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

    func testHTMLEngine() {
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

    func testNamesQuotesAndLabels() {
        XCTAssertEqual(PersonName.display("\"Gray, Terry\" <g@x.org>").name, "Gray, Terry")
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

    func testMenusOfferOnlyHandledActions() {
        let removed = ["move", "note", "original", "laterSend", "receipt", "template", "preview", "otherProject", "format"]
        XCTAssertTrue(Set(Action.allCases.map(\.rawValue)).isDisjoint(with: removed))
        let lines = MenuEngine.row(unread: true, draft: false) + MenuEngine.readingMore(starred: false)
            + MenuEngine.attachment()
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
        XCTAssertTrue(reading.footLeft.first { $0.id == "toProject" }?.off == true)
        XCTAssertEqual(reading.fold.count, 1)
        let confirm = CommandEngine.commands(front: .draft(canSend: true), stackCount: 1, fanned: false, hasFiles: true,
                                             confirmDiscard: true, canFold: true, sendLabelled: true)
        XCTAssertEqual(confirm.state, .confirm)
        XCTAssertTrue(confirm.fold.isEmpty && confirm.fan.isEmpty)
        let draft = CommandEngine.commands(front: .draft(canSend: false), stackCount: 1, fanned: false, hasFiles: true,
                                           confirmDiscard: false, canFold: false, sendLabelled: true)
        XCTAssertEqual(draft.footLeft.map(\.id), ["attachFile", "fromProject"])
        XCTAssertTrue(draft.footRight.last?.off == true)
    }

    @MainActor
    func testMailboxStoreLoadsPageAndKeepsItInTheMirror() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        XCTAssertEqual(rig.mailbox.folders("a").map(\.id), ["INBOX", "Archive", "Trash"])
        let page = try await rig.mailbox.loadPage("a", folder: "INBOX", query: nil, pageToken: nil)
        XCTAssertEqual(page.messages.count, 1)
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
    func testMailboxStoreMapsFailuresAndMovesMessages() async throws {
        let rig = try Rig()
        try await rig.mailbox.refreshFolders("a")
        _ = try await rig.mailbox.loadPage("a", folder: "INBOX", query: nil, pageToken: nil)
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
    func testSyncEventsFillFoldersAndRemovalPurges() async throws {
        let rig = try Rig()
        let stock = rig.access.stock(.mailboxes, as: Mailbox.self)
        stock.apply(inlet: "a", records: [Mailbox(id: "a/INBOX", inlet: "a", name: "INBOX", role: "inbox")], at: Date())
        try await Task.sleep(for: .milliseconds(100))
        rig.access.emit(.syncFinished(.mail, "a"))
        for _ in 0..<50 where rig.mailbox.messages("a", folder: "INBOX").isEmpty { try await Task.sleep(for: .milliseconds(20)) }
        XCTAssertEqual(rig.mailbox.folders("a").map(\.id), ["INBOX"])
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
    func testComposeReusesOnlyABlankDraftOfTheOpenMailbox() async throws {
        let rig = try Rig()
        _ = rig.addMailbox("b", prefix: "2")
        let state = InboxState(mailbox: rig.mailbox, outbox: rig.outbox, contacts: ContactState())
        await state.start()
        let id = try XCTUnwrap(state.compose())
        XCTAssertEqual(state.draft(id)?.inlet, "a")
        XCTAssertEqual(state.compose(), id)
        state.setFrom(id, inlet: "b")
        let other = try XCTUnwrap(state.compose())
        XCTAssertNotEqual(other, id)
        XCTAssertEqual(state.draft(id)?.inlet, "b")
        XCTAssertEqual(state.draft(other)?.inlet, "a")
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
}
