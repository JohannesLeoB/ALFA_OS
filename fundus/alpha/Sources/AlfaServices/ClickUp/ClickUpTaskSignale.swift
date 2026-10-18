import Foundation
import AlfaKit

public enum ClickUpEvidenceGrade: Int, CaseIterable, Sendable, Equatable {
    case stark = 0
    case mittel = 1
    case schwach = 2
    case konflikt = 3

    public var label: String {
        switch self {
        case .stark: return "stark"
        case .mittel: return "mittel"
        case .schwach: return "schwach"
        case .konflikt: return "konflikt"
        }
    }
}

public enum ClickUpBlockerType: Int, CaseIterable, Sendable, Equatable {
    case intern = 0
    case customer = 1
    case lieferant = 2
    case data = 3
    case geld = 4
    case file = 5

    public var label: String {
        switch self {
        case .intern: return "intern"
        case .customer: return "Kunde"
        case .lieferant: return "Lieferant"
        case .data: return "Daten"
        case .geld: return "Geld"
        case .file: return "Datei"
        }
    }
}

public enum ClickUpSourceSystem: Int, CaseIterable, Sendable, Equatable {
    case slack = 0
    case drive = 1
    case airtable = 2
    case mykilos = 3
    case manual = 4

    case fireflies = 5

    public var label: String {
        switch self {
        case .slack: return "Slack"
        case .drive: return "Drive"
        case .airtable: return "Airtable"
        case .mykilos: return "myKilOS"
        case .manual: return "manual"
        case .fireflies: return "fireflies"
        }
    }
}

public struct ClickUpTaskSignale: Sendable, Equatable {
    public let taskID: String
    public let taskName: String
    public let listID: String
    public var evidenceGrade: ClickUpEvidenceGrade?
    public var blockerType: ClickUpBlockerType?
    public var sourceSystem: ClickUpSourceSystem?
    public var financeRelevant: Bool
    public var reviewRequired: Bool
    public var changeOrderRelevant: Bool
    public var driveFolderURL: String?
    public var clientName: String?
    public var mykilosProjectID: String?
    public var projectPhase: ClickUpProjectPhase?

    public init(
        taskID: String, taskName: String, listID: String,
        evidenceGrade: ClickUpEvidenceGrade? = nil, blockerType: ClickUpBlockerType? = nil,
        sourceSystem: ClickUpSourceSystem? = nil, financeRelevant: Bool = false,
        reviewRequired: Bool = false, changeOrderRelevant: Bool = false,
        driveFolderURL: String? = nil, clientName: String? = nil, mykilosProjectID: String? = nil,
        projectPhase: ClickUpProjectPhase? = nil
    ) {
        self.taskID = taskID
        self.taskName = taskName
        self.listID = listID
        self.evidenceGrade = evidenceGrade
        self.blockerType = blockerType
        self.sourceSystem = sourceSystem
        self.financeRelevant = financeRelevant
        self.reviewRequired = reviewRequired
        self.changeOrderRelevant = changeOrderRelevant
        self.driveFolderURL = driveFolderURL
        self.clientName = clientName
        self.mykilosProjectID = mykilosProjectID
        self.projectPhase = projectPhase
    }

    public var hatMindestensEinSignal: Bool {
        evidenceGrade != nil || blockerType != nil || sourceSystem != nil || financeRelevant
            || reviewRequired || changeOrderRelevant || driveFolderURL != nil
            || clientName != nil || mykilosProjectID != nil || projectPhase != nil
    }

    public func aufgeloestesProjekt(in projects: [Project]) -> Project? {
        guard let roh = mykilosProjectID, let gesucht = Projektnummer(parsing: roh) else { return nil }
        return projects.first { project in
            guard let vorhanden = Projektnummer(parsing: project.projectNumber) else { return false }
            return vorhanden == gesucht
        }
    }
}

public enum ClickUpTaskSignaleMapper {
    public static func parse(from data: Data, listID: String) throws -> [ClickUpTaskSignale] {
        let decoded: SignalTasksResponse
        do {
            decoded = try JSONDecoder().decode(SignalTasksResponse.self, from: data)
        } catch {
            throw ClickUpError.decodingFailed
        }
        return decoded.tasks.map { task in
            var signal = ClickUpTaskSignale(taskID: task.id, taskName: task.name, listID: listID)
            for field in task.customFields ?? [] {
                lege(field.value, feldName: field.name, in: &signal)
            }
            return signal
        }
    }

    private static func lege(_ raw: SignalFieldValue, feldName: String, in signal: inout ClickUpTaskSignale) {
        switch feldName {
        case "evidence_grade":
            if case .zahl(let n) = raw { signal.evidenceGrade = ClickUpEvidenceGrade(rawValue: Int(n)) }
        case "blocker_type":
            if case .zahl(let n) = raw { signal.blockerType = ClickUpBlockerType(rawValue: Int(n)) }
        case "source_system":
            if case .zahl(let n) = raw { signal.sourceSystem = ClickUpSourceSystem(rawValue: Int(n)) }
        case "project_phase":
            if case .zahl(let n) = raw { signal.projectPhase = ClickUpProjectPhase(rawValue: Int(n)) }
        case "finance_relevant":
            if case .wahrheitswert(let b) = raw { signal.financeRelevant = b }
        case "review_required":
            if case .wahrheitswert(let b) = raw { signal.reviewRequired = b }
        case "change_order_relevant":
            if case .wahrheitswert(let b) = raw { signal.changeOrderRelevant = b }
        case "drive_folder_url":
            if case .text(let s) = raw, s.isEmpty == false { signal.driveFolderURL = s }
        case "client_name":
            if case .text(let s) = raw, s.isEmpty == false { signal.clientName = s }
        case "mykilos_project_id":
            if case .text(let s) = raw, s.isEmpty == false { signal.mykilosProjectID = s }
        default:
            break
        }
    }
}

private enum SignalFieldValue: Decodable {
    case none
    case zahl(Double)
    case text(String)
    case wahrheitswert(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .none
            return
        }

        if let b = try? container.decode(Bool.self) { self = .wahrheitswert(b); return }
        if let n = try? container.decode(Double.self) { self = .zahl(n); return }
        if let s = try? container.decode(String.self) { self = .text(s); return }
        self = .none
    }
}

private struct SignalTasksResponse: Decodable {
    var tasks: [SignalTaskEntity]
}

private struct SignalTaskEntity: Decodable {
    var id: String
    var name: String
    var customFields: [SignalFieldEntity]?

    enum CodingKeys: String, CodingKey {
        case id, name
        case customFields = "custom_fields"
    }
}

private struct SignalFieldEntity: Decodable {
    var name: String
    var value: SignalFieldValue

    private enum CodingKeys: String, CodingKey { case name, value }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decodeIfPresent(SignalFieldValue.self, forKey: .value) ?? .none
    }
}
