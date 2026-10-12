import Foundation

public struct DHLAdresse: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey { case name1, name2, strasse, houseNumber = "hausnummer", plz, ort, land }

    public var name1: String
    public var name2: String?
    public var strasse: String
    public var houseNumber: String
    public var plz: String
    public var ort: String
    public var land: String

    public init(name1: String, name2: String? = nil, strasse: String, houseNumber: String,
                plz: String, ort: String, land: String = "DEU") {
        self.name1 = name1
        self.name2 = name2?.trimmingCharacters(in: .whitespaces).nilWennLeer
        self.strasse = strasse
        self.houseNumber = houseNumber
        self.plz = plz
        self.ort = ort
        self.land = land
    }

    public var addressStreet: String {
        houseNumber.isEmpty ? strasse : "\(strasse) \(houseNumber)"
    }

    public static func aus(name: String, adresszeile: String?, plz: String?, ort: String?,
                           land: String = "DEU") -> DHLAdresse {
        let split = STRNummer.splitStrasseHausnummer(adresszeile)
        return DHLAdresse(
            name1: name.trimmingCharacters(in: .whitespaces),
            strasse: (split.strasse ?? "").trimmingCharacters(in: .whitespaces),
            houseNumber: (split.houseNumber ?? "").trimmingCharacters(in: .whitespaces),
            plz: (plz ?? "").trimmingCharacters(in: .whitespaces),
            ort: (ort ?? "").trimmingCharacters(in: .whitespaces),
            land: land
        )
    }
}

public struct DHLMasse: Codable, Sendable, Equatable {
    public var laengeCm: Int
    public var breiteCm: Int
    public var hoeheCm: Int

    public init(laengeCm: Int, breiteCm: Int, hoeheCm: Int) {
        self.laengeCm = laengeCm
        self.breiteCm = breiteCm
        self.hoeheCm = hoeheCm
    }

    public var istVollstaendig: Bool { laengeCm > 0 && breiteCm > 0 && hoeheCm > 0 }
}

public struct DHLVersandAuftrag: Sendable, Equatable {
    public var absender: DHLAdresse
    public var empfaenger: DHLAdresse
    public var gewichtGramm: Int
    public var produkt: String
    public var abrechnungsnummer: String
    public var referenz: String?

    public var masse: DHLMasse?
    public var versicherungswertEuro: Double?
    public var nurEigenhaendig: Bool
    public var sperrgut: Bool
    public var mitUnterschrift: Bool

    public init(absender: DHLAdresse, empfaenger: DHLAdresse, gewichtGramm: Int,
                produkt: String = "V01PAK", abrechnungsnummer: String, referenz: String? = nil,
                masse: DHLMasse? = nil, versicherungswertEuro: Double? = nil,
                nurEigenhaendig: Bool = false, sperrgut: Bool = false, mitUnterschrift: Bool = false) {
        self.absender = absender
        self.empfaenger = empfaenger
        self.gewichtGramm = gewichtGramm
        self.produkt = produkt
        self.abrechnungsnummer = abrechnungsnummer
        self.referenz = referenz
        self.masse = masse
        self.versicherungswertEuro = versicherungswertEuro
        self.nurEigenhaendig = nurEigenhaendig
        self.sperrgut = sperrgut
        self.mitUnterschrift = mitUnterschrift
    }
}

public enum DHLAuftragFehler: String, Sendable, Equatable, CaseIterable {
    case empfaengerName      = "Empfänger-Name fehlt"
    case empfaengerStrasse   = "Empfänger-Straße fehlt"
    case empfaengerPlz       = "Empfänger-PLZ fehlt oder ungültig"
    case empfaengerOrt       = "Empfänger-Ort fehlt"
    case absenderUnvollstaendig = "Absender-Adresse unvollständig"
    case gewicht             = "Gewicht muss größer als 0 sein"
    case abrechnungsnummer   = "Abrechnungsnummer muss 14-stellig sein"
}

public enum DHLAuftragPruefung {
    public static func pruefe(_ a: DHLVersandAuftrag) -> [DHLAuftragFehler] {
        var f: [DHLAuftragFehler] = []
        if a.empfaenger.name1.isEmpty { f.append(.empfaengerName) }
        if a.empfaenger.strasse.isEmpty { f.append(.empfaengerStrasse) }
        if istGueltigePlz(a.empfaenger.plz) == false { f.append(.empfaengerPlz) }
        if a.empfaenger.ort.isEmpty { f.append(.empfaengerOrt) }
        if a.absender.name1.isEmpty || a.absender.strasse.isEmpty
            || istGueltigePlz(a.absender.plz) == false || a.absender.ort.isEmpty {
            f.append(.absenderUnvollstaendig)
        }
        if a.gewichtGramm <= 0 { f.append(.gewicht) }
        if a.abrechnungsnummer.filter(\.isNumber).count != 14 { f.append(.abrechnungsnummer) }
        return f
    }

