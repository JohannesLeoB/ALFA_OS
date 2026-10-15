import XCTest
@testable import MykilosServices
import MykilosKit

final class GmailActionTests: XCTestCase {
    private func transport() -> GmailMailTransport {
        GmailMailTransport(client: GoogleGmailClient(tokenProvider: ActionToken(), session: RecordingGmail.session()))
    }

    private func labels(_ call: RecordingGmail.Call) throws -> [String: [String]] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: call.body) as? [String: [String]])
    }

    private let messages = "/gmail/v1/users/me/messages"
    private let drafts = "/gmail/v1/users/me/drafts"

    private func stepArchiveRemovesTheInboxLabelOnly() async throws {
        RecordingGmail.reset()
        try await transport().archive(messageID: "m1")
        let call = try XCTUnwrap(RecordingGmail.calls.first)
        XCTAssertEqual(RecordingGmail.calls.count, 1)
        XCTAssertEqual(call.method, "POST")
        XCTAssertEqual(call.path, "\(messages)/m1/modify")
        XCTAssertEqual(try labels(call), ["removeLabelIds": ["INBOX"]])
    }

    private func stepTrashUsesTheTrashEndpoint() async throws {
        RecordingGmail.reset()
        try await transport().trash(messageID: "m1")
        XCTAssertEqual(RecordingGmail.calls, [RecordingGmail.Call(method: "POST", path: "\(messages)/m1/trash", body: Data())])
    }

    private func stepSpamAddsTheSpamLabelAndLeavesTheInbox() async throws {
        RecordingGmail.reset()
        try await transport().markSpam(messageID: "m1")
        let call = try XCTUnwrap(RecordingGmail.calls.first)
        XCTAssertEqual(call.path, "\(messages)/m1/modify")
        XCTAssertEqual(try labels(call), ["addLabelIds": ["SPAM"], "removeLabelIds": ["INBOX"]])
    }

    private func stepMoveToALabelAddsItAndLeavesTheInbox() async throws {
        RecordingGmail.reset()
        try await transport().move(messageID: "m1", toFolderID: "Label_7")
        XCTAssertEqual(try labels(try XCTUnwrap(RecordingGmail.calls.first)), ["addLabelIds": ["Label_7"], "removeLabelIds": ["INBOX"]])
    }

    private func stepMoveToTheSystemFoldersFollowsTheirMeaning() async throws {
        RecordingGmail.reset()
        let transport = transport()
        try await transport.move(messageID: "m1", toFolderID: "TRASH")
        try await transport.move(messageID: "m1", toFolderID: "ALL")
        try await transport.move(messageID: "m1", toFolderID: "INBOX")
        let paths = RecordingGmail.calls.map(\.path)
        XCTAssertEqual(paths, ["\(messages)/m1/trash", "\(messages)/m1/modify", "\(messages)/m1/modify"])
        XCTAssertEqual(try labels(RecordingGmail.calls[1]), ["removeLabelIds": ["INBOX"]])
        XCTAssertEqual(try labels(RecordingGmail.calls[2]), ["addLabelIds": ["INBOX"]])
    }

    private func stepMoveIntoAFolderThatCannotHoldMailIsRefused() async {
        RecordingGmail.reset()
        do {
            try await transport().move(messageID: "m1", toFolderID: "SENT")
            XCTFail("move must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .folderNotFound("SENT"))
        }
        XCTAssertTrue(RecordingGmail.calls.isEmpty)
    }

    private func stepAttachmentIsDownloadedFromTheAttachmentEndpointAndDecoded() async throws {
        RecordingGmail.reset { _ in (200, #"{"data":"SGVsbG8h"}"#) }
        let data = try await transport().fetchAttachment(messageID: "m1", attachmentID: "a1")
        XCTAssertEqual(data, Data("Hello!".utf8))
        XCTAssertEqual(RecordingGmail.calls.first?.path, "\(messages)/m1/attachments/a1")
    }

    private func stepBodyCarriesTheAttachmentList() async throws {
        let parts = #"[{"mimeType":"text/plain","body":{"data":"aGk="}},{"mimeType":"application/pdf","filename":"a.pdf","body":{"attachmentId":"att1","size":42}}]"#
        RecordingGmail.reset { _ in (200, "{\"id\":\"m1\",\"payload\":{\"mimeType\":\"multipart/mixed\",\"parts\":\(parts)}}") }
        let body = try await transport().fetchBody(messageID: "m1")
        XCTAssertEqual(body.text, "hi")
        XCTAssertEqual(body.attachments, [MailAttachmentInfo(id: "att1", filename: "a.pdf", mimeType: "application/pdf", sizeBytes: 42)])
    }

    private func stepThreadReturnsEveryMessageOfTheThreadAsSummaries() async throws {
        let first = #"{"id":"m1","threadId":"t1","snippet":"one","labelIds":["INBOX"],"payload":{"headers":[{"name":"Subject","value":"Plan"}]}}"#
        let second = #"{"id":"m2","threadId":"t1","snippet":"two","labelIds":["INBOX","UNREAD"],"payload":{"headers":[{"name":"Subject","value":"Re: Plan"}]}}"#
        RecordingGmail.reset { _ in (200, "{\"messages\":[\(first),\(second)]}") }
        let thread = try await transport().fetchThread(messageID: "m2", threadID: "t1")
        XCTAssertEqual(thread.map(\.id), ["m1", "m2"])
        XCTAssertEqual(thread.map(\.subject), ["Plan", "Re: Plan"])
        XCTAssertEqual(thread[0].flags, [.seen])
        XCTAssertEqual(thread[1].flags, [])
        XCTAssertEqual(RecordingGmail.calls.first?.path, "/gmail/v1/users/me/threads/t1")
    }

    private func stepANewDraftIsCreatedAndAChangedOneIsUpdatedInPlace() async throws {
        RecordingGmail.reset { _ in (200, #"{"id":"d9"}"#) }
        let transport = transport()
        let draft = EmailDraft(to: "ann@x.test", subject: "Hi", body: "text")
        let created = try await transport.saveDraft(draft, replacing: nil)
        let updated = try await transport.saveDraft(draft, replacing: "d1")
        XCTAssertEqual(created, "d9")
        XCTAssertEqual(updated, "d9")
        XCTAssertEqual(RecordingGmail.calls.map { $0.method + " " + $0.path }, ["POST \(drafts)", "PUT \(drafts)/d1"])
    }

    private func stepDeletingADraftUsesTheDeleteVerb() async throws {
        RecordingGmail.reset()
        try await transport().deleteDraft(id: "d1")
        XCTAssertEqual(RecordingGmail.calls, [RecordingGmail.Call(method: "DELETE", path: "\(drafts)/d1", body: Data())])
    }

    private func stepSendingADraftPostsItsID() async throws {
        RecordingGmail.reset()
        try await transport().sendDraft(id: "d1")
        let call = try XCTUnwrap(RecordingGmail.calls.first)
        XCTAssertEqual(call.method + " " + call.path, "POST \(drafts)/send")
        XCTAssertEqual(try XCTUnwrap(JSONSerialization.jsonObject(with: call.body) as? [String: String]), ["id": "d1"])
    }

    private func stepAMessageOfTheDraftsFolderOpensItsDraftThroughTheDraftIDMap() async throws {
        let list = #"{"drafts":[{"id":"d1","message":{"id":"m5"}}]}"#
        let draft = #"{"id":"d1","message":{"id":"m5","threadId":"t5","payload":{"headers":[{"name":"To","value":"ann@x.test"},{"name":"Subject","value":"Plan"}],"mimeType":"text/plain","body":{"data":"aGk="}}}}"#
        RecordingGmail.reset { $0.path.hasSuffix("/d1") ? (200, draft) : (200, list) }
        let stored = try await transport().fetchDraft(messageID: "m5")
        XCTAssertEqual(stored.id, "d1")
        XCTAssertEqual(stored.draft.to, "ann@x.test")
        XCTAssertEqual(stored.draft.subject, "Plan")
        XCTAssertEqual(stored.draft.threadID, "t5")
    }

    private func stepAMessageThatIsNoDraftIsNotFoundAsOne() async {
        RecordingGmail.reset { _ in (200, #"{"drafts":[]}"#) }
        do {
            _ = try await transport().fetchDraft(messageID: "m5")
            XCTFail("fetchDraft must throw")
        } catch {
            XCTAssertEqual(error as? MailTransportError, .messageNotFound("m5"))
        }
    }

    private func stepAProviderRefusalSurfacesAsTheOriginalGoogleError() async {
        RecordingGmail.reset { _ in (403, #"{"error":{"code":403,"message":"Insufficient Permission","errors":[{"domain":"global","reason":"insufficientPermissions"}]}}"#) }
        do {
            try await transport().archive(messageID: "m1")
            XCTFail("archive must throw")
        } catch let error as GoogleGmailError {
            guard case .api(let fault) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(fault.status, 403)
            XCTAssertEqual(fault.reason, "insufficientPermissions")
        } catch {
            XCTFail("\(error)")
        }
    }

    func testTheGmailActions() async throws {
        try await stepArchiveRemovesTheInboxLabelOnly()
        try await stepTrashUsesTheTrashEndpoint()
        try await stepSpamAddsTheSpamLabelAndLeavesTheInbox()
        try await stepMoveToALabelAddsItAndLeavesTheInbox()
        try await stepMoveToTheSystemFoldersFollowsTheirMeaning()
        await stepMoveIntoAFolderThatCannotHoldMailIsRefused()
        try await stepAttachmentIsDownloadedFromTheAttachmentEndpointAndDecoded()
        try await stepBodyCarriesTheAttachmentList()
        try await stepThreadReturnsEveryMessageOfTheThreadAsSummaries()
        try await stepANewDraftIsCreatedAndAChangedOneIsUpdatedInPlace()
        try await stepDeletingADraftUsesTheDeleteVerb()
        try await stepSendingADraftPostsItsID()
        try await stepAMessageOfTheDraftsFolderOpensItsDraftThroughTheDraftIDMap()
        await stepAMessageThatIsNoDraftIsNotFoundAsOne()
        await stepAProviderRefusalSurfacesAsTheOriginalGoogleError()
    }
}
