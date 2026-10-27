public enum Capability: String, Codable, CaseIterable, Sendable {
    case mail, calendar, contacts, files, tasks, time, documents, assistant, shipping
}

public enum DataKind: String, Codable, CaseIterable, Sendable {
    case mailboxes, messages, calendar, contacts, files, projects, tasks, time, receipts, shipments

    var capability: Capability? {
        switch self {
        case .mailboxes, .messages: .mail
        case .calendar: .calendar
        case .contacts: .contacts
        case .files: .files
        case .projects: nil
        case .tasks: .tasks
        case .time: .time
        case .receipts: .documents
        case .shipments: .shipping
        }
    }
}
