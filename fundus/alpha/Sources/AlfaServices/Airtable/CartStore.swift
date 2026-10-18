import Foundation
import AlfaKit

public enum CartSendOutcome: Sendable, Equatable {
    case success(recordID: String, version: Int)

    case isEmpty
}

public struct CartStore: Sendable {
    public static let artikelBaseID      = CompanySetup.valueOrEmpty("airtable.base.article_catalog_legacy")
    public static let warenkorbBaseID    = CompanySetup.valueOrEmpty("airtable.base.checkout_cart")
    public static let warenkorbTable     = "Warenkörbe"

    public static let feldBezeichnung      = "Bezeichnung"
    public static let feldProjekt          = "Projekt"
    public static let feldPruefsumme       = "Prüfsumme"
    public static let feldVersion          = "Version"
    public static let feldStatus           = "Status"
    public static let feldAnzahlPositionen = "Anzahl Positionen"
    public static let feldGesamtEK         = "Gesamt EK (€)"
    public static let feldGesamtVK         = "Gesamt VK (€)"
    public static let feldPositionenJSON   = "Positionen (JSON)"
    public static let feldErstelltAm       = "Erstellt-am"

    static let feldPruefsummeName = "Prüfsumme"
    static let feldStatusName     = "Status"
    static let feldVersionName    = "Version"

    public static let statusAktuell     = "Aktuell"
    public static let statusArchiviert  = "Archiviert"

    private let fetcher: AirtableFetching
    private let creator: AirtableRecordCreating
    private let updater: AirtableRecordUpdating
    private let auditStore: AuditStore?
    private let actorUserID: String

    public init(
        fetcher: AirtableFetching,
        creator: AirtableRecordCreating,
        updater: AirtableRecordUpdating,
        auditStore: AuditStore? = nil,
        actorUserID: String = "system"
    ) {
        self.fetcher = fetcher
        self.creator = creator
        self.updater = updater
        self.auditStore = auditStore
        self.actorUserID = actorUserID
    }

    public func sendWarenkorbToAirtable(
        _ wk: Warenkorb,
        akteurProjektID: String = ""
    ) async throws -> CartSendOutcome {
        guard !wk.items.isEmpty else { return .isEmpty }

        let pruefsumme = wk.pruefsumme

        let bestehend = try await fetcher.fetchRecords(
            baseID: Self.warenkorbBaseID,
            table: Self.warenkorbTable
        )

        let zuArchivieren = bestehend.filter { record in
            record[Self.feldPruefsummeName]?.stringValue == pruefsumme
            && record[Self.feldStatusName]?.stringValue == Self.statusAktuell
        }

        for record in zuArchivieren {
            guard let recordID = record["_airtableRecordID"]?.stringValue else { continue }
            try await updater.updateRecord(
                baseID: Self.warenkorbBaseID,
                table: Self.warenkorbTable,
                recordID: recordID,
                fields: [Self.feldStatus: .string(Self.statusArchiviert)]
            )
        }

        let letzteVersion: Int = bestehend
            .filter { $0[Self.feldPruefsummeName]?.stringValue == pruefsumme }
            .compactMap { $0[Self.feldVersionName]?.numberValue }
            .map { Int($0) }
            .max() ?? 0
        let neueVersion = letzteVersion + 1

        let positioenenJSON = try Self.serializeItems(wk.items)

        let iso8601 = ISO8601DateFormatter().string(from: Date())

        let label: String
        if let name = wk.projektName, !name.isEmpty {
            label = "Warenkorb \(name) v\(neueVersion)"
        } else {
            let kurz = String(pruefsumme.prefix(8))
            label = "Warenkorb \(kurz) v\(neueVersion)"
        }

        var felder: [String: AirtableFieldValue] = [
            Self.feldBezeichnung: .string(label),
            Self.feldPruefsumme: .string(pruefsumme),
            Self.feldVersion: .number(Double(neueVersion)),
            Self.feldStatus: .string(Self.statusAktuell),
            Self.feldAnzahlPositionen: .number(Double(wk.items.count)),
            Self.feldGesamtEK: .number(wk.gesamtEKNetto),
            Self.feldGesamtVK: .number(wk.gesamtVKNetto),
            Self.feldPositionenJSON: .string(positioenenJSON),
            Self.feldErstelltAm: .string(iso8601)
        ]

        if let name = wk.projektName, name.isEmpty == false {
            felder[Self.feldProjekt] = .string(name)
        }

        let neueRecordID = try await creator.createRecord(
            baseID: Self.warenkorbBaseID,
            table: Self.warenkorbTable,
            fields: felder
        )

        let ekTeil = wk.gesamtEKNetto > 0 ? ", EK \(String(format: "%.2f", wk.gesamtEKNetto)) €" : ""
        await appendAudit(
            projektID: akteurProjektID,
            summary: "Warenkorb '\(label)' v\(neueVersion) → Airtable (\(wk.items.count) Pos.\(ekTeil))"
        )

        return .success(recordID: neueRecordID, version: neueVersion)
    }

    public static func serializeItems(_ items: [WarenkorbItem]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(items)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CartStoreError.serializationFailed
        }
        return string
    }

    public static func deserializeItems(from json: String) throws -> [WarenkorbItem] {
        guard let data = json.data(using: .utf8) else {
            throw CartStoreError.serializationFailed
        }
        return try JSONDecoder().decode([WarenkorbItem].self, from: data)
    }

    @MainActor
    private func appendAudit(projektID: String, summary: String) {
        let entry = AuditEntry(
            actorUserID: actorUserID,
            projectID: projektID,
            action: .warenkorbGesendet,
            summary: summary
        )
        try? auditStore?.append(entry)
    }
}

public enum CartStoreError: Error, Sendable, Equatable {
    case serializationFailed
    case leeresWarenkorb
}
