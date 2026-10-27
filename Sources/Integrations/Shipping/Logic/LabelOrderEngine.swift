enum LabelOrderEngine {
    static let billingNumberDigits = 14

    static func issues(_ order: LabelOrder) -> [LabelOrderIssue] {
        var found: [LabelOrderIssue] = []
        if order.recipient.name1.isEmpty { found.append(.recipientName) }
        if order.recipient.street.isEmpty { found.append(.recipientStreet) }
        if isValidPostalCode(order.recipient.postalCode) == false { found.append(.recipientPostalCode) }
        if order.recipient.city.isEmpty { found.append(.recipientCity) }
        if order.sender.name1.isEmpty || order.sender.street.isEmpty
            || isValidPostalCode(order.sender.postalCode) == false || order.sender.city.isEmpty {
            found.append(.senderIncomplete)
        }
        if order.weightGrams <= 0 { found.append(.weight) }
        if order.billingNumber.filter(\.isNumber).count != billingNumberDigits { found.append(.billingNumber) }
        return found
    }

    static func isValidPostalCode(_ code: String) -> Bool {
        let digits = code.filter { !$0.isWhitespace }
        return digits.count == 5 && digits.allSatisfy(\.isNumber)
    }
}
