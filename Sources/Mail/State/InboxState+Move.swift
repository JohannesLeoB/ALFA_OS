import Foundation
import Hub

extension InboxState {
    func archive(_ id: String, undoable: Bool = true) async { await relocate(id, .archive, undoable: undoable) }

    func trash(_ id: String, undoable: Bool = true, fromMenu: Bool = false) async {
        guard !inTrash(id) else { return }
        await relocate(id, .trash, undoable: undoable, toast: fromMenu ? .inTrash : .trashed)
    }

    public func inTrash(_ id: String) -> Bool {
        guard let trash = folders.first(where: { $0.role == .trash })?.id else { return false }
        return summary(id)?.folderIDs.contains(trash) == true || (selectedFolder == trash && summaries.contains { $0.id == id })
    }

    func markSpam(_ id: String, undoable: Bool = true) async { await relocate(id, .spam, undoable: undoable) }

    func checkPurge() async {
        guard let inlet = selectedInlet, currentFolder?.role == .trash else { return }
        await mailbox.checkPurge(inlet)
        purgeChecks += 1
    }

    public func canPurge(_ id: String) -> Bool {
        _ = purgeChecks
        guard let inlet = selectedInlet, inTrash(id) else { return false }
        return mailbox.canPurge(inlet)
    }

    func purge(_ id: String) async {
        guard let inlet = selectedInlet, inTrash(id) else { return }
        do {
            try await mailbox.purge(inlet, messageID: id)
        } catch {
            post(.deleteFailed, undo: { [weak self] in
                guard self?.selectedInlet == inlet else { return }
                await self?.purge(id)
            })
            return
        }
        if selectedInlet == inlet { summaries.removeAll { $0.id == id } }
        drop(id, in: inlet)
        refreshCounts()
        post(.purged)
    }

    static func relocateFailure(_ move: MoveTarget) -> ToastKind {
        switch move {
        case .archive: .archiveFailed
        case .trash: .deleteFailed
        case .spam: .moveFailed
        }
    }

    func relocate(_ id: String, _ move: MoveTarget, undoable: Bool = false, toast: ToastKind = .trashed) async {
        guard let inlet = selectedInlet, let held = summary(id) else { return }
        let origin = Self.serverFolder(selectedFolder, of: held, in: folders, inboxFirst: move == .archive)
        let staysListed = move == .archive && folders.first { $0.id == selectedFolder }?.role == .all
        let lifted = lift([id], in: inlet, keepListed: staysListed)
        let opening = reopen(lifted.next)
        let landed: String?
        do {
            switch move {
            case .archive: landed = try await mailbox.archive(inlet, messageID: id)
            case .trash: landed = try await mailbox.trash(inlet, messageID: id)
            case .spam: landed = try await mailbox.markSpam(inlet, messageID: id, locates: undoable && origin != nil)
            }
        } catch {
            putBack(lifted.entries, in: inlet, folder: selectedFolder)
            await opening?.value
            post(Self.relocateFailure(move), undo: { [weak self] in
                guard self?.selectedInlet == inlet else { return }
                await self?.relocate(id, move, undoable: undoable, toast: toast)
            })
            return
        }
        refreshCounts()
        var undo: (@MainActor () async -> Void)?
        if undoable, let landed, let origin {
            undo = { [weak self] in await self?.restore([(id, landed, inlet, origin)], fromTrash: move == .trash) }
        }
        switch move {
        case .archive: post(.archived, undo: undo)
        case .trash: post(toast, undo: undo)
        case .spam: post(.moved, undo: undo)
        }
        await opening?.value
    }

    func lift(_ ids: [String], in inlet: Inlet.ID, keepListed: Bool = false) -> (entries: [(summary: MessageSummary, index: Int)], next: String?) {
        let gone = Set(ids)
        var next: String?
        if selectedInlet == inlet, let current = selectedMessage, gone.contains(current) {
            let order = rows.map(\.id)
            if let position = order.firstIndex(of: current) {
                next = order[position...].first { !gone.contains($0) } ?? order[..<position].last { !gone.contains($0) }
            }
        }
        var entries: [(summary: MessageSummary, index: Int)] = []
        if selectedInlet == inlet && !keepListed {
            for (index, item) in summaries.enumerated() where gone.contains(item.id) { entries.append((item, index)) }
            summaries.removeAll { gone.contains($0.id) }
        }
        for id in ids { drop(id, in: inlet) }
        return (entries, next)
    }

    func putBack(_ entries: [(summary: MessageSummary, index: Int)], in inlet: Inlet.ID, folder: String?) {
        guard selectedInlet == inlet, selectedFolder == folder else { return }
        for entry in entries.sorted(by: { $0.index < $1.index }) where !summaries.contains(where: { $0.id == entry.summary.id }) {
            summaries.insert(entry.summary, at: min(entry.index, summaries.count))
        }
    }

