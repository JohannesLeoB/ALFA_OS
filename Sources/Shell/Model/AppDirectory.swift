import Foundation

struct AppGroup: Sendable, Decodable, Equatable {
    let id: String
    let titleKey: String
    let apps: [AppEntry]
}

public struct AppDirectory: Sendable, Decodable, Equatable {
    let groups: [AppGroup]

    public init(data: Data) throws {
        self = try JSONDecoder().decode(AppDirectory.self, from: data)
    }

    var apps: [AppEntry] { groups.flatMap(\.apps) }

    var first: AppEntry? { apps.first }

    func app(_ id: String) -> AppEntry? {
        apps.first { $0.id == id }
    }

    func rows(matching query: String, title: (String) -> String) -> [(group: AppGroup, apps: [AppEntry])] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return groups.compactMap { group in
            let members = group.apps.filter { entry in
                needle.isEmpty || title(entry.titleKey).lowercased().contains(needle) || title(group.titleKey).lowercased().contains(needle)
            }
            return members.isEmpty ? nil : (group, members)
        }
    }

    func menu(matching query: String, title: (String) -> String) -> [AppMenuLine] {
        var lines: [AppMenuLine] = []
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

public enum AppMenuLine: Sendable, Equatable, Identifiable {
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
}

public struct AppLanes: Sendable, Decodable, Equatable {
    public let leadingKey: String?
    public let trailingKey: String?
}

public struct AppEntry: Sendable, Decodable, Equatable {
    public let id: String
    public let titleKey: String
    public let lanes: AppLanes
}
