import Design
import Foundation

public struct CommandSlot<Action: Equatable & Sendable>: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case button
        case separator
        case pill
        case more
    }

    public let id: String
    public let action: Action?
    public let kind: Kind
    let priority: Int
    public let cost: Double
    public let off: Bool
    public let signal: Bool
    public let accent: Bool

    public init(id: String, action: Action?, kind: Kind = .button, priority: Int = 0, cost: Double = ShellValues.commandIconCost,
                off: Bool = false, signal: Bool = false, accent: Bool = false) {
        self.id = id
        self.action = action
        self.kind = kind
        self.priority = priority
        self.cost = cost
        self.off = off
        self.signal = signal
        self.accent = accent
    }

    public static var separator: CommandSlot {
        CommandSlot(id: "separator", action: nil, kind: .separator, cost: ShellValues.commandSeparatorCost)
    }

    public static var more: CommandSlot {
        CommandSlot(id: "more", action: nil, kind: .more)
    }
}

public struct CommandPlan<Action: Equatable & Sendable>: Equatable, Sendable {
    public let main: [CommandSlot<Action>]
    public let end: [CommandSlot<Action>]
    public let overflow: [CommandSlot<Action>]
}

public enum CommandBarEngine {
    public static func plan<Action>(main start: [CommandSlot<Action>], tail: [CommandSlot<Action>], fan: [CommandSlot<Action>],
                                    fold: [CommandSlot<Action>], staticMore: Bool, width: Double) -> CommandPlan<Action> {
        let gap = Tokens.Spacing.step4
        func sum(_ slots: [CommandSlot<Action>]) -> Double {
            slots.reduce(0) { $0 + $1.cost } + Double(max(0, slots.count - 1)) * gap
        }
        func end(_ hidden: [CommandSlot<Action>]) -> [CommandSlot<Action>] {
            let more = !hidden.isEmpty || staticMore
            var result = tail
            if more { result.append(.more) }
            if !fan.isEmpty || !fold.isEmpty { result.append(.separator) }
            return result + fan + fold
        }
        var main = start
        var hidden: [CommandSlot<Action>] = []
        var tailEnd = end([])
        func fits() -> Bool {
            sum(main) + (main.isEmpty ? 0 : gap) + sum(tailEnd) + ShellValues.commandSlack <= width
        }
        while !fits(), main.contains(where: { $0.kind == .button }) {
            guard let candidate = main.filter({ $0.kind == .button }).max(by: { $0.priority < $1.priority }) else { break }
            hidden.append(candidate)
            main.removeAll { $0 == candidate }
            main = main.enumerated().filter { index, slot in
                !(slot.kind == .separator && (index == 0 || index == main.count - 1 || main[index - 1].kind == .separator))
            }.map(\.element)
            tailEnd = end(hidden.filter { !$0.off })
        }
        return CommandPlan(main: main, end: tailEnd, overflow: hidden.sorted { $0.priority < $1.priority }.filter { !$0.off })
    }
}

public struct EraseStop: Equatable, Sendable {
    public let opacity: Double
    public let location: Double
}

public struct HoldEngine: Equatable, Sendable {
    let from: Double
    public let forward: Bool
    let start: Date

    public init(from: Double, forward: Bool, start: Date) {
        self.from = from
        self.forward = forward
        self.start = start
    }

    public var length: Double {
        forward ? Tokens.Duration.confirmHold * (1 - from) : Tokens.Duration.confirmRelease * from
    }

    public func fill(at date: Date) -> Double {
        let k = length <= 0 ? 1 : min(1, max(0, date.timeIntervalSince(start) / length))
        return forward ? from + (1 - from) * k : from - from * k
    }

    public static func eraseStops(fill: Double) -> [EraseStop] {
        guard fill > 0 else { return [EraseStop(opacity: 1, location: 0), EraseStop(opacity: 1, location: 1)] }
        let edge = Tokens.Confirm.eraseEdge
        let low = fill * (1 + edge) - edge
        let high = fill * (1 + edge)
        func alpha(_ x: Double) -> Double { min(1, max(0, (x - low) / edge)) }
        let a = min(1, max(0, low))
        let b = min(1, max(0, high))
        return [
            EraseStop(opacity: alpha(0), location: 0),
            EraseStop(opacity: alpha(a), location: a),
            EraseStop(opacity: alpha(b), location: b),
            EraseStop(opacity: alpha(1), location: 1)
        ]
    }

    public static func shake(fill: Double) -> Double {
        let start = Tokens.Confirm.shakeFrom
        guard fill > start else { return 0 }
        return sin(fill * Tokens.Confirm.shakeFrequency) * Tokens.Confirm.shakeAmplitude * (fill - start) / (1 - start)
    }
}
