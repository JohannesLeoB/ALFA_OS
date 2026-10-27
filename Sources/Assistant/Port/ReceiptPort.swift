public protocol ReceiptPort: Sendable {
    func receipts() async -> [ReceiptEntry]
}
