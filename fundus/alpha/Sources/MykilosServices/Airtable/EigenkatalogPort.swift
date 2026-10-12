import Foundation
import MykilosKit

public enum EigenkatalogArt: String, Sendable, CaseIterable, Identifiable, Codable {
    case planungsbaustein = "Planungsbaustein"
    case dienstleistung   = "Dienstleistung"
    case stundenleistung  = "Stundenleistung"

    public var id: String { rawValue }
    public var title: String { rawValue }

    public var kennungPraefix: String {
        switch self {
        case .planungsbaustein: "PB"
        case .dienstleistung:   "DL"
        case .stundenleistung:  "SL"
        }
    }

    public var einheiten: [String] {
        switch self {
        case .stundenleistung:  ["Stunde"]
        case .planungsbaustein: ["Stück", "lfm", "m²", "Stunde", "Tag", "Pauschale"]
        case .dienstleistung:   ["Stunde", "Tag", "Pauschale", "m²", "lfm", "Stück"]
        }
    }

    public var preisAusStundensatz: Bool { self == .stundenleistung }
}

public struct Stundensatz: Sendable, Equatable, Identifiable, Codable {
    enum CodingKeys: String, CodingKey { case id, label = "bezeichnung", kuerzel, satzNetto, gueltigAb, isActive = "aktiv", clockodoLeistung }

    public let id: String
    public let label: String
    public let kuerzel: String?
    public let satzNetto: Double?
    public let gueltigAb: Date?
    public let isActive: Bool
    public let clockodoLeistung: String?

    public init(id: String, label: String, kuerzel: String? = nil, satzNetto: Double? = nil,
                gueltigAb: Date? = nil, isActive: Bool = true, clockodoLeistung: String? = nil) {
        self.id = id
        self.label = label
        self.kuerzel = kuerzel
        self.satzNetto = satzNetto
        self.gueltigAb = gueltigAb
        self.isActive = isActive
        self.clockodoLeistung = clockodoLeistung
    }
}

public struct EigenPosition: Sendable, Equatable, Identifiable, Codable {
    enum CodingKeys: String, CodingKey { case id, art, label = "bezeichnung", identifier = "kennung", kategorie, einheit, quantity = "menge", ekNetto, vkNetto, mwstProzent, beschreibung, isActive = "aktiv", klaerungOffen, sevdeskArtikelID, stundensatzID }

    public var id: String
    public var art: EigenkatalogArt
    public var label: String
    public var identifier: String
    public var kategorie: String
    public var einheit: String
    public var quantity: Double?
    public var ekNetto: Double?
    public var vkNetto: Double?
    public var mwstProzent: Double?
    public var beschreibung: String
    public var isActive: Bool
    public var klaerungOffen: String
    public var sevdeskArtikelID: String

    public var stundensatzID: String?

    public init(id: String = "", art: EigenkatalogArt, label: String = "",
                identifier: String = "", kategorie: String = "", einheit: String = "",
                quantity: Double? = nil, ekNetto: Double? = nil, vkNetto: Double? = nil,
                mwstProzent: Double? = nil, beschreibung: String = "", isActive: Bool = true,
                klaerungOffen: String = "", sevdeskArtikelID: String = "",
                stundensatzID: String? = nil) {
        self.id = id
        self.art = art
        self.label = label
        self.identifier = identifier
        self.kategorie = kategorie
        self.einheit = einheit
        self.quantity = quantity
        self.ekNetto = ekNetto
        self.vkNetto = vkNetto
        self.mwstProzent = mwstProzent
        self.beschreibung = beschreibung
        self.isActive = isActive
        self.klaerungOffen = klaerungOffen
        self.sevdeskArtikelID = sevdeskArtikelID
        self.stundensatzID = stundensatzID
    }

    public func wirksamerVK(saetze: [Stundensatz]) -> Double? {
        guard art.preisAusStundensatz, let stundensatzID else { return vkNetto }
        guard let satz = saetze.first(where: { $0.id == stundensatzID }), let value = satz.satzNetto
        else { return vkNetto }
        return value
    }

    public var stundenKontingent: Double? {
        guard art.preisAusStundensatz else { return nil }
        return quantity ?? 0
    }
}

