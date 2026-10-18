import Foundation

public struct FarbfaecherImportErgebnis: Equatable, Sendable {
    public var faecher: Farbfaecher

    public var uebersprungen: [String]

    public init(faecher: Farbfaecher, uebersprungen: [String] = []) {
        self.faecher = faecher
        self.uebersprungen = uebersprungen
    }

    public var count: Int { faecher.entries.count }
}

public enum FarbfaecherImport {
    private static let nameSpalten = ["name", "farbe", "farbton", "bezeichnung", "colour", "color", "dekor"]
    private static let nummerSpalten = ["nummer", "nr", "code", "ral", "artikelnummer", "no", "no."]
    private static let hexSpalten = ["hex", "hexcode", "rgb", "hexwert", "html"]

    public static func ausCSV(_ text: String, faechername: String) -> FarbfaecherImportErgebnis {
        let rowItems = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.trimmingCharacters(in: .whitespaces).isEmpty == false }

        guard let header = rowItems.first else {
            return FarbfaecherImportErgebnis(faecher: Farbfaecher(name: faechername),
                                             uebersprungen: ["Datei ist leer."])
        }

        let trenner = trennzeichen(header)
        let columns = zerlege(header, trenner: trenner).map {
            $0.lowercased().trimmingCharacters(in: .whitespaces)
        }

        let iName = columns.firstIndex { nameSpalten.contains($0) }
        let iNummer = columns.firstIndex { nummerSpalten.contains($0) }
        let iHex = columns.firstIndex { hexSpalten.contains($0) }
        let iL = columns.firstIndex { $0 == "l" || $0 == "l*" }
        let iA = columns.firstIndex { $0 == "a" || $0 == "a*" }
        let iB = columns.firstIndex { $0 == "b" || $0 == "b*" }
        let hatLab = iL != nil && iA != nil && iB != nil

        guard iName != nil || iNummer != nil else {
            return FarbfaecherImportErgebnis(
                faecher: Farbfaecher(name: faechername),
                uebersprungen: ["Keine Namens-/Nummern-Spalte gefunden (erwartet z. B. „Name“ oder „Code“). Gelesene Spalten: \(columns.joined(separator: ", "))"])
        }
        guard hatLab || iHex != nil else {
            return FarbfaecherImportErgebnis(
                faecher: Farbfaecher(name: faechername),
                uebersprungen: ["Keine Farbwerte gefunden — erwartet entweder eine Spalte „Hex“ oder die drei Spalten „L“, „a“, „b“. Gelesene Spalten: \(columns.joined(separator: ", "))"])
        }

        var entries: [Farbeintrag] = []
        var uebersprungen: [String] = []

        for (number, rowItem) in rowItems.dropFirst().enumerated() {
            let felder = zerlege(rowItem, trenner: trenner)
            let zeilennummer = number + 2

            func feld(_ index: Int?) -> String? {
                guard let index, index < felder.count else { return nil }
                let value = felder[index].trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }

            let teile = [feld(iNummer), feld(iName)].compactMap { $0 }
            guard teile.isEmpty == false else {
                uebersprungen.append("Zeile \(zeilennummer): ohne Name/Nummer")
                continue
            }
            let name = teile.joined(separator: " ")

            var lab: LabFarbe?
            if hatLab,
               let l = feld(iL).flatMap(zahl), let a = feld(iA).flatMap(zahl), let b = feld(iB).flatMap(zahl) {
                lab = LabFarbe(L: l, a: a, b: b)
            } else if let hexText = feld(iHex), let srgb = SRGBFarbe.vonHex(hexText) {
                lab = FarbRaum.labVonSRGB(srgb)
            }

            guard let lab else {
                uebersprungen.append("Zeile \(zeilennummer) („\(name)“): kein lesbarer Farbwert")
                continue
            }

            entries.append(Farbeintrag(name: name, sammlung: faechername, lab: lab,
                                         herkunft: .handeingabe))
        }

        return FarbfaecherImportErgebnis(
            faecher: Farbfaecher(name: faechername, entries: entries),
            uebersprungen: uebersprungen
        )
    }

    private static func trennzeichen(_ header: String) -> Character {
        let candidates: [Character] = [";", "\t", ","]
        let beste = candidates.max { links, rechts in
            header.filter { $0 == links }.count < header.filter { $0 == rechts }.count
        }
        return beste ?? ";"
    }

    private static func zerlege(_ rowItem: String, trenner: Character) -> [String] {
        var felder: [String] = []
        var aktuell = ""
        var inAnfuehrung = false
        for zeichen in rowItem {
            if zeichen == "\"" {
                inAnfuehrung.toggle()
            } else if zeichen == trenner, inAnfuehrung == false {
                felder.append(aktuell)
                aktuell = ""
            } else {
                aktuell.append(zeichen)
            }
        }
        felder.append(aktuell)
        return felder
    }

    private static func zahl(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }
}

public struct FarbfaecherKatalog: Equatable, Sendable, Codable {
    public var faecher: [Farbfaecher]

    public init(faecher: [Farbfaecher] = []) {
        self.faecher = faecher
    }

    public func besteJeFaecher(zu lab: LabFarbe) -> [(faecher: String, match: FarbTreffer)] {
        var result: [(faecher: String, match: FarbTreffer)] = []
        for f in faecher {
            guard let bester = f.naechste(zu: lab, count: 1).first else { continue }
            result.append((faecher: f.name, match: bester))
        }
        return result.sorted { $0.match.deltaE < $1.match.deltaE }
    }

    public mutating func einhaengen(_ neuer: Farbfaecher) {
        if let index = faecher.firstIndex(where: { $0.name == neuer.name }) {
            faecher[index] = neuer
        } else {
            faecher.append(neuer)
        }
    }

    public mutating func entfernen(faechername: String) {
        faecher.removeAll { $0.name == faechername }
    }

    public var anzahlEintraege: Int { faecher.reduce(0) { $0 + $1.entries.count } }
}
