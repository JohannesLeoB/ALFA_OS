public struct AirtableContactDraft: Codable, Sendable, Equatable {
    enum Intent: String, Codable, Sendable, Equatable {
        case create
        case update
    }

    var intent: Intent
    var recordID: String?
    var name: String
    var organization: String?
    var email: String?
    var phone: String?
    var address: String?
    var category: String?
    var project: String?

    init(intent: Intent, recordID: String? = nil, name: String, organization: String? = nil,
         email: String? = nil, phone: String? = nil, address: String? = nil, category: String? = nil,
         project: String? = nil) {
        self.intent = intent
        self.recordID = recordID
        self.name = name
        self.organization = organization
        self.email = email
        self.phone = phone
        self.address = address
        self.category = category
        self.project = project
    }
}
