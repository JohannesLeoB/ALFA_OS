import Foundation
import Hub

enum Grounding {
    static let volatileMarker = "\n\u{1D}\n"

    struct Input: Sendable {
        var profile: UserProfile?
        var focusedProjectID: String?
        var conversationSummary: String?
        var signals: [Signal]
        var projects: [ProjectEntry]
        var now: Date
        var tools: [any ToolPort]
        var toolsEnabled: Bool
        var chatFilesEnabled: Bool
        var hasDriveFocus: Bool
        var hasTaskListFocus: Bool

        init(profile: UserProfile? = nil, focusedProjectID: String? = nil, conversationSummary: String? = nil,
             signals: [Signal] = [], projects: [ProjectEntry] = [], now: Date = Date(),
             tools: [any ToolPort] = [], toolsEnabled: Bool = false, chatFilesEnabled: Bool = false,
             hasDriveFocus: Bool = false, hasTaskListFocus: Bool = false) {
            self.profile = profile
            self.focusedProjectID = focusedProjectID
            self.conversationSummary = conversationSummary
            self.signals = signals
            self.projects = projects
            self.now = now
            self.tools = tools
            self.toolsEnabled = toolsEnabled
            self.chatFilesEnabled = chatFilesEnabled
            self.hasDriveFocus = hasDriveFocus
            self.hasTaskListFocus = hasTaskListFocus
        }
    }

    static let projectListLimit = 40

    static func systemPrompt(_ input: Input, text: any TextPort) -> String {
        func say(_ key: String, _ arguments: String...) -> String { text.text(key, arguments) }
        var fixed: [String] = []
        var changing: [String] = []

        var intro = say("assistant.prompt.identity")
        if let profile = input.profile, profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            intro += say("assistant.prompt.talkingTo", profile.name)
            if profile.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                intro += say("assistant.prompt.talkingToRole", profile.role)
            }
            intro += say("assistant.prompt.talkingToEnd")
            intro += say("assistant.prompt.actsFor", profile.name)
            intro += say("assistant.prompt.noImpersonation")
        }
        intro += say("assistant.prompt.style")
        fixed.append(intro)
        changing.append(say("assistant.prompt.today", dateString(input.now)))
        fixed.append(say("assistant.prompt.memory"))
        if let summary = input.conversationSummary,
           summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            changing.append("")
            changing.append(say("assistant.prompt.summaryHeader"))
            changing.append(summary)
        }
        if let focused = input.focusedProjectID,
           let project = input.projects.first(where: { $0.projectNumber == focused }) {
            var line = say("assistant.prompt.focus", project.title, project.projectNumber)
            if let phase = project.phase { line += say("assistant.prompt.focusPhase", phase) }
            line += "."
            changing.append(line)
        }
        changing.append("")
        changing.append(say("assistant.prompt.signalsHeader"))
        changing.append(input.signals.isEmpty
            ? say("assistant.prompt.noSignals")
            : input.signals.map { describe($0, text: text) }.joined(separator: "\n"))
        if input.projects.isEmpty == false {
            changing.append("")
            changing.append(say("assistant.prompt.projectsHeader"))
            changing.append(input.projects.prefix(projectListLimit).map { "- \($0.projectNumber): \($0.title)" }
                .joined(separator: "\n"))
        }

        fixed.append("")
        if input.toolsEnabled {
            fixed.append(toolsBlock(input, text: text))
        } else {
            fixed.append(say("assistant.prompt.noTools"))
        }
        let stable = fixed.joined(separator: "\n")
        let volatile = changing.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return volatile.isEmpty ? stable : stable + Grounding.volatileMarker + volatile
    }

    static func toolsBlock(_ input: Input, text: any TextPort) -> String {
        var lines = [
            text.text("assistant.prompt.tools.header", [])
                + text.text(input.chatFilesEnabled ? "assistant.prompt.tools.withFiles" : "assistant.prompt.tools.withoutFiles", []),
        ]
        let available = Set(input.tools.map(\.name))
        for tool in input.tools where tool.documented {
            switch tool.focusNeed {
            case .none: break
            case .driveFolder: if input.hasDriveFocus == false { continue }
            case .taskList: if input.hasTaskListFocus == false { continue }
            }
            for key in tool.promptKeys(available: available) { lines.append(text.text(key, [])) }
        }
        var block = lines.joined(separator: "\n")
        block += "\n" + text.text("assistant.prompt.tools.noMatch", [])
        block += text.text("assistant.prompt.tools.draftRule", [])
        return block
    }

    static func dateString(_ date: Date) -> String {
        ListingEngine.format(date, "EEEE, d. MMMM yyyy")
    }

    static func describe(_ signal: Signal, text: any TextPort) -> String {
        switch signal {
        case .projectFocused(let project):
            text.text("assistant.signal.projectFocused", [project])
        case .driveFileAdded(let project, let name):
            text.text("assistant.signal.driveFileAdded", [project, name])
        case .offerDetected(let project, let label):
            text.text("assistant.signal.offerDetected", [project, label])
        case .drawingDetected(let project, let label):
            text.text("assistant.signal.drawingDetected", [project, label])
        case .reviewSuggested(let project, let label):
            text.text("assistant.signal.reviewSuggested", [project, label])
        case .budgetThresholdCrossed(let project, let ratio):
            text.text("assistant.signal.budgetThresholdCrossed", [project, String(Int(ratio * 100))])
        case .deadlineNear(let project, let days):
            text.text("assistant.signal.deadlineNear", [project, String(days)])
        case .taskDueSoon(let project, let name, let days):
            text.text("assistant.signal.taskDueSoon", [project, name, String(days)])
        }
    }
}

