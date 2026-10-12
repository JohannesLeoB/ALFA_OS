import Foundation

public enum Fehlertext {
    public static func fuerMenschen(_ error: Error) -> String {
        let roh = String(describing: error)

        if enthaelt(roh, "401") || enthaelt(roh, "403")
            || roh.localizedCaseInsensitiveContains("unauthorized")
            || roh.localizedCaseInsensitiveContains("notconnected") {
            return "Die Anmeldung ist abgelaufen. In den Einstellungen neu verbinden."
        }

        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "Keine Verbindung. Sobald das Netz wieder da ist, lädt es von selbst."
            case .timedOut:
                return "Die Gegenstelle hat zu lange gebraucht. Später noch einmal versuchen."
            default:
                break
            }
        }
        if enthaelt(roh, "-1009") { return "Keine Verbindung. Sobald das Netz wieder da ist, lädt es von selbst." }
        if enthaelt(roh, "-1001") { return "Die Gegenstelle hat zu lange gebraucht. Später noch einmal versuchen." }

        if enthaelt(roh, "429") {
            return "Zu viele Anfragen auf einmal. Es geht gleich weiter."
        }
        if enthaelt(roh, "500") || enthaelt(roh, "502") || enthaelt(roh, "503") {
            return "Der Dienst antwortet gerade nicht. Das liegt nicht an dieser App."
        }

        if enthaelt(roh, "404") {
            return "Nicht gefunden. Möglicherweise wurde es verschoben oder gelöscht."
        }

        if let lokal = error as? LocalizedError, let text = lokal.errorDescription, text.isEmpty == false {
            return text
        }

        return "Das hat nicht geklappt. Einzelheiten stehen im Datenstrom-Protokoll."
    }

    private static func enthaelt(_ text: String, _ code: String) -> Bool {
        guard let area = text.range(of: code) else { return false }
        let davor = area.lowerBound == text.startIndex
            ? nil : text[text.index(before: area.lowerBound)]
        let danach = area.upperBound == text.endIndex
            ? nil : text[area.upperBound]
        let istZiffer: (Character?) -> Bool = { $0?.isNumber ?? false }
        return istZiffer(davor) == false && istZiffer(danach) == false
    }
}
