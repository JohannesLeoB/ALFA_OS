@MainActor
public struct ActionRouter {
    private let state: InboxState

    public init(state: InboxState) {
        self.state = state
    }

    @discardableResult
    public func message(_ action: Action, _ id: String, undoable: Bool = false, fromMenu: Bool = false) -> Bool {
        switch action {
        case .reply: Task { _ = await state.reply(to: id) }
        case .replyAll: Task { _ = await state.reply(to: id, all: true) }
        case .forward: Task { _ = await state.forward(id) }
        case .archive: Task { await state.archive(id, undoable: undoable) }
        case .trash: Task { await state.trash(id, fromMenu: fromMenu) }
        case .markRead: Task { await state.setRead(id, true) }
        case .markUnread: Task { await state.setRead(id, false) }
        case .star: Task { await state.setStarred(id, true) }
        case .unstar: Task { await state.setStarred(id, false) }
        case .spam: Task { await state.markSpam(id, undoable: undoable) }
        case .openDraft: Task { _ = await state.editDraft(id) }
        case .loadImages: state.allowRemoteImages(id)
        case .purge: Task { await state.purge(id) }
        case .saveContact: if let kind = state.saveContact(from: id) { state.announce(kind) }
        default: return false
        }
        return true
    }

    public func move(_ id: String, to folder: String) {
        Task { await state.move(id, to: folder) }
    }

    @discardableResult
    public func person(_ action: Action, name: String, address: String) -> Bool {
        switch action {
        case .writeMail:
            let entry = name.isEmpty ? address : "\"" + name + "\" <" + address + ">"
            _ = state.compose(to: entry)
        case .saveContact:
            state.announce(state.contacts.save(name: name, address: address))
        default:
            return false
        }
        return true
    }
}