    func reopen(_ id: String?) -> Task<Void, Never>? {
        guard let id else { return nil }
        return Task { [weak self] in await self?.open(id) }
    }

    public var offersOriginal: Bool {
        selectedInlet.map { mailbox.offersSource($0) } ?? false
    }

    public var offersArchive: Bool {
        guard folderActions, let role = currentFolder?.role else { return folderActions }
        return ![.archive, .sent, .drafts].contains(role)
    }

    public var offersSpam: Bool {
        folderActions && currentFolder?.role != .spam && folders.contains { $0.role == .spam }
    }

    public func original(_ id: String) async -> String? {
        guard let inlet = selectedInlet else { return nil }
        do {
            let data = try await mailbox.source(inlet, messageID: id)
            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        } catch {
            post(.readFailed)
            return nil
        }
    }

    public func moveTargets(_ id: String) -> [Folder] {
        let current = Set(summary(id)?.folderIDs ?? []).union([selectedFolder].compactMap { $0 })
        return sortedFolders.filter { !current.contains($0.id) && !Self.fixedRoles.contains($0.role) }
    }

    func move(_ id: String, to folder: String) async {
        guard let inlet = selectedInlet, let held = summary(id) else { return }
        let origin = Self.serverFolder(selectedFolder, of: held, in: folders)
        let lifted = lift([id], in: inlet)
        let opening = reopen(lifted.next)
        let landed: String?
        do {
            landed = try await mailbox.move(inlet, messageID: id, toFolder: folder)
        } catch {
            putBack(lifted.entries, in: inlet, folder: selectedFolder)
            await opening?.value
            post(.moveFailed, undo: { [weak self] in
                guard self?.selectedInlet == inlet else { return }
                await self?.move(id, to: folder)
            })
            return
        }
        refreshCounts()
        var undo: (@MainActor () async -> Void)?
        if let landed, let origin {
            undo = { [weak self] in await self?.restore([(id, landed, inlet, origin)]) }
        }
        post(.moved, undo: undo)
        await opening?.value
    }

    private static let fixedRoles: Set<FolderRole> = [.drafts, .sent, .starred, .all]

    static func serverFolder(_ selected: String?, of summary: MessageSummary, in folders: [Folder] = [], inboxFirst: Bool = false) -> String? {
        let real = folders.filter { !$0.id.hasPrefix("local:") && $0.role != .all && $0.role != .starred }.map(\.id)
        guard !real.isEmpty else {
            guard let selected, selected.hasPrefix("local:") else { return selected }
            return summary.folderIDs.first { !$0.hasPrefix("local:") }
        }
        let inbox = folders.first { $0.role == .inbox }.map(\.id).flatMap { summary.folderIDs.contains($0) ? $0 : nil }
        if inboxFirst, let inbox { return inbox }
        if let selected, real.contains(selected) { return selected }
        let reachable = folders.filter { real.contains($0.id) && !fixedRoles.contains($0.role) }.map(\.id)
        return inbox ?? summary.folderIDs.first { reachable.contains($0) }
    }

    func restore(_ moved: [(id: String, landed: String?, inlet: Inlet.ID, origin: String?)], fromTrash: Bool = false) async {
        var failed = false
        for entry in moved {
            guard let landed = entry.landed, let target = entry.origin else { continue }
            do {
                if fromTrash {
                    _ = try await mailbox.untrash(entry.inlet, messageID: landed, toFolder: target)
                } else {
                    _ = try await mailbox.move(entry.inlet, messageID: landed, toFolder: target)
                }
            } catch {
                failed = true
            }
        }
        await loadSelection()
        if failed { post(.moveFailed) }
    }

    public func attachmentData(_ id: String, attachmentID: String) async -> Data? {
        guard let inlet = selectedInlet else { return nil }
        do {
            return try await mailbox.attachment(inlet, messageID: id, attachmentID: attachmentID)
        } catch {
            post(.attachmentFailed)
            return nil
        }
    }

    func loadThread(_ id: String) async {
        guard let inlet = selectedInlet, let summary = summary(id) else { return }
        let threadID = summary.threadID.isEmpty ? id : summary.threadID
        do {
            let messages = try await mailbox.thread(inlet, messageID: id, threadID: threadID)
            update(id, in: inlet) { $0.conversation = messages }
        } catch {
            post(.threadFailed, undo: { [weak self] in await self?.loadThread(id) })
        }
    }
}

extension InboxState {
    public var offersProjectFiles: Bool { mailbox.hasFiles }

