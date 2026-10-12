import Foundation

public enum ClickUpListenPflicht {
    public static let archivPhase = "Archiviert"

    public static let leadPhase = "Lead"

    public enum Befund: Equatable, Sendable {
        case hatListe(listID: String)

        case fehltUndKannAngelegtWerden(listsName: String)

        case fehltOhneNamen

        case archiviert

        case lead
    }

    public static func pruefe(
        phase: String?, clickUpListID: String?, driveFolderName: String?
    ) -> Befund {
        if let listID = gefuellt(clickUpListID) { return .hatListe(listID: listID) }
        if phase?.caseInsensitiveCompare(archivPhase) == .orderedSame { return .archiviert }
        if phase?.caseInsensitiveCompare(leadPhase) == .orderedSame { return .lead }
        guard let name = gefuellt(driveFolderName) else { return .fehltOhneNamen }
        return .fehltUndKannAngelegtWerden(listsName: name)
    }

    private static func gefuellt(_ value: String?) -> String? {
        guard let w = value?.trimmingCharacters(in: .whitespacesAndNewlines), w.isEmpty == false
        else { return nil }
        return w
    }
}

public extension ClickUpListenPflicht.Befund {
    var klartext: String? {
        switch self {
        case .hatListe, .archiviert, .lead:
            return nil
        case .fehltUndKannAngelegtWerden(let name):
            return "Dieses Projekt hat keine ClickUp-Liste. Sie würde „\(name)“ heißen — "
                + "wie der Drive-Ordner."
        case .fehltOhneNamen:
            return "Dieses Projekt hat keine ClickUp-Liste, und der Drive-Ordnername fehlt in "
                + "Airtable — ohne ihn ist der Listenname nicht bekannt. Er wird hier bewusst "
                + "nicht erfunden, weil eine zweite Namenskonvention in ClickUp niemand mehr "
                + "einfängt."
        }
    }

    var istBehebbar: Bool {
        if case .fehltUndKannAngelegtWerden = self { return true }
        return false
    }
}
