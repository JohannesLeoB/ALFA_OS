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

    func setProgress(_ inlet: Inlet.ID, _ folder: String, _ value: SyncProgress, reporter: SyncReporter) {
        progresses[Self.key(inlet, folder)] = value
        let prefix = inlet + "\n"
        let current = progresses.filter { $0.key.hasPrefix(prefix) }.values
        let finished = fetched[inlet] ?? SyncProgress(done: 0, total: 0)
        reporter(done: finished.done + current.reduce(0) { $0 + $1.done }, total: finished.total + current.reduce(0) { $0 + $1.total })
        eventBus.emit(.progress(inlet, folder: folder))
    }

    func endProgress(_ inlet: Inlet.ID, _ folder: String) {
        guard let ended = progresses.removeValue(forKey: Self.key(inlet, folder)) else { return }
        let finished = fetched[inlet] ?? SyncProgress(done: 0, total: 0)
        fetched[inlet] = SyncProgress(done: finished.done + ended.done, total: finished.total + ended.total)
        eventBus.emit(.progress(inlet, folder: folder))
    }

    func countUnmirrored(_ inlet: Inlet.ID) async {
        guard let transport = try? transport(inlet) else { return }
        for folder in Self.folders(database, inlet) where FolderRole.countedRoles.contains(folder.role) {
            await storeCount(inlet, folder.id, transport)
            announceChange(inlet, folder.id)
        }
    }

    func storeCount(_ inlet: Inlet.ID, _ folder: String, _ transport: any MailTransportPort) async {
        guard let port = transport as? any UnseenCountPort, !Task.isCancelled,
              let count = try? await port.unseen(folderID: folder) else { return }
        let text = CountEngine.encode(count, local: localUnseen(inlet, folder))
        try? setCursor(inlet, Self.countKey(folder), text)
    }
}
