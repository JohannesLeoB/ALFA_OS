import Foundation
import MykilosKit

enum AssistantLese {
    static let rowItems = 40

    static let euro: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "de_DE")
        f.maximumFractionDigits = 2
        return f
    }()

    static func geld(_ v: Double?) -> String? { v.flatMap { euro.string(from: $0 as NSNumber) } }

    static let date: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy"
        return f
    }()

    static func kuerze(_ rowItems: [String], _ total: Int) -> String {
        var text = rowItems.joined(separator: "\n")
        if total > rowItems.count { text += "\n… und \(total - rowItems.count) weitere. Suche eingrenzen." }
        return text
    }
}

struct ListProjectsTool: AssistantTool {
    private let directory: ProjectDirectory?
    init(directory: ProjectDirectory?) { self.directory = directory }

    var name: String { "list_projects" }
    var description: String {
        "Listet die Projekte des Studios mit Nummer, Titel, Kunde und Phase. "
        + "Nutze es, wenn nach den Projekten gefragt wird, nach dem Stand eines Projekts, "
        + "oder wenn du zu einem Namen die Projektnummer brauchst. Nur lesen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "suche",
                       description: "Optionaler Filter auf Projektnummer, Titel oder Kundenname",
                       required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        guard let directory else {
            return ToolRunResult(text: "Die Projektliste ist noch nicht geladen.", isError: true)
        }
        let q = (input["suche"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let match = q.isEmpty ? directory.entries : directory.entries.filter {
            $0.projectNumber.lowercased().contains(q)
                || $0.title.lowercased().contains(q)
                || ($0.customerName?.lowercased().contains(q) ?? false)
        }
        guard match.isEmpty == false else {
            return ToolRunResult(text: q.isEmpty ? "Es sind keine Projekte geladen."
                                                 : "Kein Projekt passt auf \"\(q)\".")
        }
        let rowItems = match.prefix(AssistantLese.rowItems).map { e -> String in
            var t = "• \(e.projectNumber) | \(e.title)"
            if let k = e.customerName, k.isEmpty == false { t += " | \(k)" }
            if let ph = e.phase, ph.isEmpty == false { t += " | Phase: \(ph)" }
            if let b = AssistantLese.geld(e.budget) { t += " | Budget \(b)" }
            return t
        }
        return ToolRunResult(text: AssistantLese.kuerze(Array(rowItems), match.count))
    }
}

struct ListLagerTool: AssistantTool {
    private let store: LagerlisteStore?
    init(store: LagerlisteStore?) { self.store = store }

    var name: String { "list_lager" }
    var description: String {
        "Durchsucht die Lagerliste aus Airtable: was vorrätig ist, mit Bestand, Hersteller und Preisen. "
        + "Nutze es bei Fragen wie \"haben wir das noch da\" oder \"was liegt im Lager\". Nur lesen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "suche",
                       description: "Optionaler Filter auf Bezeichnung, Hersteller, Kategorie oder Artikelnummer",
                       required: false)]
    }

    private enum Ausgang: Sendable {
        case match([LagerItem], total: Int)
        case laedt
        case message(String)
    }

