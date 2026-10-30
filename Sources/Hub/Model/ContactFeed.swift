public struct ContactFeed: Sendable {
    public let source: ContactSource
    public let port: any ContactFeedPort

    public init(source: ContactSource, port: any ContactFeedPort) {
        self.source = source
        self.port = port
    }
}
