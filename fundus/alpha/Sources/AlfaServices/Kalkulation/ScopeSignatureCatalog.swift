import Foundation
import AlfaKit
import AlfaCalculation

public struct ScopeSignatureCatalog {
    private let densityByCandidate: [String: KitchenEquipmentDensity]

    public init(densityByCandidate: [String: KitchenEquipmentDensity]) {
        self.densityByCandidate = densityByCandidate
    }

    public var count: Int { densityByCandidate.count }

    public func density(for candidateID: String) -> KitchenEquipmentDensity {
        densityByCandidate[candidateID] ?? .unknown
    }

    public func enrich(_ anchors: [CandidateReleaseDecision]) -> [CandidateReleaseDecision] {
        guard densityByCandidate.isEmpty == false else { return anchors }
        return anchors.map { anchor in
            let density = density(for: anchor.candidateID)
            return density == .unknown ? anchor : anchor.withEquipmentDensity(density)
        }
    }

    public static var defaultURL: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("\(AppKennung.name)/Kalkulationslabor/Brain/normalized_anchor_scope_signatures.csv")
    }

    public static func load(from url: URL = defaultURL) -> ScopeSignatureCatalog {
        guard let raw = try? String(contentsOf: url, encoding: .utf8),
              let table = try? CSVTable(data: raw, lenient: true) else {
            return ScopeSignatureCatalog(densityByCandidate: [:])
        }
        var map: [String: KitchenEquipmentDensity] = [:]
        for row in table.rows {
            let id = row.string("candidate_id")
            guard id.isEmpty == false else { continue }
            let density = KitchenEquipmentDensity(rawCorpus: row.string("equipment_density"))
            guard density != .unknown else { continue }
            map[id] = density
        }
        return ScopeSignatureCatalog(densityByCandidate: map)
    }
}
