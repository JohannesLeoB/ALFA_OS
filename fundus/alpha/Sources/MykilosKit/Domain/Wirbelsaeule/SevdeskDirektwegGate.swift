import Foundation

public enum SevdeskDirektwegSperre: Equatable, Sendable {
    case mandantNichtSondiert

    case keineKontaktID

    case kontaktIDIstKeineZahl(String)

    case belegTypNichtGebaut(String)

    case keinePositionen

    case keinProjekt

    public var klartext: String {
        switch self {
        case .mandantNichtSondiert:
            return "sevDesk-Mandant noch nicht sondiert — einmalig in Einstellungen › System › "
                + "Admin-Zone prüfen lassen. Ohne die Pflicht-IDs des Mandanten lehnt sevDesk ab."
        case .keineKontaktID:
            return "Dieser Kunde hat keine sevDesk-Kontakt-ID. In sevDesk anlegen und die ID am "
                + "Kunden hinterlegen — dann geht der Direktweg."
        case .kontaktIDIstKeineZahl(let value):
            return "Die sevDesk-Kontakt-ID des Kunden ist „\(value)“ — das ist keine Zahl, sondern "
                + "offenbar ein Name. sevDesk würde den Beleg ablehnen. Bitte die echte "
                + "Kontakt-Nummer aus sevDesk am Kunden eintragen."
        case .belegTypNichtGebaut(let typ):
            return "„\(typ)“ geht nicht über den sevDesk-Direktweg — nur Angebote."
        case .keinePositionen:
            return "Der Warenkorb ist leer."
        case .keinProjekt:
            return "Erst ein Projekt wählen — die Projektnummer wird die Kostenstelle des Belegs."
        }
    }
}

public enum SevdeskDirektwegBefund: Equatable, Sendable {
    case moeglich(kontaktID: String)
    case gesperrt([SevdeskDirektwegSperre])

    public var istMoeglich: Bool { if case .moeglich = self { return true }; return false }

    public var klartext: String? {
        guard case .gesperrt(let sperren) = self, sperren.isEmpty == false else { return nil }
        return sperren.map(\.klartext).joined(separator: "\n")
    }
}

public enum SevdeskDirektwegGate {
    public static func pruefe(
        kontextVorhanden: Bool,
        sevDeskKontaktID: String,
        belegTyp: String,
        anzahlPositionen: Int,
        projectNumber: String
    ) -> SevdeskDirektwegBefund {
        var sperren: [SevdeskDirektwegSperre] = []

        if kontextVorhanden == false { sperren.append(.mandantNichtSondiert) }

        let id = sevDeskKontaktID.trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty {
            sperren.append(.keineKontaktID)
        } else if istReineZahl(id) == false {
            sperren.append(.kontaktIDIstKeineZahl(id))
        }

        if belegTyp != "Angebot" { sperren.append(.belegTypNichtGebaut(belegTyp)) }
        if anzahlPositionen <= 0 { sperren.append(.keinePositionen) }
        if projectNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sperren.append(.keinProjekt)
        }

        return sperren.isEmpty ? .moeglich(kontaktID: id) : .gesperrt(sperren)
    }

    static func istReineZahl(_ text: String) -> Bool {
        text.isEmpty == false && text.allSatisfy(\.isASCII) && text.allSatisfy(\.isNumber)
    }
}
