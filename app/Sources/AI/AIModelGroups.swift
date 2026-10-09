import Foundation

/// The models of one family, in the order of the list.
public struct AIModelGroup: Sendable, Equatable {
    /// The family as the platform names it. Nil for the models that the platform gives no family.
    public let line: String?
    public let models: [AIModelInfo]

    public init(line: String?, models: [AIModelInfo]) {
        self.line = line
        self.models = models
    }
}

/// Groups the models of the list by their family, for the choice of a model.
public enum AIModelGroups {
    /// The groups in this order: the known families (haiku, sonnet, opus, fable), then the other families in the
    /// order of their first model, then the models without a family. An empty group is left out.
    public static func grouped(_ models: [AIModelInfo]) -> [AIModelGroup] {
        var lines = ModelLine.allCases.map(\.rawValue)
        for model in models {
            if let line = model.line, !lines.contains(line) {
                lines.append(line)
            }
        }
        let keys: [String?] = lines.map { $0 } + [nil]

        return keys.compactMap { key in
            let members = models.filter { $0.line == key }
            return members.isEmpty ? nil : AIModelGroup(line: key, models: members)
        }
    }
}
