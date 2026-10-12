import Foundation

public struct CADGeraet: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, label = "bezeichnung", articleNumber = "artikelnummer", hersteller, quantity = "menge" }

    public let id: String
    public var label: String
    public var articleNumber: String?
    public var hersteller: String?
    public var quantity: Int

    public init(id: String, label: String, articleNumber: String? = nil,
                hersteller: String? = nil, quantity: Int = 1) {
        self.id = id
        self.label = label
        self.articleNumber = articleNumber
        self.hersteller = hersteller
        self.quantity = quantity
    }
}

public struct CADProjektStart: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case formatVersion, vorlageDatei, projectNumber = "projektNummer", projectTitle = "projektTitel", raum, customerName = "kundeName", kundenNummer, strasse, plz, ort, geraete, erstelltAm }

    public let formatVersion: Int

    public var vorlageDatei: String
    public var projectNumber: String
    public var projectTitle: String
    public var raum: String
    public var customerName: String
    public var kundenNummer: String?
    public var strasse: String?
    public var plz: String?
    public var ort: String?
    public var geraete: [CADGeraet]
    public var erstelltAm: Date

    public static let aktuelleVersion = 1
    public static let sidecarEndung = "mykcad.json"

    public init(vorlageDatei: String, projectNumber: String, projectTitle: String,
                raum: String = "Küche", customerName: String, kundenNummer: String? = nil,
                strasse: String? = nil, plz: String? = nil, ort: String? = nil,
                geraete: [CADGeraet] = [], erstelltAm: Date,
                formatVersion: Int = CADProjektStart.aktuelleVersion) {
        self.formatVersion = formatVersion
        self.vorlageDatei = vorlageDatei
        self.projectNumber = projectNumber
        self.projectTitle = projectTitle
        self.raum = raum
        self.customerName = customerName
        self.kundenNummer = kundenNummer
        self.strasse = strasse
        self.plz = plz
        self.ort = ort
        self.geraete = geraete
        self.erstelltAm = erstelltAm
    }

    public func kodiere() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(self)
    }

    public static func dekodiere(_ data: Data) throws -> CADProjektStart {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(CADProjektStart.self, from: data)
    }

    public var sidecarDateiname: String {
        let basis = (vorlageDatei as NSString).deletingPathExtension
        let sicher = basis.replacingOccurrences(of: " ", with: "-")
        return "\(projectNumber)_\(sicher).\(Self.sidecarEndung)"
    }

    public func titelblock(date: String) -> VWTitelblock {
        VWTitelblock(
            projektKunde: projectTitle.isEmpty ? customerName : projectTitle,
            raum: raum,
            strasse: strasse ?? "",
            plz: plz ?? "",
            ort: ort ?? "",
            customerNumber: kundenNummer,
            date: date)
    }
}
