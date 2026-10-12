import Foundation

public enum ZipArchiver {
    public enum ZipFehler: Error, Equatable {
        case isEmpty
        case koordination
    }

    public static func zip(files: [(name: String, data: Data)]) throws -> URL {
        try bündele { folder in
            var namen = Set<String>()
            for d in files {
                let name = eindeutig(d.name, in: &namen)
                try d.data.write(to: folder.appendingPathComponent(name))
            }
        }
    }

    public static func zip(sources: [URL]) throws -> (url: URL, gebündelt: Int, uebersprungen: Int) {
        var gebündelt = 0, uebersprungen = 0
        let url = try bündele { folder in
            var namen = Set<String>()
            for q in sources {
                guard FileManager.default.fileExists(atPath: q.path) else { uebersprungen += 1; continue }
                let name = eindeutig(q.lastPathComponent, in: &namen)
                do {
                    try FileManager.default.copyItem(at: q, to: folder.appendingPathComponent(name))
                    gebündelt += 1
                } catch {
                    uebersprungen += 1
                }
            }
        }
        return (url, gebündelt, uebersprungen)
    }

    private static func bündele(_ fuellen: (URL) throws -> Void) throws -> URL {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }

        try fuellen(folder)
        let content = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        guard content.isEmpty == false else { throw ZipFehler.isEmpty }

        var zipSource: URL?
        var koordFehler: NSError?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &koordFehler) { gezippt in
            let target = fm.temporaryDirectory.appendingPathComponent("zip-\(UUID().uuidString).zip")
            if (try? fm.copyItem(at: gezippt, to: target)) != nil { zipSource = target }
        }
        guard koordFehler == nil, let zipSource else { throw ZipFehler.koordination }
        return zipSource
    }

    private static func eindeutig(_ name: String, in namen: inout Set<String>) -> String {
        guard namen.contains(name) else { namen.insert(name); return name }
        let ext = (name as NSString).pathExtension
        let basis = (name as NSString).deletingPathExtension
        var i = 1
        var kandidat: String
        repeat {
            kandidat = ext.isEmpty ? "\(basis)-\(i)" : "\(basis)-\(i).\(ext)"
            i += 1
        } while namen.contains(kandidat)
        namen.insert(kandidat)
        return kandidat
    }
}