    public func projectFolders() async -> [ProjectFolder]? {
        do {
            let list = try await mailbox.projectFolders()
            return list.sorted { $0.folder.name.localizedStandardCompare($1.folder.name) == .orderedAscending }
        } catch {
            return nil
        }
    }

    public func projectFiles(_ inlet: Inlet.ID, folder: String) async -> [FileEntry]? {
        guard let list = try? await mailbox.listFiles(inlet, folder: folder) else { return nil }
        return list.sorted { left, right in
            left.isFolder == right.isFolder ? left.name.localizedStandardCompare(right.name) == .orderedAscending : left.isFolder
        }
    }

    public func projectCounts(_ inlet: Inlet.ID, folders: [FileEntry]) async -> [String: Int] {
        var counts: [String: Int] = [:]
        for folder in folders where folder.isFolder {
            if let list = try? await mailbox.listFiles(inlet, folder: folder.id) { counts[folder.id] = list.count }
        }
        return counts
    }

    public func attachProjectFile(_ draft: UUID, inlet: Inlet.ID, file: FileEntry) async {
        guard let data = try? await mailbox.readFile(inlet, fileID: file.id) else {
            post(.attachmentFailed, undo: { [weak self] in await self?.attachProjectFile(draft, inlet: inlet, file: file) })
            return
        }
        attach(draft, filename: file.name, mimeType: file.mimeType, data: data)
    }

    public func mailDocument(_ id: String, render: (OpenMessage) -> Data?) async -> MessageDocument? {
        guard var card = card(id) else { return nil }
        let body: MessageBody
        do {
            body = try await mailbox.body(card.inlet, messageID: id)
        } catch {
            post(.pdfFailed)
            return nil
        }
        card.content = content(for: body, fallback: "")
        guard body.text != nil || body.html != nil, let data = render(card) else {
            post(.pdfFailed)
            return nil
        }
        let title = card.summary.subject.isEmpty ? card.id : card.summary.subject
        let name = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".pdf"
        return MessageDocument(name: name, data: data)
    }

    public func draftDocument(_ id: UUID, render: (OpenMessage) -> Data?) -> MessageDocument? {
        guard let card = draft(id) else { return nil }
        let sender = card.draft.from.map { $0.name.isEmpty ? $0.address : $0.name + " <" + $0.address + ">" } ?? ""
        let files = card.draft.attachments.map { AttachmentInfo(id: $0.id, filename: $0.filename, mimeType: $0.mimeType, sizeBytes: $0.data.count) }
        let summary = MessageSummary(id: id.uuidString, subject: card.draft.subject, from: sender, fromRaw: sender, toRaw: card.draft.to ?? "",
                                     ccRaw: card.draft.cc ?? "", receivedAt: clock(), attachments: files)
        guard let data = render(OpenMessage(inlet: card.inlet, summary: summary, content: .text(card.draft.body))) else {
            post(.pdfFailed)
            return nil
        }
        let title = card.draft.subject.isEmpty ? id.uuidString : card.draft.subject
        return MessageDocument(name: title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".pdf", data: data)
    }

    public func documentFailed(_ id: String) {
        post(.pdfFailed)
    }

    public func mailToProjectFolder(_ id: String, project: ProjectFolder, render: @escaping (OpenMessage) -> Data?) async {
        guard let document = await mailDocument(id, render: render) else { return }
        do {
            _ = try await mailbox.putFile(project.inlet, folder: project.folder.id, name: document.name,
                                          mimeType: "application/pdf", data: document.data)
        } catch {
            post(.projectSaveFailed, undo: { [weak self] in await self?.mailToProjectFolder(id, project: project, render: render) })
            return
        }
        post(.projectSaved(project.folder.name))
    }

    public func attachmentToProjectFolder(_ id: String, attachmentID: String, name: String, project: ProjectFolder) async {
        guard let data = await attachmentData(id, attachmentID: attachmentID) else { return }
        let mimeType = card(id)?.attachments.first { $0.id == attachmentID }?.mimeType ?? "application/octet-stream"
        do {
            _ = try await mailbox.putFile(project.inlet, folder: project.folder.id, name: name, mimeType: mimeType, data: data)
        } catch {
            post(.projectSaveFailed, undo: { [weak self] in
                await self?.attachmentToProjectFolder(id, attachmentID: attachmentID, name: name, project: project)
            })
            return
        }
        post(.attachmentCopied(project.folder.name))
    }
}

extension InboxState {
    public func settleAttachments() async {
        await mailbox.settleAttachments()
    }

    public func moveAttachments(to folder: Data?, commit: @MainActor () -> Void) async -> Bool {
        await mailbox.moveAttachments(to: folder, commit: commit)
    }
}
