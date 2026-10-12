import Foundation
import ALFAcolorCore

/// All files of a package as path to bytes. Paths are relative and separated by "/".
public typealias PackageFiles = [String: Data]

/// A step lifts a package from `fromVersion` to `toVersion` (always exactly one higher). It changes only files in `files`.
/// `Migration` sets the format version in the manifest after each step.
public protocol MigrationStep: Sendable {
    var fromVersion: Int { get }
    var toVersion: Int { get }
    func apply(to files: inout PackageFiles) throws
}

/// Migrations of old packages.
/// Whoever changes the format raises `Board.formatVersion` and adds a step here.
public struct Migration: Sendable {
    public static let currentVersion = Board.formatVersion
    /// The migrations of this app.
    public static let standard = Migration(steps: [VersionTwoStep()])

    public let currentVersion: Int
    public let steps: [any MigrationStep]

    public init(currentVersion: Int = Migration.currentVersion, steps: [any MigrationStep] = []) {
        self.currentVersion = currentVersion
        self.steps = steps
    }

    /// Lifts the files from version `from` to `to`. Equal versions change nothing.
    /// Newer than known or backwards is an error, and so is a gap in the step sequence.
    public func migrate(_ files: PackageFiles, from: Int, to: Int) throws -> PackageFiles {
        guard from <= to, to <= currentVersion else { throw PackageError.unknownFormatVersion(from > to ? from : to) }
        var files = files
        var version = from
        while version < to {
            guard let step = steps.first(where: { $0.fromVersion == version }), step.toVersion == version + 1, step.toVersion <= to else {
                throw PackageError.missingMigration(from: version, to: version + 1)
            }
            try step.apply(to: &files)
            version = step.toVersion
            try Self.setManifestVersion(&files, version)
        }
        return files
    }

    static func setManifestVersion(_ files: inout PackageFiles, _ version: Int) throws {
        guard let data = files["manifest.json"] else { throw PackageError.missingFile(path: "manifest.json") }
        guard case .object(var manifest)? = try? PackageJSON.decoder().decode(JSONValue.self, from: data) else {
            throw PackageError.corruptFile(path: "manifest.json", reason: String(localized: "package.reason.notJSONObject"))
        }
        manifest["formatVersion"] = .int(version)
        files["manifest.json"] = try PackageJSON.data(JSONValue.object(manifest))
    }
}

/// Version 1 to 2.
/// - Item IDs were objects (`{"raw": "x"}`) and are now plain strings.
/// - The manifest gets a document ID and a creation time. Version 1 did not store them, so a migrated
///   document gets a new ID and the time of the migration. Both stay the same on later saves.
public struct VersionTwoStep: MigrationStep {
    public let fromVersion = 1
    public let toVersion = 2
    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    public init(makeID: @escaping @Sendable () -> UUID = { UUID() }, now: @escaping @Sendable () -> Date = { Board.currentTime() }) {
        self.makeID = makeID
        self.now = now
    }

    public func apply(to files: inout PackageFiles) throws {
        guard var manifest = try object(files["manifest.json"], path: "manifest.json") else { throw PackageError.missingFile(path: "manifest.json") }
        if manifest["documentID"] == nil { manifest["documentID"] = .string(makeID().uuidString) }
        if manifest["createdAt"] == nil, let text = ISODate.string(from: now()) { manifest["createdAt"] = .string(text) }
        files["manifest.json"] = try PackageJSON.data(JSONValue.object(manifest))

        for path in files.keys.sorted() {
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            let isSpace = parts.count == 3 && parts[0] == "spaces" && parts[2] == "space.json"
            let isLayer = parts.count == 4 && parts[0] == "spaces" && parts[2] == "layers" && path.hasSuffix(".json")
            guard isSpace || isLayer, var file = try object(files[path], path: path) else { continue }
            file["schema"] = .int(toVersion)
            if isLayer, case .array(let items)? = file["items"] {
                file["items"] = .array(try items.map { try plainID($0, path: path) })
            }
            files[path] = try PackageJSON.data(JSONValue.object(file))
        }
    }

    private func object(_ data: Data?, path: String) throws -> [String: JSONValue]? {
        guard let data else { return nil }
        guard case .object(let o)? = try? PackageJSON.decoder().decode(JSONValue.self, from: data) else {
            throw PackageError.corruptFile(path: path, reason: String(localized: "package.reason.notJSONObject"))
        }
        return o
    }

    /// Replaces `"id": {"raw": "x"}` by `"id": "x"`. Any other form stays as it is.
    private func plainID(_ item: JSONValue, path: String) throws -> JSONValue {
        guard case .object(var fields) = item, case .object(let old)? = fields["id"] else { return item }
        let field = "raw"
        guard case .string(let raw)? = old[field] else {
            throw PackageError.corruptFile(path: path, reason: String(localized: "package.reason.missingField \(field)"))
        }
        fields["id"] = .string(raw)
        return .object(fields)
    }
}
