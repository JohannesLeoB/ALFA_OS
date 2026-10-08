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

/// Migrations of old packages. Version 1 is the first, so there is no step yet.
/// Whoever changes the format raises `Board.formatVersion` and adds a step here.
public struct Migration: Sendable {
    public static let currentVersion = Board.formatVersion
    /// The migrations of this app.
    public static let standard = Migration()

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
