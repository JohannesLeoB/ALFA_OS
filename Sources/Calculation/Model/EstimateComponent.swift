import Foundation

struct EstimateComponent: Equatable, Identifiable, Sendable {
    let id: UUID
    let type: ComponentType
    var quantity: Double
    var unit: String
    var widthM: Double?
    var heightM: Double?
    var depthM: Double?
    var drawerCount: Int
    var materials: Set<String>
    var scopeNotes: [Notice]
    var componentClass: ComponentClass

    init(id: UUID = UUID(), type: ComponentType, quantity: Double, unit: String, widthM: Double? = nil, heightM: Double? = nil, depthM: Double? = nil, drawerCount: Int = 0, materials: Set<String> = [], scopeNotes: [Notice] = [], componentClass: ComponentClass? = nil) {
        self.id = id
        self.type = type
        self.quantity = quantity
        self.unit = unit
        self.widthM = widthM
        self.heightM = heightM
        self.depthM = depthM
        self.drawerCount = drawerCount
        self.materials = materials
        self.scopeNotes = scopeNotes
        self.componentClass = componentClass ?? EstimateComponent.defaultClass(for: type, unit: unit)
    }

    static func defaultClass(for type: ComponentType, unit: String) -> ComponentClass {
        switch type {
        case .baseCabinetRun: unit == "piece" ? .baseUnit : .kitchenRun
        case .island: .island
        case .tallCabinetBlock: .tallCabinetBlock
        case .wallCabinets: .kitchenRun
        case .stoneCountertop, .worktopScope: .worktopSurface
        case .drawerAddon: .baseUnit
        case .delivery, .installation, .projectLogistics: .logistics
        case .applianceScope: .applianceHandling
        case .aggregateKitchen: .aggregateKitchen
        case .other: .unknownReview
        }
    }
}
