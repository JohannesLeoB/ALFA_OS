import Foundation

public struct AuditEntry: Codable, Identifiable, Sendable {
    public enum Action: String, Codable, Sendable {
        case offerImported, draftCreated, draftSent, projectLinked, noteUpdated, estimateAdjusted, calibrationPromoted, contactCreated, driveFileUploaded,
             warenkorbGesendet,
             mailAktionAusgefuehrt,
             inviteCreated,
             clickUpStatusChanged,
             clickUpTaskCreated,
             clickUpTaskUpdated,
             clickUpTaskAssigned,
             clickUpTaskUnassigned,
             clickUpTaskDeleted,
             clickUpDependencyAdded,
             clickUpDependencyRemoved,
             clickUpCommentAdded,
             clickUpTagAdded,
             clickUpTagRemoved,
             clickUpCustomFieldSet,
             clickUpSubtaskCreated,
             clickUpTaskMoved,
             clickUpGoLiveFreigegeben,
             clickUpGoLiveGesperrt,
             clickUpTeamGoLiveFreigegeben,
             clickUpTeamGoLiveGesperrt,
             sevdeskGhostDraftPrepared,
             projektArchiviert,
             projektReaktiviert,
             airtableFeldAusClickUpUebernommen,
             dhlLabelErstellt,
             dhlSendungZugestellt,
             kalenderTerminAngelegt,
             warenkorbPositionHinzugefuegt
    }
    public let id: UUID
    public let timestamp: Date
    public let actorUserID: String
    public let projectID: String
    public let action: Action
    public let summary: String

    public let source: String?

    public let idempotenzKey: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), actorUserID: String,
                projectID: String, action: Action, summary: String,
                source: String? = nil, idempotenzKey: String? = nil) {
        self.id = id; self.timestamp = timestamp; self.actorUserID = actorUserID
        self.projectID = projectID; self.action = action; self.summary = summary
        self.source = source; self.idempotenzKey = idempotenzKey
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, actorUserID, projectID, action, summary, source, idempotenzKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id           = try container.decode(UUID.self, forKey: .id)
        self.timestamp    = try container.decode(Date.self, forKey: .timestamp)
        self.actorUserID  = try container.decode(String.self, forKey: .actorUserID)
        self.projectID    = try container.decode(String.self, forKey: .projectID)
        self.action       = try container.decode(Action.self, forKey: .action)
        self.summary      = try container.decode(String.self, forKey: .summary)
        self.source        = try container.decodeIfPresent(String.self, forKey: .source) ?? nil
        self.idempotenzKey = try container.decodeIfPresent(String.self, forKey: .idempotenzKey) ?? nil
    }
}
