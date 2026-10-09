import Foundation
import Document
import Tokens

/// Why a contract cannot be read. The whole delivery is refused, nothing is taken from it.
public enum ContractError: Error, Equatable, Sendable {
    case noManifest
    case badManifest(String)
    case missingFile(String)
    case checksumMismatch(String)
    case tokens(DTCGImportError)
}

/// The token sets of one contract. The light set comes from `vertrag/tokens.json`. The dark set holds
/// only the tokens that differ in dark mode, from `vertrag/tokens.dunkel.json`; it is nil when the file is missing.
public struct ContractSets: Equatable, Sendable {
    public static let lightName = "vertrag"
    public static let darkName = "vertrag-dunkel"

    public let light: TokenSet
    public let dark: TokenSet?
    /// Files that are in the archive but not in the manifest. They are not read.
    public let warnings: [String]

    public var sets: [TokenSet] { dark.map { [light, $0] } ?? [light] }
}

/// Reads a contract ZIP (format `setzkasten-vertrag/1`, see plan/AUSTAUSCH.md section 1).
/// Every file the manifest lists must be there and match its SHA-256.
public enum ContractImport {
    public static let format = "setzkasten-vertrag/1"
    static let manifestPath = "MANIFEST.json"
    static let lightPath = "vertrag/tokens.json"
    static let darkPath = "vertrag/tokens.dunkel.json"

    public static func read(_ contents: ZipContents) throws -> ContractSets {
        let files = Dictionary(contents.files.map { ($0.path, $0.data) }, uniquingKeysWith: { first, _ in first })
        guard let manifestData = files[manifestPath] else { throw ContractError.noManifest }
        let listed = try listedFiles(manifestData)

        for entry in listed {
            guard let data = files[entry.path] else { throw ContractError.missingFile(entry.path) }
            guard SHA256Digest.hex(data) == entry.sha256 else { throw ContractError.checksumMismatch(entry.path) }
        }
        let listedPaths = Set(listed.map(\.path))
        let warnings = files.keys.sorted()
            .filter { $0 != manifestPath && !listedPaths.contains($0) }
            .map { "\($0) is not in the manifest and is not read" }

        guard listedPaths.contains(lightPath), let light = files[lightPath] else {
            throw ContractError.missingFile(lightPath)
        }
        let lightSet = try tokens(light, name: ContractSets.lightName)
        var darkSet: TokenSet?
        if let dark = files[darkPath] {
            guard listedPaths.contains(darkPath) else { throw ContractError.badManifest("\(darkPath) is not in the manifest") }
            darkSet = try tokens(dark, name: ContractSets.darkName)
        }
        return ContractSets(light: lightSet, dark: darkSet, warnings: warnings)
    }

    private struct Listed {
        let path: String
        let sha256: String
    }

    private static func listedFiles(_ data: Data) throws -> [Listed] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ContractError.badManifest("MANIFEST.json is not a JSON object")
        }
        guard root["format"] as? String == format else {
            throw ContractError.badManifest("format is not \(format)")
        }
        guard let entries = root["dateien"] as? [[String: Any]] else {
            throw ContractError.badManifest("dateien is missing")
        }
        return try entries.map { entry in
            guard let path = entry["pfad"] as? String, let sha = entry["sha256"] as? String else {
                throw ContractError.badManifest("an entry in dateien has no pfad or sha256")
            }
            guard sha.count == 64, sha.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
                throw ContractError.badManifest("sha256 of \(path) is not 64 lower-case hex digits")
            }
            return Listed(path: path, sha256: sha)
        }
    }

    private static func tokens(_ data: Data, name: String) throws -> TokenSet {
        do {
            return try DTCGImport.tokens(from: data, name: name)
        } catch let error as DTCGImportError {
            throw ContractError.tokens(error)
        }
    }
}
