public struct Contact: Sendable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var organization: String?
    public var email: String?
    public var phone: String?
    public var address: String?
    public var category: String?
    public var project: String?

    public init(id: String, name: String, organization: String? = nil, email: String? = nil, phone: String? = nil,
                address: String? = nil, category: String? = nil, project: String? = nil) {
        self.id = id
        self.name = name
        self.organization = organization
        self.email = email
        self.phone = phone
        self.address = address
        self.category = category
        self.project = project
    }

    func matches(_ query: String) -> Bool {
        let lowered = query.lowercased()
        return name.lowercased().contains(lowered)
            || (organization?.lowercased().contains(lowered) ?? false)
            || (project?.lowercased().contains(lowered) ?? false)
    }
}
