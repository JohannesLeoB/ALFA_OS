public struct SavedDraft: Equatable, Sendable {
    public var id: String
    public var mirrorID: String

    public init(id: String, mirrorID: String? = nil) {
        self.id = id
        self.mirrorID = mirrorID ?? id
    }
}
