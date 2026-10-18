import Foundation

public enum PersistenceError: Error, LocalizedError, Equatable {
    case directoryUnavailable
    case encodeFailed
    case decodeFailed
    case writeFailed

    public var errorDescription: String? {
        switch self {
        case .directoryUnavailable: "Der Speicherort konnte nicht ermittelt werden."
        case .encodeFailed:         "Die Daten konnten nicht vorbereitet werden."
        case .decodeFailed:         "Die gespeicherten Daten konnten nicht gelesen werden."
        case .writeFailed:          "Schreiben auf die Festplatte ist fehlgeschlagen."
        }
    }
}
