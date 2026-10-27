import Foundation

struct MeteredFiles: FilesPort {
    let wrapped: any FilesPort
    let meter: CostMeter

    func projectFolders() async throws -> [FileFolder] {
        meter.record()
        return try await wrapped.projectFolders()
    }

    func files(in folderID: String) async throws -> [FileEntry] {
        meter.record()
        return try await wrapped.files(in: folderID)
    }

    func read(_ fileID: String) async throws -> Data {
        meter.record()
        let data = try await wrapped.read(fileID)
        meter.record(calls: 0, bytes: data.count)
        return data
    }

    func put(name: String, mimeType: String, data: Data, into folderID: String) async throws -> FileEntry {
        meter.record()
        meter.record(calls: 0, bytes: data.count)
        return try await wrapped.put(name: name, mimeType: mimeType, data: data, into: folderID)
    }
}

extension PortRegistry {
    public func withFiles() -> PortRegistry {
        var registry = self
        registry.register(
            (any FilesPort).self,
            capability: .files,
            wrap: { MeteredFiles(wrapped: $0, meter: $1) },
            sync: { port, inlet in
                let folders = try await port.projectFolders()
                return SyncOutcome(deliveries: [.files: folders.map { ProjectFolder(inlet: inlet, folder: $0) }])
            }
        )
        return registry
    }
}
