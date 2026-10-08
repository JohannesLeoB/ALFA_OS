import Foundation
import UniformTypeIdentifiers
import ALFAcolorCore
import Tokens

/// What an exchange format can do.
public struct ExchangeCapabilities: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    /// The format brings content into a document (import).
    public static let read = ExchangeCapabilities(rawValue: 1)
    /// The format puts a document, or a part of it, into another form (export, hand-over, conversion).
    public static let write = ExchangeCapabilities(rawValue: 2)
}

/// Where an import takes its bytes from.
public enum ExchangeSource: Sendable {
    case file(URL)
    case data(Data, type: UTType?)
}

/// What an export covers.
public enum ExchangeScope: Sendable, Equatable {
    case document
    case space(id: String)
    case items([ItemID])
}

/// Content that an import brings. The caller decides where it goes in the document.
public struct ExchangeImport: Sendable {
    public var items: [Item]
    public var assets: AssetStore
    public var tokenSets: [TokenSet]
    /// Things the format could not take over. The import still succeeded.
    public var warnings: [String]
    public init(items: [Item] = [], assets: AssetStore = AssetStore(), tokenSets: [TokenSet] = [], warnings: [String] = []) {
        self.items = items; self.assets = assets; self.tokenSets = tokenSets; self.warnings = warnings
    }
}

/// What an export makes: one file, or a folder package with several files.
public enum ExchangeOutput: Sendable {
    case file(name: String, type: UTType, data: Data)
    /// `files` maps relative paths inside the folder to bytes.
    case package(name: String, type: UTType, files: PackageFiles)
}

public enum ExchangeError: Error, Equatable, Sendable {
    /// The format does not have this capability.
    case notSupported(format: String, capability: ExchangeCapabilities)
    case duplicateFormat(String)
    /// The format has an empty identifier or no capability.
    case invalidFormat(String)
}

/// A way to bring content into a document or to take it out.
///
/// A format that reads is an import. A format that writes is an export or a hand-over package.
/// A conversion is a read with one format followed by a write with another.
/// The native package (`DocumentPackage`) is not an exchange format.
public protocol ExchangeFormat: Sendable {
    /// Stable identifier. It is never shown and never changes.
    var id: String { get }
    /// Name for the user, already localized.
    var name: String { get }
    /// File types that the format reads or writes.
    var contentTypes: [UTType] { get }
    var capabilities: ExchangeCapabilities { get }
    /// Called only when `capabilities` contains `.read`.
    func read(_ source: ExchangeSource) throws -> ExchangeImport
    /// Called only when `capabilities` contains `.write`.
    func write(_ document: ALFAcolorDocument, scope: ExchangeScope) throws -> ExchangeOutput
}

public extension ExchangeFormat {
    func read(_ source: ExchangeSource) throws -> ExchangeImport {
        throw ExchangeError.notSupported(format: id, capability: .read)
    }
    func write(_ document: ALFAcolorDocument, scope: ExchangeScope) throws -> ExchangeOutput {
        throw ExchangeError.notSupported(format: id, capability: .write)
    }
}

/// The formats that are known at run time, in the order of registration.
public struct ExchangeRegistry: Sendable {
    public private(set) var formats: [any ExchangeFormat] = []
    public init() {}

    public mutating func register(_ format: any ExchangeFormat) throws {
        guard !format.id.isEmpty, !format.capabilities.isEmpty else { throw ExchangeError.invalidFormat(format.id) }
        guard self.format(id: format.id) == nil else { throw ExchangeError.duplicateFormat(format.id) }
        formats.append(format)
    }

    public func format(id: String) -> (any ExchangeFormat)? { formats.first { $0.id == id } }

    /// Formats with the capability, optionally only those that handle `type` (the type or a subtype of it).
    public func formats(supporting capability: ExchangeCapabilities, for type: UTType? = nil) -> [any ExchangeFormat] {
        formats.filter { format in
            guard format.capabilities.contains(capability) else { return false }
            guard let type else { return true }
            return format.contentTypes.contains { type.conforms(to: $0) }
        }
    }
}
