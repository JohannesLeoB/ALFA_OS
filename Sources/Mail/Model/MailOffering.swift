import Foundation
import Hub

struct MailOffering: Equatable, Sendable {
    var ranges: [MailboxRange]
    var everywhere: Bool
}
