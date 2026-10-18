import Foundation
import AlfaKit

struct LogFrictionTool: AssistantTool {
    let store: AssistantTagebuchStore

    var name: String { "log_friction_point" }
    var description: String {
        "Notiert einen kurzen Friktionspunkt im Assistenten-Tagebuch (append-only, "
        + "kein Code-/Datei-Zugriff) — z. B. eine Datei, die du nicht lesen konntest, "
        + "widersprüchliche Daten, oder eine fehlende Information. NICHT für normale "
        + "Konversation nutzen, nur bei einem echten Hindernis bei der aktuellen Aufgabe."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "art", description: "Eine von: kann_nicht_lesen, widerspruch, fehlende_info, sonstiges"),
         ToolParameter(name: "text", description: "Kurze, konkrete Beschreibung des Friktionspunkts")]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let text = (input["text"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            return ToolRunResult(text: "Kein Text für den Tagebuch-Eintrag angegeben.", isError: true)
        }
        let art = Self.art(from: input["art"])
        let pid = AssistantScope.projectID(from: input)
        do {
            _ = try await store.append(AssistantTagebuchEintrag(projectID: pid, art: art, text: text))
            return ToolRunResult(text: "Im Assistenten-Tagebuch notiert.")
        } catch {
            return ToolRunResult(text: "Tagebuch-Eintrag konnte nicht gespeichert werden: \(error.localizedDescription)", isError: true)
        }
    }

    static func art(from raw: String?) -> AssistantTagebuchEintrag.Art {
        switch raw?.lowercased() {
        case "kann_nicht_lesen", "kannnichtlesen": return .kannNichtLesen
        case "widerspruch": return .widerspruch
        case "fehlende_info", "fehlendeinfo": return .fehlendeInfo
        default: return .sonstiges
        }
    }
}
