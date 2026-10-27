public struct EstimateOverride: Sendable, Equatable {
    public var carcassCount: Int?
    public var frontExecution: String?
    public var drawersLegrabox: Int?
    public var drawersSolid: Int?
    public var workshop: String?
    public var distanceKm: Double?

    public init(carcassCount: Int? = nil, frontExecution: String? = nil,
                drawersLegrabox: Int? = nil, drawersSolid: Int? = nil,
                workshop: String? = nil, distanceKm: Double? = nil) {
        self.carcassCount = carcassCount
        self.frontExecution = frontExecution
        self.drawersLegrabox = drawersLegrabox
        self.drawersSolid = drawersSolid
        self.workshop = workshop
        self.distanceKm = distanceKm
    }

    public var isEmpty: Bool {
        carcassCount == nil && frontExecution == nil && drawersLegrabox == nil
            && drawersSolid == nil && workshop == nil && distanceKm == nil
    }

    var openFields: [String] {
        var out: [String] = []
        if carcassCount == nil { out.append("calc.field.carcassCount") }
        if frontExecution == nil { out.append("calc.field.frontExecution") }
        if workshop == nil { out.append("calc.field.workshop") }
        return out
    }
}
