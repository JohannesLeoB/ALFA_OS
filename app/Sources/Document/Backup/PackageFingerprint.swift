import Foundation

/// A content checksum of a package folder: the relative path and the SHA-256 of every regular file, in path order.
/// Two packages with the same fingerprint hold the same files with the same bytes.
enum PackageFingerprint {
    static func of(_ package: URL) throws -> String {
        let base = package.standardizedFileURL.path
        guard let walker = FileManager.default.enumerator(at: package, includingPropertiesForKeys: [.isRegularFileKey],
                                                          options: []) else {
            throw BackupError.sourceMissing
        }
        var lines: [String] = []
        for case let file as URL in walker {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let path = file.standardizedFileURL.path
            let relative = String(path.dropFirst(base.count + 1))
            let digest = AssetStore.hash(of: try Data(contentsOf: file))
            lines.append("\(relative)\t\(digest)")
        }
        lines.sort()
        return AssetStore.hash(of: Data(lines.joined(separator: "\n").utf8))
    }
}
