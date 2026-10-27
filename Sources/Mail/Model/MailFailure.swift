import Hub

public enum MailFailure: Error, Equatable, Sendable {
    case folderNotFound(String)
    case accountIncomplete(String)
    case connectionFailed(String)
    case connectionClosed
    case timeout
    case tlsUnavailable
    case credentialsMissing
    case unsupportedAuthentication(String)
    case unsupportedCapability(String)
    case authenticationRejected(String)
    case serverRejected(String)
    case smtpRejected(Int, String)
    case recipientRejected(String, Int, String)
    case malformedResponse(String)
    case messageNotFound(String)
    case invalidMessageID(String)
    case invalidRecipient(String)
    case noRecipients
}

public enum MailboxEvent: Equatable, Sendable {
    case accountsChanged
    case foldersChanged(Inlet.ID)
    case messagesChanged(Inlet.ID, folder: String)
    case newMail(Inlet.ID, count: Int)
    case outboxChanged
    case syncFailed(Inlet.ID, Hint)
    case syncFinished(Inlet.ID)
}

enum MessageTextKey: String, Sendable {
    case offline = "mail.hint.offline"
    case rejected = "mail.hint.rejected"
    case failed = "mail.hint.failed"
    case notConnected = "hint.mail.notConnected"
    case noInlet = "hint.mail.noInlet"
    case capabilityMissing = "hint.mail.capabilityMissing"
}
