import Foundation
import MykilosKit

public struct MediathekAsset: Sendable, Equatable {
    public let recordID: String

    public let name: String
    public let drivePfad: String
    public let hersteller: String?
    public let kategorie: String?
    public let tags: [String]
    public let beschreibung: String?
    public let verifiziert: Bool

    public init(recordID: String, name: String, drivePfad: String,
                hersteller: String? = nil, kategorie: String? = nil, tags: [String] = [],
                beschreibung: String? = nil, verifiziert: Bool = false) {
        self.recordID = recordID
        self.name = name
        self.drivePfad = drivePfad
        self.hersteller = hersteller
        self.kategorie = kategorie
        self.tags = tags
        self.beschreibung = beschreibung
        self.verifiziert = verifiziert
    }

    public var suchTokens: [String] {
        var tokens = ArtikelItem.tokenize(name)
        if let h = hersteller { tokens.append(contentsOf: ArtikelItem.tokenize(h)) }
        if let k = kategorie { tokens.append(contentsOf: ArtikelItem.tokenize(k)) }
        for t in tags { tokens.append(contentsOf: ArtikelItem.tokenize(t)) }
        if let b = beschreibung { tokens.append(contentsOf: ArtikelItem.tokenize(b)) }
        return tokens
    }
}

public struct MediathekTreffer: Sendable, Equatable, Identifiable {
    public let asset: MediathekAsset
    public let score: Int
    public var id: String { asset.recordID }
    public init(asset: MediathekAsset, score: Int) { self.asset = asset; self.score = score }
}

public struct MediathekAssetKatalog: Sendable, Equatable {
    public let proPfad: [String: MediathekAsset]

    public let proDateiname: [String: MediathekAsset]

    public init(proPfad: [String: MediathekAsset], proDateiname: [String: MediathekAsset]) {
        self.proPfad = proPfad
        self.proDateiname = proDateiname
    }

    public var isEmpty: Bool { proPfad.isEmpty }
    public var count: Int { proPfad.count }

    public func asset(pfad: String) -> MediathekAsset? {
        if let exakt = proPfad[pfad] { return exakt }
        let name = (pfad as NSString).lastPathComponent.lowercased()
        return proDateiname[name]
    }

    public var alle: [MediathekAsset] { Array(proPfad.values) }

    public func search(term: String, limit: Int = 30) -> [MediathekTreffer] {
        let suchTokens = ArtikelItem.tokenize(term)
        guard suchTokens.isEmpty == false else { return [] }
        let suchSet = Set(suchTokens)
        var results: [MediathekTreffer] = []
        for asset in proPfad.values {
            let assetSet = Set(asset.suchTokens)
            let exakt = assetSet.intersection(suchSet).count
            var praefix = 0
            if exakt < suchSet.count {
                for suchWort in suchSet.subtracting(assetSet)
                where assetSet.contains(where: { $0.hasPrefix(suchWort) }) {
                    praefix += 1
                }
            }
            let score = exakt * 2 + praefix
            if score > 0 { results.append(MediathekTreffer(asset: asset, score: score)) }
        }
        return Array(results.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.asset.name < $1.asset.name
        }.prefix(limit))
    }
}

public enum MediathekAssetIndex {
    public static let baseID = CompanySetup.valueOrEmpty("airtable.base.media_library")
    static let assetsTable     = CompanySetup.valueOrEmpty("airtable.table.media_assets")
    static let herstellerTable = CompanySetup.valueOrEmpty("airtable.table.media_manufacturers")
    static let kategorienTable = CompanySetup.valueOrEmpty("airtable.table.media_categories")

    static let feldName         = "Name"
    static let feldDrivePfad    = "Drive-Pfad"
    static let feldBeschreibung = "Beschreibung"
    static let feldTags         = "Tags"
    static let feldVerifiziert  = "Verifiziert"
    static let feldKategorie    = "Kategorie"
    static let feldHersteller   = "Hersteller"
    static let feldVerknArtikelnummern = "Verkn. Artikelnummern"

