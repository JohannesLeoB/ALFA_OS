import Foundation
import AlfaKit

public enum ProjectSort: String, CaseIterable, Sendable {
    case number, name, date, kategorie, eigene
}

public enum ProjectSorter {
    public static func parseOrder(_ raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter { $0.isEmpty == false }
    }

    public static func sorted(_ projects: [Project], by sort: ProjectSort, customOrder: [String]) -> [Project] {
        switch sort {
        case .name:
            return projects.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .number:
            return projects.sorted { $0.projectNumber.localizedStandardCompare($1.projectNumber) == .orderedAscending }
        case .date:
            return projects.sorted { $0.updatedAt > $1.updatedAt }
        case .kategorie:
            return projects.sorted {
                $0.kind.rawValue == $1.kind.rawValue
                    ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    : $0.kind.rawValue < $1.kind.rawValue
            }
        case .eigene:
            let rank = Dictionary(uniqueKeysWithValues: customOrder.enumerated().map { ($1, $0) })
            return projects.sorted { a, b in
                let ra = rank[a.projectNumber], rb = rank[b.projectNumber]
                switch (ra, rb) {
                case let (x?, y?): return x < y
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):   return a.projectNumber.localizedStandardCompare(b.projectNumber) == .orderedAscending
                }
            }
        }
    }
}
