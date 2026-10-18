import Foundation

public struct KonfigAnfrage: Equatable, Sendable {
    public var betreff: String
    public var text: String

    public init(betreff: String, text: String) {
        self.betreff = betreff
        self.text = text
    }
}

public enum KonfigAnfrageText {
    public static func anfrage(draft: KonfigEntwurf, trade: Gewerk,
                               kommission: String, anredeName: String = "",
                               lieferort: String = "") -> KonfigAnfrage {
        switch trade {
        case .tischler:
            return tischler(draft: draft, kommission: kommission,
                            anredeName: anredeName, lieferort: lieferort)
        case .steinmetz:
            return stein(draft: draft, kommission: kommission, anredeName: anredeName)
        case .mykilos:
            return KonfigAnfrage(betreff: "", text: "")
        }
    }

    static func tischler(draft: KonfigEntwurf, kommission: String,
                         anredeName: String, lieferort: String) -> KonfigAnfrage {
        var absaetze: [String] = []
        absaetze.append(anredeName.isEmpty ? "Moin Moin," : "Moin Moin \(anredeName),")
        absaetze.append("ich hätte eine Anfrage für euch — siehe anbei.")

        var materialSaetze: [String] = []
        if draft.material.front.isEmpty == false {
            var satz = "Die Küche wäre komplett mit \(draft.material.front.text)-Fronten"
            if let hint = beschaffung(draft.material.front) { satz += " (\(hint))" }
            if draft.material.griff.isEmpty == false {
                satz += ", Öffnung \(draft.material.griff.text)"
            }
            satz += " ausgestattet"
            materialSaetze.append(satz)
        }
        if draft.material.korpus.isEmpty == false {
            var satz = "das Korpusinnenleben wäre \(draft.material.korpus.text)"
            if let hint = beschaffung(draft.material.korpus) { satz += " (\(hint))" }
            materialSaetze.append(satz)
        }
        if draft.material.schubkastenSystem.isEmpty == false {
            materialSaetze.append("Schubkästen \(draft.material.schubkastenSystem.text)")
        }
        if materialSaetze.isEmpty == false {
            absaetze.append(materialSaetze.joined(separator: ", ") + ".")
        }

        absaetze.append(korpusProsa(draft))

        var scope = "Alle Geräte, Arbeitsplatten, Armatur, Spülbecken, Griffe etc. kommen von uns — von euch bräuchte ich ein erstes Angebot als Kostenschätzung inkl. Montage"
        if lieferort.isEmpty == false { scope += " in \(lieferort)" }
        scope += "."
        absaetze.append(scope)

        if draft.zeitfenster.isEmpty == false {
            absaetze.append("Ausführung realistisch \(draft.zeitfenster).")
        }
        absaetze.append("Die Planung ist noch nicht final ausgearbeitet — detailliertere Zeichnungen würden wir in weiterer Absprache mit unserem Kunden ausarbeiten und dann auch nochmal einen finalen Preis anfragen.")

        absaetze.append("Lass mich gerne wissen, wenn euch in meiner Zeichnung zur Kalkulation noch was fehlt — ich freue mich auf eure Rückmeldung!")
        absaetze.append("Beste Grüße, vielen Dank")

        return KonfigAnfrage(betreff: "Anfrage Kommission \(kommission)",
                             text: absaetze.joined(separator: "\n\n"))
    }

    static func stein(draft: KonfigEntwurf, kommission: String, anredeName: String) -> KonfigAnfrage {
        var absaetze: [String] = []
        absaetze.append(anredeName.isEmpty ? "Moin Moin," : "Moin Moin \(anredeName),")
        absaetze.append("für eine Küche, die wir derzeit planen, bräuchte ich zu den Arbeitsplatten ein Angebot von Ihnen — siehe Zeichnung anbei.")

        if draft.material.arbeitsplatte.isEmpty == false {
            var satz = "Die Platten sollen aus \(draft.material.arbeitsplatte.text) gefertigt werden"
            if let hint = beschaffung(draft.material.arbeitsplatte) { satz += " (\(hint))" }
            satz += "."
            absaetze.append(satz)
        }

        let plattenZonen = draft.zonen.filter { $0.typ.hatArbeitsplatte }
        if plattenZonen.count > 1 {
            let namen = plattenZonen.map(\.displayName).joined(separator: " und ")
            absaetze.append("Es sind \(plattenZonen.count) Platten (\(namen)) — Maße und Ausschnitte stehen in der Zeichnung.")
        }

        absaetze.append("Melden Sie sich gerne jederzeit, wenn Sie noch Fragen oder Anmerkungen dazu haben!")
        absaetze.append("Vielen Dank, mit besten Grüßen")

        return KonfigAnfrage(betreff: "Anfrage Kommission \(kommission)",
                             text: absaetze.joined(separator: "\n\n"))
    }

    static func korpusProsa(_ draft: KonfigEntwurf) -> String {
        var teile: [String] = []
        for zone in draft.zonen {
            var beschreibung = "\(zone.displayName): \(zone.segmente.count) Korpen"
            let widths = Set(zone.segmente.map(\.widthMm))
            if widths.count == 1, let width = widths.first {
                beschreibung += " gleicher Breite (\(width) mm)"
            } else {
                beschreibung += " (\(zone.segmente.map { "\($0.widthMm)" }.joined(separator: "/")) mm)"
            }
            let schubL = zone.segmente.flatMap(\.faecher).reduce(0) { sum, fach in
                if case .schubkaesten(let n, .legrabox) = fach.ausstattung { return sum + n }
                return sum
            }
            let schubH = zone.segmente.flatMap(\.faecher).reduce(0) { sum, fach in
                if case .schubkaesten(let n, .holzMassiv) = fach.ausstattung { return sum + n }
                return sum
            }
            var inhalte: [String] = []
            if schubL > 0 { inhalte.append("\(schubL) Schubkästen Legrabox") }
            if schubH > 0 { inhalte.append("\(schubH) Schubkästen Holz massiv") }
            let geraete = zone.geraeteSlots.map(\.kategorie.displayName)
            if geraete.isEmpty == false { inhalte.append(geraete.joined(separator: ", ")) }
            if inhalte.isEmpty == false { beschreibung += " — \(inhalte.joined(separator: "; "))" }
            teile.append(beschreibung)
        }
        let total = "Kalkulatorisch würde ich von insgesamt \(draft.korpusAnzahl) Korpen ausgehen. "
        return total + teile.joined(separator: ". ") + "."
    }

    static func beschaffung(_ angabe: MaterialAngabe) -> String? {
        angabe.paletteID.flatMap { KonfigPalette.entry(id: $0)?.beschaffungshinweis }
    }
}
