import Foundation

public struct MirrorListing: Equatable, Sendable {
    public var ids: [String]
    public var hasOlder: Bool
    public var validity: String?

    public init(ids: [String], hasOlder: Bool, validity: String? = nil) {
        self.ids = ids
        self.hasOlder = hasOlder
        self.validity = validity
    }
}
