import Foundation

public struct AirtableContactDraft: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey { case intent, recordID, name, organisation, email, telefon, adresse, kategorie, projekt, source = "quelle", strasse, houseNumber = "hausnummer", plz, ort, land, vollerFeldsatz, history = "verlauf" }

    public enum Intent: String, Codable, Sendable, Equatable {
        case create
        case update
    }

    public var intent: Intent

    public var recordID: String?

    public var history: String?
    public var name: String
    public var organisation: String?
    public var email: String?
    public var telefon: String?
    public var adresse: String?
    public var kategorie: String?

    public var projekt: String?

    public var source: KontaktQuelle

    public var strasse: String?
    public var houseNumber: String?
    public var plz: String?
    public var ort: String?
    public var land: String?

    public var vollerFeldsatz: Bool

    public init(intent: Intent, recordID: String? = nil, name: String,
                organisation: String? = nil, email: String? = nil,
                telefon: String? = nil, adresse: String? = nil,
                kategorie: String? = nil, projekt: String? = nil,
                source: KontaktQuelle = .weitereKontakte,
                strasse: String? = nil, houseNumber: String? = nil,
                plz: String? = nil, ort: String? = nil, land: String? = nil,
                vollerFeldsatz: Bool = false) {
        self.intent = intent
        self.recordID = recordID
        self.name = name
        self.organisation = organisation
        self.email = email
        self.telefon = telefon
        self.adresse = adresse
        self.kategorie = kategorie
        self.projekt = projekt
        self.source = source
        self.strasse = strasse
        self.houseNumber = houseNumber
        self.plz = plz
        self.ort = ort
        self.land = land
        self.vollerFeldsatz = vollerFeldsatz
    }

    public var displayName: String { name }

    public var airtableFields: [String: String] {
        var f: [String: String] = ["Name": name]
        if let v = organisation { f["Organisation"] = v }
        if let v = email { f["E-Mail"] = v }
        if let v = telefon { f["Telefon"] = v }
        if let v = adresse { f["Adresse"] = v }
        if let v = kategorie { f["Kategorie"] = v }
        if let v = projekt { f["Projekt"] = v }
        return f
    }
}

public enum AirtableContactWriteOutcome: Sendable, Equatable {
    case created(String)
    case updated(String)
    case failed(String)
}

public enum ContactPhotoUploadOutcome: Sendable, Equatable {
    case uploaded(String)
    case failed(String)
}
