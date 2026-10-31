import Foundation
import Hub

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
    func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: Draft) async -> SendOutcome
    func resend(_ id: OutboxItem.ID, _ draft: Draft, draftID: String?) async -> SendOutcome?
    func confirm(_ id: OutboxItem.ID) async
    @discardableResult func discard(_ id: OutboxItem.ID) -> Bool
    func revise(_ id: OutboxItem.ID, _ draft: Draft)
    func plan(_ inlet: Inlet.ID, _ draft: Draft, draftID: String?, mirrorID: String?, at date: Date) -> OutboxItem.ID
    func sendNow(_ id: OutboxItem.ID) async -> SendOutcome?
    func unplan(_ id: OutboxItem.ID) -> OutboxItem?
}
