public struct FolderCount: Equatable, Sendable {
    public var unseen: Int
    public var total: Int

    public init(unseen: Int, total: Int) {
        self.unseen = unseen
        self.total = total
    }
}
