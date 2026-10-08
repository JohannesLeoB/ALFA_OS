import Foundation

/// Fehler beim Lesen eines DTCG-Vertrags. `pfad` nennt die Stelle im JSON, z. B. `color.akzent.$value.components[1]`.
public struct DTCGImportError: Error, Equatable, Sendable, CustomStringConvertible {
    public let pfad: String
    public let meldung: String
    public init(pfad: String, meldung: String) { self.pfad = pfad; self.meldung = meldung }
    public var description: String { "\(pfad): \(meldung)" }
}

/// Liest einen DTCG-Vertrag in einen TokenSet. Umfang: Format 2025.10 mit Gruppen, $type-Vererbung,
/// Aliasen `{gruppe.token}`, Farbe als sRGB-Objekt, Maßen, Dauern, Kurven, Schrift und Zahlen.
/// Quelle: https://www.designtokens.org/TR/2025.10/format/ und /color/.
/// Werte werden aus den Komponenten gelesen; ein `hex` wird nur geprüft, nicht verwendet.
public enum DTCGImport {
    public static func tokens(from data: Data, name: String) throws -> TokenSet {
        let wurzel: Any
        do {
            wurzel = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw DTCGImportError(pfad: "(Datei)", meldung: "kein gültiges JSON: \(error.localizedDescription)")
        }
        guard let objekt = wurzel as? [String: Any] else {
            throw DTCGImportError(pfad: "(Wurzel)", meldung: "die oberste Ebene muss ein Objekt sein")
        }
        var blaetter: [Blatt] = []
        try sammeln(objekt, pfad: [], erbtTyp: nil, into: &blaetter)
        let nachId = Dictionary(blaetter.map { ($0.id, $0) }, uniquingKeysWith: { erster, _ in erster })
        let tokens = try blaetter
            .sorted { $0.pfad.lexicographicallyPrecedes($1.pfad) }
            .map { blatt -> Token in
                let (_, wert) = try aufloesen(blatt.id, nachId, kette: [])
                return Token(blatt.pfad, wert, description: blatt.beschreibung)
            }
        return TokenSet(name: name, tokens: tokens)
    }

    // MARK: - Einsammeln der Tokens

    /// Ein Token vor der Auflösung der Aliase.
    private struct Blatt {
        let pfad: [String]
        let typ: String?
        let wert: Any
        let beschreibung: String?
        let stelle: String
        var id: String { pfad.joined(separator: ".") }
    }

    private static func sammeln(_ knoten: [String: Any], pfad: [String], erbtTyp: String?, into blaetter: inout [Blatt]) throws {
        let stelle = pfad.joined(separator: ".")
        let gruppenTyp = try typ(knoten, stelle) ?? erbtTyp
        for name in knoten.keys.sorted() {
            if name.hasPrefix("$") {
                // Metadaten ($type, $description, $deprecated, $extensions) sind erlaubt. $ref wird nicht gelesen,
                // und ein Objekt mit $-Namen wäre ein Token, das sonst still verloren ginge.
                if name == "$ref" {
                    throw fehler(anhaengen(stelle, name), "$ref wird nicht gelesen; Aliase schreibt man als {gruppe.token}")
                }
                if knoten[name] is [String: Any], name != "$extensions" {
                    throw fehler(anhaengen(stelle, name), "Name darf nicht mit $ beginnen")
                }
                continue
            }
            let kindPfad = pfad + [name]
            let kindStelle = kindPfad.joined(separator: ".")
            try pruefeName(name, kindStelle)
            guard let kind = knoten[name] as? [String: Any] else {
                throw fehler(kindStelle, "Gruppe oder Token muss ein Objekt sein")
            }
            if let wert = kind["$value"] {
                if kind["$ref"] != nil {
                    throw fehler(anhaengen(kindStelle, "$ref"), "$ref wird nicht gelesen; Aliase schreibt man als {gruppe.token}")
                }
                if let unter = kind.keys.sorted().first(where: { !$0.hasPrefix("$") }) {
                    throw fehler("\(kindStelle).\(unter)", "ein Token darf keine Untergruppe haben")
                }
                let eigenerTyp = try typ(kind, kindStelle)
                blaetter.append(Blatt(pfad: kindPfad,
                                      typ: eigenerTyp ?? gruppenTyp,
                                      wert: wert,
                                      beschreibung: try beschreibung(kind, kindStelle),
                                      stelle: kindStelle))
            } else {
                try sammeln(kind, pfad: kindPfad, erbtTyp: gruppenTyp, into: &blaetter)
            }
        }
    }