public enum EigenkatalogErgebnis: Sendable, Equatable {
    case geschrieben(recordID: String)
    case schlaeft
    case error(String)
}

public struct EigenkatalogPort: Sendable {
    public static let baseID             = CompanySetup.valueOrEmpty("airtable.base.own_catalog")
    public static let tablePositionen    = CompanySetup.valueOrEmpty("airtable.table.own_catalog_positions")
    public static let tableStundensaetze = CompanySetup.valueOrEmpty("airtable.table.own_catalog_hourly_rates")

    static let fBezeichnung  = "Bezeichnung"
    static let fArt          = "Art"
    static let fKennung      = "Kennung"
    static let fKategorie    = "Kategorie"
    static let fEinheit      = "Einheit"
    static let fMenge        = "Menge"
    static let fStundensatz  = "Stundensatz"
    static let fEK           = "Netto-EK (€)"
    static let fVK           = "Netto-VK (€)"
    static let fMwSt         = "MwSt %"
    static let fBeschreibung = "Beschreibung"
    static let fAktiv        = "Aktiv"
    static let fSevdesk      = "sevDesk Artikel-ID"
    static let fKlaerung     = "Klärung offen"
    static let fAngelegtAm   = "Angelegt am"
    static let fAngelegtVon  = "Angelegt von"
    static let fQuelle       = "Quelle"

    static let sBezeichnung = "Bezeichnung"
    static let sKuerzel     = "Kürzel"
    static let sSatz        = "Satz netto (€/h)"
    static let sGueltigAb   = "Gültig ab"
    static let sAktiv       = "Aktiv"
    static let sClockodo    = "Clockodo-Leistung"

    private let fetcher: AirtableFetching
    private let creator: AirtableRecordCreating
    private let updater: AirtableRecordUpdating

    public init(fetcher: AirtableFetching = AirtableClient(),
                creator: AirtableRecordCreating = AirtableClient(),
                updater: AirtableRecordUpdating = AirtableClient()) {
        self.fetcher = fetcher
        self.creator = creator
        self.updater = updater
    }

    public static var istWach: Bool {
        AirtableClient.isWritable(baseID: baseID, table: tablePositionen)
    }

