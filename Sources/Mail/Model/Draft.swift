import Core
import Foundation
import Hub

public struct Draft: Codable, Sendable, Equatable {
    public var to: String?
    var cc: String?
    var bcc: String?
    public var subject: String
    public var body: String
    public var attachments: [Attachment]
    public var inReplyTo: String?
    public var threadID: String?
    public var bodyHTML: String?
    var messageID: String?
    public var receiptTo: String?
    public var from: Participant?
    public internal(set) var signed: String?
    var signatureOff = false

    public init(to: String? = nil, cc: String? = nil, bcc: String? = nil, subject: String, body: String,
                attachments: [Attachment] = [], inReplyTo: String? = nil, threadID: String? = nil,
                bodyHTML: String? = nil, messageID: String? = nil, receiptTo: String? = nil, from: Participant? = nil,
                signed: String? = nil, signatureOff: Bool = false) {
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.attachments = attachments
        self.inReplyTo = inReplyTo
        self.threadID = threadID
        self.bodyHTML = bodyHTML
        self.messageID = messageID
        self.receiptTo = receiptTo
        self.from = from
        self.signed = signed
        self.signatureOff = signatureOff
    }

    private enum CodingKeys: String, CodingKey {
        case to, cc, bcc, subject, body, attachments, inReplyTo, threadID, bodyHTML, messageID, receiptTo, from, signed, signatureOff
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        to = try container.decodeIfPresent(String.self, forKey: .to)
        cc = try container.decodeIfPresent(String.self, forKey: .cc)
        bcc = try container.decodeIfPresent(String.self, forKey: .bcc)
        subject = try container.decode(String.self, forKey: .subject)
        body = try container.decode(String.self, forKey: .body)
        attachments = try container.decodeIfPresent([Attachment].self, forKey: .attachments) ?? []
        inReplyTo = try container.decodeIfPresent(String.self, forKey: .inReplyTo)
        threadID = try container.decodeIfPresent(String.self, forKey: .threadID)
        bodyHTML = try container.decodeIfPresent(String.self, forKey: .bodyHTML)
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID)
        receiptTo = try container.decodeIfPresent(String.self, forKey: .receiptTo)
        from = try container.decodeIfPresent(Participant.self, forKey: .from)
        signed = try container.decodeIfPresent(String.self, forKey: .signed)
        signatureOff = try container.decodeIfPresent(Bool.self, forKey: .signatureOff) ?? false
    }
}

public struct StoredDraft: Equatable, Sendable {
    public var id: String
    public var draft: Draft

    public init(id: String, draft: Draft) {
        self.id = id
        self.draft = draft
    }
}

extension Draft {
    var unsignedBody: String {
        guard let signed else { return body }
        return SignatureEngine.removed(signed, from: body) ?? body
    }

    mutating func resign(to signature: MailboxSignature?, explicit: Bool = false) {
        let target = signatureOff || !(explicit || signature?.onNew == true) ? nil : signature?.block
        guard target != signed else { return }
        if let signed {
            let next: String?
            var nextHTML = bodyHTML
            if let target {
                next = SignatureEngine.replaced(signed, with: target, in: body)
                nextHTML = bodyHTML.flatMap { SignatureEngine.htmlReplaced(signed, with: target, in: $0) }
            } else {
                next = SignatureEngine.removed(signed, from: body)
                nextHTML = bodyHTML.flatMap { SignatureEngine.htmlRemoved(signed, from: $0) }
            }
            guard let next, bodyHTML == nil || nextHTML != nil else { return }
            body = next
            bodyHTML = nextHTML
        } else if let target {
            body = SignatureEngine.inserted(target, into: body, aboveQuote: signature?.aboveQuote ?? false)
            bodyHTML = bodyHTML.map { SignatureEngine.htmlInserted(target, into: $0) }
        }
        signed = target
    }
}

public struct SavedDraft: Equatable, Sendable {
    public var id: String
    public var mirrorID: String

    public init(id: String, mirrorID: String? = nil) {
        self.id = id
        self.mirrorID = mirrorID ?? id
    }
}

public struct KeptDraft: Equatable, Sendable {
    public var id: UUID
    public var inlet: Inlet.ID
    public var draft: Draft
    public var remoteID: String?
    public var mirrorID: String?
    public var updatedAt: Date

    public init(id: UUID, inlet: Inlet.ID, draft: Draft, remoteID: String?, mirrorID: String?, updatedAt: Date) {
        self.id = id
        self.inlet = inlet
        self.draft = draft
        self.remoteID = remoteID
        self.mirrorID = mirrorID
        self.updatedAt = updatedAt
    }
}

