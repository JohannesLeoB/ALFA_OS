import Foundation
import Observation
import MykilosKit

@MainActor
@Observable
public final class ClickUpTaskActionStore {
    public private(set) var saveState: SaveState = .idle

    private let client: ClickUpTaskWriting
    private let audit: AuditStore

    public init(
        client: ClickUpTaskWriting = ClickUpClient(),
        audit: AuditStore
    ) {
        self.client = client
        self.audit = audit
    }

    public func setStatus(
        taskID: String, listID: String, status: String, projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.setStatus(taskID: taskID, status: status)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpStatusChanged,
                summary: "ClickUp-Status geändert: \(status)", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func updateTask(
        taskID: String, listID: String, name: String?, dueDate: Date?, priority: ClickUpPriority?,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.updateTask(taskID: taskID, name: name, dueDate: dueDate, priority: priority)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpTaskUpdated,
                summary: "ClickUp-Aufgabe aktualisiert: \(name ?? taskID)", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func assignTask(
        taskID: String, listID: String, memberID: String, memberKuerzel: String,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.assign(taskID: taskID, memberID: memberID)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpTaskAssigned,
                summary: "ClickUp-Aufgabe zugewiesen: \(memberKuerzel)", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func unassignTask(
        taskID: String, listID: String, memberID: String, memberKuerzel: String,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.unassign(taskID: taskID, memberID: memberID)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpTaskUnassigned,
                summary: "ClickUp-Zuweisung entfernt: \(memberKuerzel)", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func deleteTask(
        taskID: String, listID: String, taskName: String, projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.deleteTask(taskID: taskID)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpTaskDeleted,
                summary: "ClickUp-Aufgabe gelöscht: \(taskName)", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func addDependency(
        taskID: String, listID: String, otherTaskID: String, direction: ClickUpDependencyDirection,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.addDependency(taskID: taskID, otherTaskID: otherTaskID, direction: direction)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpDependencyAdded,
                summary: "ClickUp-Abhängigkeit gesetzt: \(direction == .waitingOn ? "wartet auf" : "blockiert") \(otherTaskID)",
                source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func removeDependency(
        taskID: String, listID: String, otherTaskID: String, direction: ClickUpDependencyDirection,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.removeDependency(taskID: taskID, otherTaskID: otherTaskID, direction: direction)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpDependencyRemoved,
                summary: "ClickUp-Abhängigkeit entfernt: \(direction == .waitingOn ? "wartet auf" : "blockiert") \(otherTaskID)",
                source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func addComment(
        taskID: String, listID: String, text: String, projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.addComment(taskID: taskID, text: text)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpCommentAdded,
                summary: "ClickUp-Kommentar hinzugefügt an Aufgabe \(taskID)", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func addTag(
        taskID: String, listID: String, tagName: String, projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.addTag(taskID: taskID, tagName: tagName)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpTagAdded,
                summary: "ClickUp-Tag \(tagName) an Aufgabe \(taskID) gehängt", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func removeTag(
        taskID: String, listID: String, tagName: String, projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.removeTag(taskID: taskID, tagName: tagName)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpTagRemoved,
                summary: "ClickUp-Tag \(tagName) von Aufgabe \(taskID) entfernt", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func setCustomFieldValue(
        taskID: String, listID: String, fieldID: String, fieldName: String, value: String,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.setCustomFieldValue(taskID: taskID, fieldID: fieldID, value: value)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpCustomFieldSet,
                summary: "ClickUp-Custom-Field „\(fieldName)“ gesetzt", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func setCustomFieldBoolValue(
        taskID: String, listID: String, fieldID: String, fieldName: String, value: Bool,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.setCustomFieldBoolValue(taskID: taskID, fieldID: fieldID, value: value)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpCustomFieldSet,
                summary: "ClickUp-Custom-Field „\(fieldName)“ gesetzt", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func setCustomFieldDateValue(
        taskID: String, listID: String, fieldID: String, fieldName: String, value: Date,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.setCustomFieldDateValue(taskID: taskID, fieldID: fieldID, value: value)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpCustomFieldSet,
                summary: "ClickUp-Custom-Field „\(fieldName)“ gesetzt", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func setCustomFieldDropdownValue(
        taskID: String, listID: String, fieldID: String, fieldName: String, optionID: String,
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.setCustomFieldDropdownValue(taskID: taskID, fieldID: fieldID, optionID: optionID)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpCustomFieldSet,
                summary: "ClickUp-Custom-Field „\(fieldName)“ gesetzt", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func setCustomFieldLabelsValue(
        taskID: String, listID: String, fieldID: String, fieldName: String, optionIDs: [String],
        projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.setCustomFieldLabelsValue(taskID: taskID, fieldID: fieldID, optionIDs: optionIDs)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpCustomFieldSet,
                summary: "ClickUp-Custom-Field „\(fieldName)“ gesetzt", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    @discardableResult
    public func createSubtask(
        listID: String, parentTaskID: String, name: String, projectID: String, actorUserID: String
    ) async throws -> String {
        saveState = .saving
        do {
            let newID = try await client.createSubtask(listID: listID, parentTaskID: parentTaskID, name: name)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpSubtaskCreated,
                summary: "ClickUp-Subtask angelegt: \(name)", source: "clickup-write"))
            saveState = .saved(Date())
            return newID
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    public func moveTask(
        taskID: String, fromListID: String, toListID: String, projectID: String, actorUserID: String
    ) async throws {
        saveState = .saving
        do {
            try await client.moveTask(taskID: taskID, toListID: toListID)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpTaskMoved,
                summary: "ClickUp-Aufgabe verschoben nach Liste \(toListID)", source: "clickup-write"))
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }

    @discardableResult
    public func createTask(
        listID: String, name: String, projectID: String, actorUserID: String
    ) async throws -> String {
        saveState = .saving
        do {
            let newID = try await client.createTask(listID: listID, name: name, content: nil)
            try audit.append(AuditEntry(
                actorUserID: actorUserID, projectID: projectID, action: .clickUpTaskCreated,
                summary: "ClickUp-Aufgabe angelegt: \(name)", source: "clickup-write"))
            saveState = .saved(Date())
            return newID
        } catch {
            saveState = .failed(error.localizedDescription)
            throw error
        }
    }
}
