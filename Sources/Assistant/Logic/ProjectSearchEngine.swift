struct ProjectSearchEngine: Sendable {
    let entries: [ProjectEntry]

    init(entries: [ProjectEntry]) {
        self.entries = entries
    }

    func filter(_ query: String) -> [ProjectEntry] {
        let lowered = query.lowercased()
        guard lowered.isEmpty == false else { return entries }
        return entries.filter {
            $0.projectNumber.lowercased().contains(lowered)
                || $0.title.lowercased().contains(lowered)
                || ($0.customerName?.lowercased().contains(lowered) ?? false)
        }
    }

    func resolve(_ query: String) -> ProjectEntry? {
        let lowered = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard lowered.isEmpty == false else { return nil }
        if let exact = entries.first(where: { $0.projectNumber.lowercased() == lowered }) { return exact }
        return entries.first { entry in
            entry.projectNumber.lowercased().contains(lowered)
                || entry.title.lowercased().contains(lowered)
                || (entry.customerName?.lowercased().contains(lowered) ?? false)
        }
    }
}
