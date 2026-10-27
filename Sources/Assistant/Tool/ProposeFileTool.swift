import Foundation

struct ProposeFileTool: ToolPort {
    private let artifacts: ArtifactStore
    private let projects: ProjectSearchEngine
    private let pdf: (any PdfRenderPort)?
    private let clock: @Sendable () -> Date

    init(artifacts: ArtifactStore, projects: ProjectSearchEngine, pdf: (any PdfRenderPort)? = nil,
         clock: @escaping @Sendable () -> Date = { Date() }) {
        self.artifacts = artifacts
        self.projects = projects
        self.pdf = pdf
        self.clock = clock
    }

    var name: String { "erzeuge_datei" }
    var access: ToolAccess { .write }
    var privacy: PrivacyCategory { .drive }
    var documented: Bool { false }
    var parameters: [ToolParameter] {
        [
            ToolParameter("dateiname", required: true), ToolParameter("format", required: true),
            ToolParameter("inhalt", required: true), ToolParameter("titel"), ToolParameter("projekt"),
        ]
    }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let fileName = input.text("dateiname")
        guard fileName.isEmpty == false else { return .failure("assistant.file.noName") }
        let rawFormat = input.text("format").lowercased()
        guard let format = FileDraft.Format(rawValue: rawFormat) else { return .failure("assistant.file.badFormat", rawFormat) }
        let content = input.values["inhalt"] ?? ""
        guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return .failure("assistant.file.empty")
        }
        var projectNumber: String?
        let wanted = input.text("projekt")
        if wanted.isEmpty == false {
            guard let match = projects.resolve(wanted) else { return .failure("assistant.file.noProjectMatch", wanted) }
            guard let folder = match.driveFolderID, folder.isEmpty == false else {
                return .failure("assistant.file.noProjectFolder", match.projectNumber)
            }
            projectNumber = match.projectNumber
        }
        let title = input.text("titel")
        var draft = FileDraft(fileName: fileName, format: format, title: title.isEmpty ? fileName : title,
                              content: content, projectNumber: projectNumber)
        let data: Data
        do {
            data = try await Self.data(for: draft, pdf: pdf)
        } catch PortFailure.notConnected {
            return .failure("assistant.file.noPdf")
        } catch {
            return .failure("assistant.file.writeFailed", error.localizedDescription)
        }
        do {
            draft.savedPath = try artifacts.write(data, name: draft.fullName, at: clock()).path
        } catch {
            return .failure("assistant.file.writeFailed", error.localizedDescription)
        }
        let line: Phrase = projectNumber.map { .make("assistant.file.savedProject", draft.fullName, $0) }
            ?? .make("assistant.file.saved", draft.fullName)
        return ToolResult(line, cards: [.fileDraft(draft)])
    }

    private static func data(for draft: FileDraft, pdf: (any PdfRenderPort)?) async throws -> Data {
        switch draft.format {
        case .text, .csv:
            return Data(draft.content.utf8)
        case .pdf:
            guard let pdf else { throw PortFailure.notConnected }
            return try await pdf.render(title: draft.title, rows: draft.rows)
        }
    }
}
