import Foundation

public enum TelefonFormat {
    public enum Result: Equatable, Sendable {
        case normalisiert(String)

        case unklar(original: String, ground: String)

        public var value: String? {
            if case .normalisiert(let w) = self { return w }
            return nil
        }
    }

    public static func normalisiere(_ roh: String) -> Result {
        let text = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return .unklar(original: roh, ground: "leer") }

        if text.contains(":::") || text.contains(";") || text.contains(" oder ")
            || text.contains(",") {
            return .unklar(original: text, ground: "mehrere Nummern in einem Feld")
        }
        if text.contains("@") {
            return .unklar(original: text, ground: "keine Telefonnummer (E-Mail)")
        }

        if text.rangeOfCharacter(from: .letters) != nil {
            return .unklar(original: text, ground: "enthält Buchstaben/Zusatz")
        }

        let istPlus = text.hasPrefix("+")
        let ziffern = text.filter { $0.isNumber && $0.isASCII }
        guard ziffern.isEmpty == false else {
            return .unklar(original: text, ground: "keine Ziffern")
        }

        if istPlatzhalter(ziffern) {
            return .unklar(original: text, ground: "Platzhalter/keine echte Nummer")
        }

        if ziffern.hasPrefix("0049") {
            return deutsch(String(ziffern.dropFirst(4)), original: text)
        }
        if istPlus, ziffern.hasPrefix("49") {
            return deutsch(String(ziffern.dropFirst(2)), original: text)
        }
        if istPlus {
            return ausland(ziffern, original: text)
        }
        if ziffern.hasPrefix("00") {
            return ausland(String(ziffern.dropFirst(2)), original: text, mitPlus: true)
        }
        if ziffern.hasPrefix("49"), ziffern.count >= 11 {
            return deutsch(String(ziffern.dropFirst(2)), original: text)
        }
        if ziffern.hasPrefix("0") {
            return deutsch(String(ziffern.dropFirst()), original: text)
        }

        if istEindeutigeMobilOhneNull(text: text, ziffern: ziffern) {
            return deutsch(ziffern, original: text)
        }
        return .unklar(original: text, ground: "kein erkennbares Präfix (führende 0 fehlt?)")
    }

    private static func deutsch(_ rest: String, original: String) -> Result {
        let ohneNull = rest.hasPrefix("0") ? String(rest.dropFirst()) : rest
        guard ohneNull.count >= 6, ohneNull.count <= 13 else {
            return .unklar(original: original, ground: "unplausible Länge (\(ohneNull.count) Ziffern)")
        }
        var (vorwahl, teilnehmer) = trenneDeutsch(ohneNull)

        if teilnehmer.isEmpty, let group = menschlicheVorwahl(original: original, national: ohneNull) {
            vorwahl = group
            teilnehmer = String(ohneNull.dropFirst(group.count))
        }
        return .normalisiert(teilnehmer.isEmpty ? "0\(vorwahl)" : "0\(vorwahl) \(teilnehmer)")
    }

    private static func ausland(_ ziffern: String, original: String, mitPlus: Bool = true) -> Result {
        guard ziffern.count >= 8, ziffern.count <= 15 else {
            return .unklar(original: original, ground: "unplausible Länge (\(ziffern.count) Ziffern)")
        }
        guard let laenge = laenderVorwahlLaenge(ziffern) else {
            return .unklar(original: original, ground: "Ländervorwahl unbekannt — nicht geraten")
        }
        let vorwahl = String(ziffern.prefix(laenge))
        let rest = String(ziffern.dropFirst(laenge))

        let sauber = rest.hasPrefix("0") ? String(rest.dropFirst()) : rest
        return .normalisiert("\(mitPlus ? "+" : "")\(vorwahl) \(sauber)")
    }

    static func trenneDeutsch(_ number: String) -> (String, String) {
        let mobil = ["15", "16", "17"]
        if let zwei = number.prefix(2).isEmpty ? nil : String(number.prefix(2)),
           mobil.contains(zwei) {
            return (String(number.prefix(3)), String(number.dropFirst(3)))
        }
        let grossstaedte = ["30", "40", "69", "89", "89", "211", "221"]
        for vorwahl in grossstaedte.sorted(by: { $0.count > $1.count }) where number.hasPrefix(vorwahl) {
            return (vorwahl, String(number.dropFirst(vorwahl.count)))
        }

        return (number, "")
    }

    static func istEindeutigeMobilOhneNull(text: String, ziffern: String) -> Bool {
        let nurZiffern = text.allSatisfy { $0.isNumber && $0.isASCII }
        guard nurZiffern else { return false }
        guard ziffern.count == 10 || ziffern.count == 11 else { return false }
        return ["15", "16", "17"].contains(String(ziffern.prefix(2)))
    }

    static func menschlicheVorwahl(original: String, national: String) -> String? {
        let groups = original.split(whereSeparator: { $0.isNumber == false })
            .map { String($0) }

        for group in groups {
            let kandidat = group.hasPrefix("0") ? String(group.dropFirst()) : group
            guard kandidat.isEmpty == false, kandidat != "49", kandidat != "0049" else { continue }
            guard national.hasPrefix(kandidat) else { continue }
            guard kandidat.count >= 2, kandidat.count <= 5,
                  kandidat.count < national.count else { return nil }
            return kandidat
        }
        return nil
    }

    static func laenderVorwahlLaenge(_ ziffern: String) -> Int? {
        let einstellig = ["1", "7"]
        let zweistellig = ["41", "43", "31", "32", "33", "34", "39", "44", "45", "46", "47",
                           "48", "49", "351", "352", "353", "420", "421"]
        for vorwahl in zweistellig where ziffern.hasPrefix(vorwahl) { return vorwahl.count }
        for vorwahl in einstellig where ziffern.hasPrefix(vorwahl) { return vorwahl.count }
        return nil
    }

    static func istPlatzhalter(_ ziffern: String) -> Bool {
        let einzigartige = Set(ziffern)
        if einzigartige.count <= 2 { return true }
        if ziffern.contains("123456789") { return true }
        return false
    }
}
