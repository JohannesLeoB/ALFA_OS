import Foundation
import MykilosKit

public struct ClickUpGanttLayout: Equatable, Sendable {
    public var bars: [ClickUpGanttBar]
    public var edges: [ClickUpGanttEdge]
    public var unscheduled: [ClickUpTask]
    public var rangeStart: Date?
    public var rangeEnd: Date?

    public static let empty = ClickUpGanttLayout(bars: [], edges: [], unscheduled: [], rangeStart: nil, rangeEnd: nil)

    static var kalender: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return cal
    }

    public static func build(tasks: [ClickUpTask], dependencies: [String: ClickUpTaskDependencies]) -> ClickUpGanttLayout {
        let cal = kalender
        var platzierbar: [PlatzierbareAufgabe] = []
        var unscheduled: [ClickUpTask] = []

        for task in tasks {
            switch (task.startDate, task.dueDate) {
            case let (start?, ende?):
                let sod = cal.startOfDay(for: start)
                let eod = cal.startOfDay(for: ende)
                platzierbar.append(PlatzierbareAufgabe(task: task, start: sod, ende: max(sod, eod)))
            case let (start?, nil):
                let sod = cal.startOfDay(for: start)
                platzierbar.append(PlatzierbareAufgabe(task: task, start: sod, ende: sod))
            case let (nil, ende?):
                let eod = cal.startOfDay(for: ende)
                platzierbar.append(PlatzierbareAufgabe(task: task, start: eod, ende: eod))
            case (nil, nil):
                unscheduled.append(task)
            }
        }

        guard platzierbar.isEmpty == false else {
            return ClickUpGanttLayout(bars: [], edges: [], unscheduled: unscheduled, rangeStart: nil, rangeEnd: nil)
        }

        let rangeStart = platzierbar.map(\.start).min()!
        let rangeEnd = platzierbar.map(\.ende).max()!

        let bars = platzierbar
            .sorted { $0.start < $1.start }
            .map { entry -> ClickUpGanttBar in
                let dayOffset = cal.dateComponents([.day], from: rangeStart, to: entry.start).day ?? 0
                let dayLength = (cal.dateComponents([.day], from: entry.start, to: entry.ende).day ?? 0) + 1
                return ClickUpGanttBar(
                    id: entry.task.id, name: entry.task.name, status: entry.task.status,
                    priority: entry.task.priority, dayOffset: dayOffset, dayLength: max(1, dayLength)
                )
            }

        let platzierteIDs = Set(bars.map(\.id))
        let edges = tasks.flatMap { task -> [ClickUpGanttEdge] in
            guard let deps = dependencies[task.id] else { return [] }
            return deps.waitingOn
                .filter { platzierteIDs.contains($0.id) && platzierteIDs.contains(task.id) }
                .map { ClickUpGanttEdge(fromID: $0.id, toID: task.id) }
        }

        return ClickUpGanttLayout(bars: bars, edges: edges, unscheduled: unscheduled, rangeStart: rangeStart, rangeEnd: rangeEnd)
    }

    private struct PlatzierbareAufgabe {
        let task: ClickUpTask
        let start: Date
        let ende: Date
    }
}

public struct ClickUpGanttBar: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var status: String
    public var priority: ClickUpPriority?

    public var dayOffset: Int

    public var dayLength: Int

    public init(id: String, name: String, status: String, priority: ClickUpPriority?, dayOffset: Int, dayLength: Int) {
        self.id = id
        self.name = name
        self.status = status
        self.priority = priority
        self.dayOffset = dayOffset
        self.dayLength = dayLength
    }
}

public struct ClickUpGanttEdge: Identifiable, Equatable, Sendable {
    public var fromID: String
    public var toID: String
    public var id: String { "\(fromID)->\(toID)" }

    public init(fromID: String, toID: String) {
        self.fromID = fromID
        self.toID = toID
    }
}
