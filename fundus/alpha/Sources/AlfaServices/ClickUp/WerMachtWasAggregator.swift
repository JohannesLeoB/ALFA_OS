import Foundation

public struct ClickUpStatusGruppe: Equatable, Sendable {
    public let status: String
    public let count: Int
    public init(status: String, count: Int) {
        self.status = status
        self.count = count
    }
}

public struct ClickUpPersonBilanz: Equatable, Sendable, Identifiable {
    public let memberID: String?

    public let name: String?
    public let offen: Int
    public let erledigt: Int

    public let offeneStatusGruppen: [ClickUpStatusGruppe]

    public var id: String { memberID ?? "__nicht_zugewiesen__" }
    public var total: Int { offen + erledigt }

    public var prozentErledigt: Int {
        total == 0 ? 0 : Int((Double(erledigt) / Double(total) * 100).rounded())
    }

    public init(memberID: String?, name: String?, offen: Int, erledigt: Int,
                offeneStatusGruppen: [ClickUpStatusGruppe]) {
        self.memberID = memberID
        self.name = name
        self.offen = offen
        self.erledigt = erledigt
        self.offeneStatusGruppen = offeneStatusGruppen
    }
}

public enum WerMachtWasAggregator {
    public static func bilanz(_ tasks: [ClickUpTask]) -> [ClickUpPersonBilanz] {
        struct Konto {
            var name: String?
            var offen = 0
            var erledigt = 0
            var offeneStatus: [String: Int] = [:]
        }
        var konten: [String?: Konto] = [:]

        for task in tasks {
            let targets: [String?] = task.assigneeIDs.isEmpty ? [nil] : task.assigneeIDs.map { Optional($0) }
            for target in targets {
                var konto = konten[target] ?? Konto()
                if let target, konto.name == nil {
                    let n = task.assigneeNamen[target]
                    konto.name = (n?.isEmpty == false) ? n : nil
                }
                if task.istErledigt {
                    konto.erledigt += 1
                } else {
                    konto.offen += 1
                    let key = task.status.isEmpty ? "Ohne Status" : task.status
                    konto.offeneStatus[key, default: 0] += 1
                }
                konten[target] = konto
            }
        }

        let bilanzen = konten.map { (memberID, konto) -> ClickUpPersonBilanz in
            let groups = konto.offeneStatus
                .map { ClickUpStatusGruppe(status: $0.key, count: $0.value) }
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.status < $1.status }
            return ClickUpPersonBilanz(
                memberID: memberID, name: konto.name,
                offen: konto.offen, erledigt: konto.erledigt, offeneStatusGruppen: groups)
        }

        return bilanzen.sorted { a, b in

            switch (a.memberID, b.memberID) {
            case (nil, nil): return false
            case (nil, _): return false
            case (_, nil): return true
            default: break
            }
            if a.total != b.total { return a.total > b.total }
            return (a.name ?? a.memberID ?? "") < (b.name ?? b.memberID ?? "")
        }
    }
}
