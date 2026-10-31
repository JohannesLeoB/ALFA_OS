import Foundation
import Hub

@MainActor
public protocol MailboxPort: AnyObject {
    var accounts: [Inlet] { get }
    var events: AsyncStream<MailboxEvent> { get }
    var hasFiles: Bool { get }
    func folders(_ inlet: Inlet.ID) -> [Folder]
    func usesLabels(_ inlet: Inlet.ID) -> Bool
    func inboxOnly(_ inlet: Inlet.ID) -> Bool
    func sendLimit(_ inlet: Inlet.ID) async -> Int?
    func refreshFolders(_ inlet: Inlet.ID) async throws(HubFailure)
    func cached(_ inlet: Inlet.ID, folder: String) async -> [MessageSummary]
    func lastSync(_ inlet: Inlet.ID, folder: String) -> Date?
    func refresh(_ inlet: Inlet.ID, folder: String) async throws(HubFailure)
    func ranges(_ inlet: Inlet.ID) -> [MailboxRange]
    func rangeChanged(_ inlet: Inlet.ID) async
    func settleAttachments() async
    func moveAttachments(to folder: Data?, commit: @MainActor () -> Void) async -> Bool
    func canLoadOlder(_ inlet: Inlet.ID, folder: String) -> Bool
    func loadOlder(_ inlet: Inlet.ID, folder: String) async throws(HubFailure)
    func canSearchEverywhere(_ inlet: Inlet.ID) -> Bool
    func search(_ inlet: Inlet.ID, folder: String, query: String, scope: SearchScope,
                continuation: SearchContinuation?) async throws(HubFailure) -> SearchPage
    func searchLocal(_ inlet: Inlet.ID, query: String) -> [MessageSummary]
    func searchOpen(_ inlet: Inlet.ID, query: String, excluding folders: Set<String>) async -> [MessageSummary]
    func body(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> MessageBody
    func setFlags(_ inlet: Inlet.ID, messageID: String, add: Set<Flag>, remove: Set<Flag>) async throws(HubFailure)
    @discardableResult func archive(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> String?
    @discardableResult func move(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubFailure) -> String?
    @discardableResult func untrash(_ inlet: Inlet.ID, messageID: String, toFolder: String) async throws(HubFailure) -> String?
    @discardableResult func trash(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> String?
    @discardableResult func markSpam(_ inlet: Inlet.ID, messageID: String, locates: Bool) async throws(HubFailure) -> String?
    func canPurge(_ inlet: Inlet.ID) -> Bool
    func offersSource(_ inlet: Inlet.ID) -> Bool
    func source(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> Data
    func checkPurge(_ inlet: Inlet.ID) async
    func purge(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure)
    func attachment(_ inlet: Inlet.ID, messageID: String, attachmentID: String) async throws(HubFailure) -> Data
    func thread(_ inlet: Inlet.ID, messageID: String, threadID: String) async throws(HubFailure) -> [MessageSummary]
    func unreadCount(_ inlet: Inlet.ID) -> Int
    func unseenCount(_ inlet: Inlet.ID, folder: String) -> Int?
    func progress(_ inlet: Inlet.ID, folder: String) -> SyncProgress?
    func draftIDs(_ inlet: Inlet.ID) -> Set<String>
    func sender(_ inlet: Inlet.ID) -> Participant
    func knownSenders(_ inlet: Inlet.ID) -> [Participant]
    func senders(_ inlet: Inlet.ID) async -> [Participant]
    func projectFolders() async throws(HubFailure) -> [ProjectFolder]
    func listFiles(_ inlet: Inlet.ID, folder: String) async throws(HubFailure) -> [FileEntry]
    func readFile(_ inlet: Inlet.ID, fileID: String) async throws(HubFailure) -> Data
    func putFile(_ inlet: Inlet.ID, folder: String, name: String, mimeType: String, data: Data) async throws(HubFailure) -> FileEntry
}

@MainActor
public protocol OutboxPort: AnyObject {
    var outbox: [OutboxItem] { get }
    var unsavedCount: Int { get }
    var keptDrafts: [KeptDraft] { get }
    func keep(_ kept: KeptDraft)
    func dropKept(_ id: UUID)
    func resave()
    func saveDraft(_ inlet: Inlet.ID, _ draft: Draft, replacing previous: SavedDraft?) async throws(HubFailure) -> SavedDraft
    func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> StoredDraft
    func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubFailure)
    func send(_ inlet: Inlet.ID, _ draft: Draft) async -> SendOutcome
    func sendDraft(_ inlet: Inlet.ID, draftID: String, mirrorID: String?, _ draft: Draft) async -> SendOutcome
    func resend(_ id: OutboxItem.ID, _ draft: Draft, draftID: String?) async -> SendOutcome?
    func confirm(_ id: OutboxItem.ID) async
    @discardableResult func discard(_ id: OutboxItem.ID) -> Bool
    func revise(_ id: OutboxItem.ID, _ draft: Draft)
    func plan(_ inlet: Inlet.ID, _ draft: Draft, draftID: String?, mirrorID: String?, at date: Date) -> OutboxItem.ID
    func sendNow(_ id: OutboxItem.ID) async -> SendOutcome?
    func unplan(_ id: OutboxItem.ID) -> OutboxItem?
}
