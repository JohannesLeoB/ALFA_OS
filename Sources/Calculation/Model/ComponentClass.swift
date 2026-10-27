enum ComponentClass: String, CaseIterable, Equatable, Hashable, Sendable {
    case baseUnit = "base_unit"
    case kitchenRun = "kitchen_run"
    case island
    case tallCabinetBlock = "tall_cabinet_block"
    case aggregateKitchen = "aggregate_kitchen"
    case worktopSurface = "worktop_surface"
    case logistics
    case applianceHandling = "appliance_handling"
    case alternative
    case unknownReview = "unknown_review"
}
