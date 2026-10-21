import Foundation

struct CountingFilesPort: FilesPort {
    let base: any FilesPort
    let meter: CostMeter

    func projectFolders() async throws -> [FileFolder] {
        meter.record()
        return try await base.projectFolders()
    }

    func files(in folderID: String) async throws -> [FileEntry] {
        meter.record()
        return try await base.files(in: folderID)
    }

    func read(_ fileID: String) async throws -> Data {
        meter.record()
        let data = try await base.read(fileID)
        meter.record(calls: 0, bytes: data.count)
        return data
    }

    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry {
        meter.record()
        meter.record(calls: 0, bytes: data.count)
        return try await base.put(name: name, mimeType: mimeType, data: data, into: folderID)
    }
}

extension PortCatalog {
    public func withFiles() -> PortCatalog {
        var catalog = self
        catalog.register(
            (any FilesPort).self,
            capability: .files,
            wrap: { CountingFilesPort(base: $0, meter: $1) },
            sync: { port, inlet in
                let folders = try await port.projectFolders()
                let records = folders.map {
                    ProjectFolderRecord(id: inlet + "/" + $0.id, inlet: inlet, folderID: $0.id, name: $0.name)
                }
                return SyncOutcome(deliveries: [.files: records])
            }
        )
        return catalog
    }
}
