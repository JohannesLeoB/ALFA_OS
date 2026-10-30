import Foundation
import Hub

extension InboxState {
    public func projectFolders(for draft: UUID) async -> [ProjectFolder] {
        await projects(key: draft.uuidString)
    }

    public func projectFolders(forMessage id: String) async -> [ProjectFolder] {
        await projects(key: id)
    }

    public func projectFiles(_ inlet: Inlet.ID, folder: String) async -> [FileEntry] {
        guard let list = try? await mailbox.listFiles(inlet, folder: folder) else { return [] }
        return list.sorted { left, right in
            left.isFolder == right.isFolder ? left.name.localizedStandardCompare(right.name) == .orderedAscending : left.isFolder
        }
    }

    public func attachProjectFile(_ draft: UUID, inlet: Inlet.ID, file: FileEntry) async {
        if let data = try? await mailbox.readFile(inlet, fileID: file.id) {
            attach(draft, filename: file.name, mimeType: file.mimeType, data: data)
        }
    }

    public func mailDocument(_ id: String, render: (OpenMessage) -> Data?) async -> MessageDocument? {
        guard var card = card(id) else { return nil }
        let body: MessageBody
        do {
            body = try await mailbox.body(card.inlet, messageID: id)
        } catch {
            return nil
        }
        card.content = content(for: body, fallback: "")
        guard body.text != nil || body.html != nil, let data = render(card) else {
            return nil
        }
        let title = card.summary.subject.isEmpty ? card.id : card.summary.subject
        let name = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".pdf"
        return MessageDocument(name: name, data: data)
    }

    public func documentFailed(_ id: String) {
    }

    public func mailToProjectFolder(_ id: String, project: ProjectFolder, render: (OpenMessage) -> Data?) async {
        guard let document = await mailDocument(id, render: render) else { return }
        do {
            _ = try await mailbox.putFile(project.inlet, folder: project.folder.id, name: document.name,
                                          mimeType: "application/pdf", data: document.data)
        } catch {
            return
        }
        post(.projectSaved)
    }

    public func attachmentToProjectFolder(_ id: String, attachmentID: String, name: String, project: ProjectFolder) async {
        guard let data = await attachmentData(id, attachmentID: attachmentID) else { return }
        let mimeType = card(id)?.attachments.first { $0.id == attachmentID }?.mimeType ?? "application/octet-stream"
        do {
            _ = try await mailbox.putFile(project.inlet, folder: project.folder.id, name: name, mimeType: mimeType, data: data)
        } catch {
            return
        }
        post(.projectSaved)
    }

    private func projects(key: String) async -> [ProjectFolder] {
        do {
            let list = try await mailbox.projectFolders()
            return list.sorted { $0.folder.name.localizedStandardCompare($1.folder.name) == .orderedAscending }
        } catch {
            return []
        }
    }
}
