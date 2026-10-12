import Foundation

public struct PDFExtractedPosition: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let sourceFile: String
    public let pageNumber: Int
    public let title: String
    public let componentType: ComponentType
    public let netPrice: Decimal
    public let unit: String
    public let quantity: Double
    public let confidence: Double
    public let extractedAt: Date

    public init(id: String, sourceFile: String, pageNumber: Int, title: String,
                componentType: ComponentType, netPrice: Decimal, unit: String,
                quantity: Double, confidence: Double, extractedAt: Date) {
        self.id = id
        self.sourceFile = sourceFile
        self.pageNumber = pageNumber
        self.title = title
        self.componentType = componentType
        self.netPrice = netPrice
        self.unit = unit
        self.quantity = quantity
        self.confidence = confidence
        self.extractedAt = extractedAt
    }
}

public extension ComponentType {
    var calculationClass: CalculationComponentClass {
        switch self {
        case .baseCabinetRun:   .kitchenRun
        case .island:           .island
        case .tallCabinetBlock: .tallCabinetBlock

        case .wallCabinets, .drawerAddon: .unknownReview
        case .stoneCountertop, .worktopScope: .worktopSurface
        case .applianceScope:   .applianceHandling
        case .delivery, .installation, .projectLogistics: .logistics
        case .aggregateKitchen: .aggregateKitchen
        case .other:            .unknownReview
        }
    }
}
