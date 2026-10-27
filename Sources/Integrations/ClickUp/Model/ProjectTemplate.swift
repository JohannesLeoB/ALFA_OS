enum ProjectTemplate {
    static let taskKeys: [String] = [
        "clickup.template.qualifyLead",
        "clickup.template.checkBriefing",
        "clickup.template.prepareMeasurement",
        "clickup.template.startPlanning",
        "clickup.template.prepareOffer",
        "clickup.template.checkOrder",
        "clickup.template.agreeInstallation",
        "clickup.template.closeAndReview",
    ]

    static var anchorKey: String { taskKeys[0] }

    static func anchor(in tasks: [ClickUpTask], named name: String) throws -> ClickUpTask? {
        let named = tasks.filter { $0.name == name }
        guard named.count <= 1 else { throw ClickUpFailure.ambiguousAnchor(name: name, count: named.count) }
        if let match = named.first { return match }
        return tasks.first(where: \.hasCustomFields)
    }

    static func phase(in tasks: [ClickUpTask], anchorName: String) -> ProjectPhase? {
        (try? anchor(in: tasks, named: anchorName))?.projectPhase
    }
}
