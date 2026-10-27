public struct ListFolderTool: ToolPort {
    static let rowLimit = 30

    private let drive: any DrivePort

    public init(drive: any DrivePort) {
        self.drive = drive
    }

    public var name: String { "list_drive_folder" }
    public var access: ToolAccess { .read }
    public var privacy: PrivacyCategory { .drive }
    public var manifestID: String { "DRIVE_ASSISTANT_LIST" }
    public var focusNeed: FocusNeed { .driveFolder }
    public var parameters: [ToolParameter] { [ToolParameter("unterordner")] }

    public func run(_ input: ToolInput, scope: ToolScope) async -> ToolResult {
        guard let folderID = scope.driveFolderID else { return .failure("assistant.drive.noFolder") }
        let filter = input.text("unterordner").lowercased()
        do {
            var files = try await drive.list(folderID: folderID)
            var subfolder: String?
            if filter.isEmpty == false {
                guard let sub = files.first(where: { $0.isFolder && $0.name.lowercased().contains(filter) }) else {
                    let folders = files.filter(\.isFolder).map(\.name).joined(separator: ", ")
                    return ToolResult(.make("assistant.drive.subfolderMissing", filter, folders))
                }
                files = try await drive.list(folderID: sub.id)
                subfolder = sub.name
            }
            return format(files, subfolder: subfolder)
        } catch PortFailure.notConnected {
            return .failure("assistant.drive.notConnected")
        } catch {
            return .failure("assistant.drive.failed", PortFailure.detail(of: error))
        }
    }

    private func format(_ files: [DriveEntry], subfolder: String?) -> ToolResult {
        guard files.isEmpty == false else {
            return ToolResult(subfolder.map { .make("assistant.drive.emptySub", $0) } ?? .make("assistant.drive.emptyRoot"))
        }
        let header: Phrase = subfolder.map { .make("assistant.drive.headerSub", $0, String(files.count)) }
            ?? .make("assistant.drive.headerRoot", String(files.count))
        var lines = [header]
        for file in files.prefix(Self.rowLimit) {
            let day = file.modifiedAt.map { " \u{2014} " + ListingEngine.shortDay($0) } ?? ""
            lines.append(.raw("\u{2022} \(file.name) [\(file.typeLabel)]\(day)"))
        }
        if files.count > Self.rowLimit { lines.append(.make("assistant.drive.more", String(files.count - Self.rowLimit))) }
        return ToolResult(lines: lines)
    }
}
