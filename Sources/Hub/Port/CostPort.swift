public protocol CostPort: Sendable {
    func book(_ item: CostItem)
}
