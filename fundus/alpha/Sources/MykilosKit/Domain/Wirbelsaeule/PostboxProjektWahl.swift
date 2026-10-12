import Foundation

public struct PostboxProjektWahl: Identifiable, Sendable, Equatable {
    public let projectNumber: String

    public let display: String

    public let customer: String?

    public let customerNumber: String?

    public let strasse: String?
    public let plz: String?
    public let ort: String?

    public let projektName: String?

    public var id: String { projectNumber }

    public init(projectNumber: String, display: String, customer: String? = nil,
                customerNumber: String? = nil, strasse: String? = nil,
                plz: String? = nil, ort: String? = nil, projektName: String? = nil) {
        self.projectNumber = projectNumber
        self.display = display
        self.customer = customer
        self.customerNumber = customerNumber
        self.strasse = strasse
        self.plz = plz
        self.ort = ort
        self.projektName = projektName
    }
}
