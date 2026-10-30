import Hub

@MainActor
public protocol OutboxPort: AnyObject {
    var outbox: [OutboxItem] { get }
    var unsavedCount: Int { get }
    func resave()
    func saveDraft(_ inlet: Inlet.ID, _ draft: Draft, replacing draftID: String?) async throws(HubFailure) -> SavedDraft
    func loadDraft(_ inlet: Inlet.ID, messageID: String) async throws(HubFailure) -> StoredDraft
    func deleteDraft(_ inlet: Inlet.ID, draftID: String) async throws(HubFailure)
    func send(_ inlet: Inlet.ID, _ draft: Draft) async -> SendOutcome
    func sendDraft(_ inlet: Inlet.ID, draftID: String, _ draft: Draft) async -> SendOutcome
    func resend(_ id: OutboxItem.ID, _ draft: Draft, draftID: String?) async -> SendOutcome?
    func confirm(_ id: OutboxItem.ID) async
    func discard(_ id: OutboxItem.ID)
    func revise(_ id: OutboxItem.ID, _ draft: Draft)
}
