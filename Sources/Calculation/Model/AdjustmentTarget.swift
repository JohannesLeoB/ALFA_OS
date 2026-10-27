enum AdjustmentTarget: String, CaseIterable, Identifiable, Sendable {
    case wholeEstimate = "whole_estimate"
    case kitchenRun = "kitchen_run"
    case island
    case tallCabinetBlock = "tall_cabinet_block"
    case drawers
    case fronts
    case worktop
    case logistics

    var id: String { rawValue }

    var localizationKey: String { "calc.target.\(rawValue)" }

    func matches(component: EstimateComponent) -> Bool {
        switch self {
        case .wholeEstimate:
            return true
        case .kitchenRun:
            return component.componentClass == .kitchenRun
        case .island:
            return component.componentClass == .island
        case .tallCabinetBlock:
            return component.componentClass == .tallCabinetBlock
        case .drawers:
            return component.type == .drawerAddon || component.drawerCount > 0
        case .fronts:
            return component.materials.contains("linoleum") || component.materials.contains("eiche") || component.materials.contains("edelstahl") || component.materials.contains("fenix")
        case .worktop:
            return component.componentClass == .worktopSurface
        case .logistics:
            return component.componentClass == .logistics
        }
    }
}
