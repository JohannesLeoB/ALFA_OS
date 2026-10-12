import Foundation

public enum SevdeskKontaktTreffer: Equatable, Sendable {
    case eindeutig(id: String, name: String?)

    case keiner

    case mehrdeutig([Kandidat])

    case nurAnsprechpartner(Kandidat)

    public struct Kandidat: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String?

        public let istAnsprechpartner: Bool
        public init(id: String, name: String?, istAnsprechpartner: Bool = false) {
            self.id = id; self.name = name; self.istAnsprechpartner = istAnsprechpartner
        }
    }

    public var eindeutigeID: String? {
        if case .eindeutig(let id, _) = self { return id }
        return nil
    }

    public func klartext(search: String) -> String {
        switch self {
        case .eindeutig(let id, let name):
            let wer = name.map { " („\($0)“)" } ?? ""
            return "sevDesk-Kontakt #\(id)\(wer) — über „\(search)“ gefunden."
        case .keiner:
            return "In sevDesk gibt es keinen Kontakt zu „\(search)“. Entweder ist der Kunde dort "
                + "nicht angelegt, oder er heißt/nummeriert dort anders."
        case .mehrdeutig(let candidates):
            let list = candidates.map { "#\($0.id)\($0.name.map { n in " \(n)" } ?? "")" }
                .joined(separator: ", ")
            return "Zu „\(search)“ passen in sevDesk \(candidates.count) Kontakte: \(list). "
                + "ALPHA kann nicht wissen, welcher gemeint ist — bitte in sevDesk eindeutig machen."
        case .nurAnsprechpartner(let k):
            let wer = k.name.map { " („\($0)“)" } ?? ""
            return "„\(search)“ trifft in sevDesk nur einen "
                + "Ansprechpartner\(wer), keine Firma. Der Beleg ginge an die Person statt an das "
                + "Unternehmen — bitte die Nummer an der Organisation hinterlegen."
        }
    }
}
