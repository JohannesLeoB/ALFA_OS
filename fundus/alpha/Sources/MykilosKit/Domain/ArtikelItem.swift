import Foundation

public struct ArtikelItem: Codable, Sendable, Equatable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, articleNumber = "artikelnummer", hersteller, kategorie, artikelbeschreibung, detailText, ean, ekNetto, vkNetto, produktbildURL, reviewZustand, sevDeskArtikelID, widthMm = "breiteMm", heightMm = "hoeheMm", tiefeMm, gewichtGramm }

    public let id: String

    public let articleNumber: String

    public let hersteller: String?

    public let kategorie: String?

    public let artikelbeschreibung: String?

    public let detailText: String?

    public let ean: String?

    public let ekNetto: Double?

    public let vkNetto: Double?

    public let produktbildURL: String?

    public let reviewZustand: ArtikelReviewZustand?

    public let sevDeskArtikelID: String?

    public let widthMm: Int?
    public let heightMm: Int?
    public let tiefeMm: Int?
    public let gewichtGramm: Int?

    public init(
        id: String,
        articleNumber: String,
        hersteller: String? = nil,
        kategorie: String? = nil,
        artikelbeschreibung: String? = nil,
        detailText: String? = nil,
        ean: String? = nil,
        ekNetto: Double? = nil,
        vkNetto: Double? = nil,
        produktbildURL: String? = nil,
        reviewZustand: ArtikelReviewZustand? = nil,
        sevDeskArtikelID: String? = nil,
        widthMm: Int? = nil,
        heightMm: Int? = nil,
        tiefeMm: Int? = nil,
        gewichtGramm: Int? = nil
    ) {
        self.id = id
        self.articleNumber = articleNumber
        self.hersteller = hersteller
        self.kategorie = kategorie
        self.artikelbeschreibung = artikelbeschreibung
        self.detailText = detailText
        self.ean = ean
        self.ekNetto = ekNetto
        self.vkNetto = vkNetto
        self.produktbildURL = produktbildURL
        self.reviewZustand = reviewZustand
        self.sevDeskArtikelID = sevDeskArtikelID
        self.widthMm = widthMm
        self.heightMm = heightMm
        self.tiefeMm = tiefeMm
        self.gewichtGramm = gewichtGramm
    }

    public var paketMasseCm: DHLMasse? {
        guard let b = widthMm, let h = heightMm, let t = tiefeMm,
              b > 0, h > 0, t > 0 else { return nil }
        func cm(_ mm: Int) -> Int { Int((Double(mm) / 10).rounded()) }
        return DHLMasse(laengeCm: cm(t), breiteCm: cm(b), hoeheCm: cm(h))
    }

    public var normalisierteArtikelnummer: String {
        LagerItem.normalisiereArtikelnummer(articleNumber)
    }

    public var suchTokens: [String] {
        var tokens: [String] = []
        tokens.append(contentsOf: Self.tokenize(articleNumber))
        if let h = hersteller { tokens.append(contentsOf: Self.tokenize(h)) }
        if let b = artikelbeschreibung { tokens.append(contentsOf: Self.tokenize(b)) }
        if let d = detailText { tokens.append(contentsOf: Self.tokenize(d)) }
        if let k = kategorie { tokens.append(contentsOf: Self.tokenize(k)) }
        if let e = ean { tokens.append(contentsOf: Self.tokenize(e)) }
        return tokens
    }

    public static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .flatMap { $0.components(separatedBy: CharacterSet.punctuationCharacters) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 }
    }
}

public struct ArtikelSuchergebnis: Sendable, Equatable, Identifiable {
    public let artikel: ArtikelItem
    public let score: Int

    public var id: String { artikel.id }

    public init(artikel: ArtikelItem, score: Int) {
        self.artikel = artikel
        self.score = score
    }
}
