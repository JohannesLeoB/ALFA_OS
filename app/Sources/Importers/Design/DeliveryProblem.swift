import Foundation

/// Why a delivery cannot be read or taken over. The review sheet shows one text per case, from the string catalog.
public enum DeliveryProblem: Equatable, Sendable {
    case notZip
    case archiveTooLarge
    case tooManyEntries
    case damagedArchive
    case unsafeName(String)
    case duplicateName(String)
    case fileTooLarge
    case unknownKind
    case badManifest
    case missingFile(String)
    case checksumMismatch(String)
    case badTokens
    case other

    public init(_ error: any Error) {
        switch error {
        case let error as ZipError:
            self = Self.archive(error)
        case let error as ContractError:
            self = Self.contract(error)
        case is MockupImportError:
            self = .badManifest
        case let error as DeliveryError:
            self = error == .tooLarge ? .fileTooLarge : .unknownKind
        default:
            self = .other
        }
    }

    private static func archive(_ error: ZipError) -> DeliveryProblem {
        switch error {
        case .notAZip: return .notZip
        case .tooLarge: return .archiveTooLarge
        case .tooManyEntries: return .tooManyEntries
        case .corruptDirectory, .unsupported: return .damagedArchive
        case .unsafePath(let name): return .unsafeName(name)
        case .duplicateName(let name): return .duplicateName(name)
        }
    }

    private static func contract(_ error: ContractError) -> DeliveryProblem {
        switch error {
        case .noManifest, .badManifest: return .badManifest
        case .missingFile(let path): return .missingFile(path)
        case .checksumMismatch(let path): return .checksumMismatch(path)
        case .tokens: return .badTokens
        }
    }
}
