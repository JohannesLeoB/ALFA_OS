import XCTest
@testable import MykilosServices
import MykilosKit

final class MailWireTests: XCTestCase {
    private func fx(_ key: String, file: StaticString = #filePath, line: UInt = #line) -> String {
        MailWireFixture.line(key, file: file, line: line)
    }

    private func parse(_ text: String) throws -> IMAPResponse {
        try IMAPResponseParser.parse(Data(text.utf8))
    }

    private func fetched(_ key: String) throws -> IMAPFetched {
        guard case .data(let values) = try parse(fx(key)), let fetched = try IMAPFetched.parse(values) else {
            throw MailTransportError.malformedResponse(key)
        }
        return fetched
    }

    func testTaggedAndStatusResponses() throws {
        XCTAssertEqual(try parse(fx("tagged.ok")), .tagged(tag: "a001", status: .ok, code: nil, text: fx("tagged.ok.text")))
        XCTAssertEqual(try parse(fx("tagged.no")),
                       .tagged(tag: "a002", status: .no, code: IMAPResponseCode(name: "AUTHENTICATIONFAILED", values: []),
                               text: fx("tagged.no.text")))
        XCTAssertEqual(try parse(fx("status.validity")),
                       .status(.ok, code: IMAPResponseCode(name: "UIDVALIDITY", values: [.number(3857529045)]),
                               text: fx("status.validity.text")))
        XCTAssertEqual(try parse(fx("status.bye")), .status(.bye, code: nil, text: fx("status.bye.text")))
        XCTAssertEqual(try parse(fx("continuation")), .continuation(fx("continuation.text")))
    }

    func testResponseCodeWithList() throws {
        guard case .status(_, let code?, _) = try parse(fx("permanent")) else { return XCTFail() }
        XCTAssertEqual(code.name, "PERMANENTFLAGS")
        XCTAssertEqual(code.values, [.list([.atom("\\Deleted"), .atom("\\Seen"), .atom("\\*")])])
    }

    func testUntaggedData() throws {
        XCTAssertEqual(try parse("* 172 EXISTS"), .data([.number(172), .atom("EXISTS")]))
        XCTAssertEqual(try parse("* SEARCH 2 84 882"), .data([.atom("SEARCH"), .number(2), .number(84), .number(882)]))
        XCTAssertEqual(try parse("* FLAGS (\\Answered \\Flagged \\Deleted \\Seen \\Draft)"),
                       .data([.atom("FLAGS"), .list([.atom("\\Answered"), .atom("\\Flagged"), .atom("\\Deleted"),
                                                     .atom("\\Seen"), .atom("\\Draft")])]))
        guard case .data(let values) = try parse(fx("list.noselect")) else { return XCTFail() }
        let entry = IMAPListEntry.parse(values)
        XCTAssertEqual(entry?.path, "~/Mail/foo")
        XCTAssertEqual(entry?.delimiter, "/")
        XCTAssertEqual(entry?.isSelectable, false)
    }

    func testListWithNilDelimiterAndSpecialUse() throws {
        guard case .data(let values) = try parse(fx("list.sent")) else { return XCTFail() }
        let entry = IMAPListEntry.parse(values)
        XCTAssertNil(entry?.delimiter)
        XCTAssertEqual(entry?.role, .sent)
    }

    func testLiteralInsideFetch() throws {
        let result = try fetched("fetch.literal")
        XCTAssertEqual(result.sections["TEXT"], Data(fx("fetch.literal.body").utf8))
        XCTAssertEqual(result.uid, 4)
    }

    func testLiteralSizeDetection() {
        XCTAssertEqual(IMAPResponseParser.literalSize(endingLine: Data("* 1 FETCH (BODY[TEXT] {342}".utf8)), 342)
        XCTAssertEqual(IMAPResponseParser.literalSize(endingLine: Data("a1 LOGIN x {5+}".utf8)), 5)
        XCTAssertNil(IMAPResponseParser.literalSize(endingLine: Data("* 1 EXISTS".utf8)))
    }

    func testEnvelopeAndInternalDateFromSpecificationExample() throws {
        let result = try fetched("envelope.raw")
        XCTAssertEqual(result.sequence, 12)
        XCTAssertEqual(result.flags, ["\\seen"])
        XCTAssertEqual(result.size, 4286)
        XCTAssertEqual(result.envelope?.subject, fx("envelope.subject"))
        XCTAssertEqual(result.envelope?.from.first?.address, fx("envelope.address"))
        XCTAssertEqual(result.envelope?.from.first?.display, fx("envelope.name"))
        XCTAssertEqual(result.envelope?.to.first?.display, fx("envelope.to"))
        XCTAssertEqual(result.envelope?.cc.count, 2)
        XCTAssertEqual(result.envelope?.messageID, fx("envelope.messageid"))
        XCTAssertEqual(result.internalDate, Date(timeIntervalSince1970: 837_596_665))
        XCTAssertEqual(result.envelope?.date.flatMap(MailMIME.parseMessageDate), Date(timeIntervalSince1970: 837_595_405))
    }

