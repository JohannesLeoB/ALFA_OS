struct SampleListing: Sendable, Equatable {
    struct Sample: Sendable, Equatable {
        let label: String
        let manufacturer: String?
        let category: String?
        let statusLabel: String

        init(label: String, manufacturer: String? = nil, category: String? = nil, statusLabel: String) {
            self.label = label
            self.manufacturer = manufacturer
            self.category = category
            self.statusLabel = statusLabel
        }
    }

    let samples: [Sample]
    let defective: Int

    init(samples: [Sample], defective: Int = 0) {
        self.samples = samples
        self.defective = defective
    }
}
