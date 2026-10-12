import Foundation

public enum IntegrationCommandAction: String, Sendable, Codable, Hashable, CaseIterable {
    case createOfferDraft       = "CREATE_OFFER_DRAFT"

    case updateOwnOfferDraft    = "UPDATE_OWN_OFFER_DRAFT"

    case refreshSevdeskStatus   = "REFRESH_SEVDESK_STATUS"
}

public enum IntegrationCommandState: String, Sendable, Codable, Hashable, CaseIterable {
    case pending        = "PENDING"
    case leased         = "LEASED"
    case processing     = "PROCESSING"
    case succeeded      = "SUCCEEDED"
    case retryWait      = "RETRY_WAIT"
    case failed         = "FAILED"
    case cancelled      = "CANCELLED"
}

public struct IntegrationCommand: Sendable, Equatable, Codable {
    public let commandID: UUID
    public let packageID: UUID
    public let revision: Int
    public let requestedAction: IntegrationCommandAction

    public let approvalToken: String?

    public let idempotencyKey: String

    public let expectedPayloadSHA256: String

    public let state: IntegrationCommandState

    public let leaseOwner: String?
    public let leaseExpiresAt: Date?

    public let attemptCount: Int
    public let nextAttemptAt: Date?
    public let lastErrorCode: String?

    public let createdAt: Date

    public init(
        commandID: UUID = UUID(),
        packageID: UUID,
        revision: Int,
        requestedAction: IntegrationCommandAction,
        approvalToken: String? = nil,
        expectedPayloadSHA256: String,
        state: IntegrationCommandState = .pending,
        leaseOwner: String? = nil,
        leaseExpiresAt: Date? = nil,
        attemptCount: Int = 0,
        nextAttemptAt: Date? = nil,
        lastErrorCode: String? = nil,
        createdAt: Date
    ) {
        self.commandID = commandID
        self.packageID = packageID
        self.revision = revision
        self.requestedAction = requestedAction
        self.approvalToken = approvalToken
        self.idempotencyKey = "MYKILOS:\(packageID):REV:\(revision):ACTION:\(requestedAction.rawValue)"
        self.expectedPayloadSHA256 = expectedPayloadSHA256
        self.state = state
        self.leaseOwner = leaseOwner
        self.leaseExpiresAt = leaseExpiresAt
        self.attemptCount = attemptCount
        self.nextAttemptAt = nextAttemptAt
        self.lastErrorCode = lastErrorCode
        self.createdAt = createdAt
    }

    public var hatGültigeFreigabe: Bool {
        guard requestedAction != .refreshSevdeskStatus else { return true }
        return approvalToken != nil && !approvalToken!.isEmpty
    }

    public func leaseIstFrei(workerID: String, now: Date = Date()) -> Bool {
        guard let owner = leaseOwner else { return true }
        if owner == workerID { return true }
        if let expires = leaseExpiresAt, now > expires { return true }
        return false
    }

    public var istVerarbeitbar: Bool {
        switch state {
        case .pending, .retryWait: return true
        default: return false
        }
    }
}

public struct IntegrationEvent: Sendable, Equatable, Codable {
    public let eventID: UUID
    public let commandID: UUID
    public let packageID: UUID
    public let revision: Int
    public let eventType: String
    public let previousState: String?
    public let newState: String

    public let payloadSHA256: String

    public let remoteObjectID: String?

    public let remoteFingerprint: String?
    public let occurredAt: Date
    public let recordedAt: Date
    public let workerID: String?
    public let resultSummary: String?

    public init(
        eventID: UUID = UUID(),
        commandID: UUID,
        packageID: UUID,
        revision: Int,
        eventType: String,
        previousState: String?,
        newState: String,
        payloadSHA256: String,
        remoteObjectID: String? = nil,
        remoteFingerprint: String? = nil,
        occurredAt: Date,
        recordedAt: Date,
        workerID: String? = nil,
        resultSummary: String? = nil
    ) {
        self.eventID = eventID
        self.commandID = commandID
        self.packageID = packageID
        self.revision = revision
        self.eventType = eventType
        self.previousState = previousState
        self.newState = newState
        self.payloadSHA256 = payloadSHA256
        self.remoteObjectID = remoteObjectID
        self.remoteFingerprint = remoteFingerprint
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.workerID = workerID
        self.resultSummary = resultSummary
    }
}
