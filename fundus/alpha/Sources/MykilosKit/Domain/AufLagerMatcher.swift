import Foundation

public struct LagerTreffer: Sendable, Equatable {
    public let lagerItem: LagerItem

    public let trefftyp: LagerTrefftyp

    public var stock: Int? { lagerItem.stock }

    public init(lagerItem: LagerItem, trefftyp: LagerTrefftyp) {
        self.lagerItem = lagerItem
        self.trefftyp = trefftyp
    }
}

public enum LagerTrefftyp: Sendable, Equatable, CaseIterable {
    case exakt

    case aehnlich
}

public struct AufLagerMatcherResult: Sendable, Equatable {
    public let exakt: [LagerTreffer]

    public let aehnlich: [LagerTreffer]

    public var alle: [LagerTreffer] { exakt + aehnlich }

    public var hatTreffer: Bool { !exakt.isEmpty || !aehnlich.isEmpty }

    public init(exakt: [LagerTreffer], aehnlich: [LagerTreffer]) {
        self.exakt = exakt
        self.aehnlich = aehnlich
    }
}

public enum AufLagerMatcher {
    public static func search(
        artikel: ArtikelItem,
        in lagerliste: [LagerItem]
    ) -> AufLagerMatcherResult {
        let normArtikel = LagerItem.normalisiereArtikelnummer(artikel.articleNumber)
        let artikelHersteller = artikel.hersteller?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let artikelTokens = Set(ArtikelItem.tokenize(artikel.artikelbeschreibung ?? artikel.articleNumber))

        var exaktTreffer: [LagerTreffer] = []
        var aehnlichTreffer: [LagerTreffer] = []

        for lager in lagerliste {
            let normLager = lager.normalisierteArtikelnummer

            if !normArtikel.isEmpty && !normLager.isEmpty && normArtikel == normLager {
                exaktTreffer.append(LagerTreffer(lagerItem: lager, trefftyp: .exakt))
                continue
            }

            if !artikelHersteller.isEmpty,
               let lagerHersteller = lager.hersteller?.trimmingCharacters(in: .whitespaces).lowercased(),
               !lagerHersteller.isEmpty,
               artikelHersteller == lagerHersteller {
                let lagerTokens = Set(ArtikelItem.tokenize(lager.label))
                if !artikelTokens.isDisjoint(with: lagerTokens) {
                    aehnlichTreffer.append(LagerTreffer(lagerItem: lager, trefftyp: .aehnlich))
                }
            }
        }

        return AufLagerMatcherResult(exakt: exaktTreffer, aehnlich: aehnlichTreffer)
    }

    public static func sucheBatch(
        artikel: [ArtikelItem],
        in lagerliste: [LagerItem]
    ) -> [String: AufLagerMatcherResult] {
        var result: [String: AufLagerMatcherResult] = [:]
        for a in artikel {
            result[a.id] = search(artikel: a, in: lagerliste)
        }
        return result
    }

    public static func normalisiereHersteller(_ h: String) -> String {
        h.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
