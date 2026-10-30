import Hub

public struct DriveRootStore: Sendable {
    static let key = "google.drive.projectsRoot"

    private let settings: SettingStore

    public init(settings: SettingStore) {
        self.settings = settings
    }

    public func current() -> DriveRoot? {
        guard let root = try? settings.value(Self.key, as: DriveRoot.self), !root.id.isEmpty else { return nil }
        return root
    }

    public func choose(_ root: DriveRoot) {
        try? settings.store(root, forKey: Self.key)
    }
}