enum ProvenanceEngine {
    enum Field: String, Sendable, Equatable {
        case to, cc, bcc, email, phone

        var textKey: String { "assistant.field." + rawValue }
    }

    enum ValueKind: String, Sendable, Equatable {
        case email
        case phone
    }

    struct UngroundedValue: Sendable, Equatable {
        let kind: ValueKind
        let field: Field
        let value: String
    }

    struct Verdict: Sendable, Equatable {
        var ungrounded: [UngroundedValue] = []

        var isGrounded: Bool { ungrounded.isEmpty }
    }

    struct Evidence: Sendable, Equatable {
        let lowercased: String
        let digitsOnly: String

        init(_ proofs: [String]) {
            let joined = proofs.joined(separator: "\n")
            self.lowercased = joined.lowercased()
            self.digitsOnly = joined.filter { $0.isNumber }
        }
    }

    struct Source: Sendable, Equatable {
        let label: String
        let text: String
    }

    struct Hit: Sendable, Equatable {
        let kind: ValueKind
        let field: Field
        let value: String
        let source: String
    }

    struct Subject {
        let emails: [(Field, String?)]
        let phone: String?
    }

    static func subject(_ draft: MailDraft) -> Subject {
        Subject(emails: [(.to, draft.to), (.cc, draft.cc), (.bcc, draft.bcc)], phone: nil)
    }

    static func subject(_ draft: ContactDraft) -> Subject {
        Subject(emails: [(.email, draft.email)], phone: draft.phone)
    }

    static func subject(_ draft: AirtableContactDraft) -> Subject {
        Subject(emails: [(.email, draft.email)], phone: draft.phone)
    }

    static func check(_ subject: Subject, evidence: Evidence) -> Verdict {
        var open: [UngroundedValue] = []
        for (field, raw) in subject.emails {
            guard let raw else { continue }
            for address in addresses(in: raw) where isEmailProven(address, evidence) == false {
                open.append(UngroundedValue(kind: .email, field: field, value: address))
            }
        }
        if let phone = subject.phone, isPhoneProven(phone, evidence) == false {
            open.append(UngroundedValue(kind: .phone, field: .phone, value: phone))
        }
        return Verdict(ungrounded: open)
    }

    static func provenance(_ subject: Subject, sources: [Source]) -> [Hit] {
        var hits: [Hit] = []
        for (field, raw) in subject.emails {
            guard let raw else { continue }
            for address in addresses(in: raw) {
                if let source = sources.first(where: { isEmailProven(address, Evidence([$0.text])) })?.label {
                    hits.append(Hit(kind: .email, field: field, value: address, source: source))
                }
            }
        }
        if let phone = subject.phone,
           let source = sources.first(where: { isPhoneProven(phone, Evidence([$0.text])) })?.label {
            hits.append(Hit(kind: .phone, field: .phone, value: phone, source: source))
        }
        return hits
    }

    static func provenanceLabel(_ hits: [Hit], text: any TextPort) -> String? {
        guard hits.isEmpty == false else { return nil }
        let parts = hits.map { "\($0.value) \u{2190} \($0.source)" }.joined(separator: ", ")
        return text.text("assistant.gate.proven", [parts])
    }

    static func warnLabel(_ verdict: Verdict, text: any TextPort) -> String {
        let values = verdict.ungrounded
            .map { "\($0.value) (\(text.text($0.field.textKey, [])))" }
            .joined(separator: ", ")
        return text.text("assistant.gate.warn", [values])
    }

    static func modelHint(_ verdict: Verdict, text: any TextPort) -> String {
        let values = verdict.ungrounded
            .map { value in
                text.text("assistant.gate.hintValue", [value.kind.rawValue, value.value, text.text(value.field.textKey, [])])
            }
            .joined(separator: "; ")
        return "\n\n" + text.text("assistant.gate.hint", [values])
    }

    static func isEmailProven(_ email: String, _ evidence: Evidence) -> Bool {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else { return true }
        return evidence.lowercased.contains(normalized)
    }

    static func isPhoneProven(_ phone: String, _ evidence: Evidence) -> Bool {
        let digits = phone.filter { $0.isNumber }
        guard digits.count >= 5 else { return true }
        let needle = String(digits.suffix(min(digits.count, 7)))
        return evidence.digitsOnly.contains(needle)
    }

    static func addresses(in text: String) -> [String] {
        let pattern = "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let area = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: area).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }
}
