import Foundation

public enum DatenschutzKategorie: String, CaseIterable, Codable, Sendable, Equatable {
    case mail = "Mail"
    case kalender = "Kalender"
    case kontakte = "Kontakte"
    case drive = "Drive & Dateien"
    case clickUp = "ClickUp & Aufgaben"
    case notizen = "Notizen"
    case aufgaben = "Interne Aufgaben"
    case katalogKalkulation = "Katalog & Kalkulation"
    case studioWissen = "Studio-Wissen"
    case chatVerlauf = "Chat-Verlauf"

    public var praeferenzKeyPath: WritableKeyPath<DatenschutzPraeferenzen, Bool> {
        switch self {
        case .mail:              \.teileMailMitAssistent
        case .kalender:           \.teileKalenderMitAssistent
        case .kontakte:           \.teileKontakteMitAssistent
        case .drive:              \.teileDriveMitAssistent
        case .clickUp:            \.teileClickUpMitAssistent
        case .notizen:            \.teileNotizenMitAssistent
        case .aufgaben:           \.teileAufgabenMitAssistent
        case .katalogKalkulation: \.teileKatalogKalkulationMitAssistent
        case .studioWissen:       \.teileStudioWissenMitAssistent
        case .chatVerlauf:        \.teileChatMitAssistent
        }
    }
}

public extension DatenschutzPraeferenzen {
    func angewandtMitAdminSperren(_ gesperrt: Set<DatenschutzKategorie>) -> DatenschutzPraeferenzen {
        var result = self
        for kategorie in gesperrt {
            result[keyPath: kategorie.praeferenzKeyPath] = false
        }
        return result
    }
}
