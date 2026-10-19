import Foundation
import Hub
import ShellCore
import enum AlfaServices.MailFlag
import struct AlfaServices.MailFolder
import enum AlfaServices.MailFolderRole
import struct AlfaServices.MailMessageSummary

public struct MailFolderName: Equatable, Sendable {
    public let key: String?
    public let text: String
}

public struct MailRowPresentation: Identifiable, Equatable, Sendable {
    public let id: String
    public let initials: String
    public let sender: String
    public let address: String
    public let outgoing: Bool
    public let draft: Bool
    public let unread: Bool
    public let starred: Bool
    public let selected: Bool
    public let picked: Bool
    public let thread: Int?
    public let date: MailDateLabel
    public let subject: String?
    public let preview: String?
}

public enum MailEmptyKind: Equatable, Sendable {
    case loading
    case notConnected
    case failed(lastLoaded: Date?)
    case noResults(query: String, folder: MailFolderName)
    case noFilterMatch
    case empty(folder: MailFolderName)
}

extension MailModel {
    public func folderName(_ id: String?) -> MailFolderName {
        guard let folder = folders.first(where: { $0.id == id }) else { return MailFolderName(key: nil, text: "") }
        if folder.role == .other { return MailFolderName(key: nil, text: folder.name) }
        return MailFolderName(key: "mail.role." + folder.role.rawValue, text: folder.name)
    }

    public var currentFolderName: MailFolderName { folderName(selectedFolder) }

    public var folderRows: [MailFolderRow] {
        let count = unread[selectedInlet ?? ""] ?? 0
        return sortedFolders.filter { $0.role != .other }.map { folder in
            MailFolderRow(folder: folder, glyph: Self.glyph(folder.role),
                          count: folder.role == .inbox ? count : folder.role == .drafts ? savedDraftCount : 0,
                          selected: folder.id == selectedFolder)
        }
    }

    public var savedDraftCount: Int {
        drafts.filter { card in
            switch card.state {
            case .sent, .queuedInOutbox, .sending: false
            default: card.remoteID != nil || { if case .saved = card.state { true } else { false } }()
            }
        }.count
    }

    public var listUnread: Int {
        rows.filter { !$0.summary.flags.contains(.seen) }.count
    }

    public var address: String { selectedAccount?.account ?? "" }

    public var accountReachable: Bool {
        switch listState {
        case .signInExpired, .failed: false
        default: true
        }
    }

    public var expiredAddress: String? {
        if case .signInExpired = listState { return address }
        return nil
    }

    public var emptyKind: MailEmptyKind? {
        switch listState {
        case .loading: .loading
        case .notConnected: .notConnected
        case .failed:
            .failed(lastLoaded: selectedInlet.flatMap { inlet in selectedFolder.flatMap { engine.lastSync(inlet, folder: $0) } })
        case .emptySearch(let query, let folder): .noResults(query: query, folder: folderName(folder))
        case .noFilterMatch: .noFilterMatch
        case .empty(let folder): .empty(folder: folderName(folder))
        case .signInExpired, .loadingMore, .loaded, .offline: nil
        }
    }

    public var rowPresentations: [MailRowPresentation] {
        let role = currentFolder?.role
        let outgoing = role == .sent || role == .drafts
        let draftsFolder = role == .drafts
        let now = clock()
        return rows.map { row in
            let item = row.summary
            let party = outgoing ? Self.firstParty(item.toRaw) : Self.sender(item)
            let name = party.name.isEmpty ? party.address : party.name
            return MailRowPresentation(
                id: item.id,
                initials: MailNames.initials(party.name),
                sender: party.name.isEmpty ? MailNames.middle(name, limit: 40) : name,
                address: party.address,
                outgoing: outgoing,
                draft: draftsFolder,
                unread: !item.flags.contains(.seen),
                starred: item.flags.contains(.flagged),
                selected: row.selected && stack.contains(.message(item.id)),
                picked: picked.contains(item.id),
                thread: row.threadCount > 1 ? row.threadCount : nil,
                date: MailDateLabel.of(item.receivedAt, now: now),
                subject: item.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : item.subject,
                preview: item.snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : item.snippet
            )
        }
    }

    public func party(_ item: MailMessageSummary) -> (name: String, address: String) {
        Self.sender(item)
    }

    static func sender(_ item: MailMessageSummary) -> (name: String, address: String) {
        let parsed = MailNames.display(item.fromRaw)
        let named = !item.from.isEmpty && !item.from.contains("@") ? item.from : parsed.name
        return (named, parsed.address.isEmpty ? item.from : parsed.address)
    }

    static func firstParty(_ raw: String) -> (name: String, address: String) {
        guard let first = MailAddresses.split(raw).first else { return ("", "") }
        return MailNames.display(first)
    }

    static func glyph(_ role: MailFolderRole) -> Icon {
        switch role {
        case .inbox: .inbox
        case .starred: .flag
        case .sent: .sent
        case .drafts: .docText
        case .all: .allMail
        case .archive: .archive
        case .spam: .junk
        case .trash: .trash
        case .other: .folder
        }
    }
}
