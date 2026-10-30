import Foundation
import Hub

public struct KeptDraft: Equatable, Sendable {
    public var id: UUID
    public var inlet: Inlet.ID
    public var draft: Draft
    public var remoteID: String?
    public var mirrorID: String?
    public var updatedAt: Date

    public init(id: UUID, inlet: Inlet.ID, draft: Draft, remoteID: String?, mirrorID: String?, updatedAt: Date) {
        self.id = id
        self.inlet = inlet
        self.draft = draft
        self.remoteID = remoteID
        self.mirrorID = mirrorID
        self.updatedAt = updatedAt
    }
}
