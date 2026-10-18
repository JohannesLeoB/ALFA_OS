import Foundation

public struct ClickUpRoutingZeile: Codable, Hashable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case routingID, ebene, richtung, appObjekt, clickUpObjekt, trigger, userScope, frequenz, noGo, clickUpRef, isActive = "aktiv", optin }

    public var id: String { routingID }
    public let routingID: String
    public let ebene: String
    public let richtung: String
    public let appObjekt: String
    public let clickUpObjekt: String
    public let trigger: String
    public let userScope: String
    public let frequenz: String
    public let noGo: String?

    public var clickUpRef: String?
    public var isActive: Bool
    public var optin: Bool

    public init(routingID: String, ebene: String, richtung: String, appObjekt: String,
                clickUpObjekt: String, trigger: String, userScope: String, frequenz: String,
                noGo: String? = nil, clickUpRef: String? = nil, isActive: Bool = false, optin: Bool = false) {
        self.routingID = routingID; self.ebene = ebene; self.richtung = richtung
        self.appObjekt = appObjekt; self.clickUpObjekt = clickUpObjekt; self.trigger = trigger
        self.userScope = userScope; self.frequenz = frequenz; self.noGo = noGo
        self.clickUpRef = clickUpRef; self.isActive = isActive; self.optin = optin
    }

    public static let defaults: [ClickUpRoutingZeile] = [
        ClickUpRoutingZeile(routingID: "CU_GLOBAL_SPACES", ebene: "global", richtung: "app→clickup", appObjekt: "Projektliste", clickUpObjekt: "Space/Folder-Baum", trigger: "Provisioning (live)", userScope: "Admin", frequenz: "einmalig"),
        ClickUpRoutingZeile(routingID: "CU_PROJ_LIST", ebene: "projekt", richtung: "app→clickup", appObjekt: "neues Projekt", clickUpObjekt: "List in Projekt-Folder", trigger: "Projekt-Anlage", userScope: "Ersteller", frequenz: "je Projekt", noGo: "nur eigenes Projekt"),
        ClickUpRoutingZeile(routingID: "CU_PROJ_TASKS", ebene: "projekt", richtung: "beide", appObjekt: "Aufgaben/Subtasks", clickUpObjekt: "Task/Subtask", trigger: "Status-/Phasenwechsel", userScope: "Projektteam", frequenz: "on-change"),
        ClickUpRoutingZeile(routingID: "CU_ROUTINE_CHECK", ebene: "projekt", richtung: "app→clickup", appObjekt: "Routine", clickUpObjekt: "Checkliste an Task", trigger: "Phasen-Eintritt", userScope: "System", frequenz: "je Phase"),
        ClickUpRoutingZeile(routingID: "CU_USER_INBOX", ebene: "user", richtung: "clickup→app", appObjekt: "Zugewiesene Tasks", clickUpObjekt: "Task (assignee)", trigger: "Polling/Webhook", userScope: "je User (eigene)", frequenz: "periodisch", noGo: "nie fremde Tasks zeigen"),
        ClickUpRoutingZeile(routingID: "CU_USER_TIME", ebene: "user", richtung: "app→clickup", appObjekt: "Zeit-Notiz (opt.)", clickUpObjekt: "Time/Comment", trigger: "Buchung (opt.)", userScope: "je User", frequenz: "on-confirm", noGo: "nur eigene")
    ]
}