    func testBodyStructureFromSpecificationExample() throws {
        guard let structure = try fetched("structure.mixed").structure else { return XCTFail() }
        XCTAssertTrue(structure.isMultipart)
        XCTAssertEqual(structure.subtype, "mixed")
        XCTAssertEqual(structure.children.map(\.section), ["1", "2"])
        XCTAssertEqual(structure.children[1].filename, "cc.diff")
        XCTAssertEqual(structure.children[1].encoding, "base64")
        XCTAssertEqual(structure.children[1].contentID, fx("structure.contentid"))
        XCTAssertEqual(structure.children[0].charset, "US-ASCII")
        XCTAssertEqual(structure.attachments.map(\.section), ["2"])
        XCTAssertEqual(structure.firstPlainText?.section, "1")
    }

    func testNestedBodyStructureWithDisposition() throws {
        guard let structure = try fetched("structure.nested").structure else { return XCTFail() }
        XCTAssertEqual(structure.firstHTML?.section, "1")
        XCTAssertEqual(structure.attachments.first?.filename, "a.pdf")
        XCTAssertEqual(structure.children[1].disposition, "attachment")
    }

    func testSingleMessageStructureGetsSectionOne() throws {
        guard let structure = try fetched("structure.single").structure else { return XCTFail() }
        XCTAssertEqual(structure.section, "1")
        XCTAssertEqual(structure.firstPlainText?.section, "1")
    }

    func testModifiedUTF7() {
        XCTAssertEqual(IMAPModifiedUTF7.decode(fx("utf7.encoded")), fx("utf7.decoded"))
        XCTAssertEqual(IMAPModifiedUTF7.encode(fx("utf7.decoded")), fx("utf7.encoded"))
        XCTAssertEqual(IMAPModifiedUTF7.decode(fx("utf7.ampersand.encoded")), fx("utf7.ampersand.decoded"))
        XCTAssertEqual(IMAPModifiedUTF7.encode(fx("utf7.umlaut.decoded")), fx("utf7.umlaut.encoded"))
        XCTAssertEqual(IMAPModifiedUTF7.decode(fx("utf7.umlaut.encoded")), fx("utf7.umlaut.decoded"))
    }

    func testEncodedWordExamplesFromSpecification() {
        XCTAssertEqual(MailMIME.decodeEncodedWords("=?ISO-8859-1?Q?a?="), "a")
        XCTAssertEqual(MailMIME.decodeEncodedWords(fx("word.space")), fx("word.space.decoded"))
        XCTAssertEqual(MailMIME.decodeEncodedWords("=?ISO-8859-1?Q?a?= =?ISO-8859-1?Q?b?="), "ab")
        XCTAssertEqual(MailMIME.decodeEncodedWords(fx("word.folded")), "ab")
        XCTAssertEqual(MailMIME.decodeEncodedWords(fx("word.underscore")), fx("word.underscore.decoded"))
        XCTAssertEqual(MailMIME.decodeEncodedWords(fx("word.charsets")), fx("word.charsets.decoded"))
        XCTAssertEqual(MailMIME.decodeEncodedWords(fx("word.address")), fx("word.address.decoded"))
        XCTAssertEqual(MailMIME.decodeEncodedWords(fx("word.latin")), fx("word.latin.decoded"))
    }

    func testTransferDecoding() {
        XCTAssertEqual(String(data: MailMIME.decodeTransfer(Data(fx("quoted.printable").utf8), encoding: "quoted-printable"),
                              encoding: .utf8), fx("quoted.printable.decoded"))
        XCTAssertEqual(MailMIME.decodeTransfer(Data("SGVs\r\nbG8=".utf8), encoding: "base64"), Data("Hello".utf8))
        XCTAssertEqual(MailMIME.string(from: Data([0x4B, 0xFC, 0x63, 0x68, 0x65]), charset: "iso-8859-1"), fx("charset.utf8"))
        XCTAssertEqual(MailMIME.string(from: Data(fx("charset.utf8").utf8), charset: "utf-8"), fx("charset.utf8"))
        XCTAssertEqual(MailMIME.string(from: Data([0x4B, 0xFC, 0x63, 0x68, 0x65]), charset: nil), fx("charset.utf8"))
    }

