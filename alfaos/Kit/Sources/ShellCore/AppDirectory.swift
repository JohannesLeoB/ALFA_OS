import Foundation

public struct AppLanes: Sendable, Decodable, Equatable {
    public let leadingKey: String?
    public let trailingKey: String?
}

public struct AppEntry: Sendable, Decodable, Equatable {
    public let id: String
    public let titleKey: String
    public let symbol: String
    public let lanes: AppLanes
}

public struct AppGroup: Sendable, Decodable, Equatable {
    public let id: String
    public let titleKey: String
    public let apps: [AppEntry]

    public func contains(_ appID: String) -> Bool {
        apps.contains { $0.id == appID }
    }
}

public struct AppDirectory: Sendable, Decodable, Equatable {
    public let groups: [AppGroup]

    public init(data: Data) throws {
        self = try JSONDecoder().decode(AppDirectory.self, from: data)
    }

    public var apps: [AppEntry] { groups.flatMap(\.apps) }

    public func app(_ id: String) -> AppEntry? {
        apps.first { $0.id == id }
    }

    public var first: AppEntry? { apps.first }

    public func rows(matching query: String, title: (String) -> String) -> [(group: AppGroup, apps: [AppEntry])] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return groups.compactMap { group in
            let members = group.apps.filter { entry in
                needle.isEmpty || title(entry.titleKey).lowercased().contains(needle) || title(group.titleKey).lowercased().contains(needle)
            }
            return members.isEmpty ? nil : (group, members)
        }
    }

    public func menu(matching query: String, title: (String) -> String) -> [MenuLine] {
        var lines: [MenuLine] = []
        var hit = 0
        for row in rows(matching: query, title: title) {
            if !lines.isEmpty { lines.append(.separator(lines.count)) }
            for entry in row.apps {
                lines.append(.entry(entry, hit))
                hit += 1
            }
        }
        return lines
    }
}

public enum MenuLine: Sendable, Equatable, Identifiable {
    case separator(Int)
    case entry(AppEntry, Int)

    public var id: String {
        switch self {
        case .separator(let line): "separator." + String(line)
        case .entry(let entry, _): entry.id
        }
    }

    public var entry: AppEntry? {
        if case .entry(let entry, _) = self { entry } else { nil }
    }

    public var hit: Int? {
        if case .entry(_, let hit) = self { hit } else { nil }
    }
}
