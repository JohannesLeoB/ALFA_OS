import Foundation
import MykilosKit

public struct ToolParameter: Sendable, Equatable {
    public let name: String
    public let type: String
    public let description: String
    public let required: Bool
    public init(name: String, type: String = "string", description: String, required: Bool = true) {
        self.name = name; self.type = type; self.description = description; self.required = required
    }
}

public struct ToolRunResult: Sendable, Equatable {
    public let text: String
    public let isError: Bool

    public let actionURL: String?

    public let schaetzung: KostenSchaetzung?

    public let contactDraft: ContactDraft?

    public let emailDraft: EmailDraft?

    public let driveFiles: [DriveFileRef]

    public let airtableContactDraft: AirtableContactDraft?

    public let clickUpDraft: ClickUpChangeDraft?

    public let terminDraft: TerminDraft?

    public let warenkorbDraft: WarenkorbDraft?

    public let dateiDraft: DateiDraft?
    public init(text: String, isError: Bool = false, actionURL: String? = nil,
                schaetzung: KostenSchaetzung? = nil, contactDraft: ContactDraft? = nil,
                emailDraft: EmailDraft? = nil, driveFiles: [DriveFileRef] = [],
                airtableContactDraft: AirtableContactDraft? = nil,
                clickUpDraft: ClickUpChangeDraft? = nil,
                terminDraft: TerminDraft? = nil,
                warenkorbDraft: WarenkorbDraft? = nil,
                dateiDraft: DateiDraft? = nil) {
        self.text = text; self.isError = isError; self.actionURL = actionURL
        self.schaetzung = schaetzung; self.contactDraft = contactDraft
        self.emailDraft = emailDraft; self.driveFiles = driveFiles
        self.airtableContactDraft = airtableContactDraft
        self.clickUpDraft = clickUpDraft
        self.terminDraft = terminDraft
        self.warenkorbDraft = warenkorbDraft
        self.dateiDraft = dateiDraft
    }
}

public protocol AssistantTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [ToolParameter] { get }
    func run(input: [String: String]) async -> ToolRunResult
}

public struct ClaudeToolDefinition: Encodable, Equatable {
    public let name: String
    public let description: String
    public let inputSchema: InputSchema

    public var cacheControl: ClaudeCacheControl?

    public init(name: String, description: String, inputSchema: InputSchema, cacheControl: ClaudeCacheControl? = nil) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.cacheControl = cacheControl
    }

    enum CodingKeys: String, CodingKey { case name, description, inputSchema = "input_schema", cacheControl = "cache_control" }

    public struct InputSchema: Encodable, Equatable {
        public let type = "object"
        public var properties: [String: Property]
        public var required: [String]
        enum CodingKeys: String, CodingKey { case type, properties, required }
    }
    public struct Property: Encodable, Equatable {
        public let type: String
        public let description: String
    }
}

extension AssistantTool {
    func wireDefinition() -> ClaudeToolDefinition {
        var properties: [String: ClaudeToolDefinition.Property] = [:]
        var required: [String] = []
        for p in parameters {
            properties[p.name] = .init(type: p.type, description: p.description)
            if p.required { required.append(p.name) }
        }
        return ClaudeToolDefinition(
            name: name, description: description,
            inputSchema: .init(properties: properties, required: required)
        )
    }
}

private let toolDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_DE")
    f.timeZone = TimeZone(identifier: "Europe/Berlin")
    f.dateFormat = "EEE d. MMM yyyy, HH:mm"
    return f
}()

public struct SearchGmailTool: AssistantTool {
    private let client: GoogleGmailFetching
    private let cache: GmailCacheStore?
    public init(client: GoogleGmailFetching = GmailAccess.client(), cache: GmailCacheStore? = nil) {
        self.client = client
        self.cache = cache
    }

    public let name = "search_gmail"

    public let description =
        "Durchsucht die E-Mails des Nutzers (nur lesen). Verwende Gmail-Suchsyntax im query, "
        + "z. B. 'from:name', 'to:name subject:Angebot', 'newer_than:30d', 'after:YYYY/MM/DD'. "
        + "WICHTIG bei Alternativen: 'OR' IMMER großgeschrieben und bei gemischten Bedingungen "
        + "klammern, z. B. 'from:(häfele OR haefele OR hafele) (Angebot OR Besteckeinsatz)' — "
        + "NIEMALS unklammertes 'from:x OR y freitext OR z' (wird falsch geparst). Bei Namen "
        + "mit Umlaut/Schreibvarianten zuerst eine EINFACHE Suche ohne OR probieren (z. B. nur "
        + "'from:häfele'), bevor komplexere OR-Ketten versucht werden. "
        + "Gibt Treffer mit Betreff, Absender und Datum zurück. Für einen Rückblick über mehr "
        + "Mails 'anzahl' erhöhen (Standard 25, max 100)."
    public var parameters: [ToolParameter] {
        [ToolParameter(name: "query", description: "Gmail-Suchabfrage (Gmail-Operatoren erlaubt)"),
         ToolParameter(name: "anzahl", description: "Max. Trefferzahl (Standard 25, max 100)", required: false)]
    }

    static func resultLimit(from input: [String: String]) -> Int {
        guard let raw = input["anzahl"], let n = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return 25 }
        return max(1, min(n, 100))
    }

    public func run(input: [String: String]) async -> ToolRunResult {
        let query = (input["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return ToolRunResult(text: "Leere Suchabfrage.", isError: true) }
        let limit = Self.resultLimit(from: input)
        do {
            let messages: [GoogleGmailMessage]

            if let hit = await cache?.cached(for: query), hit.count >= limit {
                messages = Array(hit.prefix(limit))
            } else {
                let fresh = try await client.searchMessages(query: query, maxResults: limit)
                await cache?.store(fresh, for: query)
                messages = fresh
            }
            guard messages.isEmpty == false else {
                return ToolRunResult(text: "Keine Mails für „\(query)“ gefunden.")
            }
            let lines = messages.map { m -> String in
                let date = m.receivedAt.map { toolDateFormatter.string(from: $0) } ?? "ohne Datum"
                let place = Self.placement(from: m.labels)
                var line = "• \(m.subject) — von \(m.from) (\(date))\(place.isEmpty ? "" : " · Ablage: \(place)")"
                if m.attachments.isEmpty == false {
                    line += " · Anhänge: \(m.attachments.map(\.filename).joined(separator: ", "))"
                }
                line += "\n  \(m.snippet)"
                return line
            }
            return ToolRunResult(text: lines.joined(separator: "\n"))
        } catch GoogleGmailError.notConnected {
            return ToolRunResult(text: "Gmail ist nicht verbunden. Bitte Google in den Einstellungen verbinden.", isError: true)
        } catch {
            return ToolRunResult(text: "Gmail-Suche fehlgeschlagen: \(error)", isError: true)
        }
    }

    static func placement(from labels: [String]) -> String {
        let hidden: Set<String> = ["UNREAD", "STARRED", "IMPORTANT"]
        let names = labels.filter { hidden.contains($0) == false }.map(humanLabel(_:))
        return names.joined(separator: ", ")
    }

    static func humanLabel(_ id: String) -> String {
        switch id {
        case "INBOX":  "Posteingang"
        case "SENT":   "Gesendet"
        case "DRAFT":  "Entwürfe"
        case "SPAM":   "Spam"
        case "TRASH":  "Papierkorb"
        case let c where c.hasPrefix("CATEGORY_"): "Kategorie " + c.dropFirst("CATEGORY_".count).capitalized
        default: id
        }
    }
}

public struct ListCalendarTool: AssistantTool {
    private let client: GoogleCalendarFetching
    private let team: (any GoogleCalendarTeamFetching)?

    public init(client: GoogleCalendarFetching = GoogleCalendarClient(),
                team: (any GoogleCalendarTeamFetching)? = nil) {
        self.client = client
        self.team = team
    }

    public let name = "list_calendar_events"
    public let description =
        "Listet anstehende Kalendertermine des Nutzers (nur lesen) — der eigene Kalender UND "
        + "alle abonnierten Team-Kalender. Optionaler 'query'-Filter (Freitext über Titel/Ort), "
        + "'within_days' begrenzt den Zeitraum (Standard 14)."
    public var parameters: [ToolParameter] {
        [
            ToolParameter(name: "query", description: "Optionaler Freitext-Filter", required: false),
            ToolParameter(name: "within_days", type: "integer", description: "Zeitraum in Tagen (Standard 14)", required: false)
        ]
    }

    static let maxKalender = 12

    static let nurEigenerHinweis =
        "WICHTIG: Es konnte NUR der eigene Kalender gelesen werden — die Team-Kalender nicht "
        + "(die Kalenderlisten-Freigabe fehlt; in den Einstellungen erneut mit Google verbinden). "
        + "Sage das dem Nutzer dazu. Behaupte NICHT, es gebe keine weiteren Termine."

    static func emptyText(tage: Int, nurEigener: Bool) -> String {
        let basis = "Keine anstehenden Termine in den nächsten \(tage) Tagen gefunden."
        return nurEigener ? basis + "\n\n" + nurEigenerHinweis : basis
    }

    static func rowItem(_ e: GoogleCalendarEvent) -> String {
        let when = e.startsAt.map { e.isAllDay ? "ganztägig" : toolDateFormatter.string(from: $0) } ?? "ohne Datum"
        let place = e.location.map { " @ \($0)" } ?? ""
        let kalender = e.calendarTitle.isEmpty ? "" : " [\(e.calendarTitle)]"
        return "• \(e.title) — \(when)\(place)\(kalender)"
    }

    public func run(input: [String: String]) async -> ToolRunResult {
        let roh = input["query"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = (roh?.isEmpty == false) ? roh : nil
        let days = input["within_days"].flatMap { Int($0) } ?? 14

        var teamWegFehlgeschlagen = false
        if let team {
            do {
                return result(try await Self.ueberAlleKalender(team: team, query: query, tage: days),
                                tage: days, nurEigener: false)
            } catch GoogleCalendarError.notConnected {
                return nichtVerbunden
            } catch {
                teamWegFehlgeschlagen = true
            }
        }

        do {
            let events = try await client.listUpcomingEvents(query: query, withinDays: days)
            return result(events, tage: days, nurEigener: teamWegFehlgeschlagen)
        } catch GoogleCalendarError.notConnected {
            return nichtVerbunden
        } catch {
            return ToolRunResult(text: "Kalender-Abruf fehlgeschlagen: \(error)", isError: true)
        }
    }

    private var nichtVerbunden: ToolRunResult {
        ToolRunResult(text: "Kalender ist nicht verbunden. Bitte Google in den Einstellungen verbinden.",
                      isError: true)
    }

    private func result(_ events: [GoogleCalendarEvent], tage: Int, nurEigener: Bool) -> ToolRunResult {
        guard events.isEmpty == false else {
            return ToolRunResult(text: Self.emptyText(tage: tage, nurEigener: nurEigener))
        }
        var text = events.map(Self.rowItem).joined(separator: "\n")
        if nurEigener { text += "\n\n" + Self.nurEigenerHinweis }
        return ToolRunResult(text: text)
    }

    private static func ueberAlleKalender(team: any GoogleCalendarTeamFetching,
                                          query: String?, tage: Int) async throws -> [GoogleCalendarEvent] {
        let kalender = try await team.listCalendars()
        var proKalender: [[GoogleCalendarEvent]] = []
        try await withThrowingTaskGroup(of: [GoogleCalendarEvent].self) { group in
            for k in kalender.prefix(maxKalender) {
                let title = k.summary
                group.addTask {
                    let roh = (try? await team.listUpcomingEvents(calendarID: k.id, query: query,
                                                                  withinDays: tage)) ?? []
                    return roh.map { var e = $0; e.calendarTitle = title; return e }
                }
            }
            for try await teil in group { proKalender.append(teil) }
        }
        return GoogleCalendarClient.mergeAndSort(proKalender)
    }
}

public struct SuggestCalendarEventTool: AssistantTool {
    public init() {}

    public let name = "suggest_calendar_event"
    public let description =
        "Erstellt einen Google-Kalender-Link, den der Nutzer öffnen kann, um einen Termin "
        + "direkt im Browser anzulegen. Keine API-Verbindung nötig — reine Link-Generierung. "
        + "Verwende dieses Tool, wenn der Nutzer explizit einen Termin anlegen möchte oder du "
        + "eine klare Terminempfehlung hast."
    public var parameters: [ToolParameter] {
        [
            ToolParameter(name: "title", description: "Titel des Termins (Pflicht)"),
            ToolParameter(name: "date",
                          description: "Datum im Format YYYYMMDD oder YYYYMMDDTHHmmss (optional)",
                          required: false),
            ToolParameter(name: "notes",
                          description: "Optionale Beschreibung oder Notizen",
                          required: false)
        ]
    }

    public func run(input: [String: String]) async -> ToolRunResult {
        let title = (input["title"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            return ToolRunResult(text: "Kein Titel angegeben.", isError: true)
        }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "action", value: "TEMPLATE"),
            URLQueryItem(name: "text", value: title)
        ]
        if let raw = input["date"], let dates = Self.googleDates(from: raw) {
            items.append(URLQueryItem(name: "dates", value: dates))
        }
        if let notes = input["notes"], notes.isEmpty == false {
            items.append(URLQueryItem(name: "details", value: notes))
        }
        var comps = URLComponents(string: "https://calendar.google.com/calendar/render")!
        comps.queryItems = items
        let url = comps.url?.absoluteString ?? "https://calendar.google.com/calendar/render?action=TEMPLATE"

        return ToolRunResult(
            text: "Kalender-Termin vorbereitet: \(title). Die Aktionskarte zum Öffnen erscheint "
                + "automatisch unter deiner Antwort — verweise darauf und schreibe KEINEN eigenen Link.",
            actionURL: url
        )
    }

    static func googleDates(from raw: String) -> String? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "T")

        let digitsOnly = cleaned.replacingOccurrences(of: "T", with: "")
        guard digitsOnly.allSatisfy(\.isNumber), digitsOnly.count >= 8 else { return nil }
        let datePart = String(digitsOnly.prefix(8))
        if digitsOnly.count >= 12 {
            var time = String(digitsOnly.dropFirst(8).prefix(6))
            while time.count < 6 { time += "0" }
            let start = "\(datePart)T\(time)"
            return "\(start)/\(start)"
        }
        return "\(datePart)/\(datePart)"
    }
}

