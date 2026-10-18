import Foundation

public enum STRNummerQuelle: String, Codable, Sendable, Equatable {
    case adresse
    case ort
    case variante
}

public enum STRNummerErgebnis: Sendable, Equatable {
    case gebildet(String, source: STRNummerQuelle)
    case nichtBildbar(ground: String)
}

public enum STRNummer {
    public static let defaultVariantenWhitelist: Set<String> = [
        "GERAETE", "HERD", "QUOOKER", "LIGHTNET", "SERIENKUECHE", "W-BANK", "KV5"
    ]

    public static func bilde(
        strasse: String?, houseNumber: String?, ort: String?,
        variante: String? = nil,
        whitelist: Set<String> = defaultVariantenWhitelist
    ) -> STRNummerErgebnis {
        if let variante, variante.trimmingCharacters(in: .whitespaces).isEmpty == false {
            let norm = normalisiereVariante(variante)
            if whitelist.contains(norm) {
                return .gebildet(norm, source: .variante)
            }
            return .nichtBildbar(ground: "Variante „\(variante)“ ist nicht auf der bestätigten Whitelist. Adresse/ORT angeben oder Variante freigeben.")
        }

        if let kuerzel = strassenKuerzel(strasse) {
            let hn = ziffern(houseNumber)
            return .gebildet(kuerzel + hn, source: .adresse)
        }

        if let ortKuerzel = strassenKuerzel(ort) {
            return .gebildet(ortKuerzel, source: .ort)
        }

        return .nichtBildbar(ground: "Kein Adressblock bildbar: weder Straße noch ORT vorhanden, keine bestätigte Variante.")
    }

    public static func strassenKuerzel(_ s: String?) -> String? {
        guard let s else { return nil }
        let buchstaben = transliteriere(s).filter { $0.isLetter }
        guard buchstaben.isEmpty == false else { return nil }
        return String(buchstaben.prefix(3)).uppercased()
    }

    public static func ziffern(_ s: String?) -> String {
        guard let s else { return "" }
        return String(s.filter(\.isNumber))
    }

    public static func splitStrasseHausnummer(_ kombiniert: String?) -> (strasse: String?, houseNumber: String?) {
        guard let kombiniert else { return (nil, nil) }
        let getrimmt = kombiniert.trimmingCharacters(in: .whitespacesAndNewlines)
        guard getrimmt.isEmpty == false else { return (nil, nil) }
        guard let match = getrimmt.range(
            of: #"\s+\d+\s?[a-zA-Z]?([/-]\d+\s?[a-zA-Z]?)?$"#, options: .regularExpression
        ) else {
            return (getrimmt, nil)
        }
        let houseNumber = getrimmt[match].trimmingCharacters(in: .whitespaces)
        let strasse = String(getrimmt[getrimmt.startIndex..<match.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        return (strasse.isEmpty ? nil : strasse, houseNumber)
    }

    static func normalisiereVariante(_ v: String) -> String {
        transliteriere(v).uppercased().trimmingCharacters(in: .whitespaces)
    }

    static func transliteriere(_ s: String) -> String {
        var out = ""
        for ch in s {
            switch ch {
            case "ä", "Ä": out += "ae"
            case "ö", "Ö": out += "oe"
            case "ü", "Ü": out += "ue"
            case "ß":      out += "ss"
            default:       out.append(ch)
            }
        }
        return out
    }
}
