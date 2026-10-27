struct Contact: Identifiable, Equatable, Sendable {
    var id: String
    var displayName: String
    var email: String?
    var phone: String?
    var organization: String?
}