    public static func bildIndex(papersRoot: URL,
                                 client: AirtableFetching = AirtableClient()) async throws -> [String: URL] {
        baueBildIndex(records: try await client.fetchRecords(baseID: baseID, table: assetsTable),
                      papersRoot: papersRoot)
    }

    static func baueBildIndex(records: [[String: AirtableFieldValue]],
                              papersRoot: URL) -> [String: URL] {
        var index: [String: URL] = [:]
        for fields in records {
            guard let pfad = fields[feldDrivePfad]?.anyStringValue, pfad.isEmpty == false,
                  let url = MediathekBildPfad.lokaleURL(drivePfad: pfad, papersRoot: papersRoot)
            else { continue }
            let roh = fields[feldVerknArtikelnummern]?.anyStringValue ?? ""
            for teil in roh.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" }) {
                let norm = LagerItem.normalisiereArtikelnummer(
                    teil.trimmingCharacters(in: .whitespaces))
                guard norm.isEmpty == false, index[norm] == nil else { continue }
                index[norm] = url
            }
        }
        return index
    }

    public static func load(client: AirtableFetching = AirtableClient()) async throws -> MediathekAssetKatalog {
        async let herstellerRecs = client.fetchRecords(baseID: baseID, table: herstellerTable)
        async let kategorieRecs  = client.fetchRecords(baseID: baseID, table: kategorienTable)
        async let assetRecs      = client.fetchRecords(baseID: baseID, table: assetsTable)
        let herstellerByID = namenIndex(try await herstellerRecs)
        let kategorieByID  = namenIndex(try await kategorieRecs)
        return mappe(records: try await assetRecs,
                     herstellerByID: herstellerByID, kategorieByID: kategorieByID)
    }

    static func namenIndex(_ records: [[String: AirtableFieldValue]]) -> [String: String] {
        var index: [String: String] = [:]
        for fields in records {
            guard let id = fields["_airtableRecordID"]?.stringValue,
                  let name = fields[feldName]?.anyStringValue else { continue }
            index[id] = name
        }
        return index
    }

    static func mappe(records: [[String: AirtableFieldValue]],
                      herstellerByID: [String: String],
                      kategorieByID: [String: String]) -> MediathekAssetKatalog {
        var proPfad: [String: MediathekAsset] = [:]
        var proName: [String: MediathekAsset] = [:]
        var mehrdeutigeNamen: Set<String> = []
        for fields in records {
            guard let pfad = fields[feldDrivePfad]?.anyStringValue,
                  pfad.isEmpty == false,
                  let name = fields[feldName]?.anyStringValue,
                  name.isEmpty == false else { continue }
            let asset = MediathekAsset(
                recordID: fields["_airtableRecordID"]?.stringValue ?? pfad,
                name: name,
                drivePfad: pfad,
                hersteller: fields[feldHersteller]?.firstArrayValue.flatMap { herstellerByID[$0] },
                kategorie: fields[feldKategorie]?.firstArrayValue.flatMap { kategorieByID[$0] },
                tags: fields[feldTags]?.alleArrayWerte ?? [],
                beschreibung: fields[feldBeschreibung]?.anyStringValue,
                verifiziert: fields[feldVerifiziert]?.boolValue ?? false)
            proPfad[pfad] = asset
            let fileName = (pfad as NSString).lastPathComponent.lowercased()
            if proName[fileName] != nil {
                mehrdeutigeNamen.insert(fileName)
            } else {
                proName[fileName] = asset
            }
        }
        for name in mehrdeutigeNamen { proName.removeValue(forKey: name) }
        return MediathekAssetKatalog(proPfad: proPfad, proDateiname: proName)
    }
}

extension AirtableFieldValue {
    var alleArrayWerte: [String] {
        if case .array(let values) = self { return values }
        return []
    }
}