    func run(input: [String: String]) async -> ToolRunResult {
        guard let store else {
            return ToolRunResult(text: "Lagerliste nicht verbunden — bitte in ALPHA mit Airtable anmelden.",
                                 isError: true)
        }
        let q = (input["suche"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ausgang: Ausgang = await MainActor.run {
            switch store.state {
            case .idle:
                Task { await store.load() }
                return .laedt
            case .loading:      return .laedt
            case .notConnected: return .message("Keine Verbindung zur Lagerliste (Airtable).")
            case .error(let m): return .message("Lagerliste-Fehler: \(m)")
            case .empty:        return .message("Die Lagerliste ist leer.")
            case .content:
                let alle = store.items
                let match = q.isEmpty ? alle : alle.filter { p in
                    p.label.lowercased().contains(q)
                        || (p.hersteller?.lowercased().contains(q) ?? false)
                        || (p.kategorie?.lowercased().contains(q) ?? false)
                        || (p.articleNumber?.lowercased().contains(q) ?? false)
                }
                return .match(Array(match.prefix(AssistantLese.rowItems)), total: match.count)
            }
        }
        switch ausgang {
        case .laedt:
            return ToolRunResult(text: "Die Lagerliste lädt gerade aus Airtable — bitte gleich noch einmal fragen.")
        case .message(let m):
            return ToolRunResult(text: m, isError: true)
        case .match(let items, let total):
            guard items.isEmpty == false else {
                return ToolRunResult(text: "Nichts im Lager passt auf \"\(q)\".")
            }
            let rowItems = items.map { p -> String in
                var t = "• \(p.label)"
                if let h = p.hersteller, h.isEmpty == false { t += " | \(h)" }
                if let nr = p.articleNumber, nr.isEmpty == false { t += " | Art. \(nr)" }
                if let b = p.stock { t += " | Bestand \(b)" }
                if let vk = AssistantLese.geld(p.vkNetto) { t += " | VK \(vk)" }
                return t
            }
            return ToolRunResult(text: AssistantLese.kuerze(rowItems, total))
        }
    }
}

struct ListBemusterungTool: AssistantTool {
    private let store: BemusterungStore?
    init(store: BemusterungStore?) { self.store = store }

    var name: String { "list_bemusterung" }
    var description: String {
        "Listet die Muster eines Projekts: Bezeichnung, Hersteller, Kategorie und Status "
        + "(vorgeschlagen, freigegeben, verworfen). Nur lesen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "projekt", description: "Projektnummer, z. B. 2408-01", required: true)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        guard let store else {
            return ToolRunResult(text: "Die Bemusterung ist nicht verfügbar.", isError: true)
        }
        let nr = (input["projekt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard nr.isEmpty == false else {
            return ToolRunResult(text: "Bitte eine Projektnummer angeben.", isError: true)
        }
        do {
            let result = try await store.alle(projectNumber: nr)
            guard result.muster.isEmpty == false else {
                return ToolRunResult(text: "Für Projekt \(nr) ist noch kein Muster erfasst.")
            }
            let rowItems = result.muster.prefix(AssistantLese.rowItems).map { m -> String in
                var t = "• \(m.label)"
                if let h = m.hersteller, h.isEmpty == false { t += " | \(h)" }
                if let k = m.kategorie, k.isEmpty == false { t += " | \(k)" }
                t += " | \(m.status.label)"
                return t
            }
            var text = AssistantLese.kuerze(Array(rowItems), result.muster.count)
            if result.defekte > 0 { text += "\n(\(result.defekte) Einträge ließen sich nicht lesen.)" }
            return ToolRunResult(text: text)
        } catch {
            return ToolRunResult(text: "Bemusterung konnte nicht gelesen werden: \(error.localizedDescription)",
                                 isError: true)
        }
    }
}

struct ListZeitenTool: AssistantTool {
    private let store: ClockodoZeitTabelleStore?
    init(store: ClockodoZeitTabelleStore?) { self.store = store }

    var name: String { "list_zeiten" }
    var description: String {
        "Zeigt die eigenen, in Clockodo gebuchten Zeiten des gewählten Zeitraums mit Kunde, "
        + "Leistung und Dauer. Nur die eigenen Buchungen, nur lesen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "zeitraum", description: "heute, woche oder monat — Vorgabe: woche",
                       required: false)]
    }

    private struct RowEntry: Sendable { let text: String }