    func testParameterizedValuesWithExtendedFilename() {
        let simple = MailMIME.parseParameterized(fx("param.simple"))
        XCTAssertEqual(simple.value, "text/plain")
        XCTAssertEqual(simple.parameters["charset"], "utf-8")
        XCTAssertEqual(MailMIME.parseParameterized(fx("param.extended")).parameters["filename"], fx("param.extended.decoded"))
        XCTAssertEqual(MailMIME.parseParameterized(fx("param.continued")).parameters["filename"], fx("param.continued.decoded"))
    }

    func testHeaderUnfolding() {
        let fields = MailMIME.parseHeaders(Data(fx("header.folded").utf8))
        XCTAssertEqual(fields.map(\.name), ["Subject", "From"])
        XCTAssertEqual(fields[0].value, fx("header.folded.decoded"))
    }

    func testAddressSplittingAndMailbox() {
        let list = MailMIME.splitAddresses(fx("address.list"))
        XCTAssertEqual(list.count, 3)
        let first = MailMIME.parseMailbox(list[0])
        XCTAssertEqual(first?.name, fx("address.name"))
        XCTAssertEqual(first?.address, fx("envelope.address"))
        XCTAssertEqual(MailMIME.parseMailbox("plain@example.com")?.address, "plain@example.com")
        XCTAssertNil(MailMIME.parseMailbox(fx("address.invalid")))
    }

    func testMessageReferenceRoundTrip() throws {
        let reference = IMAPMessageReference(folder: "INBOX/a:b", uidValidity: 7, uid: 99)
        XCTAssertEqual(try IMAPMessageReference.decode(reference.encoded), reference)
        XCTAssertThrowsError(try IMAPMessageReference.decode("garbage"))
    }

    func testQuotingChoosesLiteralForNonASCII() {
        XCTAssertEqual(IMAPSession.quote("INBOX"), "\"INBOX\"")
        XCTAssertEqual(IMAPSession.quote("a\"b\\c"), "\"a\\\"b\\\\c\"")
        XCTAssertNil(IMAPSession.quote(fx("charset.utf8")))
        XCTAssertNil(IMAPSession.quote("a\r\nb"))
    }

    func testSMTPReplyParsing() throws {
        XCTAssertEqual(try SMTPReply.assemble([fx("smtp.ok")]), SMTPReply(code: 250, lines: ["OK"]))
        let multi = try SMTPReply.assemble(["smtp.multi.1", "smtp.multi.2", "smtp.multi.3", "smtp.multi.4"].map { fx($0) })
        XCTAssertEqual(multi.code, 250)
        XCTAssertEqual(multi.lines.count, 4)
        XCTAssertEqual(try SMTPReply.parseLine(fx("smtp.greeting")).isLast, true)
        XCTAssertEqual(try SMTPReply.parseLine("250-first").isLast, false)
        XCTAssertEqual(try SMTPReply.parseLine("221").isLast, true)
        XCTAssertThrowsError(try SMTPReply.parseLine("hello"))
        XCTAssertThrowsError(try SMTPReply.assemble(["250-a", "251 b"]))
    }

    func testDotStuffing() {
        XCTAssertEqual(String(data: SMTPDotStuffing.apply(Data(fx("smtp.stuffed.in").utf8)), encoding: .utf8), fx("smtp.stuffed.out"))
        XCTAssertEqual(String(data: SMTPDotStuffing.apply(Data("x\r\n".utf8)), encoding: .utf8), "x\r\n.\r\n")
        XCTAssertEqual(String(data: SMTPDotStuffing.apply(Data(".a".utf8)), encoding: .utf8), "..a\r\n.\r\n")
    }

    private var account: MailAccount {
        MailProviderPresets.preset(for: .gmx).account(id: "t", displayName: fx("sender.name"), address: "joerg@example.com")
    }

