import Foundation

public enum AllOffersCollector {
    public enum Direction: String, Sendable, Equatable {
        case incoming, outgoing
        public var label: String { self == .incoming ? "Eingehend" : "Ausgehend" }
    }

    public struct AggregatedOffer: Identifiable, Sendable, Equatable {
        public let projectNumber: String
        public let projectTitle: String
        public let projectFolderID: String
        public let direction: Direction
        public let offer: ClassifiedOffer

        public var id: String { "\(projectNumber)|\(direction.rawValue)|\(offer.file.id)" }

        public init(projectNumber: String, projectTitle: String, projectFolderID: String,
                    direction: Direction, offer: ClassifiedOffer) {
            self.projectNumber = projectNumber
            self.projectTitle = projectTitle
            self.projectFolderID = projectFolderID
            self.direction = direction
            self.offer = offer
        }
    }

    public struct ProjectRef: Sendable, Equatable {
        public let projectNumber: String
        public let title: String
        public let driveFolderID: String
        public init(projectNumber: String, title: String, driveFolderID: String) {
            self.projectNumber = projectNumber
            self.title = title
            self.driveFolderID = driveFolderID
        }
    }

    public struct Outcome: Sendable, Equatable {
        public let offers: [AggregatedOffer]
        public let projectsScanned: Int
        public let projectsFailed: Int
        public init(offers: [AggregatedOffer], projectsScanned: Int, projectsFailed: Int) {
            self.offers = offers
            self.projectsScanned = projectsScanned
            self.projectsFailed = projectsFailed
        }
    }

    private enum ProjectResult: Sendable {
        case ok([AggregatedOffer])
        case failed
    }

    public static func collectAll(
        projects: [ProjectRef],
        client: GoogleDriveFetching,
        maxConcurrent: Int = 5,
        maxDepth: Int = OffersCollector.maxDepthDefault,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> Outcome {
        guard projects.isEmpty == false else {
            return Outcome(offers: [], projectsScanned: 0, projectsFailed: 0)
        }
        let total = projects.count
        let window = max(1, maxConcurrent)

        var offers: [AggregatedOffer] = []
        var scanned = 0
        var failed = 0

        try await withThrowingTaskGroup(of: ProjectResult.self) { group in
            var iterator = projects.makeIterator()
            var inFlight = 0

            for _ in 0..<window {
                guard let ref = iterator.next() else { break }
                group.addTask { try await scanProject(ref, client: client, maxDepth: maxDepth) }
                inFlight += 1
            }

            while inFlight > 0 {
                let result = try await group.next()!
                inFlight -= 1
                scanned += 1
                switch result {
                case .ok(let o): offers.append(contentsOf: o)
                case .failed:    failed += 1
                }
                onProgress?(scanned, total)
                if let ref = iterator.next() {
                    group.addTask { try await scanProject(ref, client: client, maxDepth: maxDepth) }
                    inFlight += 1
                }
            }
        }

        return Outcome(offers: offers, projectsScanned: scanned, projectsFailed: failed)
    }

    private static func scanProject(
        _ ref: ProjectRef, client: GoogleDriveFetching, maxDepth: Int
    ) async throws -> ProjectResult {
        do {
            let result = try await OffersCollector.load(
                rootFolderID: ref.driveFolderID, client: client, maxDepth: maxDepth)
            let incoming = result.incoming.map {
                AggregatedOffer(projectNumber: ref.projectNumber, projectTitle: ref.title,
                                projectFolderID: ref.driveFolderID, direction: .incoming, offer: $0)
            }
            let outgoing = result.outgoing.map {
                AggregatedOffer(projectNumber: ref.projectNumber, projectTitle: ref.title,
                                projectFolderID: ref.driveFolderID, direction: .outgoing, offer: $0)
            }
            return .ok(incoming + outgoing)
        } catch GoogleDriveError.notConnected {
            throw GoogleDriveError.notConnected
        } catch {
            return .failed
        }
    }
}

public enum AllOffersSort: String, CaseIterable, Sendable {
    case date, projekt, richtung, typ, name
}

public enum AllOffersSorter {
    public typealias Offer = AllOffersCollector.AggregatedOffer

    public static func filtered(_ offers: [Offer], category: OfferDocumentType?) -> [Offer] {
        guard let category else { return offers }
        return offers.filter { $0.offer.type == category }
    }

    public static func filtered(_ offers: [Offer], query: String) -> [Offer] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else { return offers }
        return offers.filter {
            $0.offer.file.name.localizedCaseInsensitiveContains(q)
                || $0.projectTitle.localizedCaseInsensitiveContains(q)
                || $0.projectNumber.localizedCaseInsensitiveContains(q)
                || ($0.offer.belegNummer?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    public static func sorted(_ offers: [Offer], by sort: AllOffersSort) -> [Offer] {
        switch sort {
        case .date:
            return offers.sorted {
                ($0.offer.file.modifiedAt ?? .distantPast) > ($1.offer.file.modifiedAt ?? .distantPast)
            }
        case .name:
            return offers.sorted {
                $0.offer.file.name.localizedCaseInsensitiveCompare($1.offer.file.name) == .orderedAscending
            }
        case .projekt:
            return offers.sorted {
                $0.projectNumber == $1.projectNumber
                    ? $0.offer.file.name.localizedCaseInsensitiveCompare($1.offer.file.name) == .orderedAscending
                    : $0.projectNumber.localizedStandardCompare($1.projectNumber) == .orderedAscending
            }
        case .richtung:
            return offers.sorted {
                $0.direction == $1.direction
                    ? $0.projectNumber.localizedStandardCompare($1.projectNumber) == .orderedAscending
                    : $0.direction.rawValue < $1.direction.rawValue
            }
        case .typ:
            return offers.sorted {
                $0.offer.type.rawValue == $1.offer.type.rawValue
                    ? $0.offer.file.name.localizedCaseInsensitiveCompare($1.offer.file.name) == .orderedAscending
                    : $0.offer.type.rawValue < $1.offer.type.rawValue
            }
        }
    }
}
