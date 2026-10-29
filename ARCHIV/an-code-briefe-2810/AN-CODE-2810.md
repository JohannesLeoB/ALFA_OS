# Design → Code · Was Design braucht · 28.10.2026
Arbeitsstand, nicht freigegeben (CLAUDE.md: kein Paket ohne Johannes). Lieferschein: contract/LIEFERUNG.json, 33 von 44 erledigt. Repo gelesen: CLAUDE.md, App/Shell/AssistantPanel.swift, Sources/Hub/Model/IntegrationReading.swift (Stand main 06725b4, 28.10. 13:30 Z).

## Neu erledigt seit 28.10. früh
- T5 Logos: jeder Dienst hat ein Zeichen im Ring. Dateien material/icons/: google.svg (flaches G aus Googles Anmeldeknopf), clickup.svg, claude.svg (Zeichen auf color.claudeClay), airtable.png, sevdesk.png (auf color.sevdeskRed), clockodo-kreis.png (freigestellt, auf color.clockodoBlue), dhl.svg (auf color.dhlYellow), happa.svg und mailkonten.svg (eigene Zeichen von Design). Originale: material/logos/<dienst>/. Größen je Ort: ALFA Einstellungen.dc.html (LOGOS, HL, lw, LS), ALFA Dienste.dc.html (lw, lwRow, lwStrip).
- N38: alle drei Teile gezeichnet — Assistent ganz aus = Karte im Blob (ALFA Shell, „Der Assistent ist ausgeschaltet.“, gleich eurem AssistantPanel.offCard); Abgleich je Bereich = Einstellungen, Dienst › „Abgleich“ (passt zu AreaReading: area, lastSync, choice, running); Zeit im Tooltip des Abgleich-Knopfs: siehe Frage C1.
- N43: geschlossen. releaseSpan und pointerStep bleiben Rechenschutz im Code, kein Token (euer Wort 27.10.).

## A · Was Design von Code braucht, um zu zeichnen (je Punkt: welche Daten, woher)
A1 N27 Katalog: Liste der Kategorien je Dienst (IntegrationInfo hat sie?) und welche Filter es real gibt. Ohne Liste zeichnet Design keine Filter.
A2 N28 Verwalten je Dienst: welche Felder kann die App lesen und schreiben? Clockodo (Nutzer, Leistung, Kostenstelle, Kunde, abrechenbar), Airtable (Basen, Tabellen, Felder). Bitte je Feld: lesen oder schreiben, Typ, Beispielwert aus einer echten Antwort.
A3 N29 Mitteilungen: was ist je Dienst meldbar (Art, Takt)? Gibt es „global stumm“ schon im SettingsState? Schlüssel nennen.
A4 N30 Dateiorte: wo legt die App Projektordner, Vorlagen, Anhänge ab, und was ist davon wählbar? (Bogen: Einstellungen › Dateiordner, Ordnerschema, Vorlagen; Drive › Projektordner.)
A5 N31 Detailbericht: welche Felder liefert ein Fehler wirklich (Status, Code, Servertext, Anfragekennung, Zeitpunkt)? Bitte ein echtes Beispiel je Dienst, ohne Geheimnisse.
A6 N33 Kontakte: welche Quellen kann die App heute lesen (Google Contacts, iCloud, lokale DB)? Mehrere zugleich?
A7 N15 Aus Projektordner: Quelle der Projekte, Ebenen (Projekt › Ordner › Datei), Höchstzahl, Fehlertexte (spec-mail F28 aus dem Archiv). Design zeichnet danach Leer, Laden, Fehler, Ebenen.
A9 Fähigkeiten je Provider: Liste je Postfach-Art (Google, IMAP, weitere), was technisch geht: Verschieben, Original anzeigen, Später senden, Lesebestätigung, Vorlage, Formatierung. Design blendet danach ein und aus.
A10 Absendername: neue Zeile je Postfach in Einstellungen („Absendername“, Platzhalter = Name der Person; ALFA Einstellungen senderRow; Text settings.account.senderName). Bitte Schlüssel im SettingsState und Verwendung im Absender des Entwurfs (Name <adresse>).
A8 „Name in Mail“: ihr schreibt, die Zeile braucht einen editierbaren Postfachtitel. Bitte den Schlüssel im SettingsState nennen; Design hat die Zeile (Einstellungen, Postfach › „Name in Mail“).

## B · Was Design von Code prüfen lassen will
B1 Laufende App gegen Bögen: Assistent-Chat, Postfach-Stapel, Einstellungen. Bitte je Bereich ein Bildschirmfoto hell und dunkel an Design (eure CLAUDE.md, Next tasks 3).
B2 Logos: kommen die neuen Dateien aus material/icons/ in Assets.xcassets? Clockodo bitte aus clockodo-kreis.png (die alte clockodo.png hat weiße Ecken).
B3 Werkzeuglücke Design: apply.js schreibt neue Themenfarben nur in Vertrag und TOKENBOGEN, nicht in alfa-theme.css. Für euch ohne Folgen (tokens.json kommt aus contract/).

## C · Fragen an Code
C1 Tooltip Abgleich-Knopf: im Bogen fest „Neu laden · Gerade abgeglichen“. Bitte aus lastSync rechnen („vor 3 Minuten“, „um 14:02“); welches Format nutzt ihr? Design übernimmt es.
C2 Blob-Punkt F10: ihr zeigt ihn, wenn eine Antwort fertig ist und der Assistent zu ist. Design gleich (HUELLE-F10/F11). Wie lange bleibt er (bis Öffnen)?

