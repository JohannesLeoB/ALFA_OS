import Foundation

public enum ProjektLeadBeleber {
    public static let leadsOrdnerName = "_LEADS"

    public enum Fehler: Error, Equatable {
        case leadsOrdnerNichtVorhanden(String)

        case stummelNichtGefunden(praefix: String)

        case stummelMehrdeutig(praefix: String, candidates: [String])

        case zielExistiertBereits(String)

        case nummerUngueltig(String)
    }

    public struct Plan: Equatable, Sendable {
        public let source: URL

        public let ziel: URL
    }

    public static func ordnerPraefix(ausProjektnummer nummer: String) -> String? {
        let normalisiert = nummer.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "-", with: "_")
        guard normalisiert.count >= 4, normalisiert.first?.isNumber == true else { return nil }
        return normalisiert
    }

    public static func plane(
        projektnummer: String,
        projekteRoot: URL,
        fileManager: FileManager = .default
    ) throws -> Plan {
        guard let praefix = ordnerPraefix(ausProjektnummer: projektnummer) else {
            throw Fehler.nummerUngueltig(projektnummer)
        }
        let leadsOrdner = projekteRoot.appendingPathComponent(leadsOrdnerName, isDirectory: true)
        var istOrdner: ObjCBool = false
        guard fileManager.fileExists(atPath: leadsOrdner.path, isDirectory: &istOrdner),
              istOrdner.boolValue else {
            throw Fehler.leadsOrdnerNichtVorhanden(leadsOrdner.path)
        }

        let entries = try fileManager.contentsOfDirectory(
            at: leadsOrdner, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles])
        let candidates = entries.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                && url.lastPathComponent.hasPrefix(praefix)
        }
        guard candidates.isEmpty == false else {
            throw Fehler.stummelNichtGefunden(praefix: praefix)
        }
        guard candidates.count == 1, let source = candidates.first else {
            throw Fehler.stummelMehrdeutig(
                praefix: praefix, candidates: candidates.map(\.lastPathComponent).sorted())
        }

        let ziel = projekteRoot.appendingPathComponent(source.lastPathComponent, isDirectory: true)
        if fileManager.fileExists(atPath: ziel.path) {
            throw Fehler.zielExistiertBereits(ziel.path)
        }
        return Plan(source: source, ziel: ziel)
    }

    @discardableResult
    public static func fuehreAus(
        _ plan: Plan,
        fileManager: FileManager = .default
    ) throws -> URL {
        try fileManager.moveItem(at: plan.source, to: plan.ziel)
        return plan.ziel
    }

    @discardableResult
    public static func belebe(
        projektnummer: String,
        projekteRoot: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let plan = try plane(
            projektnummer: projektnummer, projekteRoot: projekteRoot, fileManager: fileManager)
        return try fuehreAus(plan, fileManager: fileManager)
    }
}
