struct CarcassSpec: Equatable, Sendable {
    var carcassCount: Int
    var frontExecution: FrontExecution
    var drawersLegrabox: Int
    var drawersSolid: Int
    var distanceKm: Double?
    var installationBasis: InstallationBasis
    var installationHourlyRate: Double?
    var workshop: String?

    init(carcassCount: Int, frontExecution: FrontExecution, drawersLegrabox: Int = 0,
         drawersSolid: Int = 0, distanceKm: Double? = nil, installationBasis: InstallationBasis = .included,
         installationHourlyRate: Double? = nil, workshop: String? = nil) {
        self.carcassCount = max(0, carcassCount)
        self.frontExecution = frontExecution
        self.drawersLegrabox = max(0, drawersLegrabox)
        self.drawersSolid = max(0, drawersSolid)
        self.distanceKm = distanceKm
        self.installationBasis = installationBasis
        self.installationHourlyRate = installationHourlyRate
        self.workshop = workshop
    }
}

enum InstallationBasis: String, Sendable {
    case included = "inklusive"
    case separate = "separat"
    case unknown = "unbekannt"
}
