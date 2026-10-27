struct LabelCredentials: Equatable, Sendable {
    var apiKey: String
    var apiSecret: String
    var user: String
    var password: String
    var billingNumber: String
    var sender: Address?

    init(
        apiKey: String, apiSecret: String, user: String, password: String, billingNumber: String,
        sender: Address? = nil
    ) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.user = user
        self.password = password
        self.billingNumber = billingNumber
        self.sender = sender
    }
}
