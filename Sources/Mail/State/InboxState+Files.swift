import Foundation
import Hub

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
