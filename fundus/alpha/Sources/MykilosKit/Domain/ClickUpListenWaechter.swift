import Foundation

public struct ClickUpListenWaechter: Equatable, Sendable {
    public struct Fund: Equatable, Sendable, Identifiable {
        public let projektnummer: String
        public let title: String
        public let befund: ClickUpListenPflicht.Befund
        public var id: String { projektnummer }

        public init(projektnummer: String, title: String, befund: ClickUpListenPflicht.Befund) {
            self.projektnummer = projektnummer
            self.title = title
            self.befund = befund
        }
    }

    public let behebbar: [Fund]

    public let brauchtOrdnernamen: [Fund]

    public var total: Int { behebbar.count + brauchtOrdnernamen.count }
    public var istSauber: Bool { total == 0 }

    public init(behebbar: [Fund], brauchtOrdnernamen: [Fund]) {
        self.behebbar = behebbar
        self.brauchtOrdnernamen = brauchtOrdnernamen
    }

    public static func pruefe(
        projekte: [(projektnummer: String, title: String, phase: String?,
                    clickUpListID: String?, driveFolderName: String?)]
    ) -> ClickUpListenWaechter {
        var offen: [Fund] = []
        var handarbeit: [Fund] = []
        for p in projekte {
            let befund = ClickUpListenPflicht.pruefe(
                phase: p.phase, clickUpListID: p.clickUpListID, driveFolderName: p.driveFolderName)
            let fund = Fund(projektnummer: p.projektnummer, title: p.title, befund: befund)
            switch befund {
            case .hatListe, .archiviert, .lead:   continue
            case .fehltUndKannAngelegtWerden: offen.append(fund)
            case .fehltOhneNamen:          handarbeit.append(fund)
            }
        }

        return .init(behebbar: offen.sorted { $0.projektnummer > $1.projektnummer },
                     brauchtOrdnernamen: handarbeit.sorted { $0.projektnummer > $1.projektnummer })
    }

    public var zusammenfassung: String {
        if istSauber { return "Jedes geführte Projekt hat seine ClickUp-Liste." }
        var teile: [String] = []
        if behebbar.isEmpty == false {
            teile.append("\(behebbar.count) ohne ClickUp-Liste — je ein Klick")
        }
        if brauchtOrdnernamen.isEmpty == false {
            teile.append("\(brauchtOrdnernamen.count) ohne Drive-Ordnername in Airtable — "
                         + "erst dort nachtragen, dann anlegbar")
        }
        return teile.joined(separator: " · ")
    }
}
