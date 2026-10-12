import Foundation

public enum VWNamensProblem: Equatable, Sendable {
    case datumFehlt
    case datumVertauscht(gelesen: String)
    case datumUnplausibel(gelesen: String)
    case kopieWildwuchs
    case ausserhalbCAD

    public var label: String {
        switch self {
        case .datumFehlt: "Datum fehlt (JJJJMMTT_… erwartet)"
        case .datumVertauscht(let roh): "Datum vertauscht (\(roh) — TTMM statt MMTT?)"
        case .datumUnplausibel(let roh): "Datum unplausibel (\(roh))"
        case .kopieWildwuchs: "„Kopie\"-Duplikat — aufräumen oder umbenennen"
        case .ausserhalbCAD: "liegt außerhalb von 02 CAD"
        }
    }
}

public struct VWNamensHinweis: Equatable, Sendable, Identifiable {
    public let relativerPfad: String
    public let probleme: [VWNamensProblem]
    public var id: String { relativerPfad }

    public init(relativerPfad: String, probleme: [VWNamensProblem]) {
        self.relativerPfad = relativerPfad
        self.probleme = probleme
    }
}

public enum VWNamensDrift {
    public static let endungen: Set<String> = ["vwx", "3dm"]

    static let ruheOrdner: Set<String> = ["x_alt", "archiv"]

    public static func pruefe(relativePfade: [String]) -> [VWNamensHinweis] {
        var hints: [VWNamensHinweis] = []
        for pfad in relativePfade {
            let teile = pfad.split(separator: "/").map(String.init)
            guard let fileName = teile.last else { continue }
            let endung = (fileName as NSString).pathExtension.lowercased()
            guard endungen.contains(endung) else { continue }

            let ordnerTeile = teile.dropLast().map { $0.lowercased() }
            guard ordnerTeile.contains(where: { name in
                ruheOrdner.contains(where: { name.contains($0) })
            }) == false else { continue }

            var probleme: [VWNamensProblem] = []
            if let datumsProblem = pruefeDatum(fileName: fileName) { probleme.append(datumsProblem) }
            if fileName.lowercased().contains("kopie") || fileName.lowercased().contains(" copy") {
                probleme.append(.kopieWildwuchs)
            }
            if ordnerTeile.contains(where: { $0.contains("cad") }) == false {
                probleme.append(.ausserhalbCAD)
            }
            if probleme.isEmpty == false {
                hints.append(VWNamensHinweis(relativerPfad: pfad, probleme: probleme))
            }
        }
        return hints.sorted { $0.relativerPfad < $1.relativerPfad }
    }

    public static func pruefeDatum(fileName: String) -> VWNamensProblem? {
        let ziffern = fileName.prefix { $0.isNumber }
        guard ziffern.isEmpty == false else { return .datumFehlt }
        let roh = String(ziffern)
        guard roh.count == 8 else { return .datumUnplausibel(gelesen: roh) }
        guard let jahr = Int(roh.prefix(4)),
              let monat = Int(roh.dropFirst(4).prefix(2)),
              let tag = Int(roh.suffix(2)) else { return .datumUnplausibel(gelesen: roh) }
        guard (2000...2099).contains(jahr) else { return .datumUnplausibel(gelesen: roh) }
        if (1...12).contains(monat), (1...31).contains(tag) { return nil }

        if monat > 12, (1...31).contains(monat), (1...12).contains(tag) {
            return .datumVertauscht(gelesen: roh)
        }
        return .datumUnplausibel(gelesen: roh)
    }
}
