import Core

struct ScopeDensityEngine: Sendable {
    private let densityByCandidate: [String: EquipmentDensity]

    init(densityByCandidate: [String: EquipmentDensity]) {
        self.densityByCandidate = densityByCandidate
    }

    init(csv: String) {
        guard let table = try? CSVTable(data: csv, lenient: true) else {
            self.init(densityByCandidate: [:])
            return
        }
        var map: [String: EquipmentDensity] = [:]
        for row in table.rows {
            let id = row.string("candidate_id")
            guard id.isEmpty == false else { continue }
            let density = EquipmentDensity(rawCorpus: row.string("equipment_density"))
            guard density != .unknown else { continue }
            map[id] = density
        }
        self.init(densityByCandidate: map)
    }

    func enrich(_ anchors: [CandidateReleaseDecision]) -> [CandidateReleaseDecision] {
        guard densityByCandidate.isEmpty == false else { return anchors }
        return anchors.map { anchor in
            let density = densityByCandidate[anchor.candidateID] ?? .unknown
            return density == .unknown ? anchor : anchor.withEquipmentDensity(density)
        }
    }
}
