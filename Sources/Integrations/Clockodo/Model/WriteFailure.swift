import Foundation

enum WriteFailure: Error, Equatable, Sendable {
    case unconfirmed

    var key: String { "clockodo.write.unconfirmed" }
}
