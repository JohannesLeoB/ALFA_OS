public struct RichParagraph: Equatable, Sendable {
    public var list: ListKind?
    public var runs: [RichRun]

    public init(list: ListKind? = nil, runs: [RichRun]) {
        self.list = list
        self.runs = runs
    }
}
