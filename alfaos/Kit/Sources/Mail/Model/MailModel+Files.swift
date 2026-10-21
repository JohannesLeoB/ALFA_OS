import Foundation
import Hub
import struct AlfaServices.MailMessageBody

extension MailModel {
    public func projectFolders(for draft: UUID) async -> [ProjectFolderRecord] {
        await projects(key: draft.uuidString)
    }

    public func projectFiles(_ inlet: Inlet.ID, folder: String, for draft: UUID) async -> [FileEntry] {
        let key = draft.uuidString
        do {
            let list = try await engine.listFiles(inlet, folder: folder)
            actionFailures[key] = nil
            return list.sorted { left, right in
                left.isFolder == right.isFolder ? left.name.localizedStandardCompare(right.name) == .orderedAscending : left.isFolder
            }
        } catch {
            actionFailures[key] = Self.hint(error)
            return []
        }
    }

    public func attachProjectFile(_ draft: UUID, inlet: Inlet.ID, file: FileEntry) async {
        let key = draft.uuidString
        do {
            let data = try await engine.readFile(inlet, fileID: file.id)
            actionFailures[key] = nil
            attach(draft, filename: file.name, mimeType: file.mimeType, data: data)
        } catch {
            actionFailures[key] = Self.hint(error)
        }
    }

    public func projectFolders(forMessage id: String) async -> [ProjectFolderRecord] {
        await projects(key: id)
    }

    public func mailToProjectFolder(_ id: String, project: ProjectFolderRecord, render: (ReadingCard) -> Data?) async {
        guard var card = card(id) else { return }
        let body: MailMessageBody
        do {
            body = try await engine.body(card.inlet, messageID: id)
        } catch {
            actionFailures[id] = Self.hint(error)
            return
        }
        card.content = content(for: body, fallback: "")
        guard body.text != nil || body.html != nil, let data = render(card) else {
            actionFailures[id] = Hint(text: MailTextKey.failed.rawValue, detail: id)
            return
        }
        let title = card.summary.subject.isEmpty ? card.id : card.summary.subject
        let name = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") + ".pdf"
        do {
            _ = try await engine.putFile(project.inlet, folder: project.folderID, name: name, mimeType: "application/pdf", data: data)
        } catch {
            actionFailures[id] = Self.hint(error)
            return
        }
        actionFailures[id] = nil
        post(.projectSaved)
    }

    private func projects(key: String) async -> [ProjectFolderRecord] {
        do {
            let list = try await engine.projectFolders()
            actionFailures[key] = nil
            return list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            actionFailures[key] = Self.hint(error)
            return []
        }
    }
}
