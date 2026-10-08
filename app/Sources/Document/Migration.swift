import Foundation
import SetzkastenCore

/// Alle Dateien eines Pakets außer dem Manifest-Rahmen als Pfad -> Bytes. Pfade relativ, mit "/" getrennt.
public typealias PackageFiles = [String: Data]

/// Ein Schritt hebt ein Paket von `fromVersion` auf `toVersion` (immer genau eins höher). Er ändert nur Dateien in `files`;
/// die Formatversion im Manifest setzt `Migration` selbst nach jedem Schritt.
public protocol MigrationStep: Sendable {
    var fromVersion: Int { get }
    var toVersion: Int { get }
    func apply(to files: inout PackageFiles) throws
}

/// Migrationen alter Pakete. Version 1 ist die erste; es gibt noch keinen Schritt.
/// Wer das Format ändert, erhöht `Board.formatVersion` und legt hier einen Schritt ab.
public struct Migration: Sendable {
    public static let currentVersion = Board.formatVersion
    /// Die Migrationen dieser App.
    public static let standard = Migration()

    public let currentVersion: Int
    public let steps: [any MigrationStep]

    public init(currentVersion: Int = Migration.currentVersion, steps: [any MigrationStep] = []) {
        self.currentVersion = currentVersion
        self.steps = steps
    }

    /// Hebt die Dateien von Version `from` auf `to`. Gleiche Versionen ändern nichts.
    /// Neuer als bekannt oder rückwärts ist ein Fehler, ebenso eine Lücke in der Schrittfolge.
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
            throw PackageError.corruptFile(path: "manifest.json", reason: "kein JSON-Objekt")
        }
        manifest["formatVersion"] = .int(version)
        files["manifest.json"] = try PackageJSON.data(JSONValue.object(manifest))
    }
}
