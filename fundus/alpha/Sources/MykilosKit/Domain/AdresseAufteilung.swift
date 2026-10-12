import Foundation

public enum AdresseAufteilung {
    public struct Result: Equatable, Sendable {
        public let strasse: String
        public let houseNumber: String?

        public let unklar: Bool

        public init(strasse: String, houseNumber: String?, unklar: Bool = false) {
            self.strasse = strasse; self.houseNumber = houseNumber; self.unklar = unklar
        }
    }

    private static let zusatzTokens: Set<String> = [
        "stock", "og", "eg", "hinterhof", "hinterhaus", "vorderhaus", "vh", "hh", "etage",
        "aufgang", "eingang", "wareneingang", "bitte", "gebäude", "haus", "links", "rechts",
        "hof", "seitenflügel", "dachgeschoss", "keller", "zimmer", "büro", "planta", "apt",
        "unit", "of", "co", "app"
    ]

    static func hatZusatz(_ text: String) -> Bool {
        let klein = text.lowercased()
        if klein.contains("c/o") { return true }
        let tokens = klein.split(whereSeparator: {
            $0.isLetter == false && $0.isNumber == false && $0 != "-"
        })
        return tokens.contains { zusatzTokens.contains(String($0)) }
    }

    public static func teile(_ rowItem: String) -> Result {
        let text = rowItem.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
        guard text.isEmpty == false else { return .init(strasse: "", houseNumber: nil) }

        guard text.rangeOfCharacter(from: .decimalDigits) != nil else {
            return .init(strasse: text, houseNumber: nil)
        }

        if hatZusatz(text) {
            return .init(strasse: text, houseNumber: nil, unklar: true)
        }

        if text.contains(" - ") || text.contains(" – ") {
            return .init(strasse: text, houseNumber: nil, unklar: true)
        }

        let teile = text.split(separator: " ").map(String.init)

        if teile.filter({ istHausnummer($0.replacingOccurrences(of: ",", with: "")) }).count > 1 {
            return .init(strasse: text, houseNumber: nil, unklar: true)
        }

        guard teile.count >= 2 else {
            return .init(strasse: text, houseNumber: nil, unklar: true)
        }

        if istHausnummer(teile[0].replacingOccurrences(of: ",", with: "")) {
            let number = teile[0].replacingOccurrences(of: ",", with: "")
            let rest = teile.dropFirst().joined(separator: " ")
            guard rest.isEmpty == false else { return .init(strasse: text, houseNumber: nil, unklar: true) }
            return .init(strasse: rest, houseNumber: number)
        }

        let letztes = teile[teile.count - 1]
        guard istHausnummer(letztes) else {
            return .init(strasse: text, houseNumber: nil, unklar: true)
        }
        let strasse = teile.dropLast().joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
        guard strasse.isEmpty == false,
              strasse.rangeOfCharacter(from: .letters) != nil else {
            return .init(strasse: text, houseNumber: nil, unklar: true)
        }
        return .init(strasse: strasse, houseNumber: letztes)
    }

    static func istHausnummer(_ token: String) -> Bool {
        let t = token.trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
        guard let erstes = t.first, erstes.isNumber, erstes.isASCII else { return false }
        if t.count >= 5, t.allSatisfy({ $0.isNumber }) { return false }
        let erlaubt = CharacterSet(charactersIn: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-/")
        guard t.unicodeScalars.allSatisfy({ erlaubt.contains($0) }) else { return false }

        var buchstabenAmStueck = 0
        for zeichen in t {
            if zeichen.isLetter {
                buchstabenAmStueck += 1
                if buchstabenAmStueck > 3 { return false }
            } else {
                buchstabenAmStueck = 0
            }
        }
        return true
    }
}
