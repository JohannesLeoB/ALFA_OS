import Foundation
import Observation

@MainActor @Observable
public final class ExportState {
    public private(set) var running = false

    @ObservationIgnored private let port: any ExportPort

    public init(port: any ExportPort = ExportStore()) {
        self.port = port
    }

    public var canRun: Bool { port.isAvailable }

    public var fileName: String { ExportEngine.fileName(at: Date()) }

    public func run(to url: URL) async -> Bool {
        guard !running else { return false }
        running = true
        defer { running = false }
        let port = self.port
        let now = Date()
        return await Task.detached(priority: .utility) { () -> Bool in
            do {
                let source = try port.collect(at: now)
                let archive = try ArchiveEngine.archive(ExportEngine.files(from: source), at: now)
                try port.save(archive, to: url)
                return true
            } catch {
                return false
            }
        }.value
    }
}
