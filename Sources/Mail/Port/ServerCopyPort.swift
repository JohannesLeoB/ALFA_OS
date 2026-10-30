import Foundation
import Hub

public protocol ServerCopyPort: Sendable {
    func expire(_ policy: ServerCopy, now: Date) async throws
}
