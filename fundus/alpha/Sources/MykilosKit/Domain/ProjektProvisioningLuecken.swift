import Foundation

public struct ProjektProvisioningLuecken: Equatable, Sendable {
    public static let geburtskanalAbJahr = 2026

    public enum Luecke: String, Equatable, Sendable, CaseIterable {
        case driveOrdner
        case clickUpList

        public var title: String {
            switch self {
            case .driveOrdner:  "Kein Drive-Ordner"
            case .clickUpList: "Keine ClickUp-Liste"
            }
        }
    }

    public let gaps: [Luecke]

    public let ausDerApp: Bool

    public var istVollstaendig: Bool { gaps.isEmpty }

    public init(gaps: [Luecke], ausDerApp: Bool) {
        self.gaps = gaps
        self.ausDerApp = ausDerApp
    }

    public static func pruefe(
        projektnummer: String?, driveFolderID: String?, clickUpListID: String?, source: String?,
        phase: String? = nil
    ) -> ProjektProvisioningLuecken {
        let ausApp = source?.caseInsensitiveCompare("Fragebogen") == .orderedSame
        guard istImGeburtskanalZeitraum(projektnummer) else {
            return .init(gaps: [], ausDerApp: ausApp)
        }
        let istLead = phase?.caseInsensitiveCompare("Lead") == .orderedSame
        var offen: [Luecke] = []
        if isEmpty(driveFolderID) { offen.append(.driveOrdner) }
        if isEmpty(clickUpListID), istLead == false { offen.append(.clickUpList) }
        return .init(gaps: offen, ausDerApp: ausApp)
    }

    static func istImGeburtskanalZeitraum(_ projektnummer: String?) -> Bool {
        guard let roh = projektnummer?.trimmingCharacters(in: .whitespacesAndNewlines),
              let jahrText = roh.split(whereSeparator: { $0 == "-" || $0 == "_" }).first,
              let jahr = Int(jahrText), jahr > 1900
        else { return false }
        return jahr >= geburtskanalAbJahr
    }

    private static func isEmpty(_ value: String?) -> Bool {
        (value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    public var klartext: String? {
        guard istVollstaendig == false else { return nil }
        let was = gaps.map(\.title).joined(separator: " · ")
        if ausDerApp {
            return "\(was). Das Projekt wurde über ALPHA angelegt — hier ist bei der "
                + "Provisionierung etwas schiefgegangen (Details in der Schaltzentrale)."
        }
        return "\(was). Dieses Projekt wurde nicht über ALPHA angelegt (Hub-Zeile von Hand "
            + "erstellt), deshalb lief nie eine Provisionierung."
    }
}