    static let zeitFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let datumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        return f
    }()

    public func ladePositionen() async throws -> [EigenPosition] {
        let roh = try await fetcher.fetchRecords(baseID: Self.baseID, table: Self.tablePositionen)
        return roh.compactMap(Self.position(aus:))
    }

    public func ladeStundensaetze() async throws -> [Stundensatz] {
        let roh = try await fetcher.fetchRecords(baseID: Self.baseID, table: Self.tableStundensaetze)
        return roh.compactMap(Self.stundensatz(aus:))
    }

    static func position(aus felder: [String: AirtableFieldValue]) -> EigenPosition? {
        guard let label = felder[fBezeichnung]?.anyStringValue, label.isEmpty == false
        else { return nil }
        let artRoh = felder[fArt]?.stringValue ?? EigenkatalogArt.planungsbaustein.rawValue
        return EigenPosition(
            id: felder["_airtableRecordID"]?.stringValue ?? "",
            art: EigenkatalogArt(rawValue: artRoh) ?? .planungsbaustein,
            label: label,
            identifier: felder[fKennung]?.anyStringValue ?? "",
            kategorie: felder[fKategorie]?.stringValue ?? "",
            einheit: felder[fEinheit]?.stringValue ?? "",
            quantity: felder[fMenge]?.numberValue,
            ekNetto: felder[fEK]?.numberValue,
            vkNetto: felder[fVK]?.numberValue,

            mwstProzent: felder[fMwSt]?.numberValue.map { $0 * 100 },
            beschreibung: felder[fBeschreibung]?.stringValue ?? "",
            isActive: felder[fAktiv]?.boolValue ?? true,
            klaerungOffen: felder[fKlaerung]?.stringValue ?? "",
            sevdeskArtikelID: felder[fSevdesk]?.anyStringValue ?? "",
            stundensatzID: felder[fStundensatz]?.firstArrayValue)
    }

    static func stundensatz(aus felder: [String: AirtableFieldValue]) -> Stundensatz? {
        guard let label = felder[sBezeichnung]?.anyStringValue, label.isEmpty == false
        else { return nil }
        return Stundensatz(
            id: felder["_airtableRecordID"]?.stringValue ?? "",
            label: label,
            kuerzel: felder[sKuerzel]?.stringValue,
            satzNetto: felder[sSatz]?.numberValue,
            gueltigAb: felder[sGueltigAb]?.stringValue.flatMap { datumFormatter.date(from: $0) },
            isActive: felder[sAktiv]?.boolValue ?? true,
            clockodoLeistung: felder[sClockodo]?.stringValue)
    }

    public static func felder(_ position: EigenPosition,
                              angelegtVon: String,
                              angelegtAm: Date,
                              source: String = "mykilOS-Anlageformular") -> [String: AirtableFieldValue] {
        var felder: [String: AirtableFieldValue] = [:]
        func text(_ key: String, _ value: String) {
            let sauber = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if sauber.isEmpty == false { felder[key] = .string(sauber) }
        }
        text(fBezeichnung, position.label)
        felder[fArt] = .string(position.art.rawValue)
        text(fKennung, position.identifier)
        text(fKategorie, position.kategorie)
        text(fEinheit, position.einheit)
        text(fBeschreibung, position.beschreibung)
        text(fKlaerung, position.klaerungOffen)
        text(fSevdesk, position.sevdeskArtikelID)
        if let quantity = position.quantity { felder[fMenge] = .number(quantity) }
        if let ek = position.ekNetto { felder[fEK] = .number(ek) }

        if position.art.preisAusStundensatz == false, let vk = position.vkNetto {
            felder[fVK] = .number(vk)
        }
        if let satzID = position.stundensatzID, satzID.isEmpty == false {
            felder[fStundensatz] = .array([satzID])
        }

        if let mwst = position.mwstProzent { felder[fMwSt] = .number(mwst / 100) }
        felder[fAktiv] = .bool(position.isActive)
        felder[fAngelegtAm] = .string(zeitFormatter.string(from: angelegtAm))
        text(fAngelegtVon, angelegtVon)
        felder[fQuelle] = .string(source)
        return felder
    }

    public func lege(_ position: EigenPosition,
                     angelegtVon: String,
                     angelegtAm: Date = Date()) async -> EigenkatalogErgebnis {
        guard Self.istWach else { return .schlaeft }
        do {
            let recordID = try await creator.createRecord(
                baseID: Self.baseID,
                table: Self.tablePositionen,
                fields: Self.felder(position, angelegtVon: angelegtVon, angelegtAm: angelegtAm))
            return .geschrieben(recordID: recordID)
        } catch {
            return .error(String(describing: error))
        }
    }

    public func aendere(_ position: EigenPosition,
                        geaendertVon: String,
                        am: Date = Date()) async -> EigenkatalogErgebnis {
        guard Self.istWach else { return .schlaeft }
        guard position.id.isEmpty == false else {
            return .error("Position ohne Record-ID — sie wurde nie angelegt.")
        }
        var felder = Self.felder(position, angelegtVon: geaendertVon, angelegtAm: am)

        felder.removeValue(forKey: Self.fAngelegtAm)
        felder.removeValue(forKey: Self.fAngelegtVon)
        felder.removeValue(forKey: Self.fQuelle)
        do {
            try await updater.updateRecord(baseID: Self.baseID, table: Self.tablePositionen,
                                           recordID: position.id, fields: felder)
            return .geschrieben(recordID: position.id)
        } catch {
            return .error(String(describing: error))
        }
    }

    public func stilllegen(_ position: EigenPosition, durch: String) async -> EigenkatalogErgebnis {
        var stillgelegt = position
        stillgelegt.isActive = false
        return await aendere(stillgelegt, geaendertVon: durch)
    }

    public static func kennungsVorschlag(_ art: EigenkatalogArt, date: Date = Date()) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "de_DE")
        fmt.dateFormat = "yyMMdd"
        let suffix = String(UUID().uuidString.prefix(4)).uppercased()
        return "\(art.kennungPraefix)-\(fmt.string(from: date))-\(suffix)"
    }
}