public struct KostenSchaetzungTool: AssistantTool {
    private let engine: any KalkulationsEngineProviding
    public init(engine: any KalkulationsEngineProviding) { self.engine = engine }

    public let name = "schaetze_projekt"
    public let description =
        "Erstellt eine Kostenschätzung für ein Innenausbau-Projekt (Küche/Beleuchtung/Ausbau) "
        + "auf Basis einer Freitext-Beschreibung. Gibt Min/Mitte/Max-Netto und Konfidenz zurück. "
        + "Funktioniert auch ohne offenes Projekt (allgemeiner Assistent/Mail) — im Projekt-Chat "
        + "wird die Schätzung zusätzlich diesem Projekt zugeordnet."
    public var parameters: [ToolParameter] {
        [
            ToolParameter(name: "beschreibung",
                          description: "Freitext-Beschreibung (Raum, Materialien, Größe, Besonderheiten)"),
            ToolParameter(name: "korpusanzahl", type: "integer",
                          description: "Anzahl Korpusse, falls bekannt. Grober Anhalt: ein Laufmeter Küche ≈ 1,7 Korpusse. Stärkster Hebel auf die Spanne.",
                          required: false),
            ToolParameter(name: "fronten",
                          description: "Ausführung der Fronten: melamin, linoleum, furnier, lack, glas, massivholz oder edelstahl.",
                          required: false),
            ToolParameter(name: "schubkaesten_legrabox", type: "integer",
                          description: "Anzahl Schubkästen mit Serienauszug (Blum Legrabox o. ä.).",
                          required: false),
            ToolParameter(name: "schubkaesten_holz", type: "integer",
                          description: "Anzahl Schubkästen in Massivholz.",
                          required: false),
            ToolParameter(name: "werkstatt",
                          description: "Ausführende Werkstatt, falls bekannt.",
                          required: false),
            ToolParameter(name: "entfernung_km", type: "number",
                          description: "Entfernung zur Baustelle in Kilometern, für die Anfahrt.",
                          required: false)
        ]
    }

    public func run(input: [String: String]) async -> ToolRunResult {
        let beschreibung = (input["beschreibung"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let projektID = AssistantScope.projectID(from: input)

        guard beschreibung.isEmpty == false else {
            return ToolRunResult(text: "Keine Beschreibung angegeben.", isError: true)
        }
        func intValue(_ key: String) -> Int? {
            guard let raw = input[key]?.trimmingCharacters(in: .whitespaces), raw.isEmpty == false else { return nil }
            return Int(raw)
        }
        func stringValue(_ key: String) -> String? {
            guard let raw = input[key]?.trimmingCharacters(in: .whitespaces), raw.isEmpty == false else { return nil }
            return raw
        }
        let override = EstimateOverride(
            korpusCount: intValue("korpusanzahl"),
            frontExecution: stringValue("fronten"),
            drawersLegrabox: intValue("schubkaesten_legrabox"),
            drawersHolz: intValue("schubkaesten_holz"),
            workshop: stringValue("werkstatt"),
            distanceKm: stringValue("entfernung_km").flatMap(Double.init))
        do {
            let s = try await engine.schaetze(projektID: projektID, freitext: beschreibung, override: override)
            return ToolRunResult(text: Self.formatSummary(s), schaetzung: s)
        } catch {
            return ToolRunResult(text: "Schätzung fehlgeschlagen: \(error.localizedDescription)", isError: true)
        }
    }

    private static func formatSummary(_ s: KostenSchaetzung) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "de_DE")
        fmt.maximumFractionDigits = 0
        let min   = fmt.string(from: NSNumber(value: s.minNetto))   ?? "\(Int(s.minNetto))"
        let mitte = fmt.string(from: NSNumber(value: s.mitteNetto)) ?? "\(Int(s.mitteNetto))"
        let max   = fmt.string(from: NSNumber(value: s.maxNetto))   ?? "\(Int(s.maxNetto))"

        var out: String
        if let modell = s.modellLabel {
            out = "Kostenschätzung (\(modell)): \(min)–\(mitte)–\(max) € netto — Tischler-Einkaufskosten all-in (geliefert + montiert)."
        } else {
            out = "Kostenschätzung: \(min)–\(mitte)–\(max) € netto (\(Int(s.confidence * 100)) % Konfidenz, \(s.evidenceCount) Belege)"
        }
        for line in s.lines {
            if let amount = line.amountNet, line.kind != .open {
                let formatted = fmt.string(from: NSNumber(value: amount)) ?? "\(Int(amount))"
                out += "\n– \(line.label): \(formatted) €"
            } else {
                out += "\n– \(line.label): nicht enthalten"
            }
        }
        if s.hints.isEmpty == false {
            out += "\n" + s.hints.map { "• \($0)" }.joined(separator: "\n")
        }
        return out
    }
}

struct ListDriveFolderTool: AssistantTool {
    private let client: GoogleDriveFetching
    init(client: GoogleDriveFetching = GoogleDriveClient()) { self.client = client }

