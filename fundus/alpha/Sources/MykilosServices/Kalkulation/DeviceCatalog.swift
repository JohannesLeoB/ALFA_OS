import Foundation
import MykilosKit
import MykilosKalkulationsCore

public struct DeviceCatalogEntry: Sendable, Equatable {
    public let manufacturer: String
    public let category: String
    public let description: String
    public let articleNumber: String
    public let listNet: Decimal?
    public let purchaseNet: Decimal?
    public let mykilosNet: Decimal?

    public let haystack: String

    public var sellNet: Decimal? { mykilosNet ?? listNet }

    public var isAccessory: Bool {
        let c = category.lowercased()
        return c.contains("zubehör") || c.contains("zubehoer") || c.contains("ersatzteil") || c.contains("filter")
    }
}

public final class DeviceCatalog: @unchecked Sendable {
    public let entries: [DeviceCatalogEntry]
    public init(entries: [DeviceCatalogEntry]) { self.entries = entries }

    public convenience init(csv: String) throws {
        let table = try CSVTable(data: csv, lenient: true)

        let h = table.headers
        func col(_ needles: [String]) -> String? {
            for needle in needles {
                if let match = h.first(where: { $0.lowercased().contains(needle) }) { return match }
            }
            return nil
        }
        let cManu = col(["hersteller", "manufacturer", "marke"])
        let cCat = col(["kategorie", "category"])
        let cDesc = col(["artikelbeschreibung", "beschreibung", "description", "artikel"])
        let cArt = col(["artikelnummer", "artikel-nr", "article", "sku"])
        let cList = col(["liste"])
        let cEk = col(["einkauf", "netto-ek", "ek "])
        let cMyk = col(["mykilos"])
        let cSearch = col(["suchtext", "search"])

        let parsed: [DeviceCatalogEntry] = table.rows.compactMap { row in
            func v(_ key: String?) -> String { key.map { row.string($0) } ?? "" }
            func d(_ key: String?) -> Decimal? { key.flatMap { row.optionalDecimal($0) } }
            let manu = v(cManu), cat = v(cCat), desc = v(cDesc), art = v(cArt)

            if manu.isEmpty && cat.isEmpty && desc.isEmpty && art.isEmpty { return nil }
            let haystack = [v(cSearch), manu, cat, desc, art]
                .filter { !$0.isEmpty }.joined(separator: " ").lowercased()
            return DeviceCatalogEntry(
                manufacturer: manu, category: cat, description: desc, articleNumber: art,
                listNet: d(cList), purchaseNet: d(cEk), mykilosNet: d(cMyk), haystack: haystack
            )
        }
        self.init(entries: parsed)
    }

    public convenience init(url: URL) throws {
        try self.init(csv: String(contentsOf: url, encoding: .utf8))
    }

    public static func defaultURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return support
            .appendingPathComponent("\(AppKennung.name)/Kalkulationslabor/Devices/catalog.csv")
    }

    public static func loadDefault() -> DeviceCatalog? {
        let url = defaultURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? DeviceCatalog(url: url)
    }

    @discardableResult
    public static func importCatalog(from source: URL) throws -> DeviceCatalog {
        let target = defaultURL()
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.copyItem(at: source, to: target)
        return try DeviceCatalog(url: target)
    }

    public func search(_ query: String, limit: Int = 12) -> [DeviceCatalogEntry] {
        let tokens = query.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count > 1 }
        guard !tokens.isEmpty else { return [] }
        let scored = entries.compactMap { entry -> (DeviceCatalogEntry, Int)? in
            let score = tokens.reduce(0) { $0 + (entry.haystack.contains($1) ? 1 : 0) }
            return score > 0 ? (entry, score) : nil
        }
        return scored.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            if lhs.0.isAccessory != rhs.0.isAccessory { return !lhs.0.isAccessory }  
            let lp = lhs.0.sellNet ?? Decimal.greatestFiniteMagnitude
            let rp = rhs.0.sellNet ?? Decimal.greatestFiniteMagnitude
            return lp < rp
        }.prefix(limit).map(\.0)
    }
}
