import Foundation

public enum SaveState: Equatable, Sendable {
    case idle
    case saving
    case saved(Date)
    case failed(String)
}
