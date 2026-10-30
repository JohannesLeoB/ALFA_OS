import Foundation
import Hub

extension MailboxStore {
    public func unseenCount(_ inlet: Inlet.ID, folder: String) -> Int? {
        guard let text = cursor(inlet, Self.countKey(folder)), let cached = CountEngine.decode(text) else { return nil }
        return CountEngine.shown(cached, local: localUnseen(inlet, folder))
    }

    public func progress(_ inlet: Inlet.ID, folder: String) -> SyncProgress? {
        progresses[Self.key(inlet, folder)]
    }

    func setProgress(_ inlet: Inlet.ID, _ folder: String, _ value: SyncProgress) {
        progresses[Self.key(inlet, folder)] = value
        eventBus.emit(.progress(inlet, folder: folder))
    }

    func endProgress(_ inlet: Inlet.ID, _ folder: String) {
        guard progresses.removeValue(forKey: Self.key(inlet, folder)) != nil else { return }
        eventBus.emit(.progress(inlet, folder: folder))
    }

    func countUnmirrored(_ inlet: Inlet.ID) async {
        guard let transport = try? transport(inlet) else { return }
        for role in FolderRole.unseenRoles {
            guard let folder = folderID(inlet, role: role) else { continue }
            await storeCount(inlet, folder, transport)
            eventBus.emit(.messagesChanged(inlet, folder: folder))
        }
    }

    func storeCount(_ inlet: Inlet.ID, _ folder: String, _ transport: any MailTransportPort) async {
        guard let port = transport as? any UnseenCountPort, !Task.isCancelled,
              let count = try? await port.unseen(folderID: folder) else { return }
        let text = CountEngine.encode(count, local: localUnseen(inlet, folder))
        try? setCursor(inlet, Self.countKey(folder), text)
    }
}
