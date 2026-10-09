import Foundation
import ALFAcolorCore

/// Errors when reading or writing a package. The messages are for the user and say what to do.
public enum PackageError: Error, Equatable, Sendable {
    /// A single file was read instead of a folder.
    case notAPackage
    case missingFile(path: String)
    case corruptFile(path: String, reason: String)
    /// The package comes from a newer version than this app knows.
    case unknownFormatVersion(Int)
    /// The migration step between two versions is missing.
    case missingMigration(from: Int, to: Int)
    /// An ID or name does not work as a file name (empty, too long).
    case invalidIdentifier(String)
    /// Two spaces, layers or token sets have the same name, or differ only in case.
    case duplicateIdentifier(kind: String, id: String)
    /// An item refers to a layer that does not exist in the space.
    case itemWithoutLayer(item: String, layer: String, space: String)
    /// A carried path is not allowed or collides with a file that the package writes itself.
    case invalidPath(String)
    /// A token cannot be placed in the DTCG tree (empty path, "$" name, leaf and group at the same place).
    case invalidToken(String)
    case writeFailed(reason: String)
    /// The package cannot be opened (missing, no permission).
    case unreadable(reason: String)
}

extension PackageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAPackage: String(localized: "package.error.notAPackage")
        case .missingFile(let p): String(localized: "package.error.missingFile \(p)")
        case .corruptFile(let p, let r): String(localized: "package.error.corruptFile \(p) \(r)")
        case .unknownFormatVersion(let v): String(localized: "package.error.unknownFormatVersion \(v) \(Migration.currentVersion)")
        case .missingMigration(let a, let b): String(localized: "package.error.missingMigration \(a) \(b)")
        case .invalidIdentifier(let s): String(localized: "package.error.invalidIdentifier \(s)")
        case .duplicateIdentifier(let k, let id): String(localized: "package.error.duplicateIdentifier \(Self.kindName(k)) \(id)")
        case .itemWithoutLayer(let i, let l, let s): String(localized: "package.error.itemWithoutLayer \(i) \(s) \(l)")
        case .invalidPath(let p): String(localized: "package.error.invalidPath \(p)")
        case .invalidToken(let t): String(localized: "package.error.invalidToken \(t)")
        case .writeFailed(let r): String(localized: "package.error.writeFailed \(r)")
        case .unreadable(let r): String(localized: "package.error.unreadable \(r)")
        }
    }

    /// The display name of an identifier kind. Unknown kinds are shown as they are.
    private static func kindName(_ kind: String) -> String {
        switch kind {
        case "space": String(localized: "package.kind.space")
        case "layer": String(localized: "package.kind.layer")
        case "tokenSet": String(localized: "package.kind.tokenSet")
        default: kind
        }
    }
}

/// What reading notices without preventing the open.
public struct ReadReport: Equatable, Sendable {
    public struct MissingAsset: Equatable, Sendable {
        public var assetID: String
        public var itemID: ItemID
        public var spaceID: String
    }
    /// Format version as it was on disk (before a migration).
    public var formatVersionOnDisk: Int = 0
    /// Set when reading migrated: the starting version.
    public var migratedFrom: Int?
    public var writtenByAppVersion: String?
    /// Images that an item refers to and whose file is missing from the package.
    public var missingAssets: [MissingAsset] = []
    /// Only with `ReadOptions.verifyAssetHashes`: files whose content does not match their hash name.
    public var corruptAssets: [String] = []
    /// Files in `assets/` that no item uses. They stay in the package.
    public var unreferencedAssets: [String] = []
    public var warnings: [String] = []
    public var isClean: Bool { missingAssets.isEmpty && corruptAssets.isEmpty && warnings.isEmpty }
}

extension ReadReport {
    /// The notice for the status bar: the first warning, else the count of missing images. nil when there is nothing to say.
    public var statusNotice: String? {
        if let warning = warnings.first { return warning }
        if !missingAssets.isEmpty { return String(localized: "package.warning.missingAssets \(missingAssets.count)") }
        return nil
    }
}

public struct ReadOptions: Sendable {
    /// Recompute the hash of every asset file. This costs time depending on the number of images, so it is off by default.
    public var verifyAssetHashes: Bool
    public init(verifyAssetHashes: Bool = false) { self.verifyAssetHashes = verifyAssetHashes }
}

public struct DocumentReadResult: Sendable {
    public var document: ALFAcolorDocument
    public var report: ReadReport
}
