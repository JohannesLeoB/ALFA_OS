import Foundation

public struct Note: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var body: String
    public var projectID: String?
    public var color: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(id: String = UUID().uuidString, body: String, projectID: String? = nil, color: String? = nil,
                createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.body = body
        self.projectID = projectID
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var ref: String { String(id.prefix(6)) }
}

public struct Todo: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    var title: String
    var done: Bool
    var dueDate: Date?
    var projectID: String?
    var alarmActive: Bool
    let createdAt: Date
    var updatedAt: Date

    init(id: String = UUID().uuidString, title: String, done: Bool = false, dueDate: Date? = nil,
         projectID: String? = nil, alarmActive: Bool = false, createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.done = done
        self.dueDate = dueDate
        self.projectID = projectID
        self.alarmActive = alarmActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var ref: String { String(id.prefix(6)) }
}

public struct JournalEntry: Codable, Identifiable, Sendable, Equatable {
    enum Kind: String, Codable, Sendable, CaseIterable {
        case cannotRead
        case contradiction
        case missingInfo
        case other
    }

    public let id: UUID
    let timestamp: Date
    let projectID: String?
    let kind: Kind
    let text: String

    init(id: UUID = UUID(), timestamp: Date = Date(), projectID: String? = nil, kind: Kind, text: String) {
        self.id = id
        self.timestamp = timestamp
        self.projectID = projectID
        self.kind = kind
        self.text = text
    }
}

struct StudioKnowledge: Sendable {
    struct Project: Sendable, Equatable {
        let channel: String
        let phaseLabel: String
        let clientDisplay: String
        let clientKey: String
        let location: String
        let messages: Int
        let maxAmount: Double?
        let issueSignals: Int
        let issueKeywords: [String]
        let lastDate: String
    }

    struct Supplier: Sendable, Equatable {
        let name: String
        let mentions: Int
    }

    struct TeamMember: Sendable, Equatable {
        let name: String
        let messages: Int
    }

    enum Hit: Sendable, Equatable {
        case project(Project)
        case supplier(Supplier)
        case team(TeamMember)
    }

    static let totalKeys = ["channels", "messages", "project_channels", "offer_channels", "price_observations", "issue_signals"]

    let generated: String
    let totals: [String: Int]
    let projects: [Project]
    let suppliers: [Supplier]
    let team: [TeamMember]

    init?(data: Data) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let meta = root["_meta"] as? [String: Any]
        generated = (meta?["generated"] as? String) ?? ""
        totals = (meta?["totals"] as? [String: Any])?.compactMapValues { ($0 as? NSNumber)?.intValue } ?? [:]
        projects = (root["projects"] as? [[String: Any]] ?? []).map { entry in
            Project(
                channel: entry["channel"] as? String ?? "",
                phaseLabel: entry["phase_label"] as? String ?? "",
                clientDisplay: entry["client_display"] as? String ?? "",
                clientKey: entry["client_key"] as? String ?? "",
                location: entry["location"] as? String ?? "",
                messages: (entry["messages"] as? NSNumber)?.intValue ?? 0,
                maxAmount: (entry["max_amount_eur"] as? NSNumber)?.doubleValue,
                issueSignals: (entry["issue_signals"] as? NSNumber)?.intValue ?? 0,
                issueKeywords: entry["issue_keywords"] as? [String] ?? [],
                lastDate: entry["last"] as? String ?? "")
        }
        suppliers = (root["suppliers"] as? [[String: Any]] ?? []).map {
            Supplier(name: $0["name"] as? String ?? "", mentions: ($0["mentions"] as? NSNumber)?.intValue ?? 0)
        }
        team = (root["team"] as? [[String: Any]] ?? []).map {
            TeamMember(name: $0["name"] as? String ?? "", messages: ($0["messages"] as? NSNumber)?.intValue ?? 0)
        }
    }

    func overview() -> [Phrase] {
        var lines: [Phrase] = [.make("assistant.studio.overviewHeader", generated)]
        let parts: [Phrase] = Self.totalKeys.compactMap { key in
            totals[key].map { .make("assistant.studio.total." + key, String($0)) }
        }
        if parts.isEmpty == false { lines.append(.join(parts, " \u{00B7} ")) }
        let topTeam = team.sorted { $0.messages > $1.messages }.prefix(5).map { "\($0.name) (\($0.messages))" }
        if topTeam.isEmpty == false { lines.append(.make("assistant.studio.topTeam", topTeam.joined(separator: ", "))) }
        let topSuppliers = suppliers.sorted { $0.mentions > $1.mentions }.prefix(6).map { "\($0.name) (\($0.mentions))" }
        if topSuppliers.isEmpty == false { lines.append(.make("assistant.studio.topSuppliers", topSuppliers.joined(separator: ", "))) }
        return lines
    }

    func lookup(_ query: String) -> [Hit] {
        let tokens = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 }
        guard tokens.isEmpty == false else { return [] }
        func matches(_ haystack: String) -> Bool {
            let lowered = haystack.lowercased()
            return tokens.contains { lowered.contains($0) }
        }
        var hits: [Hit] = []
        let projectHits = projects
            .filter {
                matches($0.clientDisplay) || matches($0.clientKey) || matches($0.channel) || matches($0.location)
                    || matches($0.issueKeywords.joined(separator: " "))
            }
            .sorted { ($0.issueSignals, $0.messages) > ($1.issueSignals, $1.messages) }
        hits += projectHits.prefix(8).map(Hit.project)
        hits += suppliers.filter { matches($0.name) }.sorted { $0.mentions > $1.mentions }.prefix(5).map(Hit.supplier)
        hits += team.filter { matches($0.name) }.prefix(5).map(Hit.team)
        return hits
    }

    func describe(_ hit: Hit) -> Phrase {
        switch hit {
        case .project(let project):
            var parts: [Phrase] = [.raw("\u{2022} \(project.clientDisplay.isEmpty ? project.clientKey : project.clientDisplay)")]
            if project.phaseLabel.isEmpty == false { parts.append(.raw(" [\(project.phaseLabel)]")) }
            if project.location.isEmpty == false { parts.append(.raw(" \u{00B7} \(project.location)")) }
            if project.issueSignals > 0 {
                let keywords = project.issueKeywords.prefix(4).joined(separator: ", ")
                parts.append(.make("assistant.studio.issues", String(project.issueSignals)))
                if keywords.isEmpty == false { parts.append(.raw(" (\(keywords))")) }
            }
            if let amount = project.maxAmount, amount > 0 { parts.append(.make("assistant.studio.maxAmount", String(Int(amount)))) }
            if project.messages > 0 { parts.append(.make("assistant.studio.messages", String(project.messages))) }
            if project.lastDate.isEmpty == false { parts.append(.make("assistant.studio.last", project.lastDate)) }
            parts.append(.raw(" \u{00B7} #\(project.channel)"))
            return .join(parts, "")
        case .supplier(let supplier):
            return .make("assistant.studio.supplier", supplier.name, String(supplier.mentions))
        case .team(let member):
            return .make("assistant.studio.member", member.name, String(member.messages))
        }
    }
}