    /// DTCG: Namen dürfen nicht leer sein, nicht mit $ beginnen und keine Punkte oder geschweiften Klammern enthalten.
    private static func pruefeName(_ name: String, _ stelle: String) throws {
        if name.isEmpty || name.contains(where: { ".{}".contains($0) }) {
            throw fehler(stelle, "Name darf nicht leer sein und keine Punkte oder geschweiften Klammern enthalten")
        }
    }

    private static func typ(_ knoten: [String: Any], _ stelle: String) throws -> String? {
        guard let roh = knoten["$type"] else { return nil }
        guard let text = roh as? String else { throw fehler(anhaengen(stelle, "$type"), "$type muss eine Zeichenkette sein") }
        return text
    }

    private static func beschreibung(_ knoten: [String: Any], _ stelle: String) throws -> String? {
        guard let roh = knoten["$description"] else { return nil }
        guard let text = roh as? String else { throw fehler(anhaengen(stelle, "$description"), "$description muss eine Zeichenkette sein") }
        return text
    }

    // MARK: - Auflösen der Aliase

    private static func aufloesen(_ id: String, _ nachId: [String: Blatt], kette: [String]) throws -> (typ: String, wert: TokenValue) {
        guard let blatt = nachId[id] else { throw fehler(id, "Token nicht gefunden") }
        if let ziel = aliasZiel(blatt.wert) {
            let weg = kette + [id]
            if weg.contains(ziel) {
                throw fehler(blatt.stelle + ".$value", "Alias-Schleife: " + (weg + [ziel]).joined(separator: " -> "))
            }
            guard nachId[ziel] != nil else {
                throw fehler(blatt.stelle + ".$value", "Alias {\(ziel)} zeigt auf keinen Token")
            }
            let (zielTyp, zielWert) = try aufloesen(ziel, nachId, kette: weg)
            if let eigener = blatt.typ, eigener != zielTyp {
                throw fehler(anhaengen(blatt.stelle, "$type"), "Typ \(eigener) passt nicht zu {\(ziel)} (\(zielTyp))")
            }
            return (blatt.typ ?? zielTyp, zielWert)
        }
        guard let typ = blatt.typ else {
            throw fehler(blatt.stelle, "kein $type: weder am Token noch an einer übergeordneten Gruppe")
        }
        return (typ, try wert(blatt.wert, typ: typ, stelle: blatt.stelle + ".$value"))
    }

    /// `"{gruppe.token}"` ergibt `gruppe.token`; sonst nil.
    private static func aliasZiel(_ wert: Any) -> String? {
        guard let text = wert as? String, text.count > 2, text.hasPrefix("{"), text.hasSuffix("}") else { return nil }
        return String(text.dropFirst().dropLast())
    }

    // MARK: - Werte nach Typ

    private static func wert(_ roh: Any, typ: String, stelle: String) throws -> TokenValue {
        switch typ {
        case "color":
            return try farbe(roh, stelle)
        case "dimension":
            let (x, einheit) = try masse(roh, stelle, einheiten: ["px", "rem"])
            return .dimension(x, unit: einheit)
        case "duration":
            let (x, einheit) = try masse(roh, stelle, einheiten: ["ms", "s"])
            return .duration(einheit == "s" ? x * 1000 : x)
        case "number":
            return .number(try zahl(roh, stelle))
        case "fontFamily":
            if let name = roh as? String { return .fontFamily([name]) }
            if let liste = roh as? [Any], !liste.isEmpty {
                var namen: [String] = []
                for (i, eintrag) in liste.enumerated() {
                    guard let name = eintrag as? String else {
                        throw fehler("\(stelle)[\(i)]", "Schriftname muss eine Zeichenkette sein")
                    }
                    namen.append(name)
                }
                return .fontFamily(namen)
            }
            throw fehler(stelle, "fontFamily ist ein Name oder eine Liste von Namen")
        case "fontWeight":
            if let name = roh as? String {
                guard let gewicht = gewichtsNamen[name] else {
                    throw fehler(stelle, "unbekannter Gewichtsname \"\(name)\" (erlaubt sind Kleinbuchstaben wie bold oder semi-bold)")
                }
                return .fontWeight(gewicht)
            }
            let x = try zahl(roh, stelle, 1...1000)
            guard x == x.rounded() else { throw fehler(stelle, "Gewicht muss eine ganze Zahl sein") }
            return .fontWeight(Int(x))
        case "cubicBezier":
            guard let teile = roh as? [Any], teile.count == 4 else {
                throw fehler(stelle, "cubicBezier ist eine Liste aus vier Zahlen")
            }
            var p: [Double] = []
            for (i, teil) in teile.enumerated() { p.append(try zahl(teil, "\(stelle)[\(i)]")) }
            for i in [0, 2] where !(0...1).contains(p[i]) {
                throw fehler("\(stelle)[\(i)]", "x-Wert muss zwischen 0 und 1 liegen")
            }
            return .cubicBezier(p[0], p[1], p[2], p[3])
        default:
            throw fehler(stelle, "unbekannter $type \"\(typ)\"")
        }
    }

