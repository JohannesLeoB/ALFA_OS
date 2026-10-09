/// One hint of the lab: what a draft lacks, as a kind that the view can word, and the markup line that fixes it.
public struct LabHint: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        /// The draft has styles but no markup.
        case styleOnly
        /// The code has an address of a host that the network rule of the cards blocks. Carries the host.
        case blockedHost(String)
        /// The code calls a known library, and the markup has no script tag for it. Carries the library name.
        case library(String)
        /// A React draft with no default export and no component that the page can draw.
        case noComponent
    }

    public let kind: Kind
    /// The markup line that the fix adds. nil when the hint has no fix.
    public let fix: String?

    public init(kind: Kind, fix: String? = nil) {
        self.kind = kind
        self.fix = fix
    }
}
