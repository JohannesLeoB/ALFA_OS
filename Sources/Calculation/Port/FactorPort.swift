protocol FactorPort: Sendable {
    func activeFactors() throws -> [ActiveFactor]
}
