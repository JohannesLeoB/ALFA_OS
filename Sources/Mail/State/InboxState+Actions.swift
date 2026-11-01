import Foundation

extension InboxState {
    @discardableResult
    public func perform(_ action: Action, message id: String, undoable: Bool = false, fromMenu: Bool = false) -> Bool {
        switch action {
        case .reply: Task { _ = await reply(to: id) }
        case .replyAll: Task { _ = await reply(to: id, all: true) }
        case .forward: Task { _ = await forward(id) }
        case .archive: Task { await archive(id, undoable: undoable) }
        case .trash: Task { await trash(id, fromMenu: fromMenu) }
        case .markRead: Task { await setRead(id, true) }
        case .markUnread: Task { await setRead(id, false) }
        case .star: Task { await setStarred(id, true) }
        case .unstar: Task { await setStarred(id, false) }
        case .spam: Task { await markSpam(id, undoable: undoable) }
        case .openDraft: Task { _ = await editDraft(id) }
        case .loadImages: allowRemoteImages(id)
        case .purge: Task { await purge(id) }
        case .saveContact: if let kind = saveContact(from: id) { announce(kind) }
        default: return false
        }
        return true
    }

    public func startMove(_ id: String, to folder: String) {
        Task { await move(id, to: folder) }
    }

    @discardableResult
    public func perform(_ action: Action, name: String, address: String) -> Bool {
        switch action {
        case .writeMail:
            let entry = name.isEmpty ? address : "\"" + name + "\" <" + address + ">"
            _ = compose(to: entry)
        case .saveContact:
            announce(contacts.save(name: name, address: address))
        default:
            return false
        }
        return true
    }
}
