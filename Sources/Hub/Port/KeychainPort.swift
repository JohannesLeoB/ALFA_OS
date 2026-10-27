public protocol KeychainPort: Sendable {
    func put(_ value: String, at slot: KeySlot) throws
    func get(_ slot: KeySlot) throws -> String?
    func delete(_ slot: KeySlot) throws
}
