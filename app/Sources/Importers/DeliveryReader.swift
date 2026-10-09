import BoardModel
import Foundation
import Tokens

/// A delivery from the design side: a contract or a mockup package. The kind comes from the manifest in the ZIP.
public enum Delivery: Equatable, Sendable {
    case contract(ContractSets)
    case mockup(MockupDelivery)
}

public enum DeliveryError: Error, Equatable, Sendable {
    /// Neither MANIFEST.json (contract) nor manifest.json (mockup package) is in the archive.
    case unknownKind
    /// The file is larger than the limit; it is refused before it is read.
    case tooLarge
}

public enum DeliveryReader {
    /// The largest file that is read as a delivery.
    public static let fileBytes = 512 << 20

    public static func read(_ data: Data, now: Date = .now) throws -> Delivery {
        let contents = try ZipReader.read(data)
        let names = Set(contents.files.map(\.path))
        if names.contains(ContractImport.manifestPath) {
            return .contract(try ContractImport.read(contents))
        }
        if names.contains("manifest.json") {
            return .mockup(try MockupImport.read(contents, now: now))
        }
        throw DeliveryError.unknownKind
    }

    /// Reads a delivery from a file. The size is checked first, so a huge file is never loaded.
    public static func read(fileAt url: URL, now: Date = .now, limit: Int = fileBytes) throws -> Delivery {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= limit else { throw DeliveryError.tooLarge }
        return try read(try Data(contentsOf: url), now: now)
    }
}

/// What the review sheet shows before anything is taken over.
public struct DeliveryReview: Equatable, Sendable {
    /// Token changes of the light set, and of the dark set. Empty for a mockup package.
    public let changes: [TokenChange]
    public let darkChanges: [TokenChange]
    public let frames: Int
    public let pieces: Int
    public let warnings: [String]

    /// `tokenSets` are the sets of the document; the changes compare with the sets of the same name.
    public init(_ delivery: Delivery, tokenSets: [TokenSet]) {
        switch delivery {
        case .contract(let contract):
            changes = TokenDiff.changes(from: tokenSets.first { $0.name == ContractSets.lightName }, to: contract.light)
            darkChanges = contract.dark.map { TokenDiff.changes(from: tokenSets.first { $0.name == ContractSets.darkName }, to: $0) } ?? []
            frames = 0
            pieces = 0
            var notes = contract.warnings
            if contract.dark == nil, tokenSets.contains(where: { $0.name == ContractSets.darkName }) {
                notes.append("the contract has no dark file: the dark set of the document stays")
            }
            warnings = notes
        case .mockup(let mockup):
            changes = []
            darkChanges = []
            frames = mockup.frames.count
            pieces = mockup.pieces.count
            warnings = mockup.warnings
        }
    }
}

/// Takes a delivery over into the document as one undo step.
@MainActor
public enum DeliveryApply {
    @discardableResult
    public static func apply(_ delivery: Delivery, to store: BoardStore) throws -> Bool {
        switch delivery {
        case .contract(let contract):
            return try ContractApply.apply(contract, to: store)
        case .mockup(let mockup):
            return try MockupPlacement.place(mockup, in: store)
        }
    }
}
