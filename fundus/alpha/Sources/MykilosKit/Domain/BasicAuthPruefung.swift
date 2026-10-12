import Foundation

public enum BasicAuthBefund: Equatable, Sendable {
    case plausibel

    case isEmpty

    case praefixFehlt

    case falschesSchema(String)

    case klartextStattBase64

    case base64MitUmbruch

    case laengePasstNicht(fehlend: Int)

    case keinGueltigesBase64

    case keinDoppelpunkt

    public var hint: String? {
        switch self {
        case .plausibel:
            return nil
        case .isEmpty:
            return "Es ist kein Wert hinterlegt."
        case .praefixFehlt:
            return "Der Wert beginnt nicht mit dem Wort Basic und einem Leerzeichen — "
                 + "vermutlich wurde nur der kodierte Teil eingefügt. Der komplette Header "
                 + "lautet: Basic <kodierter Teil>."
        case .falschesSchema(let schema):
            return "Der Wert beginnt mit \(schema) statt mit Basic — die Kantine erwartet "
                 + "Basic-Auth."
        case .klartextStattBase64:
            return "Hinter Basic stehen die Zugangsdaten offenbar im Klartext. Basic-Auth "
                 + "braucht sie Base64-kodiert — ALPHA kann das unten übernehmen, ohne dass "
                 + "sie den Rechner verlassen."
        case .base64MitUmbruch:
            return "Beim Kopieren ist ein Zeilenumbruch mitgekommen — ohne ihn wäre der Wert "
                 + "gültig. ALPHA kann ihn unten entfernen."
        case .laengePasstNicht(let fehlend):
            let zeichen = fehlend == 1 ? "ein Zeichen" : "\(fehlend) Zeichen"
            return "Beim Kopieren ist \(zeichen) verlorengegangen: Base64 kodiert je 4 Zeichen "
                 + "zu 3 Bytes, die Länge muss also durch 4 teilbar sein — sie ist es nicht. "
                 + "Den Wert bitte noch einmal vollständig kopieren und neu eintragen."
        case .keinGueltigesBase64:
            return "Hinter Basic steht kein gültiges Base64 — beim Kopieren ist vermutlich "
                 + "etwas abgeschnitten worden."
        case .keinDoppelpunkt:
            return "Der kodierte Teil enthält kein benutzer:passwort — Basic-Auth braucht "
                 + "beides, getrennt durch einen Doppelpunkt."
        }
    }
}

public enum BasicAuthPruefung {
    public static func pruefe(_ roh: String) -> BasicAuthBefund {
        let value = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { return .isEmpty }

        let teile = value.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard teile.count == 2 else { return .praefixFehlt }

        let schema = String(teile[0])
        guard schema.caseInsensitiveCompare("Basic") == .orderedSame else {
            return .falschesSchema(schema)
        }

        let kodiert = String(teile[1]).trimmingCharacters(in: .whitespacesAndNewlines)

        if kodiert.contains(":") { return .klartextStattBase64 }

        if Data(base64Encoded: kodiert) == nil {
            let ohneWhitespace = kodiert.filter { $0.isWhitespace == false }
            if Data(base64Encoded: ohneWhitespace) != nil { return .base64MitUmbruch }

            let alphabet = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
            let sauber = ohneWhitespace.allSatisfy { alphabet.contains($0) }
            let rest = ohneWhitespace.count % 4
            if sauber, rest != 0 { return .laengePasstNicht(fehlend: 4 - rest) }

            return .keinGueltigesBase64
        }

        guard let data = Data(base64Encoded: kodiert) else { return .keinGueltigesBase64 }
        guard let klartext = String(data: data, encoding: .utf8), klartext.contains(":") else {
            return .keinDoppelpunkt
        }
        return .plausibel
    }

    public static func repariere(_ roh: String) -> String? {
        let value = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        let teile = value.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard teile.count == 2,
              String(teile[0]).caseInsensitiveCompare("Basic") == .orderedSame else { return nil }
        let kodiert = String(teile[1]).trimmingCharacters(in: .whitespacesAndNewlines)

        switch pruefe(value) {
        case .klartextStattBase64:
            return "Basic " + Data(kodiert.utf8).base64EncodedString()
        case .base64MitUmbruch:
            return "Basic " + kodiert.filter { $0.isWhitespace == false }
        default:
            return nil
        }
    }
}
