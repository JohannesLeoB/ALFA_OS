import Foundation
import Hub

extension InboxState {
    public func settleAttachments() async {
        await mailbox.settleAttachments()
    }

    public func moveAttachments(to folder: Data?, commit: @MainActor () -> Void) async -> Bool {
        await mailbox.moveAttachments(to: folder, commit: commit)
    }
}
