import Foundation

public struct ProvisioningWaechter: Equatable, Sendable {
    public struct Fund: Equatable, Sendable, Identifiable {
        public let projektnummer: String
        public let title: String
        public let gaps: ProjektProvisioningLuecken
        public var id: String { projektnummer }

        public init(projektnummer: String, title: String, gaps: ProjektProvisioningLuecken) {
            self.projektnummer = projektnummer
            self.title = title
            self.gaps = gaps
        }
    }

    public let vonHand: [Fund]

    public let ausDerAppUnvollstaendig: [Fund]

    public var total: Int { vonHand.count + ausDerAppUnvollstaendig.count }
    public var istSauber: Bool { total == 0 }

    public init(vonHand: [Fund], ausDerAppUnvollstaendig: [Fund]) {
        self.vonHand = vonHand
        self.ausDerAppUnvollstaendig = ausDerAppUnvollstaendig
    }

    public static func pruefe(
        projekte: [(projektnummer: String, title: String, driveFolderID: String?,
                    clickUpListID: String?, source: String?, phase: String?)],
        archivPhase: String = "Archiviert"
    ) -> ProvisioningWaechter {
        var hand: [Fund] = []
        var app: [Fund] = []
        for p in projekte where p.phase != archivPhase {
            let gaps = ProjektProvisioningLuecken.pruefe(
                projektnummer: p.projektnummer, driveFolderID: p.driveFolderID,
                clickUpListID: p.clickUpListID, source: p.source,
                phase: p.phase)
            guard gaps.istVollstaendig == false else { continue }
            let fund = Fund(projektnummer: p.projektnummer, title: p.title, gaps: gaps)
            if gaps.ausDerApp { app.append(fund) } else { hand.append(fund) }
        }

        return .init(vonHand: hand.sorted { $0.projektnummer > $1.projektnummer },
                     ausDerAppUnvollstaendig: app.sorted { $0.projektnummer > $1.projektnummer })
    }

    public var zusammenfassung: String {
        if istSauber { return "Alle aktiven Projekte haben Drive-Ordner und ClickUp-Liste." }
        var teile: [String] = []
        if vonHand.isEmpty == false {
            teile.append("\(vonHand.count) an ALPHA vorbei angelegt (Hub-Zeile von Hand)")
        }
        if ausDerAppUnvollstaendig.isEmpty == false {
            teile.append("\(ausDerAppUnvollstaendig.count) aus der App, aber unvollständig — "
                         + "hier ist die Provisionierung gescheitert")
        }
        return teile.joined(separator: " · ")
    }
}
