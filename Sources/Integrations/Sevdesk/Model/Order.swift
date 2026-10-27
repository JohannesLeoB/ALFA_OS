struct Order: Identifiable, Equatable, Sendable {
    var id: String
    var orderNumber: String?
    var orderType: String
    var rawStatus: String
    var sumNet: Double
    var sumTax: Double
    var sumGross: Double
    var contactID: String?
    var customerInternalNote: String?
    var header: String?

    init(
        id: String, orderNumber: String? = nil, orderType: String, rawStatus: String,
        sumNet: Double = 0, sumTax: Double = 0, sumGross: Double = 0, contactID: String? = nil,
        customerInternalNote: String? = nil, header: String? = nil
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.orderType = orderType
        self.rawStatus = rawStatus
        self.sumNet = sumNet
        self.sumTax = sumTax
        self.sumGross = sumGross
        self.contactID = contactID
        self.customerInternalNote = customerInternalNote
        self.header = header
    }
}
