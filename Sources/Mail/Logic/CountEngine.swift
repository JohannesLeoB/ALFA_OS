enum CountEngine {
    struct Cached: Equatable {
        var count: FolderCount
        var local: Int
    }

    static func encode(_ count: FolderCount, local: Int) -> String {
        [count.unseen, count.total, local].map(String.init).joined(separator: " ")
    }

    static func decode(_ text: String) -> Cached? {
        let parts = text.split(separator: " ").compactMap { Int($0) }
        guard parts.count == 3, parts.allSatisfy({ $0 >= 0 }) else { return nil }
        return Cached(count: FolderCount(unseen: parts[0], total: parts[1]), local: parts[2])
    }

    static func shown(_ cached: Cached, local: Int) -> Int {
        max(0, cached.count.unseen + local - cached.local)
    }
}
