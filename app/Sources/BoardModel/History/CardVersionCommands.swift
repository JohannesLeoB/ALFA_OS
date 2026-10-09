import Foundation
import ALFAcolorCore
import Document

/// Why a version command was refused. A refused command changes nothing.
public enum VersionError: Error, Equatable, Sendable {
    /// The item is not a card of the active space.
    case unknownItem(ItemID)
    /// The item is not a code card, so it has no versions.
    case notCode(ItemID)
    /// No version has this index.
    case unknownVersion(Int)
    /// The code is larger than one version may be.
    case tooLarge
    /// The card or its layer is locked, so its code may not change.
    case locked
}

extension VersionError {
    /// The catalog key of the notice that tells why a change was refused.
    public var noticeKey: String {
        switch self {
        case .locked: "version.notice.locked"
        case .tooLarge: "version.notice.tooLarge"
        case .unknownItem, .notCode, .unknownVersion: "version.notice.failed"
        }
    }
}

/// The version commands of a code card. Each one is one undo step.
/// Versions are part of the document: they are saved with it, and a board change does not remove them.
/// The current code of a card is not a version. Before the code changes, the code before it is kept.
extension BoardStore {
    /// Keeps the current code of a code card as a version. Returns false and changes nothing when the newest version already has the same code.
    @discardableResult
    public func keepVersion(of item: ItemID, at date: Date = Date()) throws -> Bool {
        let card = try codeCard(item)
        let kept = try version(of: card, reason: .manual, at: date)
        return try changeVersions(nameKey: "undo.version.keep") { _, versions in
            versions.append(kept, to: item)
        }
    }

    /// Keeps a lab draft that the card is about to replace, as a version of reason draft. Returns false and changes
    /// nothing when the draft has the card's own code. A draft larger than one version is refused, so the lab keeps it.
    @discardableResult
    public func keepDraftVersion(of item: ItemID, language: CodeLanguage, files: [String: String], at date: Date = Date()) throws -> Bool {
        let card = try codeCard(item)
        guard card.language != language || card.files != files else { return false }
        let draft = CardVersion(date: date, reason: .draft, language: language, files: files)
        guard CardVersions.accepts(draft) else { throw VersionError.tooLarge }
        return try changeVersions(nameKey: "undo.version.keep") { _, versions in
            versions.append(draft, to: item)
        }
    }

    /// Restores a version: the card gets its code, and the code it had before is kept as a version first.
    /// Returns false when the version already is the current code. A locked card is refused.
    @discardableResult
    public func restoreVersion(_ index: Int, of item: ItemID, at date: Date = Date()) throws -> Bool {
        let card = try codeCard(item)
        try ensureUnlocked(card)
        let list = document.versions.versions(of: item)
        guard list.indices.contains(index) else { throw VersionError.unknownVersion(index) }
        let chosen = list[index]
        let current = try version(of: card, reason: .manual, at: date)
        guard !current.hasSameCode(as: chosen) else { return false }
        return try changeVersions(nameKey: "undo.version.restore") { board, versions in
            try setCode(of: card, to: chosen.language, files: chosen.files, in: &board)
            versions.append(current, to: item)
        }
    }

    /// Removes one version. The card stays as it is. Undo puts the version back in its place.
    @discardableResult
    public func deleteVersion(_ index: Int, of item: ItemID) throws -> Bool {
        _ = try codeCard(item)
        guard document.versions.versions(of: item).indices.contains(index) else { throw VersionError.unknownVersion(index) }
        return try changeVersions(nameKey: "undo.version.delete") { _, versions in
            _ = versions.remove(at: index, of: item)
        }
    }

    /// Writes the code of the lab to a code card in one step. The code before it is kept as a version (reason lab),
    /// but only when the code changes. A change of the width alone keeps no version. Returns false when nothing changed.
    @discardableResult
    public func saveLabCode(of item: ItemID, language: CodeLanguage, files: [String: String], width: Double?, at date: Date = Date()) throws -> Bool {
        let card = try codeCard(item)
        try ensureUnlocked(card)
        let before = try version(of: card, reason: .lab, at: date)
        let after = CardVersion(date: date, reason: .lab, language: language, files: files)
        return try changeVersions(nameKey: "undo.setContent") { board, versions in
            try setCode(of: card, to: language, files: files, width: width, in: &board)
            if !before.hasSameCode(as: after) {
                versions.append(before, to: item)
            }
        }
    }

    // MARK: Helpers

    /// A code card of the active space with its code.
    private struct CodeCardRecord {
        let item: Item
        let space: Space
        let language: CodeLanguage
        let files: [String: String]
        let width: Double?
    }

    private func codeCard(_ id: ItemID) throws -> CodeCardRecord {
        guard let space = activeSpace, let item = space.items.first(where: { $0.id == id }) else {
            throw VersionError.unknownItem(id)
        }
        guard case .code(let language, let files, let width) = item.content else { throw VersionError.notCode(id) }
        return CodeCardRecord(item: item, space: space, language: language, files: files, width: width)
    }

    /// The code of a card as a version. Refused when it is larger than one version may be.
    private func version(of card: CodeCardRecord, reason: CardVersion.Reason, at date: Date) throws -> CardVersion {
        let version = CardVersion(date: date, reason: reason, language: card.language, files: card.files)
        guard CardVersions.accepts(version) else { throw VersionError.tooLarge }
        return version
    }

    /// A locked card, or a card on a locked layer, keeps its code.
    private func ensureUnlocked(_ card: CodeCardRecord) throws {
        let lockedLayer = card.space.layers.contains { $0.id == card.item.layerID && $0.locked }
        guard !card.item.locked, !lockedLayer else { throw VersionError.locked }
    }

    /// Sets the code of a card on a copy of the board. The rectangle, the layer and the place stay.
    private func setCode(of card: CodeCardRecord, to language: CodeLanguage, files: [String: String], width: Double? = nil, in board: inout Board) throws {
        let content = Content.code(language: language, files: files, previewWidth: width ?? card.width)
        _ = try Command.setContent(card.item.id, content).apply(to: &board, spaceID: card.space.id, selection: selection)
    }
}
