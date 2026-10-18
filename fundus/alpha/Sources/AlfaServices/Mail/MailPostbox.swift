import Foundation
import AlfaKit

public protocol MailPostbox: GoogleGmailFetching, GoogleGmailWriting, GoogleGmailDraftEditing, GoogleGmailLabelModifying {
    func fetchMessage(messageID: String) async throws -> GoogleGmailMessage

    func fetchHistory(startHistoryId: String) async throws -> GmailHistoryDelta

    func deleteDraft(id: String) async throws

    func listLabelsWithColors() async throws -> [GmailLabel]
}

extension GoogleGmailClient: MailPostbox {}

public enum MailPostboxes {
    public static func current() -> any MailPostbox {
        GmailAccess.client()
    }
}
