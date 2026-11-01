import Foundation

public protocol ContactBookPort {
    func load() -> [Contact]
    func save(_ contacts: [Contact]) throws
}
