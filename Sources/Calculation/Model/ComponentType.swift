enum ComponentType: String, CaseIterable, Equatable, Sendable {
    case baseCabinetRun = "base_cabinet_run"
    case island
    case tallCabinetBlock = "tall_cabinet_block"
    case wallCabinets = "wall_cabinets"
    case stoneCountertop = "stone_countertop"
    case worktopScope = "worktop_scope"
    case applianceScope = "appliance_scope"
    case drawerAddon = "drawer_addon"
    case delivery
    case installation
    case projectLogistics = "project_logistics"
    case aggregateKitchen = "aggregate_kitchen"
    case other

    var localizationKey: String { "calc.componentType.\(rawValue)" }
}
