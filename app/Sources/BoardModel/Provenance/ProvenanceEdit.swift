import Foundation
import ALFAcolorCore

/// The origin fields as the inspector shows them. Empty text means no value.
public struct ProvenanceDraft: Equatable, Sendable {
    public var url: String
    public var file: String
    public var via: String
    public var license: String

    public init(url: String = "", file: String = "", via: String = "", license: String = "") {
        self.url = url
        self.file = file
        self.via = via
        self.license = license
    }

    /// The fields of a source. An item without a source gives empty fields.
    public init(source: Source?) {
        self.init(url: source?.url?.absoluteString ?? "", file: source?.file ?? "",
                  via: source?.via ?? "", license: source?.license ?? "")
    }
}

/// Why an origin could not be set.
public enum ProvenanceError: Error, Equatable, Sendable {
    /// The address is not a URL with a scheme, for example "example.com" without "https://".
    case invalidURL
}

/// Turns a draft into the origin of an item. Pure logic: the board is not read here.
public enum ProvenanceEdit {
    /// The source that a draft makes. Nil when every field is empty: the item then has no origin.
    /// A source that the item already had keeps its import date; a new one gets `now`.
    public static func source(for draft: ProvenanceDraft, existing: Source?, now: Date = .now) throws -> Source? {
        let url = trimmed(draft.url)
        let file = trimmed(draft.file)
        let via = trimmed(draft.via)
        let license = trimmed(draft.license)
        guard url != nil || file != nil || via != nil || license != nil else { return nil }
        var address: URL?
        if let url {
            guard let parsed = URL(string: url), parsed.scheme != nil else { throw ProvenanceError.invalidURL }
            address = parsed
        }
        return Source(url: address, file: file, license: license, via: via ?? "",
                      importedAt: existing?.importedAt ?? now)
    }

    /// Text without the spaces at the ends. Nil when nothing is left.
    static func trimmed(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

extension BoardStore {
    /// Sets the origin of the selected items to the draft. An empty draft removes it. One undo step.
    /// Returns false when no item changes. An invalid address changes nothing and throws.
    @discardableResult
    public func perform(provenance draft: ProvenanceDraft) throws -> Bool {
        var commands: [Command] = []
        for item in selectedItems {
            let next = try ProvenanceEdit.source(for: draft, existing: item.source)
            if next != item.source { commands.append(.setSource(item.id, next)) }
        }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.source"))
    }

    /// Removes the origin of the selected items. One undo step. Returns false when no item has an origin.
    @discardableResult
    public func removeProvenance() throws -> Bool {
        let commands: [Command] = selectedItems.compactMap { item in
            item.source == nil ? nil : .setSource(item.id, nil)
        }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.source"))
    }
}
