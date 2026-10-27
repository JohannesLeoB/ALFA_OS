public struct ProjectEntry: Sendable, Equatable {
    let projectNumber: String
    let title: String
    let customerName: String?
    let driveFolderID: String?
    let phase: String?
    let budget: Double?

    init(projectNumber: String, title: String, customerName: String? = nil, driveFolderID: String? = nil,
         phase: String? = nil, budget: Double? = nil) {
        self.projectNumber = projectNumber
        self.title = title
        self.customerName = customerName
        self.driveFolderID = driveFolderID
        self.phase = phase
        self.budget = budget
    }
}
