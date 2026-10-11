import Foundation

public struct AppGroup: Sendable, Decodable, Equatable {
    public let id: String
    public let titleKey: String
}

public struct AppLanes: Sendable, Decodable, Equatable {
    public let leadingKey: String
    public let centerKey: String
    public let trailingKey: String
}

public struct AppEntry: Sendable, Decodable, Equatable {
    public let id: String
    public let group: String
    public let titleKey: String
    public let symbol: String
    public let lanes: AppLanes
}

public struct AppDirectory: Sendable, Decodable, Equatable {
    public let groups: [AppGroup]
    public let apps: [AppEntry]

    public init(groups: [AppGroup], apps: [AppEntry]) {
        self.groups = groups
        self.apps = apps
    }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(AppDirectory.self, from: data)
    }

    public func app(_ id: String) -> AppEntry? {
        apps.first { $0.id == id }
    }

    public var first: AppEntry? { apps.first }

    public func rows(matching query: String, title: (String) -> String) -> [(group: AppGroup, apps: [AppEntry])] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        return groups.compactMap { group in
            let members = apps.filter { entry in
                entry.group == group.id
                    && (needle.isEmpty || title(entry.titleKey).lowercased().contains(needle) || title(group.titleKey).lowercased().contains(needle))
            }
            return members.isEmpty ? nil : (group, members)
        }
    }
}
