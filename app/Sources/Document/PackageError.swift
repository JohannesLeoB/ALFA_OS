import Foundation
import ALFAcolorCore

/// Fehler beim Lesen oder Schreiben eines Pakets. Die Meldungen sind für Johannes gedacht und sagen, was zu tun ist.
public enum PackageError: Error, Equatable, Sendable {
    /// Gelesen wurde eine einzelne Datei statt eines Ordners.
    case notAPackage
    case missingFile(path: String)
    case corruptFile(path: String, reason: String)
    /// Das Paket stammt aus einer neueren Fassung als diese App kennt.
    case unknownFormatVersion(Int)
    /// Zwischen zwei Versionen fehlt der Migrationsschritt.
    case missingMigration(from: Int, to: Int)
    /// Eine ID oder ein Name taugt nicht als Dateiname (leer, zu lang).
    case invalidIdentifier(String)
    /// Zwei Räume, Ebenen, Tokensätze heißen gleich, oder nur in Groß- und Kleinschreibung verschieden.
    case duplicateIdentifier(kind: String, id: String)
    /// Ein Stück verweist auf eine Ebene, die es im Raum nicht gibt.
    case itemWithoutLayer(item: String, layer: String, space: String)
    /// Ein mitgeführter Pfad ist unzulässig oder kollidiert mit einer Datei, die das Paket selbst schreibt.
    case invalidPath(String)
    /// Ein Token lässt sich im DTCG-Baum nicht ablegen (leerer Pfad, "$"-Name, Blatt und Gruppe am selben Ort).
    case invalidToken(String)
    case writeFailed(reason: String)
    /// Das Paket lässt sich nicht öffnen (nicht vorhanden, keine Berechtigung).
    case unreadable(reason: String)
}

extension PackageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notAPackage: "Das ist kein ALFAcolor-Paket (ein Ordner mit der Endung .alfacolor), sondern eine einzelne Datei."
        case .missingFile(let p): "Im Paket fehlt die Datei \(p)."
        case .corruptFile(let p, let r): "Die Datei \(p) im Paket ist beschädigt: \(r)"
        case .unknownFormatVersion(let v): "Dieses Dokument hat die Formatversion \(v). Diese App kennt höchstens \(Migration.currentVersion). Bitte die App aktualisieren; das Dokument wurde nicht verändert."
        case .missingMigration(let a, let b): "Für die Umstellung von Version \(a) auf \(b) gibt es keinen Migrationsschritt."
        case .invalidIdentifier(let s): "„\(s)“ lässt sich nicht als Dateiname im Paket verwenden."
        case .duplicateIdentifier(let k, let id): "\(k) „\(id)“ kommt doppelt vor (auch Groß-/Kleinschreibung zählt hier als gleich)."
        case .itemWithoutLayer(let i, let l, let s): "Das Stück \(i) im Raum „\(s)“ liegt auf der Ebene „\(l)“, die es dort nicht gibt."
        case .invalidPath(let p): "Der Pfad „\(p)“ ist im Paket nicht erlaubt oder wird vom Paket selbst belegt."
        case .invalidToken(let t): "Das Token „\(t)“ lässt sich nicht als DTCG ablegen."
        case .writeFailed(let r): "Das Dokument konnte nicht geschrieben werden: \(r)"
        case .unreadable(let r): "Das Dokument konnte nicht gelesen werden: \(r)"
        }
    }
}

/// Was das Lesen auffällt, ohne dass es das Öffnen verhindert.
public struct ReadReport: Equatable, Sendable {
    public struct MissingAsset: Equatable, Sendable {
        public var assetID: String
        public var itemID: ItemID
        public var spaceID: String
    }
    /// Formatversion, wie sie auf der Platte stand (vor einer Migration).
    public var formatVersionOnDisk: Int = 0
    /// Gesetzt, wenn beim Lesen migriert wurde: die Ausgangsversion.
    public var migratedFrom: Int?
    public var writtenByAppVersion: String?
    /// Bilder, auf die ein Stück verweist, deren Datei im Paket fehlt.
    public var missingAssets: [MissingAsset] = []
    /// Nur mit `ReadOptions.verifyAssetHashes`: Dateien, deren Inhalt nicht zu ihrem Hash-Namen passt.
    public var corruptAssets: [String] = []
    /// Dateien in `assets/`, die kein Stück benutzt. Sie bleiben im Paket.
    public var unreferencedAssets: [String] = []
    public var warnings: [String] = []
    public var isClean: Bool { missingAssets.isEmpty && corruptAssets.isEmpty && warnings.isEmpty }
}

public struct ReadOptions: Sendable {
    /// Hash jeder Asset-Datei nachrechnen. Kostet Zeit je nach Bildmenge, darum aus.
    public var verifyAssetHashes: Bool
    public init(verifyAssetHashes: Bool = false) { self.verifyAssetHashes = verifyAssetHashes }
}

public struct DocumentReadResult: Sendable {
    public var document: ALFAcolorDocument
    public var report: ReadReport
}