    var name: String { "list_drive_folder" }
    var description: String {
        "Listet Dateien und Unterordner im verlinkten Google-Drive-Projektordner. "
        + "Gibt Name, Typ und Änderungsdatum zurück — liest KEINE Dateiinhalte. "
        + "Mit 'unterordner' (z. B. '01 ANGEBOTE', '02 CAD') gezielt in einen Unterordner schauen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "unterordner",
                       description: "Optionaler Unterordner-Name (z. B. '01 ANGEBOTE'). Leer = Projektordner-Wurzel.")]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let folderID = (input["_driveFolderID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let filter   = (input["unterordner"]    ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !folderID.isEmpty else {
            return ToolRunResult(text: "Kein Drive-Ordner für dieses Projekt verknüpft.", isError: true)
        }
        do {
            var files = try await client.listFolder(folderID: folderID)
            var prefix = "Projektordner"
            if !filter.isEmpty {
                if let sub = files.first(where: { $0.isFolder && $0.name.lowercased().contains(filter) }) {
                    files = try await client.listFolder(folderID: sub.id)
                    prefix = sub.name
                } else {
                    let folders = files.filter { $0.isFolder }.map { $0.name }.joined(separator: ", ")
                    return ToolRunResult(text: "Unterordner '\(filter)' nicht gefunden. Vorhandene Ordner: \(folders)")
                }
            }
            return format(files, prefix: prefix)
        } catch GoogleDriveError.notConnected {
            return ToolRunResult(text: "Google Drive nicht verbunden. In Einstellungen verbinden.", isError: true)
        } catch {
            return ToolRunResult(text: "Drive-Abruf fehlgeschlagen: \(error.localizedDescription)", isError: true)
        }
    }

    private func format(_ files: [GoogleDriveFile], prefix: String) -> ToolRunResult {
        guard !files.isEmpty else { return ToolRunResult(text: "\(prefix): leer.") }
        let fmt = DateFormatter(); fmt.dateFormat = "dd.MM.yy"
        let lines = files.prefix(30).map { f in
            "• \(f.name) [\(f.typeLabel)]\(f.modifiedAt.map { " — \(fmt.string(from: $0))" } ?? "")"
        }
        let more = files.count > 30 ? "\n… und \(files.count - 30) weitere." : ""
        return ToolRunResult(text: "\(prefix) (\(files.count) Einträge):\n" + lines.joined(separator: "\n") + more)
    }
}

struct SearchContactsTool: AssistantTool {
    private let client: GoogleContactsFetching
    init(client: GoogleContactsFetching = GoogleContactsClient()) { self.client = client }

    var name: String { "search_contacts" }
    var description: String {
        "Durchsucht die Google-Kontakte des verbundenen Accounts (nur lesen). "
        + "Gibt Name, E-Mail, Telefon und Organisation passender Kontakte zurück."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "query", description: "Suchbegriff (Name, Firma, E-Mail-Fragment)")]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let query = (input["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return ToolRunResult(text: "Leere Suchabfrage.", isError: true) }
        do {
            let contacts = try await client.searchContacts(query: query)
            guard contacts.isEmpty == false else {
                return ToolRunResult(text: "Keine Kontakte für „\(query)“ gefunden.")
            }
            let lines = contacts.prefix(15).map { c -> String in
                var parts = ["• \(c.displayName)"]
                if let org = c.organization, org.isEmpty == false { parts.append("(\(org))") }
                if let mail = c.email, mail.isEmpty == false { parts.append("· \(mail)") }
                if let tel = c.phone, tel.isEmpty == false { parts.append("· \(tel)") }
                return parts.joined(separator: " ")
            }
            return ToolRunResult(text: lines.joined(separator: "\n"))
        } catch GoogleContactsError.notConnected {
            return ToolRunResult(text: "Google ist nicht verbunden. Bitte in den Einstellungen verbinden.", isError: true)
        } catch {
            return ToolRunResult(text: "Kontaktsuche fehlgeschlagen: \(error)", isError: true)
        }
    }
}

struct ListClickUpTasksTool: AssistantTool {
    private let client: ClickUpFetching
    init(client: ClickUpFetching = ClickUpClient()) { self.client = client }

    var name: String { "list_clickup_tasks" }
    var description: String {
        "Listet die offenen ClickUp-Aufgaben des aktuellen Projekts (nur lesen) "
        + "mit Status, Fälligkeit und Zuständigkeit. Nur im Projekt-Chat verfügbar."
    }
    var parameters: [ToolParameter] { [] }

    func run(input: [String: String]) async -> ToolRunResult {
        let listID = (input["_clickUpListID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard listID.isEmpty == false else {
            return ToolRunResult(text: "Keine ClickUp-Liste für dieses Projekt verknüpft.", isError: true)
        }
        do {
            let tasks = try await client.tasks(listID: listID)
            guard tasks.isEmpty == false else { return ToolRunResult(text: "Keine offenen Aufgaben in dieser Liste.") }
            let lines = tasks.prefix(25).map { t -> String in
                var parts = ["• \(t.name) [\(t.status)]"]
                if t.isUrgent { parts.append("· DRINGEND") }
                if let due = t.dueDate { parts.append("· fällig \(toolDateFormatter.string(from: due))") }
                if let who = t.assignee, who.isEmpty == false { parts.append("· \(who)") }
                return parts.joined(separator: " ")
            }
            return ToolRunResult(text: lines.joined(separator: "\n"))
        } catch ClickUpError.notConnected {
            return ToolRunResult(text: "ClickUp ist nicht verbunden. Bitte in den Einstellungen verbinden.", isError: true)
        } catch {
            return ToolRunResult(text: "ClickUp-Abruf fehlgeschlagen: \(error)", isError: true)
        }
    }
}

struct ProposeClickUpChangeTool: AssistantTool {
    private let client: ClickUpFetching
    private let listings: [ProjectClickUpRef]

    init(client: ClickUpFetching = ClickUpClient(), listings: [ProjectClickUpRef]) {
        self.client = client
        self.listings = listings
    }

