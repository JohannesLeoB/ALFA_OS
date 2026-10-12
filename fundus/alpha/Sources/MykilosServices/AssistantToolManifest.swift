import Foundation

public enum AssistantToolManifest {
    public static let toolToManifestID: [String: String] = [
        "search_gmail": "GMAIL_SEARCH",
        "read_email": "GMAIL_SEARCH",
        "create_draft": "GMAIL_DRAFT_CREATE",
        "list_calendar_events": "CALENDAR_LIST",
        "suggest_calendar_event": "CALENDAR_SUGGEST",
        "list_drive_folder": "DRIVE_ASSISTANT_LIST",
        "find_offers": "DRIVE_OFFERS_FIND",
        "read_drive_file": "DRIVE_FILE_READ",
        "search_contacts": "CONTACTS_QUERY",
        "create_contact": "CONTACTS_CREATE",
        "list_clickup_tasks": "CLICKUP_TASKS",
        "list_all_clickup_tasks": "CLICKUP_TASKS",
        "propose_clickup_change": "CLICKUP_TASKS",
        "search_katalog": "AIRTABLE_ARTIKELKATALOG",
        "query_studio_knowledge": "STUDIO_KNOWLEDGE_QUERY",
        "lookup_kunde": "AIRTABLE_KUNDEN_LOOKUP",
        "lookup_kontakt": "AIRTABLE_KONTAKTE_LOOKUP",
        "list_airtable_kontakte": "AIRTABLE_KONTAKTE_LOOKUP",
        "search_airtable_kontakt": "AIRTABLE_KONTAKTE_LOOKUP",
        "create_airtable_kontakt": "AIRTABLE_KONTAKTE_CREATE",
        "update_airtable_kontakt": "AIRTABLE_KONTAKTE_UPDATE",
        "create_note": "ASSISTANT_NOTES",
        "list_notes": "ASSISTANT_NOTES",
        "update_note": "ASSISTANT_NOTES",
        "delete_note": "ASSISTANT_NOTES",
        "create_task": "ASSISTANT_TASKS",
        "list_tasks": "ASSISTANT_TASKS",
        "complete_task": "ASSISTANT_TASKS",
        "delete_task": "ASSISTANT_TASKS",
        "schaetze_projekt": "KALKULATION_LOCAL"
    ]

    public static let umbrellaID = "ASSISTANT_TOOL_CALL"

    public static func manifestID(forTool toolName: String) -> String {
        toolToManifestID[toolName] ?? umbrellaID
    }
}
