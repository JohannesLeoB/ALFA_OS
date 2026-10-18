import Foundation

public enum WorkBasketSortKey: Sendable {
    case erstelltAbsteigend

    case erstelltAufsteigend

    case versionAbsteigend

    case projectNumber
}

extension Array where Element == WorkBasket {
    public func sortiert(nach key: WorkBasketSortKey) -> [WorkBasket] {
        switch key {
        case .erstelltAbsteigend:
            return sorted { $0.erstellt > $1.erstellt }
        case .erstelltAufsteigend:
            return sorted { $0.erstellt < $1.erstellt }
        case .versionAbsteigend:
            return sorted { $0.version > $1.version }
        case .projectNumber:
            return sorted { $0.projectNumber < $1.projectNumber }
        }
    }

    public func gefiltert(nachInhaltsArt inhaltsArt: InhaltsArt?) -> [WorkBasket] {
        guard let inhaltsArt else { return self }
        return filter { $0.inhaltsArt == inhaltsArt }
    }

    public func gefiltert(nachProjekt projectNumber: String?) -> [WorkBasket] {
        guard let projectNumber, !projectNumber.isEmpty else { return self }
        return filter { $0.projectNumber == projectNumber }
    }

    public func gefiltert(nachStatusFall wunsch: WorkBasketStatus?) -> [WorkBasket] {
        guard let wunsch else { return self }
        return filter { $0.status.istGleicherFall(wunsch) }
    }
}

extension WorkBasketStatus {
    public func istGleicherFall(_ other: WorkBasketStatus) -> Bool {
        switch (self, other) {
        case (.kalkulation, .kalkulation),
             (.bestaetigt, .bestaetigt),
             (.nachtrag, .nachtrag),
             (.gutschrift, .gutschrift):
            return true
        default:
            return false
        }
    }
}

extension Array where Element == any Pick {
    public func sortiertNachBezeichnung() -> [any Pick] {
        sorted { $0.snapshot.label < $1.snapshot.label }
    }

    public func gefiltert(nachMatrix matrix: CatalogMatrix?) -> [any Pick] {
        guard let matrix else { return self }
        return filter { $0.matrix == matrix }
    }
}