public struct OpenDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var inlet: Inlet.ID
    public var draft: Draft
    public var state: DraftState
    public var outboxID: OutboxItem.ID?
    public var remoteID: String?
    public var mirrorID: String?
    public var saveFailure: Hint?
    public var tooLarge = false

    public func people(_ field: RecipientField) -> [Participant] {
        switch field {
        case .to: RecipientEngine.parse(draft.to)
        case .cc: RecipientEngine.parse(draft.cc)
        case .bcc: RecipientEngine.parse(draft.bcc)
        }
    }

    public var addressees: [Participant] {
        for field in RecipientField.allCases {
            let found = people(field)
            if !found.isEmpty { return found }
        }
        return []
    }

    public var canSend: Bool {
        switch state {
        case .sending, .queuedInOutbox, .sent: return false
        default: break
        }
        return RecipientField.allCases.contains { !people($0).isEmpty } && !draft.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var needsGrant: Bool {
        guard case .sendFailed(let hint) = state else { return false }
        return Self.asksSignIn(hint)
    }

    public var saveNeedsSignIn: Bool {
        saveFailure.map(Self.asksSignIn) ?? false
    }

    private static func asksSignIn(_ hint: Hint) -> Bool {
        hint.kind == .signIn || hint.text == Hint.signInExpiredText
    }

    public var failedToSend: Bool {
        if case .sendFailed = state { return !needsGrant }
        return false
    }

    public var status: DraftStatus? {
        switch state {
        case .sending: return .sending
        case .queuedInOutbox: return .outbox
        case .saving: return .saving
        case .saved: return .saved
        default: break
        }
        if tooLarge { return .tooLarge }
        if failedToSend { return .sendFailed }
        return saveFailure == nil ? nil : .notSaved
    }
}

public enum DraftState: Equatable, Sendable {
    case idle
    case edited
    case saving
    case saved(Date)
    case sending
    case sent
    case sendFailed(Hint)
    case queuedInOutbox
}

public enum DraftStatus: Equatable, Sendable {
    case saving
    case saved
    case sending
    case outbox
    case sendFailed
    case notSaved
    case tooLarge

    public var key: String {
        switch self {
        case .saving: "mail.draft.saving"
        case .saved: "mail.draft.saved"
        case .sending: "mail.draft.sending"
        case .outbox: "mail.draft.outbox"
        case .sendFailed: "mail.draft.sendFailed"
        case .notSaved: "mail.draft.notSaved"
        case .tooLarge: "mail.draft.tooLarge"
        }
    }

    public var failed: Bool { self == .sendFailed || self == .notSaved || self == .tooLarge }
}

public struct RichRun: Equatable, Sendable {
    public var text: String
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var link: String?

    public init(_ text: String, bold: Bool = false, italic: Bool = false, underline: Bool = false, link: String? = nil) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.link = link
    }

    var plain: Bool { !bold && !italic && !underline && link == nil }
}

public struct RichParagraph: Equatable, Sendable {
    public var list: ListKind?
    public var runs: [RichRun]

    public init(list: ListKind? = nil, runs: [RichRun]) {
        self.list = list
        self.runs = runs
    }
}

public enum ListKind: String, Sendable, CaseIterable {
    case bullet
    case number
}

public struct SenderChoice: Identifiable, Equatable, Sendable {
    public let inlet: Inlet.ID
    public let sender: Participant

    public var id: String { inlet + "\n" + sender.address.lowercased() }

    public init(inlet: Inlet.ID, sender: Participant) {
        self.inlet = inlet
        self.sender = sender
    }
}

public struct SenderNames: Equatable, Sendable {
    public var chosen: String
    public var profile: String

    public init(chosen: String = "", profile: String = "") {
        self.chosen = chosen
        self.profile = profile
    }
}

public struct Participant: Identifiable, Equatable, Sendable, Codable {
    public let id: Int
    public let name: String
    public let address: String

    public init(id: Int = 0, name: String, address: String) {
        self.id = id
        self.name = name
        self.address = address
    }

    public var initials: String { PersonName.initials(name) }

    public var label: String { name.isEmpty ? PersonName.middle(address, limit: NameLimit.person) : name }

    public var chipLabel: String { name.isEmpty ? PersonName.middle(address, limit: NameLimit.chip) : name }

    public var detail: String { name.isEmpty ? "" : PersonName.middle(address, limit: NameLimit.personAddress) }

