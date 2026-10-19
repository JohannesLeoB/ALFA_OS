import Foundation
import ShellCore

public struct CommandSlot: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case button
        case separator
        case pill
    }

    public let id: String
    public let action: MailAction?
    public let kind: Kind
    public let priority: Int
    public let cost: Double
    public let off: Bool
    public let signal: Bool
    public let accent: Bool

    public init(id: String, action: MailAction?, kind: Kind = .button, priority: Int = 0, cost: Double = SheetValues.commandIconCost,
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

    public static let separator = CommandSlot(id: "separator", action: nil, kind: .separator, cost: SheetValues.commandSeparatorCost)
}

public struct CommandPlan: Equatable, Sendable {
    public let main: [CommandSlot]
    public let end: [CommandSlot]
    public let overflow: [CommandSlot]
}

public enum CommandBar {
    public static func plan(main start: [CommandSlot], tail: [CommandSlot], fan: [CommandSlot], fold: [CommandSlot],
                            staticMore: Bool, width: Double) -> CommandPlan {
        let gap = Design.Spacing.step4
        func sum(_ slots: [CommandSlot]) -> Double {
            slots.reduce(0) { $0 + $1.cost } + Double(max(0, slots.count - 1)) * gap
        }
        func end(_ hidden: [CommandSlot]) -> [CommandSlot] {
            let more = !hidden.isEmpty || staticMore
            var result = tail
            if more { result.append(CommandSlot(id: "more", action: .more)) }
            if !fan.isEmpty || !fold.isEmpty { result.append(.separator) }
            return result + fan + fold
        }
        var main = start
        var hidden: [CommandSlot] = []
        var tailEnd = end([])
        func fits() -> Bool {
            sum(main) + (main.isEmpty ? 0 : gap) + sum(tailEnd) + SheetValues.commandSlack <= width
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
