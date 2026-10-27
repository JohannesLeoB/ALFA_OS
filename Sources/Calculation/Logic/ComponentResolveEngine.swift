struct ComponentResolveEngine: Sendable {
    func resolve(_ request: EstimateInput) -> [ComponentRequirement] {
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
                    scopeNotes: [Notice("calc.note.drawerFromText")],
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
                scopeNotes: [Notice("calc.note.logisticsSeparate")],
                componentClass: .logistics
            ))
        }

        return components.map { requirement(for: $0, request: request) }
    }

    private func requirement(for component: EstimateComponent, request: EstimateInput) -> ComponentRequirement {
        func make(allowed: Set<ComponentClass>, forbidden: Set<ComponentClass>, minEvidence: Int, maxScale: Double) -> ComponentRequirement {
            ComponentRequirement(component: component, allowedComponentClasses: allowed, forbiddenComponentClasses: forbidden, minEvidenceCount: minEvidence, maxScaleFactor: maxScale)
        }
        let isAtomic = component.componentClass == .baseUnit || component.type == .drawerAddon || component.unit == "piece"
        if isAtomic {
            return make(allowed: [.baseUnit], forbidden: [.aggregateKitchen, .island, .tallCabinetBlock, .worktopSurface, .logistics, .alternative, .unknownReview], minEvidence: 1, maxScale: 1.4)
        }
        switch component.componentClass {
        case .kitchenRun:
            return make(allowed: request.components.count >= 3 ? [.kitchenRun, .aggregateKitchen] : [.kitchenRun], forbidden: [.baseUnit, .island, .tallCabinetBlock, .worktopSurface, .alternative, .unknownReview], minEvidence: 2, maxScale: 1.8)
        case .island:
            return make(allowed: [.island], forbidden: [.aggregateKitchen, .kitchenRun, .tallCabinetBlock, .worktopSurface, .alternative, .unknownReview], minEvidence: 2, maxScale: 1.8)
        case .tallCabinetBlock:
            return make(allowed: [.tallCabinetBlock], forbidden: [.aggregateKitchen, .kitchenRun, .island, .worktopSurface, .alternative, .unknownReview], minEvidence: 1, maxScale: 1.6)
        case .worktopSurface:
            return make(allowed: [.worktopSurface], forbidden: [.aggregateKitchen, .kitchenRun, .island, .alternative, .unknownReview], minEvidence: 2, maxScale: 2.0)
        case .logistics:
            return make(allowed: [.logistics], forbidden: [.aggregateKitchen, .worktopSurface, .alternative, .unknownReview], minEvidence: 1, maxScale: 1.5)
        case .aggregateKitchen:
            return make(allowed: [.kitchenRun, .island, .tallCabinetBlock, .aggregateKitchen], forbidden: [.alternative, .unknownReview], minEvidence: 3, maxScale: 1.4)
        default:
            return make(allowed: [component.componentClass], forbidden: [.alternative, .unknownReview], minEvidence: 1, maxScale: 1.5)
        }
    }
}
