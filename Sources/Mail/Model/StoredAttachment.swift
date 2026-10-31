import Foundation

struct StoredAttachment: Equatable, Sendable {
    var inlet: String
    var message: String
    var attachment: String
    var path: String
    var size: Int
    var receivedAt: Date?
    var storedAt: Date

    var age: Date { receivedAt ?? storedAt }

    var identity: String { inlet + "\n" + message + "\n" + attachment }
}
