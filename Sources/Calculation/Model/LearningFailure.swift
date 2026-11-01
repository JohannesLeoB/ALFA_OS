import Foundation

enum LearningFailure: Error, Equatable, Sendable {
    case sessionNotFound(String)
    case candidateNotFound(String)
    case candidateNotPromotable(String)
    case recordNotFound(String)
    case carcassSnapshotMissing(String)
    case carcassTargetNotInSession(key: String, sessionID: String)
    case unknownCarcassTarget(String)
}