    func testMessageBuilderHeadersAndRecipients() throws {
        let draft = EmailDraft(to: "A <a@example.com>, b@example.com", cc: "c@example.com", bcc: "hidden@example.com",
                               subject: fx("subject.unicode"), body: fx("body.two"), inReplyTo: "abc@x")
        let message = try MailMessageBuilder.build(draft, account: account, messageID: "id-1", date: Date(timeIntervalSince1970: 0))
        let text = String(decoding: message.data, as: UTF8.self)
        XCTAssertEqual(message.recipients, ["a@example.com", "b@example.com", "c@example.com", "hidden@example.com"])
        XCTAssertEqual(message.sender, "joerg@example.com")
        XCTAssertTrue(text.contains("From: =?UTF-8?B?"))
        XCTAssertTrue(text.contains("<joerg@example.com>"))
        XCTAssertTrue(text.contains("Cc: c@example.com\r\n"))
        XCTAssertFalse(text.lowercased().contains("hidden@example.com"))
        XCTAssertTrue(text.contains("Date: Thu, 01 Jan 1970 00:00:00 +0000"))
        XCTAssertTrue(text.contains("In-Reply-To: <abc@x>"))
        XCTAssertTrue(text.contains("Message-ID: <id-1@example.com>"))
        XCTAssertTrue(text.contains("Content-Type: text/plain; charset=\"UTF-8\""))
        XCTAssertFalse(text.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
        XCTAssertTrue(message.data.allSatisfy { $0 < 128 })
        XCTAssertNotNil(message.data.firstRange(of: Data("\r\n\r\n".utf8)))
    }

    func testMessageBuilderAttachmentsAndAlternative() throws {
        let attachment = DraftAttachment(filename: fx("attachment.name"), mimeType: "application/pdf", data: Data(repeating: 7, count: 100))
        let draft = EmailDraft(to: "a@example.com", subject: "S", body: "plain", attachments: [attachment], bodyHTML: "<p>hi</p>")
        let message = try MailMessageBuilder.build(draft, account: account, messageID: "id-2")
        let text = String(decoding: message.data, as: UTF8.self)
        XCTAssertTrue(text.contains("multipart/mixed"))
        XCTAssertTrue(text.contains("multipart/alternative"))
        XCTAssertTrue(text.contains("text/html"))
        XCTAssertTrue(text.contains(fx("attachment.fallback")))
        XCTAssertTrue(text.contains("filename*=UTF-8''"))
        XCTAssertTrue(message.data.allSatisfy { $0 < 128 })
    }

    func testMessageBuilderRejectsMissingOrInvalidRecipients() {
        XCTAssertThrowsError(try MailMessageBuilder.build(EmailDraft(subject: "S", body: "b"), account: account)) {
            XCTAssertEqual($0 as? MailTransportError, .noRecipients)
        }
        XCTAssertThrowsError(try MailMessageBuilder.build(EmailDraft(to: "nonsense", subject: "S", body: "b"), account: account)) {
            XCTAssertEqual($0 as? MailTransportError, .invalidRecipient("nonsense"))
        }
    }

    func testLongNonASCIIHeaderIsFoldedIntoShortEncodedWords() {
        let source = String(repeating: "\u{E4}", count: 80)
        let encoded = MailMessageBuilder.encodeHeader(source)
        for line in encoded.components(separatedBy: "\r\n") {
            XCTAssertLessThanOrEqual(line.count, 76)
            XCTAssertTrue(line.trimmingCharacters(in: .whitespaces).hasPrefix("=?UTF-8?B?"))
        }
        XCTAssertEqual(MailMIME.decodeEncodedWords(encoded), source)
    }

    func testOAuthWithoutTokenSourceIsTypedError() async {
        let outlook = MailProviderPresets.preset(for: .outlook).account(id: "o", displayName: "", address: "x@example.com")
        do {
            _ = try await IMAPSMTPMailTransport(account: outlook).listFolders()
            XCTFail()
        } catch {
            XCTAssertEqual(error as? MailTransportError, .oauthUnavailable(.outlook))
        }
    }

    func testIncompleteAccountIsTypedError() async {
        let generic = MailProviderPresets.preset(for: .generic).account(id: "g", displayName: "", address: "x@example.com")
        do {
            _ = try await IMAPSMTPMailTransport(account: generic).listFolders()
            XCTFail()
        } catch {
            XCTAssertEqual(error as? MailTransportError, .accountIncomplete("incoming"))
        }
    }

    func testAnIMAPPageHoldsTheNewestUIDsAndTheTokenPointsAtTheOldestOfThem() async throws {
        let server = try LoopbackIMAPServer(uids: [1, 2, 3, 4, 5])
        defer { server.stop() }
        var account = MailProviderPresets.preset(for: .generic).account(id: "g", displayName: "", address: "x@example.test")
        account.incoming = MailServerSettings(host: "127.0.0.1", port: server.port, security: .none, authentication: .password, username: "x")
        let transport = IMAPSMTPMailTransport(account: account, password: { "secret" })
        let page = try await transport.listMessages(folderID: "INBOX", query: nil, pageToken: nil, maxResults: 2)
        let uids = try page.messages.map { try IMAPMessageReference.decode($0.id).uid }
        XCTAssertEqual(uids, [5, 4])
        XCTAssertEqual(page.nextPageToken, "4")
    }
}
