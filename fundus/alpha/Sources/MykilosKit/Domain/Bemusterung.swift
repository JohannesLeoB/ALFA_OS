import Foundation

public enum BemusterungStatus: String, Codable, CaseIterable, Sendable {
    case vorgeschlagen
    case gezeigt
    case gewaehlt
    case abgelehnt
    case bestellt

    public var label: String {
        switch self {
        case .vorgeschlagen: "Vorgeschlagen"
        case .gezeigt:       "Gezeigt"
        case .gewaehlt:      "Gewählt"
        case .abgelehnt:     "Abgelehnt"
        case .bestellt:      "Bestellt"
        }
    }

    public var sortRang: Int {
        switch self {
        case .gewaehlt:      0
        case .gezeigt:       1
        case .vorgeschlagen: 2
        case .bestellt:      3
        case .abgelehnt:     4
        }
    }
}

public enum BemusterungQuelle: String, Codable, CaseIterable, Sendable {
    case manuell
    case papers
    case katalog

    public var label: String {
        switch self {
        case .manuell: "manuell"
        case .papers:  "Papers"
        case .katalog: "Katalog"
        }
    }
}

public struct BemusterungsMuster: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", label = "bezeichnung", hersteller, kategorie, articleNumber = "artikelnummer", imagePath = "bildPfad", source = "quelle", draftName = "entwurfName", status, notiz, erstelltAm, aktualisiertAm }

    public let id: String
    public let projectNumber: String
    public var label: String
    public var hersteller: String?
    public var kategorie: String?
    public var articleNumber: String?
    public var imagePath: String?
    public var source: BemusterungQuelle
    public var draftName: String?
    public var status: BemusterungStatus
    public var notiz: String?
    public var erstelltAm: Date
    public var aktualisiertAm: Date

    public init(
        id: String = UUID().uuidString,
        projectNumber: String,
        label: String,
        hersteller: String? = nil,
        kategorie: String? = nil,
        articleNumber: String? = nil,
        imagePath: String? = nil,
        source: BemusterungQuelle = .manuell,
        draftName: String? = nil,
        status: BemusterungStatus = .vorgeschlagen,
        notiz: String? = nil,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.id = id
        self.projectNumber = projectNumber
        self.label = label
        self.hersteller = hersteller
        self.kategorie = kategorie
        self.articleNumber = articleNumber
        self.imagePath = imagePath
        self.source = source
        self.draftName = draftName
        self.status = status
        self.notiz = notiz
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
}

public extension BemusterungsMuster {
    static func ausArtikel(
        _ artikel: ArtikelItem,
        projectNumber: String,
        status: BemusterungStatus = .vorgeschlagen,
        id: String = UUID().uuidString,
        jetzt: Date = Date()
    ) -> BemusterungsMuster {
        func nichtLeer(_ s: String?) -> String? {
            let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? nil : t
        }
        return BemusterungsMuster(
            id: id,
            projectNumber: projectNumber,
            label: nichtLeer(artikel.artikelbeschreibung) ?? artikel.articleNumber,
            hersteller: nichtLeer(artikel.hersteller),
            kategorie: nichtLeer(artikel.kategorie),
            articleNumber: artikel.articleNumber,
            imagePath: nichtLeer(artikel.produktbildURL),
            source: .katalog,
            draftName: nil,
            status: status,
            notiz: nil,
            erstelltAm: jetzt,
            aktualisiertAm: jetzt)
    }
}

public enum BemusterungAuswertung {
    public static func nachKategorie(_ patterns: [BemusterungsMuster]) -> [(kategorie: String, patterns: [BemusterungsMuster])] {
        let groups = Dictionary(grouping: patterns) { $0.kategorie?.isEmpty == false ? $0.kategorie! : "Ohne Kategorie" }
        return groups
            .map { (kategorie: $0.key, patterns: $0.value.sorted { sortiere($0, $1) }) }
            .sorted { $0.kategorie.localizedCaseInsensitiveCompare($1.kategorie) == .orderedAscending }
    }

    public static func drafts(_ patterns: [BemusterungsMuster]) -> [String] {
        Array(Set(patterns.compactMap { $0.draftName?.isEmpty == false ? $0.draftName : nil }))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public static func bilanz(_ patterns: [BemusterungsMuster]) -> String {
        let gewaehlt = patterns.filter { $0.status == .gewaehlt }.count
        let gezeigt  = patterns.filter { $0.status == .gezeigt }.count
        let offen    = patterns.filter { $0.status == .vorgeschlagen }.count
        var teile: [String] = []
        if gewaehlt > 0 { teile.append("\(gewaehlt) gewählt") }
        if gezeigt > 0 { teile.append("\(gezeigt) gezeigt") }
        if offen > 0 { teile.append("\(offen) offen") }
        return teile.isEmpty ? "\(patterns.count) Muster" : teile.joined(separator: " · ")
    }

    private static func sortiere(_ a: BemusterungsMuster, _ b: BemusterungsMuster) -> Bool {
        if a.status.sortRang != b.status.sortRang { return a.status.sortRang < b.status.sortRang }
        return a.label.localizedCaseInsensitiveCompare(b.label) == .orderedAscending
    }
}