## D0 · Entschieden
T6 Kartenstapel 8a/8b: keine Wahl in den Einstellungen. Es gilt Johannes 21.10. „Cardstacks sind nicht gut geeignet hier als Bauteil“, „keine cardstaks hier“ (entscheidungen.md:342), weil er danach nichts anderes gesagt hat (28.10.). Mail behält die Vorgabe 8a gestaffelt; 8b bleibt nur Entwurfsvariante im Bogen, keine Einstellung für die Person.

N26 Ordnung der Einstellungen: bleibt wie im Bogen, nach Gegenstand (Ich, Firma, Dateiordner, Verbindungen, Schutz und System) — Johannes 28.10. „bleibt wie im bogen“. Kein Baum nach Zugehörigkeit.
N20 Mail-Funktionen: Johannes 28.10.: alle realen Funktionen und die gängigen jedes Mail-Programms vorsehen und einbauen.
- Real bei euch (Sources/Mail/State, main 2c25dc2): Verfassen, Antworten, Allen antworten, Weiterleiten, Entwurf sichern/verwerfen/bearbeiten, Senden, Anhängen (Datei, aus Projektordner), Als PDF in Projektordner, Archivieren, Löschen, Endgültig löschen, Wiederherstellen, Als Spam, Verschieben (Port move), Gelesen/Ungelesen, Markieren, Flags, Bilder laden, Empfänger aufklappen; Draft hat cc, bcc, bodyHTML.
- Gängig, im Bogen vorgesehen, bei euch noch ohne Funktion (bitte bauen): Lesekarte › Verschieben nach … (Ordnerliste), Original anzeigen (Quelltext der Mail); Entwurf › Später senden …, Lesebestätigung anfordern, Als Vorlage sichern; Formatleiste Fett, Kursiv, Unterstrichen, Aufzählung, Nummerierung, Zitat, Link, Format entfernen (in bodyHTML). Drucken = macOS-Druckdialog.
- Gestrichen: „Notiz anfügen“ (kein Mail-Standard, keine Funktion bei euch).
- Bisher galt bei euch „Menüeinträge ohne Funktion bleiben weg, bis sie gehen“ (CLAUDE.md): jetzt bitte bauen statt weglassen.
- Johannes 28.10.: „Das muss natürlich immer auch nur in der UI sein, wenn es der jeweilige Mail Provider auch technisch vorsieht.“ Regel: jeder dieser Einträge erscheint nur, wenn das Postfach ihn technisch kann; sonst fehlt er ganz (nicht ausgegraut). Bogen: ALFA Mail, CAPS und can(f) je Fähigkeit move, original, later, receipt, template, format; Tweak „provider“ Google | IMAP | Alles an.
- Annahme Design, bitte je Provider bestätigen oder berichtigen (A9): Google und IMAP können Verschieben, Original, Lesebestätigung (Kopfzeile Disposition-Notification-To), Vorlage (lokal), Format (HTML); „Später senden“ im Bogen bei beiden aus, weil kein Server-Versand zur Zeit bekannt ist. Wenn ihr Später senden über einen eigenen Ausgang der App baut, schaltet es ein.

N35 Lage der Meldung (Toast): Johannes 28.10. „was ist global die beste Option? diese bauen.“ Festlegung Design, gilt in allen Bereichen:
- Ort: in der Bahn, in der die Handlung geschah, mittig über dem Fuß der Bahn (Mail: bottom = size.footerHeight + spacing.step8). Nicht an den Blob gebunden, nicht am Fensterrand.
- Ebene: über dem Inhalt, unter Menü und Blob — layer.toast 4 < layer.menu 5 < layer.blob 6 (Vertrag). Der Blob ist das Werkzeug der Person und bleibt immer greifbar; eine Meldung darf ihn nie verdecken. Liegt der Blob über der Meldung, bleibt die Meldung trotzdem lesbar daneben, weil sie in der Bahn sitzt und der Blob am Rand.
- Grund: Rückmeldung gehört an den Ort der Handlung (Apple HIG, Material „Snackbar über dem schwebenden Knopf, nicht darunter versteckt“); ein dauerhaftes Bedienteil hat Vorrang vor einer flüchtigen Meldung.
- Euer Bau „unter dem Blob“ (Ebene) ist damit richtig; bitte den Ort je Bahn übernehmen, falls er bei euch am Fenster hängt.

Assistent ohne Projekt: Johannes 28.10. „assistent hat nichts mit projekt/ohne Projekt zu tun, bitte De-Sloppen“. Im Bogen ist die Zeile „Ohne Projekt“ unter dem Chat gestrichen (ALFA Shell, assistant-scope zeigt nur noch „Verlauf löschen“, und nur wenn es einen Verlauf gibt); Text shell.assistantScope.home aus dem Vertrag entfernt. Bitte bei euch: AssistantScope ohne Beschriftung (ConversationScope .home/.project nicht anzeigen), nur der Löschen-Knopf bei Verlauf.

## D · Offen bei Johannes (nicht an Code)
eigener Name einer Hauptadresse im Absender.
