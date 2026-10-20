import XCTest
@testable import AlfaServices
import AlfaKit

final class IMAPActionTests: XCTestCase {
    private let message = "7:5:INBOX"

    private func commands(_ server: EmulatedIMAPStream) -> [String] {
        ActionFixture.withoutLogin(server.commands)
    }

    private func stepArchiveMovesToTheArchiveFolder() async throws {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 MOVE UIDPLUS")
        try await ActionFixture.transport(StreamQueue([server])).archive(messageID: message)
        XCTAssertEqual(commands(server), ["SELECT \"INBOX\"", "LIST \"\" \"*\"", "UID MOVE 5 \"Archive\""])
    }

    private func stepArchiveWithoutMoveCopiesFlagsDeletedAndExpunges() async throws {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 UIDPLUS")
        try await ActionFixture.transport(StreamQueue([server])).archive(messageID: message)
        XCTAssertEqual(commands(server).suffix(3), ["UID COPY 5 \"Archive\"", "UID STORE 5 +FLAGS.SILENT (\\Deleted)", "UID EXPUNGE 5"])
    }

    private func stepArchiveWithoutAnArchiveFolderIsRefusedAndTouchesNothing() async {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 MOVE", folders: ["* LIST (\\HasNoChildren) \"/\" INBOX"])
        do {
            try await ActionFixture.transport(StreamQueue([server])).archive(messageID: message)
            XCTFail("archive must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .folderNotFound("archive"))
        }
        XCTAssertFalse(commands(server).contains { $0.contains("MOVE") || $0.contains("COPY") || $0.contains("STORE") })
    }

    private func stepMoveGoesToTheNamedFolderAndRefusesUnknownOnes() async throws {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 MOVE")
        let transport = ActionFixture.transport(StreamQueue([server, ActionFixture.server(capabilities: "IMAP4rev1 MOVE")]))
        try await transport.move(messageID: message, toFolderID: "Projects")
        XCTAssertEqual(commands(server).last, "UID MOVE 5 \"Projects\"")
        do {
            try await transport.move(messageID: message, toFolderID: "Nowhere")
            XCTFail("move must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .folderNotFound("Nowhere"))
        }
    }

    private func stepTrashGoesToTheTrashFolder() async throws {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 MOVE")
        try await ActionFixture.transport(StreamQueue([server])).trash(messageID: message)
        XCTAssertEqual(commands(server).last, "UID MOVE 5 \"Trash\"")
    }

    private func stepTrashWithoutATrashFolderOnlyFlagsTheMessageDeleted() async throws {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 MOVE", folders: ["* LIST (\\HasNoChildren) \"/\" INBOX"])
        try await ActionFixture.transport(StreamQueue([server])).trash(messageID: message)
        XCTAssertEqual(commands(server).last, "UID STORE 5 +FLAGS.SILENT (\\Deleted)")
        XCTAssertFalse(commands(server).contains { $0.contains("MOVE") })
    }

    private func stepSpamGoesToTheJunkFolder() async throws {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 MOVE")
        try await ActionFixture.transport(StreamQueue([server])).markSpam(messageID: message)
        XCTAssertEqual(commands(server).last, "UID MOVE 5 \"Junk\"")
    }

    private func stepAMessageOfAnOlderMailboxVersionIsNeverTouched() async {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 MOVE")
        do {
            try await ActionFixture.transport(StreamQueue([server])).archive(messageID: "8:5:INBOX")
            XCTFail("archive must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .messageNotFound("8:5:INBOX"))
        }
        XCTAssertFalse(commands(server).contains { $0.contains("MOVE") })
    }

    private static let structure = "* 1 FETCH (UID 5 BODYSTRUCTURE ((\"TEXT\" \"PLAIN\" (\"CHARSET\" \"UTF-8\") NIL NIL \"7BIT\" 5 1)"
        + "(\"APPLICATION\" \"PDF\" (\"NAME\" \"a.pdf\") NIL NIL \"BASE64\" 8 NIL (\"ATTACHMENT\" (\"FILENAME\" \"a.pdf\")) NIL)"
        + " \"MIXED\" (\"BOUNDARY\" \"x\") NIL NIL))"

    private func attachmentServer() -> EmulatedIMAPStream {
        ActionFixture.server(capabilities: "IMAP4rev1") { command, _ in
            if command.hasSuffix("(UID BODYSTRUCTURE)") { return IMAPReply(untagged: [Self.structure]) }
            if command.hasSuffix("BODY.PEEK[1])") { return IMAPReply(untagged: ["* 1 FETCH (UID 5 BODY[1] {5}\r\nhello)"]) }
            if command.hasSuffix("BODY.PEEK[2])") { return IMAPReply(untagged: ["* 1 FETCH (UID 5 BODY[2] {8}\r\nSGVsbG8h)"]) }
            return nil
        }
    }

    private func stepBodyListsTheAttachmentsOfTheMessage() async throws {
        let body = try await ActionFixture.transport(StreamQueue([attachmentServer()])).fetchBody(messageID: message)
        XCTAssertEqual(body.text, "hello")
        XCTAssertEqual(body.attachments, [MailAttachmentInfo(id: "2", filename: "a.pdf", mimeType: "application/pdf", sizeBytes: 8)])
    }

    private func stepAttachmentIsFetchedBySectionWithoutMarkingReadAndDecoded() async throws {
        let server = attachmentServer()
        let data = try await ActionFixture.transport(StreamQueue([server])).fetchAttachment(messageID: message, attachmentID: "2")
        XCTAssertEqual(data, Data("Hello!".utf8))
        XCTAssertTrue(commands(server).contains("UID FETCH 5 (UID BODY.PEEK[2])"))
    }

    private func threadServer(found: String) -> EmulatedIMAPStream {
        ActionFixture.server(capabilities: "IMAP4rev1") { command, _ in
            if command.hasPrefix("UID SEARCH") { return IMAPReply(untagged: ["* SEARCH \(found)"]) }
            if command.hasPrefix("UID FETCH") {
                let uids = command.split(separator: " ")[2].split(separator: ",")
                return IMAPReply(untagged: uids.enumerated().map { "* \($0.offset + 1) FETCH (UID \($0.element) FLAGS (\\Seen))" })
            }
            return nil
        }
    }

    private func stepThreadIsFoundThroughMessageIDReferencesAndInReplyToInTheSameFolder() async throws {
        let server = threadServer(found: "3 6")
        let thread = try await ActionFixture.transport(StreamQueue([server]))
            .fetchThread(messageID: message, threadID: "<root@x.test>")
        XCTAssertEqual(thread.map(\.id), ["7:3:INBOX", "7:5:INBOX", "7:6:INBOX"])
        let id = "\"<root@x.test>\""
        XCTAssertTrue(commands(server).contains(
            "UID SEARCH UNDELETED OR OR HEADER MESSAGE-ID \(id) HEADER REFERENCES \(id) HEADER IN-REPLY-TO \(id)"))
        XCTAssertTrue(commands(server).contains("EXAMINE \"INBOX\""))
    }

    private func stepListSearchesExcludeMessagesFlaggedDeleted() async throws {
        let server = threadServer(found: "3")
        _ = try await ActionFixture.transport(StreamQueue([server])).listMessages(folderID: "INBOX", query: nil, pageToken: nil, maxResults: 5)
        XCTAssertTrue(commands(server).contains("UID SEARCH UNDELETED"))
        let second = threadServer(found: "3")
        _ = try await ActionFixture.transport(StreamQueue([second])).listMessages(folderID: "INBOX", query: "abc", pageToken: nil, maxResults: 5)
        XCTAssertTrue(commands(second).contains("UID SEARCH UNDELETED TEXT \"abc\""))
    }

    private func stepThreadWithoutHeadersIsTheMessageAloneAndNoSearchRuns() async throws {
        let server = threadServer(found: "3")
        let thread = try await ActionFixture.transport(StreamQueue([server])).fetchThread(messageID: message, threadID: message)
        XCTAssertEqual(thread.map(\.id), [message])
        XCTAssertFalse(commands(server).contains { $0.hasPrefix("UID SEARCH") })
    }

    private func draftServer(capabilities: String = "IMAP4rev1 UIDPLUS", appendStatus: String = "OK [APPENDUID 99 12] done")
        -> EmulatedIMAPStream {
        ActionFixture.server(capabilities: capabilities) { command, _ in
            if command.hasPrefix("APPEND") { return IMAPReply(status: appendStatus) }
            if command.hasPrefix("UID SEARCH") { return IMAPReply(untagged: ["* SEARCH 41"]) }
            return nil
        }
    }

    private func stepSavingADraftAppendsItToTheDraftsFolderFlaggedDraft() async throws {
        let server = draftServer()
        let id = try await ActionFixture.transport(StreamQueue([server]))
            .saveDraft(EmailDraft(to: "ann@x.test", subject: "Hi", body: "text"), replacing: nil)
        XCTAssertEqual(id, "99:12:Drafts")
        let append = try XCTUnwrap(commands(server).first { $0.hasPrefix("APPEND") })
        XCTAssertTrue(append.hasPrefix("APPEND \"Drafts\" (\\Draft) {"))
        let stored = String(decoding: try XCTUnwrap(server.literals.first), as: UTF8.self)
        XCTAssertTrue(stored.contains("Subject: Hi\r\n"))
        XCTAssertTrue(stored.contains("To: ann@x.test\r\n"))
    }

    private func stepADraftWithoutRecipientIsSavedAndKeepsItsBlindCopy() async throws {
        let server = draftServer()
        _ = try await ActionFixture.transport(StreamQueue([server]))
            .saveDraft(EmailDraft(bcc: "hidden@x.test", subject: "Hi", body: "text"), replacing: nil)
        let stored = String(decoding: try XCTUnwrap(server.literals.first), as: UTF8.self)
        XCTAssertTrue(stored.contains("Bcc: hidden@x.test\r\n"))
    }

    private func stepSavingWithoutAnAppendUidFindsTheNewDraftByItsMessageID() async throws {
        let server = draftServer(capabilities: "IMAP4rev1", appendStatus: "OK done")
        let id = try await ActionFixture.transport(StreamQueue([server]))
            .saveDraft(EmailDraft(to: "ann@x.test", subject: "Hi", body: "text"), replacing: nil)
        XCTAssertEqual(id, "7:41:Drafts")
        XCTAssertTrue(commands(server).contains { $0.hasPrefix("UID SEARCH HEADER MESSAGE-ID \"") })
    }

    private func stepReplacingADraftRemovesTheOldOneOnlyAfterTheNewOneIsStored() async throws {
        let server = draftServer()
        let id = try await ActionFixture.transport(StreamQueue([server]))
            .saveDraft(EmailDraft(to: "ann@x.test", subject: "Hi", body: "text"), replacing: "7:20:Drafts")
        XCTAssertEqual(id, "99:12:Drafts")
        let log = commands(server)
        let append = try XCTUnwrap(log.firstIndex { $0.hasPrefix("APPEND") })
        let remove = try XCTUnwrap(log.firstIndex(of: "UID STORE 20 +FLAGS.SILENT (\\Deleted)"))
        XCTAssertLessThan(append, remove)
        XCTAssertEqual(log.last, "UID EXPUNGE 20")
    }

    private func stepSavingWithoutADraftsFolderIsRefused() async {
        let server = ActionFixture.server(capabilities: "IMAP4rev1", folders: ["* LIST (\\HasNoChildren) \"/\" INBOX"])
        do {
            _ = try await ActionFixture.transport(StreamQueue([server])).saveDraft(EmailDraft(subject: "Hi", body: "x"), replacing: nil)
            XCTFail("save must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .folderNotFound("drafts"))
        }
        XCTAssertTrue(server.literals.isEmpty)
    }

    private static let envelopeDraft = "* 1 FETCH (UID 20 ENVELOPE (\"Mon, 1 Jan 2026 10:00:00 +0000\" \"Plan\" NIL NIL NIL"
        + " ((\"Ann\" NIL \"ann\" \"x.test\")) NIL ((\"Bob\" NIL \"bob\" \"x.test\")) \"<r@x.test>\" \"<d@x.test>\")"
        + " BODYSTRUCTURE (\"TEXT\" \"PLAIN\" (\"CHARSET\" \"UTF-8\") NIL NIL \"7BIT\" 5 1))"

    private func storedDraftServer(capabilities: String = "IMAP4rev1 UIDPLUS") -> EmulatedIMAPStream {
        ActionFixture.server(capabilities: capabilities) { command, _ in
            if command.hasSuffix("(UID ENVELOPE BODYSTRUCTURE)") { return IMAPReply(untagged: [Self.envelopeDraft]) }
            if command.hasSuffix("BODY.PEEK[1])") { return IMAPReply(untagged: ["* 1 FETCH (UID 20 BODY[1] {5}\r\nhello)"]) }
            return nil
        }
    }

    private func stepAStoredDraftIsRebuiltFromEnvelopeAndText() async throws {
        let stored = try await ActionFixture.transport(StreamQueue([storedDraftServer()])).fetchDraft(messageID: "7:20:Drafts")
        XCTAssertEqual(stored.id, "7:20:Drafts")
        XCTAssertEqual(stored.draft.subject, "Plan")
        XCTAssertEqual(stored.draft.body, "hello")
        XCTAssertTrue(try XCTUnwrap(stored.draft.to).contains("ann@x.test"))
        XCTAssertTrue(try XCTUnwrap(stored.draft.bcc).contains("bob@x.test"))
        XCTAssertNil(stored.draft.cc)
        XCTAssertEqual(stored.draft.inReplyTo, "<r@x.test>")
    }

    private func stepSendingAStoredDraftSendsItThenRemovesIt() async throws {
        let fetch = storedDraftServer()
        let smtp = EmulatedSMTPStream()
        let remove = storedDraftServer()
        let queue = StreamQueue([fetch, smtp, remove])
        try await ActionFixture.transport(queue).sendDraft(id: "7:20:Drafts")
        XCTAssertTrue(smtp.delivered.contains("Subject: Plan"))
        XCTAssertTrue(smtp.commands.contains { $0.hasPrefix("RCPT TO:<ann@x.test>") })
        XCTAssertEqual(ActionFixture.withoutLogin(remove.commands).suffix(2),
                       ["UID STORE 20 +FLAGS.SILENT (\\Deleted)", "UID EXPUNGE 20"])
    }

    private func stepAFailedSendKeepsTheStoredDraft() async {
        let queue = StreamQueue([storedDraftServer()])
        do {
            try await ActionFixture.transport(queue).sendDraft(id: "7:20:Drafts")
            XCTFail("send must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .connectionFailed("smtp.ionos.de"))
        }
        XCTAssertEqual(queue.openedCount, 1)
    }

    private func stepASendLargerThanTheDeclaredSizeIsRefusedBeforeUpload() async {
        let smtp = EmulatedSMTPStream(size: 100)
        do {
            try await ActionFixture.transport(StreamQueue([smtp])).send(EmailDraft(to: "ann@x.test", subject: "Plan", body: "hello"))
            XCTFail("send must throw")
        } catch {
            guard case .smtpRejected(552, _)? = error as? MailTransportError else { return XCTFail("wrong error \(error)") }
        }
        XCTAssertFalse(smtp.commands.contains("DATA"))
    }

    private func stepDeletingADraftFlagsItDeletedAndExpunges() async throws {
        let server = ActionFixture.server(capabilities: "IMAP4rev1 UIDPLUS")
        try await ActionFixture.transport(StreamQueue([server])).deleteDraft(id: "7:20:Drafts")
        XCTAssertEqual(commands(server), ["SELECT \"Drafts\"", "UID STORE 20 +FLAGS.SILENT (\\Deleted)", "UID EXPUNGE 20"])
    }

    func testTheIMAPActions() async throws {
        try await stepArchiveMovesToTheArchiveFolder()
        try await stepArchiveWithoutMoveCopiesFlagsDeletedAndExpunges()
        await stepArchiveWithoutAnArchiveFolderIsRefusedAndTouchesNothing()
        try await stepMoveGoesToTheNamedFolderAndRefusesUnknownOnes()
        try await stepTrashGoesToTheTrashFolder()
        try await stepTrashWithoutATrashFolderOnlyFlagsTheMessageDeleted()
        try await stepSpamGoesToTheJunkFolder()
        await stepAMessageOfAnOlderMailboxVersionIsNeverTouched()
        try await stepBodyListsTheAttachmentsOfTheMessage()
        try await stepAttachmentIsFetchedBySectionWithoutMarkingReadAndDecoded()
        try await stepThreadIsFoundThroughMessageIDReferencesAndInReplyToInTheSameFolder()
        try await stepListSearchesExcludeMessagesFlaggedDeleted()
        try await stepThreadWithoutHeadersIsTheMessageAloneAndNoSearchRuns()
        try await stepSavingADraftAppendsItToTheDraftsFolderFlaggedDraft()
        try await stepADraftWithoutRecipientIsSavedAndKeepsItsBlindCopy()
        try await stepSavingWithoutAnAppendUidFindsTheNewDraftByItsMessageID()
        try await stepReplacingADraftRemovesTheOldOneOnlyAfterTheNewOneIsStored()
        await stepSavingWithoutADraftsFolderIsRefused()
        try await stepAStoredDraftIsRebuiltFromEnvelopeAndText()
        try await stepSendingAStoredDraftSendsItThenRemovesIt()
        await stepAFailedSendKeepsTheStoredDraft()
        await stepASendLargerThanTheDeclaredSizeIsRefusedBeforeUpload()
        try await stepDeletingADraftFlagsItDeletedAndExpunges()
    }
}
