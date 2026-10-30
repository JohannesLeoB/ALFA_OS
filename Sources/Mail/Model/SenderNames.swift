public struct SenderNames: Equatable, Sendable {
    public var chosen: String
    public var profile: String

    public init(chosen: String = "", profile: String = "") {
        self.chosen = chosen
        self.profile = profile
    }
}
