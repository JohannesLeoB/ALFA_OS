import Foundation

public enum AllPlansCollector {
    public typealias ProjectRef = AllOffersCollector.ProjectRef

    public struct AggregatedPlan: Identifiable, Sendable, Equatable {
        public let projectNumber: String
        public let projectTitle: String
        public let projectFolderID: String
        public let category: PlanCategory
        public let file: GoogleDriveFile

        public var id: String { "\(projectNumber)|\(category.rawValue)|\(file.id)" }

        public init(projectNumber: String, projectTitle: String, projectFolderID: String,
                    category: PlanCategory, file: GoogleDriveFile) {
            self.projectNumber = projectNumber
            self.projectTitle = projectTitle
            self.projectFolderID = projectFolderID
            self.category = category
            self.file = file
        }
    }

    public struct Outcome: Sendable, Equatable {
        public let plans: [AggregatedPlan]
        public let projectsScanned: Int
        public let projectsFailed: Int
        public init(plans: [AggregatedPlan], projectsScanned: Int, projectsFailed: Int) {
            self.plans = plans
            self.projectsScanned = projectsScanned
            self.projectsFailed = projectsFailed
        }
    }

    private enum ProjectResult: Sendable {
        case ok([AggregatedPlan])
        case failed
    }

    public static func collectAll(
        projects: [ProjectRef],
        client: GoogleDriveFetching,
        maxConcurrent: Int = 5,
        maxDepth: Int = PlanCollector.maxDepthDefault,
        onProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> Outcome {
        guard projects.isEmpty == false else {
            return Outcome(plans: [], projectsScanned: 0, projectsFailed: 0)
        }
        let total = projects.count
        let window = max(1, maxConcurrent)

        var plans: [AggregatedPlan] = []
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
                case .ok(let p): plans.append(contentsOf: p)
                case .failed:    failed += 1
                }
                onProgress?(scanned, total)
                if let ref = iterator.next() {
                    group.addTask { try await scanProject(ref, client: client, maxDepth: maxDepth) }
                    inFlight += 1
                }
            }
        }

        return Outcome(plans: plans, projectsScanned: scanned, projectsFailed: failed)
    }

    private static func scanProject(
        _ ref: ProjectRef, client: GoogleDriveFetching, maxDepth: Int
    ) async throws -> ProjectResult {
        do {
            let result = try await PlanCollector.load(
                rootFolderID: ref.driveFolderID, client: client, maxDepth: maxDepth)
            var plans: [AggregatedPlan] = []
            for (category, files) in result.filesByCategory where category.inGlobalKatalog {
                plans.append(contentsOf: files.map {
                    AggregatedPlan(projectNumber: ref.projectNumber, projectTitle: ref.title,
                                   projectFolderID: ref.driveFolderID, category: category, file: $0)
                })
            }
            return .ok(plans)
        } catch GoogleDriveError.notConnected {
            throw GoogleDriveError.notConnected
        } catch {
            return .failed
        }
    }
}

public enum AllPlansSort: String, CaseIterable, Sendable {
    case date, projekt, kategorie, name
}

public enum AllPlansSorter {
    public typealias Plan = AllPlansCollector.AggregatedPlan

    public static func filtered(_ plans: [Plan], category: PlanCategory?) -> [Plan] {
        guard let category else { return plans }
        return plans.filter { $0.category == category }
    }

    public static func filtered(_ plans: [Plan], query: String) -> [Plan] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else { return plans }
        return plans.filter {
            $0.file.name.localizedCaseInsensitiveContains(q)
                || $0.projectTitle.localizedCaseInsensitiveContains(q)
                || $0.projectNumber.localizedCaseInsensitiveContains(q)
        }
    }

    public static func sorted(_ plans: [Plan], by sort: AllPlansSort) -> [Plan] {
        switch sort {
        case .date:
            return plans.sorted {
                ($0.file.modifiedAt ?? .distantPast) > ($1.file.modifiedAt ?? .distantPast)
            }
        case .name:
            return plans.sorted {
                $0.file.name.localizedCaseInsensitiveCompare($1.file.name) == .orderedAscending
            }
        case .projekt:
            return plans.sorted {
                $0.projectNumber == $1.projectNumber
                    ? $0.file.name.localizedCaseInsensitiveCompare($1.file.name) == .orderedAscending
                    : $0.projectNumber.localizedStandardCompare($1.projectNumber) == .orderedAscending
            }
        case .kategorie:
            return plans.sorted {
                $0.category == $1.category
                    ? $0.file.name.localizedCaseInsensitiveCompare($1.file.name) == .orderedAscending
                    : categoryRank($0.category) < categoryRank($1.category)
            }
        }
    }

    private static func categoryRank(_ category: PlanCategory) -> Int {
        PlanCategory.allCases.firstIndex(of: category) ?? .max
    }
}
