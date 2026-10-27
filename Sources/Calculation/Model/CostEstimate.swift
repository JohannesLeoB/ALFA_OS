public struct CostEstimate: Sendable, Equatable {
    public let estimateID: String
    public let projectID: String
    public let minNet: Double
    public let maxNet: Double
    public let midNet: Double
    public let confidence: Double
    public let evidenceCount: Int
    public let costFloor: Double
    public let costFloorRatio: Double
    public let topEvidence: [PriceEvidence]
    public let modelLabel: Notice?
    public let hints: [Notice]
    public let lines: [EstimateBreakdownLine]
    public let excludes: [Notice]

    public init(
        estimateID: String,
        projectID: String,
        minNet: Double,
        maxNet: Double,
        midNet: Double,
        confidence: Double,
        evidenceCount: Int,
        costFloor: Double,
        costFloorRatio: Double,
        topEvidence: [PriceEvidence],
        modelLabel: Notice? = nil,
        hints: [Notice] = [],
        lines: [EstimateBreakdownLine] = [],
        excludes: [Notice] = []
    ) {
        self.estimateID = estimateID
        self.projectID = projectID
        self.minNet = minNet
        self.maxNet = maxNet
        self.midNet = midNet
        self.confidence = confidence
        self.evidenceCount = evidenceCount
        self.costFloor = costFloor
        self.costFloorRatio = costFloorRatio
        self.topEvidence = topEvidence
        self.modelLabel = modelLabel
        self.hints = hints
        self.lines = lines
        self.excludes = excludes
    }
}