    var name: String { "propose_clickup_change" }
    var description: String {
        "Schlägt eine Änderung in ClickUp vor: Aufgabe ANLEGEN, STATUS setzen (auch abhaken), FÄLLIGKEIT setzen oder ZUWEISEN. "
        + "Du schreibst NICHT selbst — es entsteht eine Bestätigungskarte, erst der Klick des Nutzers führt aus. "
        + "Im Projekt-Chat gilt die Liste des offenen Projekts; sonst 'projekt' (Nummer oder Titel) nennen."
    }
    var parameters: [ToolParameter] {
        [
            ToolParameter(name: "aktion", description: "anlegen | status | faelligkeit | zuweisen", required: true),
            ToolParameter(name: "aufgabe", description: "Name der Aufgabe (bei anlegen der neue Name, sonst (Teil des) vorhandenen Namens)", required: true),
            ToolParameter(name: "status", description: "Zielstatus, genau wie er in list_clickup_tasks in eckigen Klammern steht", required: false),
            ToolParameter(name: "faellig", description: "Fälligkeit als yyyy-MM-dd", required: false),
            ToolParameter(name: "wem", description: "Bei zuweisen: Name des Teammitglieds, wie es in ClickUp heißt", required: false),
            ToolParameter(name: "projekt", description: "Projektnummer oder Titel, wenn kein Projekt offen ist", required: false)
        ]
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func run(input: [String: String]) async -> ToolRunResult {
        let action = (input["aktion"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aufgabe = (input["aufgabe"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard aufgabe.isEmpty == false else { return ToolRunResult(text: "Es fehlt der Name der Aufgabe.", isError: true) }

        let projekt = (input["projekt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var listID = (input["_clickUpListID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var projectNumber = (input["_projektID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if projekt.isEmpty == false {
            let match = listings.filter {
                $0.projectNumber.caseInsensitiveCompare(projekt) == .orderedSame
                || $0.title.localizedCaseInsensitiveContains(projekt)
            }
            guard match.count == 1, let ref = match.first else {
                return ToolRunResult(
                    text: match.isEmpty ? "Kein Projekt mit ClickUp-Liste gefunden für „\(projekt)“."
                        : "Mehrere Projekte passen auf „\(projekt)“: " + match.map(\.projectNumber).joined(separator: ", "),
                    isError: true)
            }
            listID = ref.listID
            projectNumber = ref.projectNumber
        }
        guard listID.isEmpty == false else {
            return ToolRunResult(text: "Keine ClickUp-Liste bekannt — nenne das Projekt.", isError: true)
        }

        let faellig = (input["faellig"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let dueDate = faellig.isEmpty ? nil : Self.dayFormatter.date(from: faellig)
        if faellig.isEmpty == false, dueDate == nil {
            return ToolRunResult(text: "Fälligkeit nicht lesbar — erwartet yyyy-MM-dd.", isError: true)
        }

        if action == "anlegen" {
            let draft = ClickUpChangeDraft(intent: .create, listID: listID, projectNumber: projectNumber,
                                           taskName: aufgabe, dueDate: dueDate)
            return ToolRunResult(text: "Bestätigungskarte erzeugt: Aufgabe „\(aufgabe)“ anlegen. Noch NICHT angelegt.",
                                 clickUpDraft: draft)
        }

        let tasks: [ClickUpTask]
        do {
            tasks = try await client.tasks(listID: listID, includeClosed: false)
        } catch ClickUpError.notConnected {
            return ToolRunResult(text: "ClickUp ist nicht verbunden. Bitte in den Einstellungen verbinden.", isError: true)
        } catch {
            return ToolRunResult(text: "ClickUp-Abruf fehlgeschlagen: \(error)", isError: true)
        }
        let passend = tasks.filter { $0.name.localizedCaseInsensitiveContains(aufgabe) }
        guard passend.count == 1, let task = passend.first else {
            return ToolRunResult(
                text: passend.isEmpty ? "Keine offene Aufgabe passt auf „\(aufgabe)“."
                    : "Mehrere Aufgaben passen: " + passend.prefix(8).map(\.name).joined(separator: " · "),
                isError: true)
        }

        switch action {
        case "status":
            let status = (input["status"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard status.isEmpty == false else { return ToolRunResult(text: "Es fehlt der Zielstatus.", isError: true) }
            let draft = ClickUpChangeDraft(intent: .status, listID: listID, projectNumber: projectNumber,
                                           taskID: task.id, taskName: task.name, status: status)
            return ToolRunResult(text: "Bestätigungskarte erzeugt: „\(task.name)“ auf Status \(status). Noch NICHT geändert.",
                                 clickUpDraft: draft)
        case "faelligkeit":
            guard let dueDate else { return ToolRunResult(text: "Es fehlt die Fälligkeit (yyyy-MM-dd).", isError: true) }
            let draft = ClickUpChangeDraft(intent: .dueDate, listID: listID, projectNumber: projectNumber,
                                           taskID: task.id, taskName: task.name, dueDate: dueDate)
            return ToolRunResult(text: "Bestätigungskarte erzeugt: „\(task.name)“ fällig \(faellig). Noch NICHT geändert.",
                                 clickUpDraft: draft)
        case "zuweisen":
            let wem = (input["wem"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard wem.isEmpty == false else { return ToolRunResult(text: "Es fehlt der Name, wem zugewiesen werden soll.", isError: true) }
            let mitglieder: [ClickUpMember]
            do { mitglieder = try await client.listMembers(listID: listID) }
            catch { return ToolRunResult(text: "Die Mitglieder der Liste konnten nicht geladen werden: \(error)", isError: true) }
            let passende = mitglieder.filter { $0.username.localizedCaseInsensitiveContains(wem) }
            guard passende.count == 1, let mitglied = passende.first else {
                return ToolRunResult(
                    text: passende.isEmpty
                        ? "Niemand in dieser Liste heißt „\(wem)“. Bekannt sind: " + mitglieder.prefix(12).map(\.username).joined(separator: " · ")
                        : "Mehrere passen auf „\(wem)“: " + passende.map(\.username).joined(separator: " · "),
                    isError: true)
            }
            let draft = ClickUpChangeDraft(intent: .assign, listID: listID, projectNumber: projectNumber,
                                           taskID: task.id, taskName: task.name,
                                           memberID: mitglied.id, memberName: mitglied.username)
            return ToolRunResult(text: "Bestätigungskarte erzeugt: „\(task.name)“ an \(mitglied.username). Noch NICHT zugewiesen.",
                                 clickUpDraft: draft)
        default:
            return ToolRunResult(text: "Unbekannte Aktion — erlaubt: anlegen, status, faelligkeit, zuweisen.", isError: true)
        }
    }
}

struct AllClickUpTasksTool: AssistantTool {
    private let client: ClickUpFetching
    private let listings: [ProjectClickUpRef]

    private let maxLists = 20
    init(client: ClickUpFetching = ClickUpClient(), listings: [ProjectClickUpRef]) {
        self.client = client
        self.listings = listings
    }

    var name: String { "list_all_clickup_tasks" }
    var description: String {
        "Projektübergreifende Übersicht aller offenen ClickUp-Aufgaben (nur lesen), gruppiert "
        + "nach Projekt. Nutze es für „Was steht insgesamt offen?“ statt list_clickup_tasks "
        + "(das nur das aktuelle Projekt zeigt). Optional 'projekt' = Filter auf einen Namen/Nr."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "projekt", description: "optionaler Projekt-Filter (Name oder Nummer)", required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let filter = (input["projekt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var refs = listings
        if filter.isEmpty == false {
            refs = refs.filter { $0.projectNumber.lowercased().contains(filter) || $0.title.lowercased().contains(filter) }
        }
        guard refs.isEmpty == false else {
            return ToolRunResult(text: "Kein Projekt hat eine verknüpfte ClickUp-Liste. (Listen-IDs werden in Airtable gepflegt.)")
        }
        let limited = Array(refs.prefix(maxLists))
        var blocks: [String] = []
        var total = 0
        var failed = 0
        for ref in limited {
            do {
                let tasks = try await client.tasks(listID: ref.listID)
                guard tasks.isEmpty == false else { continue }
                total += tasks.count
                let lines = tasks.prefix(15).map { t -> String in
                    var parts = ["  • \(t.name) [\(t.status)]"]
                    if t.isUrgent { parts.append("· DRINGEND") }
                    if let due = t.dueDate { parts.append("· fällig \(toolDateFormatter.string(from: due))") }
                    return parts.joined(separator: " ")
                }
                blocks.append("\(ref.projectNumber) \(ref.title) (\(tasks.count)):\n" + lines.joined(separator: "\n"))
            } catch ClickUpError.notConnected {
                return ToolRunResult(text: "ClickUp ist nicht verbunden. Bitte in den Einstellungen verbinden.", isError: true)
            } catch {
                failed += 1
            }
        }
        guard blocks.isEmpty == false else {
            return ToolRunResult(text: "Keine offenen Aufgaben über alle verknüpften Projekte.")
        }
        var footer: [String] = []
        if refs.count > limited.count { footer.append("… \(refs.count - limited.count) weitere Listen nicht geladen (Limit \(maxLists)).") }
        if failed > 0 { footer.append("\(failed) Liste(n) nicht erreichbar.") }
        let header = "Offene Aufgaben: \(total) über \(blocks.count) Projekt(e)."
        return ToolRunResult(text: ([header] + blocks + footer).joined(separator: "\n"))
    }
}

struct SearchKatalogTool: AssistantTool {
    private let store: ArtikelKatalogStore?
    init(store: ArtikelKatalogStore?) { self.store = store }

    var name: String { "search_katalog" }
    var description: String {
        "Sucht Artikel und Geräte in der mykilOS-Artikeldatenbank (Gaggenau, Miele, Blum…, live aus Airtable). "
        + "Gibt Hersteller, Bezeichnung, Artikelnummer, MYKILOS-Verkaufspreis und Einkaufspreis zurück. "
        + "Nützlich für Kalkulationsfragen wie \"Was kostet ein Gaggenau Backofen?\". Nur lesen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "query", description: "Suchbegriff: Hersteller, Kategorie, Artikelnummer oder Produktlabel", required: true)]
    }

    private enum Ausgang: Sendable {
        case match([ArtikelSuchergebnis])
        case laedt(Int)
        case isEmpty
        case nichtVerbunden
        case error(String)
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let query = (input["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return ToolRunResult(text: "Bitte einen Suchbegriff angeben (z. B. \"Gaggenau Backofen\" oder \"Blum Scharnier\").", isError: true)
        }
        guard let store else {
            return ToolRunResult(text: "Artikeldatenbank nicht verbunden — bitte in ALPHA mit Airtable anmelden.", isError: true)
        }

        let ausgang: Ausgang = await MainActor.run {
            switch store.state {
            case .idle:
                Task { await store.load() }
                return .laedt(0)
            case .loading(let n): return .laedt(n)
            case .notConnected:   return .nichtVerbunden
            case .error(let m):   return .error(m)
            case .empty:          return .isEmpty
            case .content:        return .match(Array(store.search(term: query).prefix(10)))
            }
        }
        switch ausgang {
        case .nichtVerbunden:
            return ToolRunResult(text: "Keine Verbindung zur Artikeldatenbank (Airtable). Bitte Verbindung prüfen.", isError: true)
        case .error(let m):
            return ToolRunResult(text: "Artikeldatenbank-Fehler: \(m)", isError: true)
        case .isEmpty:
            return ToolRunResult(text: "Die Artikeldatenbank ist leer.", isError: true)
        case .laedt(let n):
            let zusatz = n > 0 ? " (\(n) Artikel bisher)" : ""
            return ToolRunResult(text: "Der Artikelkatalog lädt gerade aus Airtable\(zusatz) — bitte gleich noch einmal fragen.")
        case .match(let results):
            guard !results.isEmpty else {
                return ToolRunResult(text: "Keine Artikel f\u{00FC}r \"\(query)\" in der Artikeldatenbank gefunden. Tipp: k\u{00FC}rzerer Suchbegriff oder Herstellername.")
            }
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.locale = Locale(identifier: "de_DE")
            f.maximumFractionDigits = 2
            func euro(_ v: Double?) -> String? { v.flatMap { f.string(from: $0 as NSNumber) } }
            let lines = results.map { e -> String in
                let a = e.artikel
                let name = a.artikelbeschreibung ?? a.articleNumber
                let hersteller = a.hersteller ?? "–"
                var preis = ""
                if let vk = euro(a.vkNetto) { preis += " | VK \(vk)" }
                if let ek = euro(a.ekNetto) { preis += " | EK \(ek)" }
                return "• \(hersteller) | \(name) | Art. \(a.articleNumber)\(preis)"
            }
            return ToolRunResult(text: "Katalog-Treffer f\u{00FC}r \"\(query)\":\n" + lines.joined(separator: "\n"))
        }
    }
}

struct QueryStudioKnowledgeTool: AssistantTool {
    private let brain: StudioBrain
    init(brain: StudioBrain) { self.brain = brain }

    var name: String { "query_studio_knowledge" }
    var description: String {
        "Durchsucht die lokale Studio-Wissensbasis aus der Projekthistorie "
        + "(Projekte mit Phase/Problem-Signalen/Beträgen, Lieferanten, Team). "
        + "Nutze sie für Fragen zu früheren oder laufenden Projekten, Kunden und Lieferanten. "
        + "Leere/allgemeine Anfrage gibt eine Gesamtübersicht (Kennzahlen, Top-Köpfe/Lieferanten)."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "query", description: "Kunde, Projekt, Ort oder Lieferant (leer = Übersicht)", required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let query = (input["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty || ["übersicht", "overview", "statistik", "gesamt", "stats"].contains(query.lowercased()) {
            return ToolRunResult(text: brain.overview)
        }
        let hits = brain.lookup(query)
        guard hits.isEmpty == false else {
            return ToolRunResult(text: "Keine Treffer in der Studio-Wissensbasis für „\(query)“. Tipp: Kundenname, Ort oder Lieferant.")
        }
        return ToolRunResult(text: hits.map(brain.describe).joined(separator: "\n"))
    }
}

struct LookupKundeTool: AssistantTool {
    private let brain: KundenBrain
    init(brain: KundenBrain) { self.brain = brain }

    var name: String { "lookup_kunde" }
    var description: String {
        "Durchsucht die lokal synchronisierten Airtable-Kunden (nur lesen): Kundenname, "
        + "Kundennummer und Anzahl Projekte. Liefert KEINE E-Mail/Telefon — dafür "
        + "search_contacts (Google-Kontakte). Leere Anfrage = Kundenübersicht."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "query", description: "Kundenname oder Kundennummer (leer = Übersicht)", required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let query = (input["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty || ["übersicht", "overview", "alle", "liste"].contains(query.lowercased()) {
            return ToolRunResult(text: brain.overview)
        }
        let hits = brain.lookup(query)
        guard hits.isEmpty == false else {
            return ToolRunResult(text: "Keine Kunden für „\(query)“ gefunden. Tipp: Teil des Namens oder Kundennummer.")
        }
        return ToolRunResult(text: hits.map(brain.describe).joined(separator: "\n"))
    }
}

struct LookupKontaktTool: AssistantTool {
    private let directory: ContactDirectory
    init(directory: ContactDirectory) { self.directory = directory }

    var name: String { "lookup_kontakt" }
    var description: String {
        "Durchsucht das Airtable-Kontaktverzeichnis (Kunden, Lieferanten, Handwerker, Team): "
        + "liefert Name, Organisation, Telefon, E-Mail, ADRESSE und Projekt. Nutze DIESES "
        + "Werkzeug für Adress-/Telefon-/E-Mail-Fragen zu Personen (z. B. „Adresse Beispielkunde?“)."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "query", description: "Name, Organisation oder Projekt")]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let query = (input["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            return ToolRunResult(text: "Wonach soll ich im Kontaktverzeichnis suchen? (Name/Firma/Projekt)", isError: true)
        }
        let hits = directory.search(query)
        guard hits.isEmpty == false else {
            return ToolRunResult(text: "Keine Kontakte für „\(query)“ gefunden.")
        }
        let lines = hits.map { contact -> String in
            var head = contact.name
            if let org = contact.organisation { head += " · \(org)" }
            var detail: [String] = []
            if let tel = contact.telefon { detail.append("☎ \(tel)") }
            if let mail = contact.email { detail.append("✉ \(mail)") }
            if let adr = contact.adresse { detail.append("⌂ \(adr)") }
            if let proj = contact.projekt { detail.append("Projekt \(proj)") }
            return detail.isEmpty ? head : "\(head)\n  " + detail.joined(separator: " · ")
        }
        return ToolRunResult(text: lines.joined(separator: "\n"))
    }
}

struct FindOffersTool: AssistantTool {
    private let client: GoogleDriveFetching
    private let directory: ProjectDirectory?
    init(client: GoogleDriveFetching = GoogleDriveClient(), directory: ProjectDirectory? = nil) {
        self.client = client
        self.directory = directory
    }

    var name: String { "find_offers" }
    var description: String {
        "Findet Angebote und Rechnungen im Google-Drive-Projektordner (eingehende UND "
        + "ausgehende, auch verschachtelt z. B. in '01 INFOS'). Nur lesen. Im Projekt-Chat "
        + "automatisch fürs offene Projekt; sonst das Projekt über 'projekt' (Name/Nummer/Kunde) angeben."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "projekt", description: "Projekt (Name, Nummer oder Kunde) — nur nötig ohne offenes Projekt", required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        var folderID = (input["_driveFolderID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var label = "dem aktuellen Projekt"
        let q = (input["projekt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if folderID.isEmpty || q.isEmpty == false {
            guard q.isEmpty == false else {
                return ToolRunResult(text: "Für welches Projekt? Nenne Name, Nummer oder Kunde.", isError: true)
            }
            guard let entry = directory?.resolve(q) else {
                return ToolRunResult(text: "Projekt \(q) nicht gefunden.", isError: true)
            }
            guard let fid = entry.driveFolderID, fid.isEmpty == false else {
                return ToolRunResult(text: "Für \(entry.title) (\(entry.projectNumber)) ist kein Drive-Ordner verknüpft.", isError: true)
            }
            folderID = fid
            label = "\(entry.title) (\(entry.projectNumber))"
        }
        do {
            let result = try await OffersCollector.load(rootFolderID: folderID, client: client)
            return ToolRunResult(text: Self.format(result, label: label), driveFiles: Self.refs(result))
        } catch GoogleDriveError.notConnected {
            return ToolRunResult(text: "Google Drive nicht verbunden. In den Einstellungen verbinden.", isError: true)
        } catch {
            return ToolRunResult(text: "Angebots-Suche fehlgeschlagen: \(error.localizedDescription)", isError: true)
        }
    }

    private static func refs(_ r: OffersCollector.Result) -> [DriveFileRef] {
        let fmt = DateFormatter(); fmt.dateFormat = "dd.MM.yy"; fmt.locale = Locale(identifier: "de_DE")
        func map(_ offers: [ClassifiedOffer], _ richtung: String) -> [DriveFileRef] {
            offers.prefix(40).map { o in
                var sub = "\(richtung) · \(o.type.label)"
                if let d = o.file.modifiedAt { sub += " · \(fmt.string(from: d))" }
                return DriveFileRef(id: o.file.id, name: o.file.name, mimeType: o.file.mimeType,
                                    webViewLink: o.file.webViewLink, subtitle: sub)
            }
        }
        return map(r.outgoing, "ausgehend") + map(r.incoming, "eingehend")
    }

    private static func format(_ r: OffersCollector.Result, label: String) -> String {
        guard r.incoming.isEmpty == false || r.outgoing.isEmpty == false else {
            return "Keine Angebote/Rechnungen in \(label) gefunden."
        }
        let fmt = DateFormatter(); fmt.dateFormat = "dd.MM.yy"; fmt.locale = Locale(identifier: "de_DE")
        func lines(_ offers: [ClassifiedOffer]) -> String {
            offers.prefix(20).map { o in
                var parts = ["• \(o.file.name) [\(o.type.label)]"]
                if let nr = o.belegNummer { parts.append("· \(nr)") }
                if let d = o.file.modifiedAt { parts.append("· \(fmt.string(from: d))") }
                return parts.joined(separator: " ")
            }.joined(separator: "\n")
        }
        var s = "Angebote in \(label):"
        if r.outgoing.isEmpty == false { s += "\n\nAusgehend (\(r.outgoing.count)):\n" + lines(r.outgoing) }
        if r.incoming.isEmpty == false { s += "\n\nEingehend (\(r.incoming.count)):\n" + lines(r.incoming) }
        return s
    }
}

struct ReadDriveFileTool: AssistantTool {
    private let client: GoogleDriveFetching
    private let directory: ProjectDirectory?
    init(client: GoogleDriveFetching = GoogleDriveClient(), directory: ProjectDirectory? = nil) {
        self.client = client
        self.directory = directory
    }

    var name: String { "read_drive_file" }
    var description: String {
        "Liest den INHALT einer Datei im Google-Drive-Projektordner (PDF, Google Docs/"
        + "Sheets/Slides, Textdateien) als Klartext. Nutze es, um z. B. einen Fragebogen, "
        + "ein Angebot oder eine Notiz im Drive auszuwerten. 'datei' = Dateiname (Teil reicht). "
        + "Im Projekt-Chat automatisch das offene Projekt; ein anderes Projekt über 'projekt' angeben. Nur lesen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "datei", description: "Dateiname oder Teil davon (z. B. 'Fragebogen')"),
         ToolParameter(name: "projekt", description: "Projekt (Name/Nummer/Kunde) — leer = das offene Projekt", required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let file = (input["datei"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard file.isEmpty == false else {
            return ToolRunResult(text: "Welche Datei? Nenne (einen Teil) des Dateinamens.", isError: true)
        }
        var folderID = (input["_driveFolderID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let q = (input["projekt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty == false, let fid = directory?.resolve(q)?.driveFolderID, fid.isEmpty == false {
            folderID = fid
        } else if folderID.isEmpty {
            return ToolRunResult(text: "Kein Projekt im Fokus. Nenne das Projekt (Name/Nummer).", isError: true)
        }
        do {
            guard let file = try await DriveFileReader.findFile(named: file, in: folderID, client: client) else {
                return ToolRunResult(text: "Datei mit \(file) im Projektordner nicht gefunden.", isError: true)
            }
            guard let text = try await DriveFileReader.text(of: file, client: client) else {
                return ToolRunResult(text: "\(file.name): kein lesbarer Textinhalt (Bild/Binärformat).")
            }
            return ToolRunResult(text: "Inhalt von \(file.name):\n\n\(text)")
        } catch GoogleDriveError.notConnected {
            return ToolRunResult(text: "Drive-Lesezugriff fehlt. Google in den Einstellungen (neu) verbinden — der drive.readonly-Scope wird für Dateiinhalte gebraucht.", isError: true)
        } catch {
            return ToolRunResult(text: "Datei konnte nicht gelesen werden: \(error.localizedDescription)", isError: true)
        }
    }
}

enum AssistantScope {
    static func projectID(from input: [String: String]) -> String? {
        let value = (input["_projektID"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct CreateNoteTool: AssistantTool {
    private let store: AssistantNotesStore
    init(store: AssistantNotesStore) { self.store = store }
    var name: String { "create_note" }
    var description: String {
        "Legt eine persistente Notiz/Erinnerung an (lokal gespeichert, überlebt den "
        + "Chat-/App-Neustart). Nutze es, wenn der Nutzer etwas notieren oder sich erinnern lassen will. "
        + "Im Projekt-Chat wird die Notiz automatisch diesem Projekt zugeordnet."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "text", description: "Der Notiztext"),
         ToolParameter(name: "trotzdem", description: "true = auch anlegen, wenn es schon eine sehr ähnliche Notiz gibt")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let text = (input["text"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return ToolRunResult(text: "Kein Notiztext angegeben.", isError: true) }
        let pid = AssistantScope.projectID(from: input)
        do {
            if (input["trotzdem"] ?? "").lowercased() != "true",
               let schonDa = NotizDublette.vorhandene(zu: text, in: try await store.all()) {
                return ToolRunResult(text: "Nicht angelegt — es gibt schon eine sehr ähnliche Notiz [\(schonDa.ref)]: "
                    + "\(schonDa.body). Zum Ändern update_note mit diesem Kurzbezug, zum bewussten Doppeln trotzdem=true.")
            }
            let note = try await store.create(text, projectID: pid)
            var msg = "Notiz angelegt [\(note.ref)]"
            if let p = note.projectID { msg += " (Projekt \(p))" }
            return ToolRunResult(text: msg + ": \(note.body)")
        } catch {
            return ToolRunResult(text: "Notiz konnte nicht gespeichert werden: \(error.localizedDescription)", isError: true)
        }
    }
}

struct ListNotesTool: AssistantTool {
    private let store: AssistantNotesStore
    init(store: AssistantNotesStore) { self.store = store }
    var name: String { "list_notes" }
    var description: String {
        "Listet gespeicherte Notizen/Erinnerungen (neueste zuerst) mit Kurzbezug. Im "
        + "Projekt-Chat standardmäßig die Notizen DIESES Projekts plus die globalen; "
        + "mit alle=true alle Projekte."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "alle", description: "true = Notizen aller Projekte, sonst nur das aktuelle + globale")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let pid = AssistantScope.projectID(from: input)
        let alle = (input["alle"] ?? "").lowercased() == "true"
        do {
            let notes = (alle || pid == nil) ? try await store.all() : try await store.scoped(to: pid)
            guard notes.isEmpty == false else { return ToolRunResult(text: "Keine Notizen gespeichert.") }
            let fmt = DateFormatter(); fmt.dateFormat = "dd.MM.yy HH:mm"; fmt.locale = Locale(identifier: "de_DE")
            let lines = notes.map { note -> String in
                let tag = note.projectID.map { " · Projekt \($0)" } ?? ""
                return "• [\(note.ref)] \(note.body)\(tag) (\(fmt.string(from: note.updatedAt)))"
            }
            return ToolRunResult(text: lines.joined(separator: "\n"))
        } catch {
            return ToolRunResult(text: "Notizen konnten nicht geladen werden: \(error.localizedDescription)", isError: true)
        }
    }
}

struct UpdateNoteTool: AssistantTool {
    private let store: AssistantNotesStore
    init(store: AssistantNotesStore) { self.store = store }
    var name: String { "update_note" }
    var description: String {
        "Ändert den Text einer bestehenden Notiz. 'note' = Kurzbezug/ID oder Teil des alten Textes."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "note", description: "Kurzbezug, ID oder Textausschnitt der Notiz"),
         ToolParameter(name: "text", description: "Der neue Notiztext")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let q = (input["note"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let text = (input["text"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false, text.isEmpty == false else {
            return ToolRunResult(text: "Notiz-Bezug und neuer Text nötig.", isError: true)
        }
        let pid = AssistantScope.projectID(from: input)
        do {
            guard let note = try await store.update(matching: q, newBody: text, scopedTo: pid) else {
                return ToolRunResult(text: "Keine Notiz zu \(q) gefunden.", isError: true)
            }
            return ToolRunResult(text: "Notiz [\(note.ref)] aktualisiert: \(note.body)")
        } catch {
            return ToolRunResult(text: "Aktualisierung fehlgeschlagen: \(error.localizedDescription)", isError: true)
        }
    }
}

struct DeleteNoteTool: AssistantTool {
    private let store: AssistantNotesStore
    init(store: AssistantNotesStore) { self.store = store }
    var name: String { "delete_note" }
    var description: String { "Löscht eine Notiz. 'note' = Kurzbezug/ID oder Teil des Textes." }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "note", description: "Kurzbezug, ID oder Textausschnitt der zu löschenden Notiz")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let q = (input["note"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else {
            return ToolRunResult(text: "Welche Notiz? Nenne Kurzbezug oder Textausschnitt.", isError: true)
        }
        let pid = AssistantScope.projectID(from: input)
        do {
            guard let note = try await store.delete(matching: q, scopedTo: pid) else {
                return ToolRunResult(text: "Keine Notiz zu \(q) gefunden.", isError: true)
            }
            return ToolRunResult(text: "Notiz gelöscht [\(note.ref)]: \(note.body)")
        } catch {
            return ToolRunResult(text: "Löschen fehlgeschlagen: \(error.localizedDescription)", isError: true)
        }
    }
}

enum DueDateParser {
    static func parse(_ raw: String?) -> Date? {
        let s = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.isEmpty == false else { return nil }
        if let d = ISO8601DateFormatter().date(from: s) { return d }
        let cal = Calendar(identifier: .gregorian)
        for pattern in ["yyyy-MM-dd", "dd.MM.yyyy", "dd.MM.yy"] {
            let fmt = DateFormatter()
            fmt.calendar = cal
            fmt.locale = Locale(identifier: "de_DE")
            fmt.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
            fmt.dateFormat = pattern
            if let d = fmt.date(from: s) { return d }
        }
        return nil
    }
}

private let assistantTaskDateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateFormat = "dd.MM.yy"
    fmt.locale = Locale(identifier: "de_DE")
    return fmt
}()

struct CreateTaskTool: AssistantTool {
    private let store: AssistantTasksStore
    init(store: AssistantTasksStore) { self.store = store }
    var name: String { "create_task" }
    var description: String {
        "Legt eine persistente Aufgabe/Erinnerung an (lokal, überlebt den Neustart). "
        + "Nutze es für interne Memos und To-dos, die der Nutzer sich selbst setzt. "
        + "Optionales Fälligkeitsdatum als ISO (yyyy-MM-dd). Im Projekt-Chat wird die "
        + "Aufgabe automatisch diesem Projekt zugeordnet."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "titel", description: "Worum geht die Aufgabe"),
         ToolParameter(name: "faellig", description: "Optionales Fälligkeitsdatum (yyyy-MM-dd), sonst leer")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let title = (input["titel"] ?? input["text"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return ToolRunResult(text: "Kein Aufgabentitel angegeben.", isError: true) }
        let due = DueDateParser.parse(input["faellig"])
        let pid = AssistantScope.projectID(from: input)
        do {
            let task = try await store.create(title, dueDate: due, projectID: pid)
            var msg = "Aufgabe angelegt [\(task.ref)]"
            if let p = task.projectID { msg += " (Projekt \(p))" }
            msg += ": \(task.title)"
            if let d = task.dueDate { msg += " (fällig \(assistantTaskDateFormatter.string(from: d)))" }
            return ToolRunResult(text: msg)
        } catch {
            return ToolRunResult(text: "Aufgabe konnte nicht gespeichert werden: \(error.localizedDescription)", isError: true)
        }
    }
}

struct ListTasksTool: AssistantTool {
    private let store: AssistantTasksStore
    init(store: AssistantTasksStore) { self.store = store }
    var name: String { "list_tasks" }
    var description: String {
        "Listet Aufgaben/Erinnerungen (offene zuerst, nach Fälligkeit) mit Kurzbezug und "
        + "Status. Im Projekt-Chat standardmäßig die Aufgaben DIESES Projekts plus globale; "
        + "mit alle=true alle Projekte."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "nur_offen", description: "true = nur offene Aufgaben, sonst alle"),
         ToolParameter(name: "alle", description: "true = Aufgaben aller Projekte, sonst nur das aktuelle + globale")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let nurOffen = (input["nur_offen"] ?? "").lowercased() == "true"
        let alle = (input["alle"] ?? "").lowercased() == "true"
        let pid = AssistantScope.projectID(from: input)
        do {
            var tasks = (alle || pid == nil) ? try await store.all() : try await store.scoped(to: pid)
            if nurOffen { tasks = tasks.filter { !$0.done } }
            guard tasks.isEmpty == false else {
                return ToolRunResult(text: nurOffen ? "Keine offenen Aufgaben." : "Keine Aufgaben gespeichert.")
            }
            let lines = tasks.map { task -> String in
                let box = task.done ? "✓" : "○"
                var line = "\(box) [\(task.ref)] \(task.title)"
                if let p = task.projectID { line += " · Projekt \(p)" }
                if let d = task.dueDate { line += " (fällig \(assistantTaskDateFormatter.string(from: d)))" }
                return line
            }
            return ToolRunResult(text: lines.joined(separator: "\n"))
        } catch {
            return ToolRunResult(text: "Aufgaben konnten nicht geladen werden: \(error.localizedDescription)", isError: true)
        }
    }
}

struct CompleteTaskTool: AssistantTool {
    private let store: AssistantTasksStore
    init(store: AssistantTasksStore) { self.store = store }
    var name: String { "complete_task" }
    var description: String {
        "Hakt eine Aufgabe als erledigt ab (oder öffnet sie mit erledigt=false wieder). "
        + "'aufgabe' = Kurzbezug/ID oder Teil des Titels."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "aufgabe", description: "Kurzbezug, ID oder Titelausschnitt der Aufgabe"),
         ToolParameter(name: "erledigt", description: "true (Standard) = abhaken, false = wieder öffnen")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let q = (input["aufgabe"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else {
            return ToolRunResult(text: "Welche Aufgabe? Nenne Kurzbezug oder Titelausschnitt.", isError: true)
        }
        let done = (input["erledigt"] ?? "true").lowercased() != "false"
        let pid = AssistantScope.projectID(from: input)
        do {
            guard let task = try await store.setDone(matching: q, done: done, scopedTo: pid) else {
                return ToolRunResult(text: "Keine Aufgabe zu \(q) gefunden.", isError: true)
            }
            return ToolRunResult(text: "Aufgabe [\(task.ref)] \(done ? "erledigt" : "wieder offen"): \(task.title)")
        } catch {
            return ToolRunResult(text: "Aktualisierung fehlgeschlagen: \(error.localizedDescription)", isError: true)
        }
    }
}

struct DeleteTaskTool: AssistantTool {
    private let store: AssistantTasksStore
    init(store: AssistantTasksStore) { self.store = store }
    var name: String { "delete_task" }
    var description: String { "Löscht eine Aufgabe. 'aufgabe' = Kurzbezug/ID oder Teil des Titels." }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "aufgabe", description: "Kurzbezug, ID oder Titelausschnitt der zu löschenden Aufgabe")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let q = (input["aufgabe"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.isEmpty == false else {
            return ToolRunResult(text: "Welche Aufgabe? Nenne Kurzbezug oder Titelausschnitt.", isError: true)
        }
        let pid = AssistantScope.projectID(from: input)
        do {
            guard let task = try await store.delete(matching: q, scopedTo: pid) else {
                return ToolRunResult(text: "Keine Aufgabe zu \(q) gefunden.", isError: true)
            }
            return ToolRunResult(text: "Aufgabe gelöscht [\(task.ref)]: \(task.title)")
        } catch {
            return ToolRunResult(text: "Löschen fehlgeschlagen: \(error.localizedDescription)", isError: true)
        }
    }
}

struct ReadEmailTool: AssistantTool {
    private let client: GoogleGmailFetching
    init(client: GoogleGmailFetching = GmailAccess.client()) { self.client = client }

    var name: String { "read_email" }
    var description: String {
        "Liest den VOLLEN Inhalt einer E-Mail (nicht nur die Vorschau). 'query' = Gmail-Suche, "
        + "die die Mail eindeutig trifft (z. B. 'from:name subject:Leuchten'). Optional 'nummer' "
        + "= n-ter Treffer (Standard 1). Nutze es, wenn der Nutzer den Mailinhalt wissen will."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "query", description: "Gmail-Suche, die die Mail trifft"),
         ToolParameter(name: "nummer", description: "n-ter Treffer (Standard 1)", required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let query = (input["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return ToolRunResult(text: "Leere Suchabfrage.", isError: true) }
        let index = max(1, Int(input["nummer"] ?? "1") ?? 1)
        do {
            let hits = try await client.searchMessages(query: query, maxResults: max(index, 5))
            guard hits.isEmpty == false else { return ToolRunResult(text: "Keine Mail für „\(query)“ gefunden.") }
            guard index <= hits.count else {
                return ToolRunResult(text: "Nur \(hits.count) Treffer — Nummer \(index) gibt es nicht.", isError: true)
            }
            let msg = hits[index - 1]
            let body = (try await client.fetchBody(messageID: msg.id)).trimmingCharacters(in: .whitespacesAndNewlines)
            let date = msg.receivedAt.map { toolDateFormatter.string(from: $0) } ?? "ohne Datum"
            let shown = body.count > 6000 ? String(body.prefix(6000)) + "\n… [gekürzt]" : (body.isEmpty ? "(kein lesbarer Text-Body)" : body)
            return ToolRunResult(text: "Betreff: \(msg.subject)\nVon: \(msg.from) (\(date))\n\n\(shown)")
        } catch GoogleGmailError.notConnected {
            return ToolRunResult(text: "Gmail ist nicht verbunden. Bitte in den Einstellungen verbinden.", isError: true)
        } catch {
            return ToolRunResult(text: "Mail konnte nicht gelesen werden: \(error)", isError: true)
        }
    }
}

struct CreateDraftTool: AssistantTool {
    var name: String { "create_draft" }
    var description: String {
        "Bereitet einen E-Mail-ENTWURF vor (Empfänger optional, Betreff, Text). Du schreibst "
        + "NICHT selbst und versendest NIE — es entsteht eine Bestätigungskarte, der Nutzer legt "
        + "den Entwurf in Gmail ab (erscheint dann auch in Apple Mail). Behaupte nie, die Mail "
        + "sei gesendet oder schon gespeichert."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "betreff", description: "Betreff der Mail"),
         ToolParameter(name: "text", description: "Mailtext (Body)"),
         ToolParameter(name: "an", description: "Empfänger-E-Mail (optional)", required: false)]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        let subject = (input["betreff"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = (input["text"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard subject.isEmpty == false || body.isEmpty == false else {
            return ToolRunResult(text: "Für einen Entwurf brauche ich mindestens Betreff oder Text.", isError: true)
        }
        let to = (input["an"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = EmailDraft(to: to.isEmpty ? nil : to, subject: subject, body: body)
        return ToolRunResult(
            text: "Entwurf vorbereitet: \(draft.headline). Zeige dem Nutzer die Bestätigungskarte — "
                + "der Entwurf wird erst nach Bestätigung in Gmail abgelegt, nicht von dir.",
            emailDraft: draft)
    }
}

struct CreateContactTool: AssistantTool {
    var name: String { "create_contact" }
    var description: String {
        "Schlägt einen NEUEN Google-Kontakt vor. Schreibt nichts automatisch — der "
        + "Nutzer bestätigt den Kontakt an einer Karte. Pflichtfeld: Vorname (oder "
        + "vollständiger Name in 'vorname')."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "vorname", description: "Vorname (oder vollständiger Name)"),
         ToolParameter(name: "nachname", description: "Nachname (optional)"),
         ToolParameter(name: "email", description: "E-Mail (optional)"),
         ToolParameter(name: "telefon", description: "Telefon (optional)"),
         ToolParameter(name: "firma", description: "Firma/Organisation (optional)")]
    }
    func run(input: [String: String]) async -> ToolRunResult {
        func clean(_ key: String) -> String? {
            let v = (input[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
        guard let given = clean("vorname") ?? clean("name") else {
            return ToolRunResult(text: "Kein Name für den Kontakt angegeben.", isError: true)
        }
        let draft = ContactDraft(givenName: given, familyName: clean("nachname"),
                                 email: clean("email"), phone: clean("telefon"),
                                 organization: clean("firma"))
        var parts = ["Kontakt-Entwurf: \(draft.displayName)"]
        if let m = draft.email { parts.append(m) }
        if let p = draft.phone { parts.append(p) }
        if let o = draft.organization { parts.append(o) }
        let summary = parts.joined(separator: " · ")
        return ToolRunResult(
            text: "\(summary). Zeige dem Nutzer die Bestätigungskarte — der Kontakt wird "
                + "erst nach Bestätigung angelegt, nicht von dir.",
            contactDraft: draft)
    }
}

struct ListAirtableKontakteTool: AssistantTool {
    private let directory: ContactDirectory
    init(directory: ContactDirectory) { self.directory = directory }

    var name: String { "list_airtable_kontakte" }
    var description: String {
        "Listet alle Kontakte aus dem Airtable-Kontaktverzeichnis (Kunden, Lieferanten, "
        + "Handwerker, Team, Sonstige). Optional 'kategorie' filtern. Gibt Name, Organisation, "
        + "E-Mail, Telefon und Adresse zurück. Nur lesen, kein Live-API-Call."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "kategorie",
                       description: "Optionaler Kategorie-Filter (z. B. Projektkunde, Lieferant, Handwerker, MYKILOS-Team, Sonstige)",
                       required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let katFilter = (input["kategorie"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var contacts = directory.contacts
        if katFilter.isEmpty == false {
            contacts = contacts.filter { ($0.kategorie ?? "").lowercased().contains(katFilter) }
        }
        guard contacts.isEmpty == false else {
            let suffix = katFilter.isEmpty ? "" : " mit Kategorie '\(katFilter)'"
            return ToolRunResult(text: "Keine Kontakte im Verzeichnis\(suffix) gefunden.")
        }
        let lines = contacts.prefix(50).map { c -> String in
            var head = "• \(c.name)"
            if let org = c.organisation { head += " · \(org)" }
            if let kat = c.kategorie { head += " [\(kat)]" }
            var detail: [String] = []
            if let tel  = c.telefon { detail.append("☎ \(tel)") }
            if let mail = c.email { detail.append("✉ \(mail)") }
            if let adr  = c.adresse { detail.append("⌂ \(adr)") }
            return detail.isEmpty ? head : "\(head)\n  " + detail.joined(separator: " · ")
        }
        let more = contacts.count > 50 ? "\n… und \(contacts.count - 50) weitere." : ""
        return ToolRunResult(text: "Kontaktverzeichnis (\(contacts.count)):\n" + lines.joined(separator: "\n") + more)
    }
}

struct SearchAirtableKontaktTool: AssistantTool {
    private let directory: ContactDirectory
    init(directory: ContactDirectory) { self.directory = directory }

    var name: String { "search_airtable_kontakt" }
    var description: String {
        "Sucht einen Kontakt im Airtable-Verzeichnis nach Name, Organisation oder Projekt. "
        + "Liefert Kontaktdetails (E-Mail, Telefon, Adresse, Kategorie, Airtable-ID). "
        + "Nutze DIESES Tool, wenn du Kontaktdaten zu einer Person oder Firma brauchst. Nur lesen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "query", description: "Name, Organisation oder Projekt")]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let query = (input["query"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            return ToolRunResult(text: "Wonach soll ich suchen? (Name/Firma/Projekt)", isError: true)
        }
        let hits = directory.search(query, limit: 10)
        guard hits.isEmpty == false else {
            return ToolRunResult(text: "Keine Kontakte f\u{00FC}r \"\(query)\" im Verzeichnis gefunden.")
        }
        let lines = hits.map { c -> String in
            var head = "• \(c.name)"
            if let org = c.organisation { head += " · \(org)" }
            if let kat = c.kategorie { head += " [\(kat)]" }
            var detail: [String] = ["ID: \(c.id)"]
            if let tel  = c.telefon { detail.append("☎ \(tel)") }
            if let mail = c.email { detail.append("✉ \(mail)") }
            if let adr  = c.adresse { detail.append("⌂ \(adr)") }
            if let proj = c.projekt { detail.append("Projekt \(proj)") }
            return "\(head)\n  " + detail.joined(separator: " · ")
        }
        return ToolRunResult(text: lines.joined(separator: "\n"))
    }
}

struct CreateAirtableKontaktTool: AssistantTool {
    private let directory: ContactDirectory?
    init(directory: ContactDirectory? = nil) { self.directory = directory }

    var name: String { "create_airtable_kontakt" }
    var description: String {
        "Schlägt einen NEUEN Kontakt im Airtable-Verzeichnis vor. Schreibt NICHTS automatisch — "
        + "der Nutzer bestätigt an einer Karte. Pflichtfeld: Name. KEIN Delete."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "name", description: "Vollständiger Name (Pflicht)"),
         ToolParameter(name: "organisation", description: "Firma/Organisation (optional)", required: false),
         ToolParameter(name: "email", description: "E-Mail (optional)", required: false),
         ToolParameter(name: "telefon", description: "Telefon (optional)", required: false),
         ToolParameter(name: "adresse", description: "Adresse (optional)", required: false),

         ToolParameter(name: "kategorie", description: "Kategorie: Projektkunde / Lieferant / Handwerker / Architekt/Planer / MYKILOS-Team / Sonstige",
                       required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        func clean(_ key: String) -> String? {
            let v = (input[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
        guard let name = clean("name") else {
            return ToolRunResult(text: "Kein Name für den Kontakt angegeben.", isError: true)
        }
        let draft = AirtableContactDraft(
            intent: .create, name: name,
            organisation: clean("organisation"),
            email: clean("email"),
            telefon: clean("telefon"),
            adresse: clean("adresse"),
            kategorie: clean("kategorie")
        )
        var parts = ["Airtable-Kontakt-Entwurf: \(draft.name)"]
        if let m = draft.email { parts.append(m) }
        if let p = draft.telefon { parts.append(p) }
        if let o = draft.organisation { parts.append(o) }
        let summary = parts.joined(separator: " · ")

        var hint = ""
        if let directory {
            let match = AntiDuplikat.pruefeKunde(
                DuplikatKandidat(name: name, firma: clean("organisation"),
                                 email: clean("email"), telefon: clean("telefon")),
                stock: [], kontakte: directory.contacts)
            if match.isEmpty == false {
                let namen = match.prefix(3).map { $0.detail }.joined(separator: "; ")
                hint = " ACHTUNG — möglicher Doppel-Eintrag: \(namen). Frage den Nutzer, ob "
                    + "trotzdem NEU angelegt werden soll, statt ungeprüft zu doppeln."
            }
        }

        return ToolRunResult(
            text: "\(summary).\(hint) Zeige dem Nutzer die Bestätigungskarte — der Kontakt "
                + "wird erst nach Bestätigung in Airtable angelegt, nicht von dir.",
            airtableContactDraft: draft)
    }
}

struct UpdateAirtableKontaktTool: AssistantTool {
    var name: String { "update_airtable_kontakt" }
    var description: String {
        "Schlägt eine ÄNDERUNG an einem bestehenden Airtable-Kontakt vor. Schreibt NICHTS "
        + "automatisch — Bestätigungskarte erforderlich. 'record_id' = Airtable-Record-ID "
        + "(aus search_airtable_kontakt ermittelbar). Nur geänderte Felder angeben. KEIN Delete."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "record_id", description: "Airtable-Record-ID des Kontakts (rec…)"),
         ToolParameter(name: "name", description: "Neuer Name (optional)", required: false),
         ToolParameter(name: "organisation", description: "Neue Firma (optional)", required: false),
         ToolParameter(name: "email", description: "Neue E-Mail (optional)", required: false),
         ToolParameter(name: "telefon", description: "Neues Telefon (optional)", required: false),
         ToolParameter(name: "adresse", description: "Neue Adresse (optional)", required: false),
         ToolParameter(name: "kategorie", description: "Neue Kategorie (optional)", required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        func clean(_ key: String) -> String? {
            let v = (input[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
        guard let recordID = clean("record_id") else {
            return ToolRunResult(text: "Keine Record-ID angegeben. Ermittle sie erst mit search_airtable_kontakt.", isError: true)
        }
        let name = clean("name") ?? "(unverändert)"
        let draft = AirtableContactDraft(
            intent: .update,
            recordID: recordID,
            name: name,
            organisation: clean("organisation"),
            email: clean("email"),
            telefon: clean("telefon"),
            adresse: clean("adresse"),
            kategorie: clean("kategorie")
        )
        return ToolRunResult(
            text: "Kontakt-Änderungs-Entwurf für ID \(recordID): \(name). Zeige dem Nutzer "
                + "die Bestätigungskarte — die Änderung wird erst nach Bestätigung übernommen.",
            airtableContactDraft: draft)
    }
}

public struct AssistantToolRegistry: Sendable {
    private let tools: [any AssistantTool]

    public init(tools: [any AssistantTool]) { self.tools = tools }

    public static func standard(
        gmail: GoogleGmailFetching = GmailAccess.client(),
        gmailCache: GmailCacheStore? = nil,
        calendar: GoogleCalendarFetching = GoogleCalendarClient(),
        drive: GoogleDriveFetching = GoogleDriveClient(),
        contacts: GoogleContactsFetching = GoogleContactsClient(),
        clickUp: ClickUpFetching = ClickUpClient(),
        studioBrain: StudioBrain? = StudioBrain.shared,
        kalkulationsEngine: (any KalkulationsEngineProviding)? = nil,
        artikelKatalog: ArtikelKatalogStore? = nil,
        kundenDirectory: KundenBrain? = nil,
        contactDirectory: ContactDirectory? = nil,
        clickUpListings: [ProjectClickUpRef] = [],
        notesStore: AssistantNotesStore? = nil,
        tasksStore: AssistantTasksStore? = nil,
        tagebuchStore: AssistantTagebuchStore? = nil,
        projectDirectory: ProjectDirectory? = nil,
        lagerliste: LagerlisteStore? = nil,
        sampling: BemusterungStore? = nil,
        zeiten: ClockodoZeitTabelleStore? = nil,
        sendungen: (any SendungsVerfolgend)? = nil
    ) -> AssistantToolRegistry {
        var tools: [any AssistantTool] = [
            SearchGmailTool(client: gmail, cache: gmailCache),
            ReadEmailTool(client: gmail),
            CreateDraftTool(),

            ListCalendarTool(client: calendar, team: calendar as? any GoogleCalendarTeamFetching),
            SuggestCalendarEventTool(),
            ListDriveFolderTool(client: drive),
            FindOffersTool(client: drive, directory: projectDirectory),
            ReadDriveFileTool(client: drive, directory: projectDirectory),
            SearchContactsTool(client: contacts),
            CreateContactTool(),
            ListClickUpTasksTool(client: clickUp),
            ProposeClickUpChangeTool(client: clickUp, listings: clickUpListings),
            SearchKatalogTool(store: artikelKatalog),
            ListBelegeTool()
        ]
        if let projectDirectory {
            tools.append(ListProjectsTool(directory: projectDirectory))
        }
        if let lagerliste {
            tools.append(ListLagerTool(store: lagerliste))
        }
        if let sampling {
            tools.append(ListBemusterungTool(store: sampling))
        }
        if let zeiten {
            tools.append(ListZeitenTool(store: zeiten))
        }
        if let sendungen {
            tools.append(VerfolgeSendungTool(client: sendungen))
        }
        tools.append(ProposeTerminTool())
        tools.append(ErzeugeDateiTool(directory: projectDirectory))
        if artikelKatalog != nil || lagerliste != nil {
            tools.append(ProposeWarenkorbTool(katalog: artikelKatalog, lager: lagerliste))
        }
        if let studioBrain {
            tools.append(QueryStudioKnowledgeTool(brain: studioBrain))
        }
        if let kundenDirectory {
            tools.append(LookupKundeTool(brain: kundenDirectory))
        }
        if let contactDirectory {
            tools.append(LookupKontaktTool(directory: contactDirectory))

            tools.append(ListAirtableKontakteTool(directory: contactDirectory))
            tools.append(SearchAirtableKontaktTool(directory: contactDirectory))
            tools.append(CreateAirtableKontaktTool(directory: contactDirectory))
            tools.append(UpdateAirtableKontaktTool())
        }
        if clickUpListings.isEmpty == false {
            tools.append(AllClickUpTasksTool(client: clickUp, listings: clickUpListings))
        }
        if let notesStore {
            tools.append(CreateNoteTool(store: notesStore))
            tools.append(ListNotesTool(store: notesStore))
            tools.append(UpdateNoteTool(store: notesStore))
            tools.append(DeleteNoteTool(store: notesStore))
        }
        if let tasksStore {
            tools.append(CreateTaskTool(store: tasksStore))
            tools.append(ListTasksTool(store: tasksStore))
            tools.append(CompleteTaskTool(store: tasksStore))
            tools.append(DeleteTaskTool(store: tasksStore))
        }
        if let tagebuchStore {
            tools.append(LogFrictionTool(store: tagebuchStore))
        }
        if let engine = kalkulationsEngine {
            tools.append(KostenSchaetzungTool(engine: engine))
        }
        return AssistantToolRegistry(tools: tools)
    }

    public var toolNames: [String] { tools.map(\.name) }

    public func definitions() -> [ClaudeToolDefinition] {
        tools.map { $0.wireDefinition() }
    }

    public func schaetzDefinitions() -> [ClaudeToolDefinition] {
        tools.filter { $0.name == "schaetze_projekt" }.map { $0.wireDefinition() }
    }

    public func run(name: String, inputJSON: Data, projektID: String? = nil, driveFolderID: String? = nil, clickUpListID: String? = nil) async -> ToolRunResult {
        guard let tool = tools.first(where: { $0.name == name }) else {
            return ToolRunResult(text: "Tool nicht erlaubt oder unbekannt: \(name)", isError: true)
        }
        var input = Self.stringDict(from: inputJSON)
        if let id  = projektID { input["_projektID"]      = id }
        if let fid = driveFolderID { input["_driveFolderID"]  = fid }
        if let lid = clickUpListID { input["_clickUpListID"]  = lid }
        return await tool.run(input: input)
    }

    static func stringDict(from data: Data) -> [String: String] {
        guard let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [:] }
        return raw.compactMapValues { v in
            if let s = v as? String { return s }
            if let n = v as? NSNumber { return n.stringValue }
            return nil
        }
    }
}
