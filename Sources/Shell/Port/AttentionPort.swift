public protocol AttentionPort: Sendable {
    @MainActor func badge(_ count: Int)
    func prepare() async
    func announce(title: String) async
}
