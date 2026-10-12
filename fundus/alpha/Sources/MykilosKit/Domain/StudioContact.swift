import Foundation

public enum KontaktQuelle: String, Codable, Sendable, Equatable {
    case golden
    case lieferant
    case weitereKontakte
}

public struct StudioContact: Codable, Identifiable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, name, organisation, email, telefon, adresse, strasse, houseNumber = "hausnummer", plz, ort, land, sevDeskKontaktID, zahlungszielTage, zahlungsbedingungText, projekt, kategorie, vorname, nachname, photoURL, customerNumber = "kundennummer", source = "quelle", history = "verlauf" }

    public let id: String
    public var name: String
    public var organisation: String?
    public var email: String?
    public var telefon: String?
    public var adresse: String?

    public var strasse: String?

    public var houseNumber: String?
    public var plz: String?
    public var ort: String?

    public var land: String?
    public var sevDeskKontaktID: String?
    public var zahlungszielTage: Int?
    public var zahlungsbedingungText: String?
    public var projekt: String?
    public var kategorie: String?

    public var vorname: String?
    public var nachname: String?

    public var photoURL: String?

    public var customerNumber: String?

    public var history: String?

    public var source: KontaktQuelle

    public init(id: String, name: String, organisation: String? = nil, email: String? = nil,
                telefon: String? = nil, adresse: String? = nil,
                strasse: String? = nil, houseNumber: String? = nil,
                plz: String? = nil, ort: String? = nil,
                land: String? = nil, sevDeskKontaktID: String? = nil,
                zahlungszielTage: Int? = nil, zahlungsbedingungText: String? = nil,
                projekt: String? = nil,
                kategorie: String? = nil, vorname: String? = nil, nachname: String? = nil,
                photoURL: String? = nil, customerNumber: String? = nil, history: String? = nil,
                source: KontaktQuelle = .weitereKontakte) {
        self.id = id
        self.name = name
        self.organisation = organisation
        self.email = email
        self.telefon = telefon
        self.adresse = adresse
        self.strasse = strasse
        self.houseNumber = houseNumber
        self.plz = plz
        self.ort = ort
        self.land = land
        self.sevDeskKontaktID = sevDeskKontaktID
        self.zahlungszielTage = zahlungszielTage
        self.zahlungsbedingungText = zahlungsbedingungText
        self.projekt = projekt
        self.kategorie = kategorie
        self.vorname = vorname
        self.nachname = nachname
        self.photoURL = photoURL
        self.customerNumber = customerNumber
        self.history = history
        self.source = source
    }

    public func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        return name.lowercased().contains(q)
            || (organisation?.lowercased().contains(q) ?? false)
            || (projekt?.lowercased().contains(q) ?? false)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        organisation = try c.decodeIfPresent(String.self, forKey: .organisation)
        email = try c.decodeIfPresent(String.self, forKey: .email)
        telefon = try c.decodeIfPresent(String.self, forKey: .telefon)
        adresse = try c.decodeIfPresent(String.self, forKey: .adresse)
        strasse = try c.decodeIfPresent(String.self, forKey: .strasse)
        houseNumber = try c.decodeIfPresent(String.self, forKey: .houseNumber)
        plz = try c.decodeIfPresent(String.self, forKey: .plz)
        ort = try c.decodeIfPresent(String.self, forKey: .ort)
        land = try c.decodeIfPresent(String.self, forKey: .land)
        sevDeskKontaktID = try c.decodeIfPresent(String.self, forKey: .sevDeskKontaktID)
        zahlungszielTage = try c.decodeIfPresent(Int.self, forKey: .zahlungszielTage)
        zahlungsbedingungText = try c.decodeIfPresent(String.self, forKey: .zahlungsbedingungText)
        projekt = try c.decodeIfPresent(String.self, forKey: .projekt)
        kategorie = try c.decodeIfPresent(String.self, forKey: .kategorie)
        vorname = try c.decodeIfPresent(String.self, forKey: .vorname)
        nachname = try c.decodeIfPresent(String.self, forKey: .nachname)
        photoURL = try c.decodeIfPresent(String.self, forKey: .photoURL)
        customerNumber = try c.decodeIfPresent(String.self, forKey: .customerNumber)
        history = try c.decodeIfPresent(String.self, forKey: .history)
        source = try c.decodeIfPresent(KontaktQuelle.self, forKey: .source) ?? .weitereKontakte
    }
}
