import Foundation

public enum DriveLocalResolver {
    public static let xattrName = "com.google.drivefs.item-id#S"

    public static func driveItemID(at url: URL) -> String? {
        let path = url.path
        let size = getxattr(path, xattrName, nil, 0, 0, 0)
        guard size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        let read = getxattr(path, xattrName, &buffer, size, 0, 0)
        guard read == size else { return nil }
        return String(bytes: buffer, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
    }

    public static func firstChild(of directory: URL, withItemID itemID: String) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else { return nil }
        return items.first { driveItemID(at: $0) == itemID }
    }

    public static func find(itemID: String,
                            in root: URL,
                            fileName: String? = nil,
                            maxDepth: Int = 6) -> URL? {
        var nameFallback: URL?

        func walk(_ directory: URL, depth: Int) -> URL? {
            guard depth <= maxDepth,
                  let items = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: .skipsHiddenFiles
                  ) else { return nil }
            for item in items {
                if driveItemID(at: item) == itemID { return item }
                if let fileName, nameFallback == nil,
                   item.lastPathComponent == fileName { nameFallback = item }
            }

            for item in items {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir, let hit = walk(item, depth: depth + 1) { return hit }
            }
            return nil
        }

        return walk(root, depth: 0) ?? nameFallback
    }
}
