public struct Contact: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var customerNumber: String?

    public init(id: String, name: String, customerNumber: String? = nil) {
        self.id = id
        self.name = name
        self.customerNumber = customerNumber
    }
}

enum ContactMatch: Equatable, Sendable {
    case unique(id: String, name: String?)
    case none
    case ambiguous([Candidate])
    case contactPersonOnly(Candidate)

    struct Candidate: Equatable, Sendable, Identifiable {
        let id: String
        let name: String?
        let isContactPerson: Bool

        init(id: String, name: String?, isContactPerson: Bool = false) {
            self.id = id
            self.name = name
            self.isContactPerson = isContactPerson
        }
    }
}
