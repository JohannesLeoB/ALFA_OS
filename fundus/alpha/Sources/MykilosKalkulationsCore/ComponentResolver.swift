import Foundation

public struct AnchorEligibility: Equatable {
    public let allowedComponentClasses: Set<CalculationComponentClass>
    public let forbiddenComponentClasses: Set<CalculationComponentClass>
    public let minEvidenceCount: Int
    public let maxScaleFactor: Double
    public let requiredScopeCompatibility: [String]

    public init(allowedComponentClasses: Set<CalculationComponentClass>, forbiddenComponentClasses: Set<CalculationComponentClass>, minEvidenceCount: Int, maxScaleFactor: Double, requiredScopeCompatibility: [String]) {
        self.allowedComponentClasses = allowedComponentClasses
        self.forbiddenComponentClasses = forbiddenComponentClasses
        self.minEvidenceCount = minEvidenceCount
        self.maxScaleFactor = maxScaleFactor
        self.requiredScopeCompatibility = requiredScopeCompatibility
    }

    public static func forComponent(_ component: EstimateComponent, request: EstimateRequest) -> AnchorEligibility {
        let isAtomic = component.componentClass == .baseUnit || component.type == .drawerAddon || component.unit == "piece"
        if isAtomic {
            return AnchorEligibility(
                allowedComponentClasses: [.baseUnit],
                forbiddenComponentClasses: [.aggregateKitchen, .island, .tallCabinetBlock, .worktopSurface, .logistics, .alternative, .unknownReview],
                minEvidenceCount: 1,
                maxScaleFactor: 1.4,
                requiredScopeCompatibility: []
            )
        }
        switch component.componentClass {
        case .kitchenRun:
            return AnchorEligibility(
                allowedComponentClasses: request.components.count >= 3 ? [.kitchenRun, .aggregateKitchen] : [.kitchenRun],
                forbiddenComponentClasses: [.baseUnit, .island, .tallCabinetBlock, .worktopSurface, .alternative, .unknownReview],
                minEvidenceCount: 2,
                maxScaleFactor: 1.8,
                requiredScopeCompatibility: []
            )
        case .island:
            return AnchorEligibility(
                allowedComponentClasses: [.island],
                forbiddenComponentClasses: [.aggregateKitchen, .kitchenRun, .tallCabinetBlock, .worktopSurface, .alternative, .unknownReview],
                minEvidenceCount: 2,
                maxScaleFactor: 1.8,
                requiredScopeCompatibility: []
            )
        case .tallCabinetBlock:
            return AnchorEligibility(
                allowedComponentClasses: [.tallCabinetBlock],
                forbiddenComponentClasses: [.aggregateKitchen, .kitchenRun, .island, .worktopSurface, .alternative, .unknownReview],
                minEvidenceCount: 1,
                maxScaleFactor: 1.6,
                requiredScopeCompatibility: []
            )
        case .worktopSurface:
            return AnchorEligibility(
                allowedComponentClasses: [.worktopSurface],
                forbiddenComponentClasses: [.aggregateKitchen, .kitchenRun, .island, .alternative, .unknownReview],
                minEvidenceCount: 2,
                maxScaleFactor: 2.0,
                requiredScopeCompatibility: []
            )
        case .logistics:
            return AnchorEligibility(
                allowedComponentClasses: [.logistics],
                forbiddenComponentClasses: [.aggregateKitchen, .worktopSurface, .alternative, .unknownReview],
                minEvidenceCount: 1,
                maxScaleFactor: 1.5,
                requiredScopeCompatibility: []
            )
        case .aggregateKitchen:
            return AnchorEligibility(
                allowedComponentClasses: [.kitchenRun, .island, .tallCabinetBlock, .aggregateKitchen],
                forbiddenComponentClasses: [.alternative, .unknownReview],
                minEvidenceCount: 3,
                maxScaleFactor: 1.4,
                requiredScopeCompatibility: ["aggregate_only_for_plausibility"]
            )
        default:
            return AnchorEligibility(
                allowedComponentClasses: [component.componentClass],
                forbiddenComponentClasses: [.alternative, .unknownReview],
                minEvidenceCount: 1,
                maxScaleFactor: 1.5,
                requiredScopeCompatibility: []
            )
        }
    }
}

public final class ComponentResolver {
    public init() {}

    public func resolve(_ request: EstimateRequest) -> [ComponentRequirement] {
        var components: [EstimateComponent] = []
        for component in request.components {
            var adjusted = component
            if adjusted.type == .baseCabinetRun && adjusted.quantity <= 1 && adjusted.unit == "lfm" {
                adjusted.unit = "piece"
                adjusted.componentClass = .baseUnit
            }
            components.append(adjusted)

            if component.drawerCount > 0 {
                let materials = component.materials.filter { $0 == "eiche" || $0 == "legrabox" }
                components.append(EstimateComponent(
                    type: .drawerAddon,
                    quantity: Double(component.drawerCount),
                    unit: "piece",
                    drawerCount: component.drawerCount,
                    materials: materials,
                    scopeNotes: ["Aus Freitext als separate Schubkasten-/Beschlagsposition erkannt."],
                    componentClass: .baseUnit
                ))
            }
        }

        let needsLogisticsLine = request.scope.includesDelivery || request.scope.includesInstallation || components.filter { $0.componentClass != .baseUnit }.count >= 2
        if needsLogisticsLine && !components.contains(where: { $0.componentClass == .logistics }) {
            components.append(EstimateComponent(
                type: .delivery,
                quantity: 1,
                unit: "scope",
                materials: [],
                scopeNotes: ["Lieferung/Montage als separate Position; prüfen, ob enthalten oder bauseits."],
                componentClass: .logistics
            ))
        }

        return components.map { component in
            let eligibility = AnchorEligibility.forComponent(component, request: request)
            return ComponentRequirement(
                component: component,
                allowedComponentClasses: eligibility.allowedComponentClasses,
                forbiddenComponentClasses: eligibility.forbiddenComponentClasses,
                minEvidenceCount: eligibility.minEvidenceCount,
                maxScaleFactor: eligibility.maxScaleFactor,
                requiredScopeCompatibility: eligibility.requiredScopeCompatibility
            )
        }
    }
}
