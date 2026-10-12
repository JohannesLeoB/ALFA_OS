import Foundation
import MykilosKit

private final class BundleFinder {}

public struct StudioBrain: Sendable {
    public struct Project: Sendable {
        public let channel: String
        public let phaseLabel: String
        public let clientDisplay: String
        public let clientKey: String
        public let location: String
        public let messages: Int
        public let maxAmountEur: Double?
        public let priceMentions: Int
        public let issueSignals: Int
        public let issueKeywords: [String]
        public let daysSinceLast: Int
        public let lastDate: String
    }
    public struct Supplier: Sendable { public let name: String; public let mentions: Int }
    public struct TeamMember: Sendable { public let name: String; public let messages: Int }

    public let generated: String
    public let totals: [String: Int]
    public let projects: [Project]
    public let suppliers: [Supplier]
    public let team: [TeamMember]

    public static let shared: StudioBrain? = {
        guard let url = sichereRessourcenURL(name: "studio_brain", ext: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return StudioBrain(data: data)
    }()

    static func sichereRessourcenURL(name: String, ext: String) -> URL? {
        let fileName = "\(name).\(ext)"
        let bundleName = "\(AppKennung.name)_MykilosServices.bundle"
        let fm = FileManager.default

        let basen: [URL] = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle(for: BundleFinder.self).bundleURL,
            Bundle(for: BundleFinder.self).bundleURL.deletingLastPathComponent()
        ].compactMap { $0 }
        for base in basen {
            let imBundle = base.appendingPathComponent(bundleName).appendingPathComponent(fileName)
            if fm.fileExists(atPath: imBundle.path) { return imBundle }

            let direkt = base.appendingPathComponent(fileName)
            if fm.fileExists(atPath: direkt.path) { return direkt }
        }
        return nil
    }

    public init?(data: Data) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        let meta = root["_meta"] as? [String: Any]
        self.generated = (meta?["generated"] as? String) ?? "unbekannt"
        self.totals = (meta?["totals"] as? [String: Any])?.compactMapValues { ($0 as? NSNumber)?.intValue } ?? [:]

        self.projects = (root["projects"] as? [[String: Any]] ?? []).map { p in
            Project(
                channel: p["channel"] as? String ?? "",
                phaseLabel: p["phase_label"] as? String ?? "",
                clientDisplay: p["client_display"] as? String ?? "",
                clientKey: p["client_key"] as? String ?? "",
                location: p["location"] as? String ?? "",
                messages: (p["messages"] as? NSNumber)?.intValue ?? 0,
                maxAmountEur: (p["max_amount_eur"] as? NSNumber)?.doubleValue,
                priceMentions: (p["price_mentions"] as? NSNumber)?.intValue ?? 0,
                issueSignals: (p["issue_signals"] as? NSNumber)?.intValue ?? 0,
                issueKeywords: p["issue_keywords"] as? [String] ?? [],
                daysSinceLast: (p["days_since_last"] as? NSNumber)?.intValue ?? 0,
                lastDate: p["last"] as? String ?? ""
            )
        }
        self.suppliers = (root["suppliers"] as? [[String: Any]] ?? []).map {
            Supplier(name: $0["name"] as? String ?? "", mentions: ($0["mentions"] as? NSNumber)?.intValue ?? 0)
        }
        self.team = (root["team"] as? [[String: Any]] ?? []).map {
            TeamMember(name: $0["name"] as? String ?? "", messages: ($0["messages"] as? NSNumber)?.intValue ?? 0)
        }
    }

    public enum Hit: Sendable { case project(Project); case supplier(Supplier); case team(TeamMember) }

    public var overview: String {
        var out = ["Studio-Wissensbasis (Stand \(generated)):"]
        if totals.isEmpty == false {
            let order = ["channels", "messages", "project_channels", "offer_channels", "price_observations", "issue_signals"]
            let parts = order.compactMap { k in totals[k].map { "\(label(for: k)): \($0)" } }
            if parts.isEmpty == false { out.append(parts.joined(separator: " · ")) }
        }
        let topTeam = team.sorted { $0.messages > $1.messages }.prefix(5).map { "\($0.name) (\($0.messages))" }
        if topTeam.isEmpty == false { out.append("Aktivste Köpfe: " + topTeam.joined(separator: ", ")) }
        let topSup = suppliers.sorted { $0.mentions > $1.mentions }.prefix(6).map { "\($0.name) (\($0.mentions))" }
        if topSup.isEmpty == false { out.append("Top-Lieferanten: " + topSup.joined(separator: ", ")) }
        return out.joined(separator: "\n")
    }

    public func lookup(_ query: String) -> [Hit] {
        let tokens = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count >= 2 }
        guard tokens.isEmpty == false else { return [] }
        func matches(_ haystack: String) -> Bool {
            let h = haystack.lowercased()
            return tokens.contains { h.contains($0) }
        }
        var hits: [Hit] = []
        let projHits = projects
            .filter { matches($0.clientDisplay) || matches($0.clientKey) || matches($0.channel) || matches($0.location) || matches($0.issueKeywords.joined(separator: " ")) }
            .sorted { ($0.issueSignals, $0.messages) > ($1.issueSignals, $1.messages) }
        hits += projHits.prefix(8).map(Hit.project)
        hits += suppliers.filter { matches($0.name) }.sorted { $0.mentions > $1.mentions }.prefix(5).map(Hit.supplier)
        hits += team.filter { matches($0.name) }.prefix(5).map(Hit.team)
        return hits
    }

    public func describe(_ hit: Hit) -> String {
        switch hit {
        case .project(let p):
            var parts = ["• \(p.clientDisplay.isEmpty ? p.clientKey : p.clientDisplay)"]
            if p.phaseLabel.isEmpty == false { parts.append("[\(p.phaseLabel)]") }
            if p.location.isEmpty == false { parts.append("· \(p.location)") }
            if p.issueSignals > 0 {
                let kw = p.issueKeywords.prefix(4).joined(separator: ", ")
                parts.append("· \(p.issueSignals) Problem-Signale\(kw.isEmpty ? "" : " (\(kw))")")
            }
            if let amt = p.maxAmountEur, amt > 0 { parts.append("· max € \(Int(amt))") }
            if p.messages > 0 { parts.append("· \(p.messages) Nachrichten") }
            if p.lastDate.isEmpty == false { parts.append("· zuletzt \(p.lastDate)") }
            parts.append("· #\(p.channel)")
            return parts.joined(separator: " ")
        case .supplier(let s):
            return "• Lieferant \(s.name): \(s.mentions) Erwähnungen in Projekt-Channels"
        case .team(let t):
            return "• Team: \(t.name) — \(t.messages) Nachrichten"
        }
    }

    private func label(for key: String) -> String {
        switch key {
        case "channels": "Channels"
        case "messages": "Nachrichten"
        case "project_channels": "Projekt-Channels"
        case "offer_channels": "Angebots-Channels"
        case "price_observations": "Preis-Beobachtungen"
        case "issue_signals": "Problem-Signale"
        default: key
        }
    }
}