    /// Gewichtsnamen nach DTCG 2025.10 (Groß- und Kleinschreibung zählt).
    private static let gewichtsNamen: [String: Int] = [
        "thin": 100, "hairline": 100,
        "extra-light": 200, "ultra-light": 200,
        "light": 300,
        "normal": 400, "regular": 400, "book": 400,
        "medium": 500,
        "semi-bold": 600, "demi-bold": 600,
        "bold": 700,
        "extra-bold": 800, "ultra-bold": 800,
        "black": 900, "heavy": 900,
        "extra-black": 950, "ultra-black": 950,
    ]

    private static func farbe(_ roh: Any, _ stelle: String) throws -> TokenValue {
        guard let o = roh as? [String: Any] else {
            throw fehler(stelle, "Farbe muss ein Objekt mit colorSpace und components sein")
        }
        guard let raum = o["colorSpace"] as? String else {
            throw fehler(stelle + ".colorSpace", "colorSpace fehlt oder ist keine Zeichenkette")
        }
        guard raum == "srgb" else {
            throw fehler(stelle + ".colorSpace", "nur \"srgb\" wird gelesen, gefunden: \"\(raum)\"")
        }
        guard let teile = o["components"] as? [Any], teile.count == 3 else {
            throw fehler(stelle + ".components", "components muss eine Liste aus drei Zahlen sein")
        }
        var kanaele: [Double] = []
        for (i, teil) in teile.enumerated() {
            kanaele.append(try zahl(teil, "\(stelle).components[\(i)]", 0...1))
        }
        var alpha = 1.0
        if o["alpha"] != nil { alpha = try zahl(o["alpha"], stelle + ".alpha", 0...1) }
        if o["hex"] != nil {
            guard let hex = o["hex"] as? String, RGB(hex: hex) != nil else {
                throw fehler(stelle + ".hex", "hex ist keine gültige Farbe")
            }
        }
        return .color(RGB(r: kanaele[0], g: kanaele[1], b: kanaele[2], a: alpha))
    }

    private static func masse(_ roh: Any, _ stelle: String, einheiten: [String]) throws -> (Double, String) {
        guard let o = roh as? [String: Any] else {
            throw fehler(stelle, "Maß muss ein Objekt mit value und unit sein")
        }
        let x = try zahl(o["value"], stelle + ".value")
        guard let einheit = o["unit"] as? String, einheiten.contains(einheit) else {
            throw fehler(stelle + ".unit", "unit muss \(einheiten.joined(separator: " oder ")) sein")
        }
        return (x, einheit)
    }

    /// Eine Zahl, kein Wahrheitswert. Optional mit Bereich.
    private static func zahl(_ roh: Any?, _ stelle: String, _ bereich: ClosedRange<Double>? = nil) throws -> Double {
        guard let roh else { throw fehler(stelle, "fehlt") }
        guard let n = roh as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() else {
            throw fehler(stelle, "Zahl erwartet")
        }
        let x = n.doubleValue
        if let bereich, !bereich.contains(x) {
            throw fehler(stelle, "\(x) liegt nicht zwischen \(bereich.lowerBound) und \(bereich.upperBound)")
        }
        return x
    }

    // MARK: - Hilfen

    private static func fehler(_ pfad: String, _ meldung: String) -> DTCGImportError {
        DTCGImportError(pfad: pfad.isEmpty ? "(Wurzel)" : pfad, meldung: meldung)
    }

    private static func anhaengen(_ stelle: String, _ teil: String) -> String {
        stelle.isEmpty ? teil : "\(stelle).\(teil)"
    }
}
