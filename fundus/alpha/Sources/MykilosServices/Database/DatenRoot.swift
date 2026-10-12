import Foundation
import MykilosKit

public enum DatenRoot {
    public static let kanonischerName = AppKennung.name

    public static let legacyNamen: [String] = []

    public static let markerName = ".datenroot-konsolidiert"

    public static func applicationSupport(fileManager fm: FileManager = .default) -> URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
    }

    public static func kanonisch(appSupport: URL) -> URL {
        appSupport.appendingPathComponent(kanonischerName, isDirectory: true)
    }

    public static func root(fileManager fm: FileManager = .default) -> URL {
        kanonisch(appSupport: applicationSupport(fileManager: fm))
    }

    public static func uebergangsPfad(_ relativerPfad: String, appSupport: URL,
                                      fileManager fm: FileManager = .default) -> URL {
        return kanonisch(appSupport: appSupport).appendingPathComponent(relativerPfad)
    }

    public static func uebergangsPfad(_ relativerPfad: String, fileManager fm: FileManager = .default) -> URL {
        uebergangsPfad(relativerPfad, appSupport: applicationSupport(fileManager: fm), fileManager: fm)
    }

    public static func markerURL(appSupport: URL) -> URL {
        kanonisch(appSupport: appSupport).appendingPathComponent(markerName)
    }

    public static func istKonsolidiert(appSupport: URL, fileManager fm: FileManager = .default) -> Bool {
        fm.fileExists(atPath: markerURL(appSupport: appSupport).path)
    }

    public struct Schritt: Equatable, Sendable {
        public let source: URL
        public let ziel: URL

        public let kollision: Bool
    }

    static func istGleicherOrdner(_ a: URL, _ b: URL) -> Bool {
        guard let ia = try? a.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier,
              let ib = try? b.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier
        else { return false }
        return ia.isEqual(ib)
    }

    public static func plane(appSupport: URL, ausser: Set<String> = [],
                             fileManager fm: FileManager = .default) -> [Schritt] {
        let zielRoot = kanonisch(appSupport: appSupport)
        var schritte: [Schritt] = []
        for name in legacyNamen {
            let quelleRoot = appSupport.appendingPathComponent(name, isDirectory: true)
            var istOrdner: ObjCBool = false
            guard fm.fileExists(atPath: quelleRoot.path, isDirectory: &istOrdner), istOrdner.boolValue
            else { continue }

            if istGleicherOrdner(quelleRoot, zielRoot) { continue }
            let inhalte = (try? fm.contentsOfDirectory(
                at: quelleRoot, includingPropertiesForKeys: nil)) ?? []
            for entry in inhalte.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if ausser.contains(entry.lastPathComponent) { continue }
                let ziel = zielRoot.appendingPathComponent(entry.lastPathComponent)
                let kollision = fm.fileExists(atPath: ziel.path)
                    || schritte.contains { $0.ziel.lastPathComponent == entry.lastPathComponent }
                schritte.append(Schritt(source: entry, ziel: ziel, kollision: kollision))
            }
        }
        return schritte
    }

    public struct Ergebnis: Equatable, Sendable {
        public var verschoben: Int
        public var uebersprungen: Int
        public init(verschoben: Int = 0, uebersprungen: Int = 0) {
            self.verschoben = verschoben
            self.uebersprungen = uebersprungen
        }
    }

    @discardableResult
    public static func konsolidiere(appSupport: URL, ausser: Set<String> = [],
                                    fileManager fm: FileManager = .default) throws -> Ergebnis {
        if istKonsolidiert(appSupport: appSupport, fileManager: fm) {
            return Ergebnis()
        }
        let zielRoot = kanonisch(appSupport: appSupport)
        try fm.createDirectory(at: zielRoot, withIntermediateDirectories: true)
        var result = Ergebnis()
        for schritt in plane(appSupport: appSupport, ausser: ausser, fileManager: fm) {
            if schritt.kollision {
                result.uebersprungen += 1
                continue
            }

            if fm.fileExists(atPath: schritt.ziel.path) {
                result.uebersprungen += 1
                continue
            }
            try fm.moveItem(at: schritt.source, to: schritt.ziel)
            result.verschoben += 1
        }

        fm.createFile(atPath: markerURL(appSupport: appSupport).path, contents: Data())
        return result
    }
}
