import Foundation

struct PdfPosition: Equatable, Identifiable, Sendable {
    let id: String
    let sourceFile: String
    let pageNumber: Int
    let title: String
    let componentType: ComponentType
    let netPrice: Decimal
    let unit: String
    let quantity: Double
    let confidence: Double
    let extractedAt: Date

    init(id: String, sourceFile: String, pageNumber: Int, title: String, componentType: ComponentType, netPrice: Decimal, unit: String, quantity: Double, confidence: Double, extractedAt: Date) {
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

    var componentClass: ComponentClass {
        switch componentType {
        case .baseCabinetRun: .kitchenRun
        case .island: .island
        case .tallCabinetBlock: .tallCabinetBlock
        case .wallCabinets, .drawerAddon: .unknownReview
        case .stoneCountertop, .worktopScope: .worktopSurface
        case .applianceScope: .applianceHandling
        case .delivery, .installation, .projectLogistics: .logistics
        case .aggregateKitchen: .aggregateKitchen
        case .other: .unknownReview
        }
    }
}
