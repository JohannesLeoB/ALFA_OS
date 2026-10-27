public protocol CarcassParameterPort: Sendable {
    func parameters() async -> CarcassParameters?
}
