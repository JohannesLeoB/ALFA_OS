import Foundation

public enum ClickUpNachruestFehler: Error, LocalizedError, Equatable {
    case nichtNachruestbar(ClickUpListenPflicht.Befund)

    public var errorDescription: String? {
        switch self {
        case .nichtNachruestbar(let befund):
            switch befund {
            case .hatListe(let id):
                return "Dieses Projekt hat bereits die ClickUp-Liste \(id)."
            case .archiviert:
                return "Dieses Projekt ist archiviert — dort wird nicht mehr gearbeitet, also "
                    + "braucht es auch keine ClickUp-Liste."
            case .fehltOhneNamen:
                return "Der Drive-Ordnername fehlt in Airtable. Ohne ihn ist der Listenname nicht "
                    + "bekannt, und er wird hier nicht erfunden — sonst entstünde eine zweite "
                    + "Namenskonvention in ClickUp. Trage den Ordnernamen in der Hub-Zeile nach."
            case .lead:
                return "Dieses Projekt ist ein Lead: es hat bewusst nur eine Karte in "
                    + "„Leads 2026\" — die volle Liste entsteht erst beim Beleben."
            case .fehltUndKannAngelegtWerden:
                return nil
            }
        }
    }
}