    func run(input: [String: String]) async -> ToolRunResult {
        guard let store else {
            return ToolRunResult(text: "Clockodo ist nicht angebunden — bitte in den Einstellungen verbinden.",
                                 isError: true)
        }
        let roh = (input["zeitraum"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let zeitraum = ClockodoZeitraum(rawValue: roh) ?? .woche

        let brauchtStammdaten = await MainActor.run {
            store.zeitraum = zeitraum
            return store.kunden.isEmpty || store.leistungen.isEmpty
        }
        if brauchtStammdaten { await store.ladeClockodoStammdaten() }
        await store.ladeGebuchteEintraege()

        let gelesen: (rowItems: [String], sum: Int, total: Int, error: String?) = await MainActor.run {
            let entries = store.gebuchteEintraege
            let sum = entries.reduce(0) { $0 + $1.dauerSekunden }
            let rowItems = entries.prefix(AssistantLese.rowItems).map { e -> String in
                let b = store.label(fuer: e)
                var t = "• \(AssistantLese.date.string(from: e.start)) | \(b.kunde) | \(b.leistung) | \(e.dauerText)"
                if let txt = e.text, txt.isEmpty == false { t += " | \(txt)" }
                return t
            }
            return (Array(rowItems), sum, entries.count, store.stammdatenFehler)
        }
        if gelesen.total == 0, let error = gelesen.error {
            return ToolRunResult(text: "Clockodo meldet: \(error)", isError: true)
        }
        guard gelesen.rowItems.isEmpty == false else {
            return ToolRunResult(text: "Für \(zeitraum.label) sind keine Zeiten gebucht.")
        }
        let stunden = String(format: "%.1f", Double(gelesen.sum) / 3600)
        let list = AssistantLese.kuerze(gelesen.rowItems, gelesen.total)
        return ToolRunResult(text: "\(zeitraum.label), gebucht: \(stunden) h\n" + list)
    }
}

struct ListBelegeTool: AssistantTool {
    private let speicher: SevdeskBelegRegisterSpeicher
    init(speicher: SevdeskBelegRegisterSpeicher = .init()) { self.speicher = speicher }

    var name: String { "list_belege" }
    var description: String {
        "Listet die in sevDesk angelegten Belege mit Belegnummer, Art, Projekt und Kunde. "
        + "Nutze es bei Fragen nach Angeboten, Rechnungen oder Belegnummern. Nur lesen, legt nichts an."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "projekt", description: "Optionale Projektnummer oder Kundenname als Filter",
                       required: false)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let q = (input["projekt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let alle = speicher.alle()
        let match = q.isEmpty ? alle : alle.filter {
            $0.projectNumber.lowercased().contains(q)
                || $0.belegnummer.lowercased().contains(q)
                || ($0.customersName?.lowercased().contains(q) ?? false)
        }
        guard match.isEmpty == false else {
            return ToolRunResult(text: q.isEmpty ? "Im Belegregister steht noch nichts."
                                                 : "Kein Beleg passt auf \"\(q)\".")
        }
        let sortiert = match.sorted { $0.angelegtAm > $1.angelegtAm }
        let rowItems = sortiert.prefix(AssistantLese.rowItems).map { e -> String in
            var t = "• \(e.belegArt) \(e.belegnummer) | \(e.projectNumber)"
            if let k = e.customersName, k.isEmpty == false { t += " | \(k)" }
            t += " | \(AssistantLese.date.string(from: e.angelegtAm))"
            return t
        }
        return ToolRunResult(text: AssistantLese.kuerze(Array(rowItems), match.count))
    }
}

struct VerfolgeSendungTool: AssistantTool {
    private let client: (any SendungsVerfolgend)?
    init(client: (any SendungsVerfolgend)?) { self.client = client }

    var name: String { "verfolge_sendung" }
    var description: String {
        "Fragt den Lieferstatus einer DHL-Sendung zu einer Sendungsnummer ab. Nur lesen."
    }
    var parameters: [ToolParameter] {
        [ToolParameter(name: "nummer", description: "Die Sendungs- oder Trackingnummer", required: true)]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        guard let client else {
            return ToolRunResult(text: "Die Sendungsverfolgung ist nicht angebunden — DHL-Schlüssel fehlt.",
                                 isError: true)
        }
        let number = (input["nummer"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard number.isEmpty == false else {
            return ToolRunResult(text: "Bitte eine Sendungsnummer angeben.", isError: true)
        }
        let sendung = Sendung(trackingNummer: number,
                              dienst: SendungsErkennung.erkenneDienst(number),
                              label: number)
        do {
            let verfolgt = try await client.verfolge(sendung)
            var text = "\(verfolgt.trackingNummer): \(verfolgt.status.label)"
            if let s = verfolgt.statusText, s.isEmpty == false { text += " — \(s)" }
            return ToolRunResult(text: text)
        } catch let error as SendungsFehler {
            return ToolRunResult(text: error.errorDescription ?? "Sendung konnte nicht abgefragt werden.",
                                 isError: true)
        } catch {
            return ToolRunResult(text: "Sendung konnte nicht abgefragt werden: \(error.localizedDescription)",
                                 isError: true)
        }
    }
}

struct ProposeTerminTool: AssistantTool {
    init() {}

    var name: String { "propose_termin" }
    var description: String {
        "Schlägt einen Termin im Google-Kalender vor. Du legst ihn NICHT selbst an — es entsteht "
        + "eine Bestätigungskarte, erst der Klick des Nutzers schreibt in den Kalender. "
        + "Nimm dieses Werkzeug statt suggest_calendar_event, wenn der Termin wirklich eingetragen werden soll."
    }
    var parameters: [ToolParameter] {
        [
            ToolParameter(name: "titel", description: "Titel des Termins", required: true),
            ToolParameter(name: "start", description: "Beginn als yyyy-MM-dd HH:mm oder yyyy-MM-dd für ganztägig", required: true),
            ToolParameter(name: "dauer", description: "Dauer in Minuten, Vorgabe 60 (bei ganztägig ohne Wirkung)", required: false),
            ToolParameter(name: "ort", description: "Ort des Termins", required: false),
            ToolParameter(name: "notiz", description: "Beschreibung", required: false),
            ToolParameter(name: "gaeste", description: "E-Mail-Adressen, mit Komma getrennt", required: false)
        ]
    }

    private static func kalender() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return c
    }

    private static func former(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        f.dateFormat = format
        return f
    }

    static func lese(_ roh: String) -> (start: Date, ganztaegig: Bool)? {
        let t = roh.trimmingCharacters(in: .whitespacesAndNewlines)
        if let mitZeit = former("yyyy-MM-dd HH:mm").date(from: t) { return (mitZeit, false) }
        if let nurTag = former("yyyy-MM-dd").date(from: t) { return (nurTag, true) }
        return nil
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let title = (input["titel"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            return ToolRunResult(text: "Es fehlt der Titel des Termins.", isError: true)
        }
        guard let gelesen = Self.lese(input["start"] ?? "") else {
            return ToolRunResult(text: "Beginn nicht lesbar — erwartet yyyy-MM-dd HH:mm oder yyyy-MM-dd.",
                                 isError: true)
        }
        let minuten = Int(input["dauer"] ?? "") ?? 60
        let ende: Date = gelesen.ganztaegig
            ? Self.kalender().date(byAdding: .day, value: 1, to: gelesen.start) ?? gelesen.start
            : gelesen.start.addingTimeInterval(TimeInterval(max(minuten, 5) * 60))

        let gaeste = (input["gaeste"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("@") }

        func gefuellt(_ key: String) -> String? {
            let v = (input[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }

        let draft = TerminDraft(title: title, start: gelesen.start, ende: ende,
                                ganztaegig: gelesen.ganztaegig,
                                ort: gefuellt("ort"), beschreibung: gefuellt("notiz"), gaeste: gaeste)
        return ToolRunResult(text: "Bestätigungskarte erzeugt: „\(title)“. Noch NICHT eingetragen.",
                             terminDraft: draft)
    }
}

struct ProposeWarenkorbTool: AssistantTool {
    private let katalog: ArtikelKatalogStore?
    private let lager: LagerlisteStore?

    init(katalog: ArtikelKatalogStore?, lager: LagerlisteStore?) {
        self.katalog = katalog
        self.lager = lager
    }

    var name: String { "propose_warenkorb" }
    var description: String {
        "Schlägt vor, einen Artikel in den Warenkorb zu legen. Du legst ihn NICHT selbst hinein — "
        + "es entsteht eine Bestätigungskarte, erst der Klick des Nutzers legt ab. "
        + "Der Artikel wird zuerst im Katalog, dann im Lager gesucht; ohne Treffer wird nichts vorgeschlagen."
    }
    var parameters: [ToolParameter] {
        [
            ToolParameter(name: "artikel", description: "Artikelnummer oder Bezeichnung, wie in search_katalog oder list_lager gefunden", required: true),
            ToolParameter(name: "menge", description: "Stückzahl, Vorgabe 1", required: false)
        ]
    }

    private enum Fund: Sendable {
        case katalog(label: String, number: String, ek: Double?, vk: Double?, recordID: String?)
        case lager(label: String, number: String, ek: Double?, vk: Double?, recordID: String?)
        case mehrdeutig([String])
        case keiner
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let search = (input["artikel"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard search.isEmpty == false else {
            return ToolRunResult(text: "Es fehlt der Artikel.", isError: true)
        }
        let quantity = max(Int(input["menge"] ?? "") ?? 1, 1)

        let fund: Fund = await MainActor.run {
            if let katalog, case .content = katalog.state {
                let match = katalog.search(term: search).prefix(5)
                if match.count == 1, let e = match.first {
                    let a = e.artikel
                    return .katalog(label: a.artikelbeschreibung ?? a.articleNumber,
                                    number: a.articleNumber, ek: a.ekNetto, vk: a.vkNetto,
                                    recordID: a.id)
                }
                if match.count > 1 {
                    return .mehrdeutig(match.map { $0.artikel.artikelbeschreibung ?? $0.artikel.articleNumber })
                }
            }
            if let lager, case .content = lager.state {
                let match = lager.items.filter {
                    $0.label.localizedCaseInsensitiveContains(search)
                        || ($0.articleNumber?.localizedCaseInsensitiveContains(search) ?? false)
                }.prefix(5)
                if match.count == 1, let p = match.first {
                    return .lager(label: p.label, number: p.articleNumber ?? p.id,
                                  ek: p.ekNetto, vk: p.vkNetto, recordID: p.id)
                }
                if match.count > 1 { return .mehrdeutig(match.map(\.label)) }
            }
            return .keiner
        }

        switch fund {
        case .keiner:
            return ToolRunResult(text: "Kein Artikel passt auf \"\(search)\" — weder im Katalog noch im Lager. "
                                 + "Es wird nichts vorgeschlagen.", isError: true)
        case .mehrdeutig(let namen):
            return ToolRunResult(text: "Mehrere Artikel passen auf \"\(search)\": "
                                 + namen.joined(separator: " · ") + ". Bitte genauer benennen.", isError: true)
        case .katalog(let b, let nr, let ek, let vk, let rec):
            let draft = WarenkorbDraft(label: b, articleNumber: nr, quantity: quantity,
                                       ekNetto: ek, vkNetto: vk, source: "katalog", artikelRecordID: rec)
            return ToolRunResult(text: "Bestätigungskarte erzeugt: \(quantity)× \(b). Noch NICHT im Warenkorb.",
                                 warenkorbDraft: draft)
        case .lager(let b, let nr, let ek, let vk, let rec):
            let draft = WarenkorbDraft(label: b, articleNumber: nr, quantity: quantity,
                                       ekNetto: ek, vkNetto: vk, source: "lager", artikelRecordID: rec)
            return ToolRunResult(text: "Bestätigungskarte erzeugt: \(quantity)× \(b) aus dem Lager. Noch NICHT im Warenkorb.",
                                 warenkorbDraft: draft)
        }
    }
}

struct ErzeugeDateiTool: AssistantTool {
    private let directory: ProjectDirectory?
    init(directory: ProjectDirectory?) { self.directory = directory }

    var name: String { "erzeuge_datei" }
    var description: String {
        "Schlägt vor, eine Datei zu erzeugen — Text, Tabelle (CSV) oder PDF. Du schreibst sie NICHT "
        + "selbst: es entsteht eine Bestätigungskarte, erst der Klick des Nutzers legt sie an. "
        + "Sie landet im Datenordner der App; mit 'projekt' wird sie zusätzlich in den Drive-Ordner "
        + "dieses Projekts gelegt. Für CSV und für PDF-Tabellen: Spalten mit Semikolon trennen, "
        + "eine Zeile je Datensatz, die erste Zeile ist die Kopfzeile."
    }
    var parameters: [ToolParameter] {
        [
            ToolParameter(name: "dateiname", description: "Name ohne Pfad, z. B. Materialliste", required: true),
            ToolParameter(name: "format", description: "text | csv | pdf", required: true),
            ToolParameter(name: "inhalt", description: "Der vollständige Inhalt der Datei", required: true),
            ToolParameter(name: "titel", description: "Überschrift im PDF; ohne Angabe der Dateiname", required: false),
            ToolParameter(name: "projekt", description: "Projektnummer, wenn die Datei auch ins Projekt soll", required: false)
        ]
    }

    func run(input: [String: String]) async -> ToolRunResult {
        let name = (input["dateiname"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            return ToolRunResult(text: "Es fehlt der Dateiname.", isError: true)
        }
        let rohFormat = (input["format"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let format = DateiDraft.Format(rawValue: rohFormat) else {
            return ToolRunResult(text: "Unbekanntes Format „\(rohFormat)“ — erlaubt: text, csv, pdf.",
                                 isError: true)
        }
        let content = input["inhalt"] ?? ""
        guard content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return ToolRunResult(text: "Eine leere Datei wird nicht angelegt.", isError: true)
        }

        var projectNumber: String?
        let gewuenscht = (input["projekt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if gewuenscht.isEmpty == false {
            guard let match = directory?.resolve(gewuenscht) else {
                return ToolRunResult(text: "Kein Projekt passt auf „\(gewuenscht)“ — ohne Projekt "
                                     + "kann die Datei nicht abgelegt werden.", isError: true)
            }
            guard let folder = match.driveFolderID, folder.isEmpty == false else {
                return ToolRunResult(text: "Projekt \(match.projectNumber) hat keinen Drive-Ordner "
                                     + "hinterlegt — die Datei kann dort nicht abgelegt werden.",
                                     isError: true)
            }
            projectNumber = match.projectNumber
        }

        let title = (input["titel"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = DateiDraft(fileName: name, format: format,
                               title: title.isEmpty ? name : title,
                               content: content, projectNumber: projectNumber)
        let wohin = projectNumber.map { " und ins Projekt \($0)" } ?? ""
        return ToolRunResult(text: "Bestätigungskarte erzeugt: \(draft.vollerName)\(wohin). Noch NICHT angelegt.",
                             dateiDraft: draft)
    }
}
