import Foundation
import Hub
import struct AlfaKit.MailLeadVorschlag

public struct MailMessageRef: Equatable, Sendable {
    public let inlet: Inlet.ID
    public let messageID: String

    public init(inlet: Inlet.ID, messageID: String) {
        self.inlet = inlet
        self.messageID = messageID
    }
}

public enum MailCommand: Equatable, Sendable {
    case attachmentToProjectFolder(MailMessageRef, attachmentID: String, project: String?)
    case leadFromMail(MailMessageRef, MailLeadVorschlag)
    case print(MailMessageRef)
    case exportPDF(MailMessageRef)
}