    public static func istGueltigePlz(_ plz: String) -> Bool {
        let z = plz.filter { !$0.isWhitespace }
        return z.count == 5 && z.allSatisfy(\.isNumber)
    }
}

public enum DHLReferenz {
    public static let maxLaenge = 35

    public static func kommissionAusProjektname(_ name: String) -> String {
        var s = name.trimmingCharacters(in: .whitespaces)
        if let regex = try? NSRegularExpression(pattern: "^\\d{4}[_-]\\d{2,4}[_-]") {
            let range = NSRange(s.startIndex..<s.endIndex, in: s)
            s = regex.stringByReplacingMatches(in: s, range: range, withTemplate: "")
        }
        s = s.replacingOccurrences(of: "_", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s.trimmingCharacters(in: .whitespaces)
    }

    public static func refNo(projectNumber: String?, projektName: String?) -> String? {
        let kommission = projektName.map(kommissionAusProjektname)?.nilWennLeer
        let number = projectNumber?.trimmingCharacters(in: .whitespaces).nilWennLeer
        let teile = [kommission, number].compactMap { $0 }
        guard teile.isEmpty == false else { return nil }
        let zusammen = teile.joined(separator: " · ")
        return String(zusammen.prefix(maxLaenge))
    }
}

private extension String {
    var nilWennLeer: String? { isEmpty ? nil : self }
}

public enum DHLOrderBuilder {
    public struct OrderRequest: Codable, Equatable {
        public let profile: String
        public let shipments: [Shipment]
    }
    public struct Shipment: Codable, Equatable {
        public let product: String
        public let billingNumber: String
        public let refNo: String?
        public let shipper: Address
        public let consignee: Address
        public let details: Details
        public let services: Services?
    }
    public struct Address: Codable, Equatable {
        public let name1: String
        public let name2: String?
        public let addressStreet: String
        public let postalCode: String
        public let city: String
        public let country: String
    }
    public struct Details: Codable, Equatable {
        public let weight: Weight
        public let dim: Dimension?
    }
    public struct Weight: Codable, Equatable {
        public let uom: String
        public let value: Int
    }
    public struct Dimension: Codable, Equatable {
        public let uom: String
        public let length: Int
        public let width: Int
        public let height: Int
    }
    public struct Services: Codable, Equatable {
        public let namedPersonOnly: Bool?
        public let bulkyGoods: Bool?
        public let signedForByRecipient: Bool?
        public let additionalInsurance: MonetaryValue?
    }
    public struct MonetaryValue: Codable, Equatable {
        public let currency: String
        public let value: Double
    }

    public static func request(_ a: DHLVersandAuftrag, profil: String = "STANDARD_GRUPPENPROFIL") -> OrderRequest {
        OrderRequest(profile: profil, shipments: [
            Shipment(
                product: a.produkt,
                billingNumber: a.abrechnungsnummer.filter(\.isNumber),
                refNo: a.referenz,
                shipper: adresse(a.absender),
                consignee: adresse(a.empfaenger),
                details: Details(weight: Weight(uom: "g", value: a.gewichtGramm), dim: dimension(a.masse)),
                services: services(a)
            )
        ])
    }

    private static func dimension(_ m: DHLMasse?) -> Dimension? {
        guard let m, m.istVollstaendig else { return nil }
        return Dimension(uom: "cm", length: m.laengeCm, width: m.breiteCm, height: m.hoeheCm)
    }

    private static func services(_ a: DHLVersandAuftrag) -> Services? {
        let versicherung = (a.versicherungswertEuro ?? 0) > 0
            ? MonetaryValue(currency: "EUR", value: a.versicherungswertEuro!) : nil
        let hatService = a.nurEigenhaendig || a.sperrgut || a.mitUnterschrift || versicherung != nil
        guard hatService else { return nil }
        return Services(
            namedPersonOnly: a.nurEigenhaendig ? true : nil,
            bulkyGoods: a.sperrgut ? true : nil,
            signedForByRecipient: a.mitUnterschrift ? true : nil,
            additionalInsurance: versicherung)
    }

    private static func adresse(_ d: DHLAdresse) -> Address {
        Address(name1: d.name1, name2: d.name2, addressStreet: d.addressStreet,
                postalCode: d.plz.filter { !$0.isWhitespace }, city: d.ort, country: d.land)
    }
}