    public var full: String { name.isEmpty ? address : name + " \u{00B7} " + address }

    public var first: String {
        name.isEmpty ? PersonName.middle(address, limit: NameLimit.firstName)
            : String(name.split(whereSeparator: { $0.isWhitespace }).first ?? "")
    }
}

public enum RecipientGroup: Equatable, Sendable {
    case to
    case cc
    case none
}

public struct Recipients: Equatable, Sendable {
    public let to: [Participant]
    public let cc: [Participant]

    public var all: [Participant] { to + cc }

    public var summary: String { RecipientEngine.summary(all) }

    public var more: Int? { all.count > NameLimit.recipientsInline ? all.count - 1 : nil }

    public func group(at index: Int) -> RecipientGroup {
        if index == 0 { return .to }
        return index == to.count && !cc.isEmpty ? .cc : .none
    }
}

public enum RecipientField: String, CaseIterable, Sendable {
    case to
    case cc
    case bcc
}

public struct Suggestion: Identifiable, Equatable, Sendable {
    public var id: String { address.lowercased() }
    public let name: String
    public let address: String
    public let tag: SuggestionTag

    public var initials: String { PersonName.initials(name) }

    public var shown: String { PersonName.middle(address, limit: NameLimit.suggestionAddress) }
}

public enum SuggestionTag: Equatable, Sendable {
    case contact
    case sender

    public var key: String { self == .contact ? "mail.suggest.contact" : "mail.suggest.sender" }
}

public struct Contact: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var name: String
    public var address: String
}

public enum OutboxState: Equatable, Sendable {
    case waiting
    case checking
    case sending
    case failed(Hint)
    case unverified(Hint)
    case planned(Date)
    case missed(Date)

    public var key: String {
        switch self {
        case .waiting: "mail.outbox.state.waiting"
        case .checking: "mail.outbox.state.checking"
        case .sending: "mail.outbox.state.sending"
        case .failed(let hint): hint.text
        case .unverified: "mail.outbox.state.failed"
        case .planned: "mail.later.planned"
        case .missed: "mail.later.missed"
        }
    }

    public var offersRowActions: Bool {
        switch self {
        case .waiting, .failed, .planned, .missed: true
        case .checking, .sending, .unverified: false
        }
    }

    public var inFlight: Bool {
        switch self {
        case .checking, .sending: true
        case .waiting, .failed, .unverified, .planned, .missed: false
        }
    }

    public var needsAttention: Bool {
        switch self {
        case .failed, .unverified: true
        case .waiting, .checking, .sending, .planned, .missed: false
        }
    }

    public var plannedAt: Date? {
        switch self {
        case .planned(let date), .missed(let date): date
        case .waiting, .checking, .sending, .failed, .unverified: nil
        }
    }

    public var missed: Bool {
        if case .missed = self { return true }
        return false
    }
}

public struct OutboxItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    let inlet: Inlet.ID
    let draft: Draft
    let messageID: String
    var draftID: String?
    var mirrorID: String?
    private(set) var state: OutboxState
    private(set) var attempts: Int

    init(inlet: Inlet.ID, draft: Draft, draftID: String? = nil) {
        self.init(id: UUID(), inlet: inlet, draft: draft, messageID: UUID().uuidString.lowercased(), draftID: draftID,
                  state: .waiting, attempts: 0)
    }

    init(id: UUID, inlet: Inlet.ID, draft: Draft, messageID: String, draftID: String?, mirrorID: String? = nil,
         state: OutboxState, attempts: Int) {
        self.id = id
        self.inlet = inlet
        self.draft = draft
        self.messageID = messageID
        self.draftID = draftID
        self.mirrorID = mirrorID
        self.state = state
        self.attempts = attempts
    }

    mutating func startSending() {
        state = .sending
        attempts += 1
    }

    mutating func startChecking() {
        state = .checking
        attempts += 1
    }

    mutating func proceed() {
        guard state == .checking else { return }
        state = .sending
    }

    mutating func wait() { state = .waiting }

    mutating func fail(_ hint: Hint) { state = .failed(hint) }

    mutating func unverify(_ hint: Hint) { state = .unverified(hint) }

    mutating func plan(at date: Date) { state = .planned(date) }

    mutating func miss() {
        guard case .planned(let date) = state else { return }
        state = .missed(date)
    }
}

public enum SendOutcome: Equatable, Sendable {
    case sent
    case queued(OutboxItem.ID)
}
