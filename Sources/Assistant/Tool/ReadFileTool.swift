struct ReadFileTool: ToolPort {
    private let drive: any DrivePort
    private let projects: ProjectSearchEngine

    init(drive: any DrivePort, projects: ProjectSearchEngine) {
        self.drive = drive
        self.projects = projects
    }

    var name: String { "read_drive_file" }
    var access: ToolAccess { .read }
    var privacy: PrivacyCategory { .drive }
    var manifestID: String { "DRIVE_FILE_READ" }
    var parameters: [ToolParameter] { [ToolParameter("datei", required: true), ToolParameter("projekt")] }

    func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        let fileName = input.text("datei")
        guard fileName.isEmpty == false else { return .failure("assistant.file.whichFile") }
        var folderID = scope.driveFolderID ?? ""
        let query = input.text("projekt")
        if query.isEmpty == false, let folder = projects.resolve(query)?.driveFolderID, folder.isEmpty == false {
            folderID = folder
        } else if folderID.isEmpty {
            return .failure("assistant.file.noProject")
        }
        do {
            guard let file = try await drive.findFile(named: fileName, in: folderID) else {
                return .failure("assistant.file.notFound", fileName)
            }
            guard let text = try await drive.text(of: file) else {
                return ToolResult(.make("assistant.file.noText", file.name))
            }
            return ToolResult(lines: [.make("assistant.file.content", file.name), .raw(""), .raw(text)])
        } catch PortFailure.notConnected {
            return .failure("assistant.file.noAccess")
        } catch {
            return .failure("assistant.file.readFailed", PortFailure.detail(of: error))
        }
    }
}
