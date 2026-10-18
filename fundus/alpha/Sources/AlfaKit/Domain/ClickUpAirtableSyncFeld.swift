import Foundation

public struct ClickUpAirtableSyncFeld: Identifiable, Sendable, Equatable {
    public enum Typ: String, Sendable, Equatable {
        case zahl
        case text
        case date
        case dropdown
    }

    public let clickUpName: String

    public let airtableName: String

    public let typ: Typ

    public let isActive: Bool

    public var id: String { clickUpName }

    public init(clickUpName: String, airtableName: String, typ: Typ, isActive: Bool = true) {
        self.clickUpName = clickUpName
        self.airtableName = airtableName
        self.typ = typ
        self.isActive = isActive
    }
}

public enum ClickUpAirtableSyncRegister {
    public static let alle: [ClickUpAirtableSyncFeld] = [

        ClickUpAirtableSyncFeld(clickUpName: "project_phase", airtableName: "Phase", typ: .dropdown),
        ClickUpAirtableSyncFeld(clickUpName: "Wahrscheinlichkeit", airtableName: "Wahrscheinlichkeit %", typ: .zahl),
        ClickUpAirtableSyncFeld(clickUpName: "Kontaktweg", airtableName: "Kontaktweg", typ: .dropdown),
        ClickUpAirtableSyncFeld(clickUpName: "Budgetstatus", airtableName: "Budgetstatus", typ: .dropdown),

        ClickUpAirtableSyncFeld(clickUpName: "Quelle", airtableName: "Quelle (Sales)", typ: .dropdown),
        ClickUpAirtableSyncFeld(clickUpName: "Projektart", airtableName: "Projektart", typ: .dropdown),
        ClickUpAirtableSyncFeld(clickUpName: "Umsetzungszeitraum", airtableName: "Umsetzungsdatum", typ: .date),
        ClickUpAirtableSyncFeld(clickUpName: "Deal-Date!", airtableName: "Deal-Date", typ: .date),
        ClickUpAirtableSyncFeld(clickUpName: "Erwarteter Umsatz", airtableName: "Erwarteter Umsatz", typ: .zahl)
    ]

    public static var active: [ClickUpAirtableSyncFeld] { alle.filter(\.isActive) }

    public static func fuerClickUp(_ name: String) -> ClickUpAirtableSyncFeld? {
        alle.first { $0.isActive && $0.clickUpName == name }
    }
}
