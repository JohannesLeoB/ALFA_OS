Export: 21.10.2026

# ALFA · Spezifikation (Wort für Wort in Funktion übersetzt)
Stand 21.10.2026. Dies ist die einzige Sammlung der App-Anforderungen. Der Wortlaut von Johannes liegt nur in `entscheidungen.md`, die maschinenlesbaren Entscheide in `lieferung-an-code/decisions.json`. Quelle je Punkt in Klammern: Datum oder Datei. Was nicht belegt ist, steht unter „Offen“.

## 1 · Grundsätze
- Mail und Einstellungen sind der Hub der App. Projekte, Heute, Kataloge definiert Johannes später (19.10.).
- Hülle, Blob, Abgleich, Personenmarke, Bahnen, Griffe, Abstände und Radien gibt es genau einmal. Jede Änderung gilt sofort in allen Bögen, die daraus gebaut sind (CLAUDE.md).
- Code übernimmt alle Maße aus dem Entwurf (17.10.). Der neueste Export gilt und muss vollständig sein (18.10.).
- Jeder Wert ist ein Token. Lose Zahlen in Bögen gelten als nicht geliefert (Brief v10, A1).
- Unter der Oberfläche heißt alles englisch. Sichtbare Texte kommen zentral aus einem Textsystem (Deutsch, später Englisch) (18.10.).
- Kein ZIP und kein Download vor Johannes' „100 % sauber“ (CLAUDE.md).

## 2 · Hülle und Bahnen
- Drei Bahnen: links Ordner und Postfach, Mitte Liste, rechts Karten. Die rechte Bahn wächst, die Mitte kann wachsen. Ob eine Ansicht gesperrt ist, entscheidet Johannes später; vorgesehen ist ein Schalter je Ansicht, Standard offen (16./17.10.).
- Der Blob sitzt oben links und liegt über Menü und Toast. Er öffnet das Menü, in dem der Assistent als Orb wohnt. Der Assistent wird später ein voller Bereich mit Menüeintrag (16.10.).
- Oben rechts sitzt der Abgleich-Knopf mit den Initialen der Person.
- Griffe sind Haarlinien mit 12 Treffer-Fläche (16.10.). Menübreiten folgen dem 56er-Raster.
- Der Stapel der Karten zeigt gestaffelt die offenen Mails und Entwürfe. Eine Übersicht zeigt sie als Kacheln, wahlweise den Stapel oder den ganzen Ordner, in drei Größen. Die Steuerung der Übersicht (Stapel, Ordner, Klein, Mittel, Groß) sitzt als Symbolknöpfe im Kopf der rechten Bahn (21.10.).
- Der Wechsel zwischen Stapel und Übersicht darf nicht anstrengen: keine springenden Karten, sanfte Überblendung (21.10.).
- Die Zahl der Spalten in der Übersicht folgt der Breite der Bahn. Die Kachelhöhe bleibt je Größe fest.

## 3 · Mail
- Die gewählte Zeile in Liste, Bahn und Stapel ist dunkel (Fläche `inverse`, Schrift `onInverse`), nicht grau (21.10., gemäß Kontrastprotokoll 19.10.).
- Mehrere Konten (bis drei) sind per Klick auf „Postfach“ wählbar, schmal und ruhig (19.10.).
- Signatur: je Postfach eine eigene (Beispiel johannes@, accounting@, info@). Anlegen, Bearbeiten und Entfernen in der Konto-Karte der Einstellungen, in Mail wird nur gewählt (20.10.). Optionen je Signatur: unter neue Mails setzen, über zitiertem Text setzen. Die Vorlage ist die Signaturen-Ansicht von macOS Mail.
- Initialen in Marken und Ringen sehen überall gleich aus: Geist, 11,5, Gewicht 500, Laufweite 0,06 em (21.10.).
- Fehler und Nachladen: Der Master zeigt Fehler nur für Liste, Verbindung, Senden und Abgleich. Archivieren, Verschieben, Papierkorb, Markieren, Lesen, Anhang, Verlauf, Entwurf speichern und Postausgang brauchen eine Darstellung. „Mehr laden“ ist gezeichnet, aber nie aktiv (Brief v10, N7).
- „Mail zu groß“ und ein Sofort-Abgleich (IDLE) brauchen Hinweis und Text oder die Angabe, dass sie unsichtbar bleiben (Brief v10, N4, N5).

## 4 · Einstellungen und Hub
- Gruppen: Ich, Firma, Verbindungen, Schutz und System.
- Kartenstapel gibt es in den Einstellungen nicht (21.10.). Ein Eintrag öffnet genau eine Karte in der rechten Bahn und ersetzt die vorige; es gibt keine Übersicht. (Meine Umsetzung, die Form hat Johannes nicht genannt.) Die Karte hat keinen Kopf (kein Titel, keine Marke, kein Schließen); die Auswahl links zeigt, welche offen ist. Mail behält den Stapel.
- Abmelden („Auf diesem Mac abmelden“) trennt alle verbundenen Dienste, mit denen die Person verbunden ist oder war, und startet die App neu. Text: „Trennt alle verbundenen Dienste und startet die App neu.“ (20.10.).
- Im Code löscht das Abmelden heute zusätzlich die Mails der Dienste samt Postausgang. Code hält fest, Johannes habe am 20.10. 22:08 auf die Frage „Warnung mit Zahl der ungesendeten Mails, Name, Firmendaten und Darstellung bleiben“ mit „lets go“ geantwortet. Johannes erinnert das nicht (21.10.). Code hat den Brief am 22.10. neu gefasst (Sync 22.10. 01:01 UTC): Die Zeile „alle abmelden“ nennt Aufzählung und Zahl der verbundenen Dienste; ob vorher gewarnt wird und was mit ungesendeten Mails geschieht, entscheidet Johannes, bis dahin wird dazu nichts gezeichnet (BRIEF.txt N2). Offen bei Johannes: Warnung vor ungesendeten Mails ja oder nein.
- Zustände von Diensten: Verbunden, Gleicht ab, Verbindet, Nicht verbunden, Fehler, Schlüssel gespeichert, Schlüsselbund nicht lesbar. „Verwaist“ gibt es nicht mehr (20.10.).
- Die Zahl der Dienste wird nicht angezeigt (20.10.).
- Konto hinzufügen und entfernen, Vorlage entfernen, „Jetzt abgleichen“ mit Rückmeldung: gebaut, nicht abgenommen.

## 5 · Integrationen
- DHL ist eine Integration mit einer Karte. Felder: Tracking-Schlüssel, Versand-Schlüssel, Secret, Benutzer, Passwort, Abrechnungsnummer. Kein Sandbox-Schalter, der Betrieb ist live. Aufgaben: Sendung verfolgen, Etikett kaufen und drucken (20.10.).
- Happa Happa liefert den Speiseplan der Kantine über eine Schnittstelle (Bilder und Daten). Fotos kommen erst ab etwa 11 Uhr, davor Platzhalter. Anzeige: Gericht, Beschreibung, Foto, Preis. Kein Gästepreis. Eine Vollansicht ist nicht dringend (20.10.).
- KI-Integrationen (Claude und folgende): Modellwahl aus der Anbieterliste, Zähler der Tokens seit einem Datum mit Zurücksetzen, ein Schätzwert aus eingetragenem Preis je Million Tokens (Johannes: 50-Cent-Schritte genügen), kein Guthaben (20.10., Brief v10 N6).
- Logos fehlen für Google, Mail-Konten, ClickUp, Claude, Airtable, sevDesk und Happa Happa (Material von Johannes nötig).

## 6 · Heute und Widgets
- „Heute“ ist die Startseite der App und noch nicht entworfen. DHL und Happa Happa werden dort Widgets (20.10.).
- Ein Widget ist nur wählbar, wenn sein Dienst erfolgreich verbunden ist. Ohne Verbindung oder ohne Schlüssel gibt es kein Widget (20.10.).
- Ein laufendes Widget zeigt keine Statusanzeige. Nur bei einem Problem erscheint ein Haarring mit Ausrufezeichen in Signalfarbe. Keine Erklärtexte in der Oberfläche (20.10.).
- Gezeichnet sind: DHL Verfolgen, DHL Etikett kaufen, Happa Happa heute (vor und nach 11 Uhr), Woche, Detail, Widget-Wahl.
- Das Code-Gedächtnis führt „Widgets gestrichen (11.10.)“, hat „Heute“ aber am 20.10. gegen Johannes' Ansage nachgetragen (siehe Abschnitt 12). Die Ansage vom 20.10. gilt.

## 7 · Farbe, Glas, Schrift, Bewegung
- Der harte Schwarz-Weiß-Kontrast soll sich lösen. Vorgabe: eine Leiter von Weiß über Grau bis Schwarz, dazu höchstens vier bis sechs matte Boldfarben, anfangs ohne Blau, Liquid Glass nicht selbst farbig, keine vollfarbigen Knöpfe auf neutralen Flächen (20./21.10.). Alles dazu ist Exploration (`ALFA Farbleiter.dc.html`): Export gesperrt, nicht baurelevant, nicht im Tokenbogen, bis Johannes es freigibt. Runde 1 (mit Blau) ist verworfen. Runde 2, keine Wahl: 2a Erde·Oxblut (#420f0e, #7e2b33, #9c3e17, #c58a00, #bc927a), 2b Zypresse·Terrakotta (#263e16, #71382d, #955341, #b36924, #ccae72), 2c Mauve·Kakao (#76453c, #7e2b33, #9c3e17, #b36924, #a08e9c). Neutrale Leiter 0 bis 1000: #ffffff, #f2f2f7, #e5e5ea, #d1d1d6, #c7c7cc, #aeaeb2, #8e8e93, #636366, #48484a, #3a3a3c, #2c2c2e, #1c1c1e, #000000 (nach Kenntnis der Apple-Systemgrautöne, nicht gelesen). Hex der Farben aus den Bildern gemessen. Wiederaufnahme nur nach Widerruf: erst Johannes fragen, dann `TOKENBOGEN.json`, `alfa-theme.css`, Bögen, `contract/` neu erzeugen, Kontrast prüfen (Text 4,5:1).
- Der Blob und der Abgleich-Knopf nutzen `inverse` hell (#171717). Der Wert #3d3d3d ist zurückgenommen (21.10.).
- Glas folgt `surface.glass` aus dem Tokenbogen, Radius 20.
- Laufweiten: im Tokenbogen drei Tokens (`control` 0,01, `mark` 0,06, `title` −0,02), im Vertrag `contract/` noch fünf (dazu `markSmall`, `orbInitials`). Initialen überall `mark`. ALFA Dienste weicht noch ab.
- Bewegung: Federn und Dauern stehen in `motion.*` und `motion-springs.json`. Die neuen Werte des Stapel-Übergangs (200, 240, 300 ms, 8 und 10 px, 24 ms Staffel) sind noch keine Tokens.

## 8 · Verhalten und Maße (aus den Rückgaben 16. bis 19.10.)
**Bahnen und Griffe**
- Seitenbahnen links und rechts sowie die Mitte haben je mindestens 280. Die Bahnen laufen als Akkordeon: zuerst schrumpft die rechte, dann die linke, dann faltet rechts, dann links; die Mitte gibt nie nach. Gefaltet ist eine Bahn 56 breit, unter 112 faltet sie.
- Ein Doppelklick auf eine gefaltete Bahn öffnet sie auf Ruhebreite 280. Ein Symbol in der gefalteten Bahn öffnet genau diesen Eintrag samt Bahn.
- Griffe sind Haarlinien, 1 breit, 64 lang (aktiv 2 breit, 96 lang).
- Blob in Ruhe 56 × 40, wach mindestens 124; passt der Bereichsname nicht, springt er auf 280. Das Auge ist 4 × 8, Abstand 4. Der Blob weicht der Maus nicht aus, die Augen folgen ihr.
- Symbolknöpfe sind rund, 28. Der rechte Innenrand im Kopf ist 8. Leiste über den Bahnen: Blob 40, 12 Abstand, Bahnen ab 52.
- Radien: Bahn und Karte 20 (unten 0, Karte bündig mit dem Kopf), Zeile 12, Kapsel 999, Hinweis 8, Feld 4. Stapel-Bewegung 520 ms.
- Fenster: Die App läuft im Vollbild. Eine Mindestgröße ist nicht wichtig, Code folgt der Apple-Praxis.
- Eine dünne Linie unter dem Kopf erscheint nur beim Scrollen, langsam ein und im Ruhezustand wieder aus.

**Kacheln (Einstellungen)**
- Kacheln gibt es nur unter „Verbindungen“, mit Logo oder Initial des Dienstes und dem Zustand. Andere Gruppen sind Listen. Kachelhöhe 112, Radius 12, in Ruhe ohne Kante, beim Überfahren ein Schatten, beim Drücken 0,98, die Kachelreihen rasten ein, der Gruppentitel steht im Kopf.

**Löschen und Bestätigen**
- Mails löschen geht ohne Rückfrage, mit Rückgängig 4 Sekunden lang (Toast), das Ziel ist der alte Ordner. Trennen und Konto löschen laufen über die Bestätigen-Pille: 1 Sekunde halten, der Knopf wird von links wegradiert und zittert zum Ende, der Ja-Knopf sitzt dort, wo der Klick war, und behält seine Größe, Tooltip wie bei macOS („Halten zum …“).
- „Verschieben nach …“ ist eine Liste mit Ordnern und Labels.

**Mail**
- Mehrfachauswahl: Marke anklicken, im Kopf stehen „n gewählt“, Alle wählen, Gelesen/ungelesen, Archivieren, Papierkorb, Aufheben, Rückgängig.
- Kein Impressum an jede Mail. Bilder laden schaltet jede Person in den Datenschutz-Einstellungen an oder aus.
- Mitteilungsoptionen liest Code aus den Dokumentationen der Dienste. Team: nur Anzeige Persönlich und Firma. Das Impressum liefert Johannes.

**Namen und Tokens**
- Tokens kommen nur von Design. Code bestimmt die Namen unter der Oberfläche, Design übersetzt. Zustandswörter der Dienste: Verbunden, Gleicht ab, Verbindet, Nicht verbunden, Fehler, Schlüssel gespeichert, Schlüsselbund nicht lesbar.
- Die Schrift ist Geist, lokal (300, 400, 500, 600 über die Variable Datei). Keine Monoschrift.
- Fläche: flach. Lack und Glas später. Die Stimmungsfarben (Koralle, Aprikose, Rose) bleiben für Stapel und Typen.

## 9 · Weitere Anforderungen und Arbeitsweise
**Assistent und Blob**
- Der Assistent hat die Zustände Ruhe, Eingabe, Denkt, Verlauf und Fehler (Entwurf in `ALFA Entscheidungen` 7, nicht gebaut, nicht abgenommen). Heute gibt es einen Mini-Chat per Doppelklick auf den Blob. Der Assistent bekommt später einen vollen Bereich mit Menüeintrag.
- Eine Lupe soll ein Maßband ausfahren (Johannes' Idee vom 13.10., der Entwurf liegt nicht im Projekt). „Blob anheften“ ist ungeklärt: Im Bogen gibt es den Knopf „Anheften · bleibt im Stapel“, der eine Karte im Stapel festhält.
- Keine Navigation von Mail zu Einstellungen.

**Konto-Wähler**
- Ein Klick auf „Postfach“ entfaltet den Kopf der linken Bahn, die Marken fächern auf, die gewählte ist gefüllt, dazu „+“. Esc oder ein Klick daneben schließt. Offen: Kontrast hell und dunkel, lange Adressen, Bedienung mit echter Maus, Abnahme.

**Arbeitsweise Design**
- Belege vor jeder Aussage: Datei und Zeile oder Wortlaut. Ohne Beleg gilt ein Wert als von Design gesetzt.
- Messen statt „lädt fehlerfrei“. Vor „fehlt“ in allen Dateien unter mehreren Namen suchen.
- Bewegung lässt sich nur mit echter Maus bestätigen. Beim Messen Übergänge abschalten.
- Neuen Vertrag erst nach Sicherung des vorigen Standes erzeugen, danach die drei Prüfläufe (P1 gültig, P2 stimmig, P3 Protokoll). Werkzeuge liegen in `contract-build/`.
- Jede Ansage von Johannes sofort in `decisions.json` und `entscheidungen.md` eintragen.
- Code baut nur, was der Master zeigt. Er liest die Änderungen seit dem 18.10. erst nach Johannes' „raus“.

## 10 · Regeln der Oberfläche und Grenzfälle
- Keine Monoschrift. Keine Zahlen in Ringen. Keine ⌘-Kürzel in der Oberfläche. Farbe nie auf Aktionen; Signalrot nur für Destruktives. Fremde Inhalte (Mail, PDF, Bild) werden nie eingefärbt und bleiben weiß, auch im Dunkeln. Tooltips sind der System-Titel. Keine farbigen Kanten an Elementen (17.10.).
- Keine Erklär- und Meta-Sätze in der Oberfläche (unter Knöpfen, Zeilen, Karten, die beschreiben, was etwas tut). Erlaubt sind Fehler- und Warntexte; nichts kommt in die UI, was nicht funktionsbedingt ist (21.10.). Ein Hinweis „Drive-Freigabe fehlt“ wird nicht gezeichnet (Brief v12 N18 entfällt).
- Lange Inhalte: Der Betreff in der Liste hat eine Zeile mit Ellipsis und trägt den Volltext als Titel. Adressen und Dateinamen werden in der Mitte gekürzt (Anfang und Ende bleiben). URLs im Mailtext brechen um. Wo gekürzt wird, steht der Volltext im Titel.
- Eine Mail-Liste mit 1.284 Einträgen lädt in 120er-Schritten beim Scrollen. Ob sie virtualisiert oder paginiert wird, ist offen (Empfehlung: virtualisieren).
- Markup für Zeile, Kartenkopf, Kartenfuß, Menü und Toast steht in Mail und Einstellungen je einmal, Logik und Bausteine gemeinsam in `alfa-bausteine.js`. Ob daraus Kind-DCs werden, ist offen.
- Kontrast: Text mindestens 4,5:1, hell und dunkel, gemessen für Mail (17 Zustände) und Einstellungen. Nicht gemessen: Hover, Fokusring, Symbole ohne Text, dunkle Zustände mit Schlimmstem Fall.

## 11 · Was Code gebaut hat und was Design fehlt (stand.md ganz gelesen, 21.10.; Wortlaut für Brief v11 geht zuerst an Johannes)
**Gebaut und von Johannes bestätigt (Code, 19. bis 21.10.)**
- Hülle, Bauteile, Einstellungen und Mail nach Master 1810. Mail und Einstellungen sind der Hub, Projekte, Heute und Kataloge definiert Johannes später (19.10.).
- Sechs Dienste mit Prüfung beim Anbieter: ClickUp, Clockodo, Claude, Airtable, sevDesk, DHL Sendungen. DHL Versand und Happa Happa sind noch ohne Anbindung.
- IMAP mit IDLE je Konto (Gmail bleibt beim Takt), Postausgang mit Wiederholen, kein doppeltes Senden.
- Entwürfe: Bearbeiten behält „Nicht gesendet“, Verwerfen löscht auch auf dem Server, Senden ohne Empfänger oder Betreff zeigt den Hinweis „Empfänger fehlt“.
- Startansicht (Mail, Einstellungen, Zuletzt offen), „Bilder in Mails laden“ (Vorgabe aus), HTML-Mail mit echtem Inhalt auf hellem Blatt, Fremdes gesperrt bis zur Freigabe.
- Suche beim Tippen über alle Ordner außer Spam und Papierkorb, Server erst mit Enter.

**Lücken im Master, die Design zeichnen oder entscheiden muss**
- **Takt „Sofort“** fehlt (Brief v10 N5). **Gmail „zu groß“**: kein eigener Hinweistext (N4).
- **Nachladen und Aktionsfehler** (Archivieren, Verschieben, Papierkorb, Markieren, Postausgang): „Mehr laden“ ist gezeichnet, nie aktiv; die Liste endet bei 50. Unlesbare Postausgang-Zeilen und lokale Speicherfehler sind unsichtbar (N7).
- **App-Sperre:** gesperrter Zustand fehlt (Überlagerung, Entsperren, Fehlschlag).
- **Texte:** „Bild blockiert“ (:977), „Betreff leer“. In `INHALT.json` sind „Externe Bilder“ (bilder) und „Mail-Bilder“ (mbilder) derselbe Schalter.
- **Mail-Schrift:** Token sagt Geist zuerst, das Blatt der HTML-Mail zeigt die Systemschrift. Was gilt, ist offen.
- **Karte nach Senden:** Der Master entfernt sie, die App behält sie als „gesendet“. Der Master bindet `status` (:1000) nirgends.
- **Kachelhöhe:** Johannes 112, der Master zeichnete 96. Gilt 112 (19.10.).
- **Fensterhöhe 244** hat Code selbst gewählt (kein Master-Token). Johannes soll entscheiden.
- **Ohne Wirkung, weil der Bereich fehlt:** Assistent aus, Chat-Dateien, Geburtstage, Rolle, Kürzel, Telefon.

**Entscheide von Johannes, die Design betreffen**
- **Konten:** Mehrere Mail-Konten, Design liefert, tendenziell als Wähler (19.10.). Firmendaten und Impressum trägt die Person selbst ein. Fokusring-Abstand entscheidet Design.
- **Kartei (19.10.):** „Beide als Einstellung“, gestaffelt (8a, Vorgabe) oder Turm (8b). Am 21.10. gilt für die Einstellungen „keine Cardstacks hier“. Die Einstellung für Mail bleibt zu klären.
- **Dummy-Abschnitte nicht bauen** (16.10.): Tastenkürzel, Backups, Tagebuch, Werkstattfaktoren, Mitteilungen.
- **Hub als Wurzelwerk (20.10.):** Integrationen als Daten, Ein- und Ausgänge, Mail als erster voller Anbinder. DHL und Happa Happa kommen als Widgets oder Ansichtsteile, die Design zeichnet.
- **KI-Karte:** Modellwahl, Token-Zähler mit Zurücksetzen, Schätzwert aus eingetragenem Preis, kein Guthaben.
- **Sprache:** Unter der Oberfläche alles englisch, sichtbare Texte zentral aus einem Textsystem (Deutsch, später Englisch).
- **Microsoft 365** ist nicht relevant bis Ende November. Google: etwa 10 bis 20 Testpersonen, Solo-Entwickler, kein Markt.

**Stand der Übergabe**
- Brief v10 liegt in `DESIGN/brief/BRIEF.txt`, ist aber noch nicht an Design gegangen. N2 wird nach Johannes' Wort neu geschrieben. N8 („Heute“ fehlt in „Beim Öffnen“, `ALFA Mail.dc.html:762`) wartet auf sein Ja.
- Widerspruch: Code führt „Heute und Widgets gestrichen“ (11.10.: „Widgets sind JETZT kein Thema“). Johannes' Ansage vom 20.10. ist neuer.
- Zitate in den `app-*.md` von Code sind zu fast der Hälfte (21 von 44) im Korpus nicht belegt. Sie zählen hier nicht als Spec.

## 12 · Funktionen und Entscheide aus dem Code-Gedächtnis (alle Dateien in .claude/memory gelesen, 21.10.)
**Ziel und Reichweite**
- Erstes Ziel gestuft: Ende November Umfang C ohne Kalkulation, Launch Ende 2026 mit dem Rest. Hub, Einstellungen und Mail stehen vorn, die übrigen Bereiche definiert Johannes später.
- Die App ist ein Betriebssystem der Studios mit vielen Modulen, eine App, modular. iOS, iPadOS und Web folgen später und abgespeckt; die Struktur sieht das vor, erzwingt es nicht. Die Bedienung läuft über die Maus, nicht über Tastenkürzel. Die App ist für den Vollbildschirm gedacht.
- Rechte: Wer angemeldet ist, darf alles. Nur die Firma sperrt einzelne Dienste, Rollen kommen später als Einstellung. Keine Schutz- und Erklärtexte in der Oberfläche. Das Schloss „Nur Verwaltende ändern das“ in der Dienstkarte widerspricht dem und ist entfernt.
- Alles Feste kommt aus Auswahl, Einstellung oder Onboarding, keine Firmennamen und Namen im Code. Die App kann zuerst alles, Einschränkungen kommen später als Einstellung.

**Heute (Johannes 20.10., noch nicht gezeichnet)**
- „Heute“ ist die Dashboard-Startansicht mit Widgets. Gleiches Layout wie die Hülle, linke und rechte Bahn können fehlen oder anders sein, die mittlere Bahn nimmt die volle Breite ein, gerastert, im Stil der Hülle.
- Die mittlere Bahn ist ein Widget-Brett: viele Widgets in einem Raster, das die Person selbst anordnet. Widgets tragen Funktionen, haben Ein- und Ausgänge zu Hub und Modulen. Beispiele: DHL, Clockodo-Zeiten, ClickUp-Aufgaben, Slack, Teams, Google Workspace, Geräte. Das Motiv ist ein App-Store: Integrationen kommen als Widgets.
- Entfernen und Auswählen von Widgets gibt es. „Beim Öffnen“ in Mail braucht den Punkt „Heute“ (N8, wartet auf Johannes).

**Hub und Dateien**
- Der Hub ist der Netzwerkstecker zu allen Apps und Diensten. Ein Dateiort ist Ordner auf dem Mac, Google Drive, Dropbox oder Server (WebDAV, SMB); alle vier gehören ins Ziel. Firma und Person wählen im Hub die Orte, Kontakte und „Projekt anlegen“ können mehrere Routen haben: lokal, Tabellen, Apple Kontakte, Google Workspace, Airtable.
- „Dateiordner“ ist nicht Google Drive. „Vorlagen“ sind Briefvorlagen, Textbausteine, Briefpapiere, Standarddokumente und Planunterlagen oder Musterseiten (DWG, PDF, HTML), befüllbare Templates. „Mail in Projektordner ablegen“ geht über den Hub; der Ordner heißt je Person Projektordner, Buchhaltungsordner oder anders.
- Projekt anlegen schreibt wirklich, nach Vorschau und Bestätigung: Projektnummer, Ordner, Datensatz, Liste; jeder Schritt höchstens einmal. Vorschau und Bestätigung sind nicht gezeichnet.
- Die Darstellung von Konto, Dateiorten und Vorlagen ist Auftrag an Design (Dateiorte-Karte, Vorlagen-Ansicht).

**Mail**
- Bis zu drei Postfächer je Person, über alle Anbieter. Anmeldung: Adresse eingeben, Anbieter erkennen, dann OAuth oder vorbelegte Server mit App-Passwort, ein Formular nur als letzter Ausweg. Gmail und Workspace laufen über OAuth.
- Konten werden in den Einstellungen angelegt (12.10.), nicht in der Mail-Ansicht; in Mail wird nur gewählt.
- Mail-Ablage lokal, vier Regler (Johannes 20.10.): Zeitraum 7, 30, 90 Tage oder alles (Vorgabe 30), Schalter „Anhänge lokal speichern“, Obergrenze in GB (automatisch), eigener Ablageordner. Die Regler sind nicht gezeichnet; wie der Ablageordner zu „Datenbank nie sichtbar“ passt, ist offen.
- Standard-Takte im Master: Mail alle 5 Minuten, Kontakte stündlich, Dateien alle 15 Minuten (:392). Der Takt „Sofort“ fehlt.
- Absendername gehört zum Postfach (Vorgabe vom Anbieter, im Postfach änderbar). Der Name in „Ich“ ist nur eine Vorgabe. Das betrifft Signatur und Konto-Karte.
- Mail-Texte „ohne Empfänger“ und „ohne Betreff“ fehlen.

**Einstellungen und Dienste**
- Der Hub ist der Ort, an dem alle Integrationen leben. Je Hub-Integration gibt es später einen Schalter, ob der Assistent sie nutzen darf (Johannes: „Design entwirft mit mir“); der Altbestand hat zehn feste Kategorien und „Assistent ganz aus“. Die Form entscheidet Design mit Johannes.
- KI-Karte: Schätzwert in 50-Cent-Schritten aus Verbrauch und eingetragenem Preis je Million Tokens. Preise monatlich aus dem Web aktualisieren ist ein Vorschlag, nicht entschieden.
- Datan wird Modul in ALFA_OS (Preislisten lesen, belegen, prüfen) und schreibt in den eigenen Datenspeicher, erst nach dem Design-Nachzug.
- Team-Anzeige (Kollegen) nur mit Hub-Quelle. Rolle, Kürzel, Telefon und Geburtstag sind zunächst nur Profilfelder.

**Warenkorb (nicht gezeichnet)**
- Zwei getrennte Körbe. Die App entwirft nur, sie gibt keine belegführenden Dokumente aus. Checkout: ein Warenkorb, viele Ziele (Musterliste als PDF, Moodboard, ZIP, CSV, später Adobe), jedes Ziel zuerst Vorschau, dann Bestätigung.
- Einkaufspreise erscheinen in Exporten nur, wenn Firma oder Person es einstellt. Ein Mail-Entwurf mit PDF und Einkaufspreis durch den Assistenten ist ausgeschlossen.

**Arbeitsweise**
- Ergebnis statt Wort, kurz, Fakten zum Bestätigen, Ändern oder Verneinen. Fragen, die sich recherchieren lassen, stelle ich nicht. Nichts geht ohne Johannes' Zustimmung zum Wortlaut an Code oder Design.
- Tokens müssen gegenseitig geprüft und „steckerfertig“ sein; der Status (freigegeben, orange, von Design gesetzt) ist ihm gleich. Design und Code kontrollieren einander.
- Name der App: ALFA, keine Firmennamen und kein „myk“ in Tokens, Schlüsseln, Metadaten (19.10.).
- Der Anspruch „Nur das ALFA-Interface, keine Farbwelten“ (10.10., im Code-Gedächtnis zitiert, nicht belegt) steht gegen die Farbleiter. Die Farbleiter ruht.

## 13 · Abgleich mit Brief v10 (BRIEF.txt, Schemas, Prüfskripte, Lieferung 15 gelesen, 21.10.)
**Was der Brief von Design verlangt (gilt, solange Johannes nichts ändert)**
- Der nächste Export liefert `contract/` für Mail, Einstellungen und Hülle: jeder Wert ein Token, jedes Bauteil und Element mit fester id (`data-id`), jeder sichtbare Text mit Schlüssel, jede Änderung protokolliert. Pflichtdateien: base, theme-light, theme-dark, alfa.resolver, components, views, texts, changes, akte, werte-abgleich. Prüfläufe P1 (`validate.py`), P2 (`check_contract.py`), P3 (`diff_contract.py`) vor dem Export, Ausgaben als `contract/PRUEFUNG.txt`.
- Eine Quelle (A1, A2): Bögen verweisen nur per `var(--…)`. Eine Zahl, die nur inline steht, gilt als nicht geliefert. `TOKENBOGEN.json` entfällt oder wird aus `contract/` erzeugt; zwei Wertquellen nebeneinander gibt es nicht.
- Status der Tokens heißen `approved`, `approved-provisional`, `set-by-design`. Jeder Token braucht Status oder Quelle.
- Zu jedem Bauteil mit Zuständen oder Bewegung: Zustände, Übergänge, Grenzbreiten, Umbruch (A6). Was fehlt, baut Code ohne Übergang.

**Befund im Projekt (gemessen)**
- `TOKENBOGEN.json` hat 370 Tokens: 17 approved, 9 approved-provisional, 103 set-by-design, 52 mit Quelle, **189 ohne Status und Quelle**. Der Vertrag (`contract/base.tokens.json`, 282 Tokens) führt die Laufweiten `markSmall` und `orbInitials`, der Tokenbogen nicht mehr: zwei Wertquellen, die auseinanderlaufen. Meine Handänderungen am Tokenbogen (Inverse hell, Laufweiten) stehen nicht im Vertrag, `changes.json` endet am 19.10. 21:00.
- Lose Zahlen in den Bögen, die der Brief ausdrücklich nennt: `ALFA Mail.dc.html:74` Kachelhöhe 96 (gilt 112, entschieden), `:59` Laufweite .01em. Neu von mir inline: Stapelübergang 200, 240, 300 ms, 8 und 10 px, Staffel 24 ms.
- Ich habe die Prüfläufe P1 bis P3 nicht ausgeführt, auch nicht ihre JS-Fassungen in `contract-build/`. Ob der Vertrag heute valide ist, weiß ich nicht.

**Punkte des Briefs, die Johannes' Wort ändert oder die ich noch entscheiden muss**
- **W-05 Dienstzahl** (Brief: auf Gezähltes bringen): Johannes 20.10.: Die Zahl wird nicht angezeigt. Der Eintrag entfällt.
- **N2 Abmelden:** Der Brief hat „lets go“ als Entscheid. Johannes erinnert das nicht, Text wird nach seinem Wort neu geschrieben („trennt alle verbundenen Dienste“).
- **N6 KI-Preis:** Der Brief lässt den Nutzer den Preis je Modell eintragen. Johannes hat danach „Web-Update monatlich oder so“ gesagt: Der Preis wird monatlich aus dem Web aufgefrischt und ist überschreibbar. Nicht entschieden, Vorschlag von Code.
- **Kartenstapel 8a und 8b als Einstellung** (Brief, 19.10.): in den Einstellungen gilt jetzt „keine Cardstacks hier“. Für Mail offen.
- **L-015 Fokusring-Abstand** (2 oder 1) und **L-016 menu-row** (Radius und Innenabstand 12 oder 8): Design wählt je einen Wert. Von mir noch nicht entschieden.
- **W-03** Fenster 960 × 600 streichen. **W-04** trailingTextInset 12 (`decisions.json:99` nennt noch 14). **W-06** Gruppen der Einstellungen: Ich, Firma, Verbindungen, Schutz, System. **W-07** alle 47 Felder in `INHALT.json` im Vertrag oder gestrichen.
- **T5 L-008 bis L-013** (Konto hinzufügen, Kontowechsel, Signatur, Logos, Rückmeldung „Jetzt abgleichen“, Entfernen mit Bestätigen-Pille) und **N1 bis N7** sind der Zeichenauftrag. Heute gezeichnet: DHL-Karte und Widgets, Signatur und Konto-Wähler (ALFA Mail), Konto-Karte.
- **Später (B-01 bis B-04, B-06 bis B-09):** Lead aus Mail, Kontaktblatt, Speichern in Drive, Ablegen per Ziehen, Klartext/HTML, Link öffnen, Alle Anhänge. Projekte, Heute, Kataloge, Warenkorb nach dem Pilot im selben Format.

**Aus Lieferung 15 (Code, 17.10., älter als Brief v10)**
- Die Übersichts-Steuerung gehört in die Spaltenleiste (Entwurf: `HB`, `fanB`), nicht in den Kartenkopf. Das deckt sich mit Johannes' Kommentar vom 21.10.
- Offen von damals: Aktionen von Kachel, Fuß und „Mehr“ als Liste (Antworten, Weiterleiten), Drucken und PDF (Gruppe im Fuß?), „Verschieben nach …“, Namen `konten` gegen `mailkonten`, Bahn-Minimum links 224 als Token, Assistent-Breite 360, Blob-Wurf, Schatten-Faktor, Kopf rechts 10, Menüabstände 10 und 18 gegen 12 und 8. Was davon seit Master 1810 erledigt ist, habe ich nicht gegengeprüft.

## 14 · Anfrage von Code, 21.10. (Lieferung angefordert, noch nicht freigegeben)
- Code verlangt den Export mit `contract/` und `contract/PRUEFUNG.txt` (P1, P2, P3 ohne Fund) und je T1 bis T8, N1 bis N7 „erledigt“ oder „offen“. Nach `CLAUDE.md` geht nichts raus, bevor Johannes „100 % sauber“ sagt.
- Stand der Prüfung (JS-Fassungen, 21.10.): P1 valide (9 Dateien). P2 hat 75 Funde: Der Vertrag kennt die neuen Elemente der Bögen nicht (`mail.account-alert`, `settings.card-*`, Konto-Wähler, Signatur) und führt Bauteile ohne Gegenstück in den Bögen. P3 nicht lauffähig gegen einen neuen Vertrag, weil keiner erzeugt ist.
- **App-Icon:** Das „B A-Monogramm, vorläufig“ ist Übergangs-Icon bei Code. Gefordert: endgültiges Icon als SVG und in den macOS-Größen 16 bis 1024. Material von Johannes nötig.
- **App-Sperre:** Schalter gezeichnet (`ALFA Mail.dc.html:763`), gesperrter Zustand nicht: Sperrbildschirm, Entsperren mit Touch ID oder Passwort, Fehlschlag, erneutes Sperren nach der Pause.
- **Bild blockiert:** Kachel (`:977`) braucht Textschlüssel und Maße im Vertrag.
- **Doppelte Bilder-Einstellung:** In `INHALT.json` „Externe Bilder“ (:550–551) und „Mail-Bilder“ (:576–577); eine entfällt.
- **Leerer Betreff:** eigener Hinweis „Betreff fehlt“: ja (Johannes 21.10.). Zu zeichnen.
- **Schrift:** Geist, auch im Blatt der HTML-Mail (Johannes 21.10.: bereits gesagt, siehe Abschnitt 8).
- Kachelhöhe Integrationen bleibt 112.

## 15 · App-Icon
- Gewählt: 4b Papierstufen (sechs gestufte Bögen Creme bis Rot, großes weißes A mit schwarzer Haarlinie, dunkler warmer Grund). Status approved-provisional („orange freigegeben“, Johannes 21.10.). Quelle: `ALFA Icon.dc.html`. Noch zu liefern: SVG und macOS-Größen 16 bis 1024, Gegenprüfung in 16 und 32 Pixel.

## 16 · Offen (entscheidet Johannes)
Abmelden mit ungesendeten Mails; Widgets gestrichen oder gewollt; Ob eine Karte statt Stapel in den Einstellungen so gewollt ist; Farbleiter; Sperre je Ansicht; Fensterhöhe; Logos; Kachelnamen; Maßband-Lupe liefern; „Blob anheften“ erklären; Systemfrage iOS, iPadOS, Web; Reife, ab der Code baut (auch bei von Design gesetzten Werten); Kind-DCs ja oder nein; Google-Anmeldung (vier Wege, Code empfiehlt „extern, in Produktion, ungeprüft“); Wortlaut von Brief v11 und Freigabe von Brief v10; N4 bis N7 zeichnen.

## 17 · Sperre und Stempel (21.10.)
- Was Johannes nicht auf allen verwendenden Bögen live gesehen hat, existiert nicht. Ein Token, Bauteil, Name, Block oder Maß gilt erst, wenn es zugleich in allen verwendenden Bögen angewandt, im Tokenbogen und im Vertrag einmalig erfasst und von ihm gesehen ist.
- Jeder Bogen, der nicht vollständig aktuell ist, trägt in jeder Ansicht einen fett roten, diagonalen Stempel „GESPERRT“ (roter Rahmen, Datum, Hinweis „nicht abgenommen“); er deckt den Bogen, blockiert keine Eingabe. Pages, JSONs, Tokenbögen, MDs, Archive, alte Verträge und Lieferungen sind ungültig, solange der Stempel steht. Export, Weitergabe, Verwendung gesperrt.
- Aufheben nur durch Johannes; heute tragen alle 14 Bögen den Stempel (`contract-build/sperre.json`).

## 18 · Brief v12 gezeichnet (21.10., Design-Festlegungen, von Johannes nicht gesehen)
- Abmelden: „Auf diesem Mac abmelden“ ist eine Zeile mit Bestätigen-Pille („Abmelden?“). Die Zeile nennt Zahl und Namen der verbundenen Dienste („Trennt 3 Dienste · …“); keine Warnung vor ungesendeten Mails (22.10. nach neuem N2 zurückgenommen).
- Mail zu groß: beim Senden zeigt der Entwurf den Hinweis „Mail zu groß“ mit „Anhänge ändern“; Status „Zu groß“.
- Neue Mail kommt ohne Takt-Eintrag „Sofort“: IMAP-Konten melden neue Mail sofort, solange der Takt nicht „Aus“ ist.
- KI-Dienste (Claude): Modell aus der Liste, Verbrauch seit Datum mit Eingabe und Ausgabe, Preis je Mio. Tokens von der Person; ohne beide Preise kein Schätzwert; Schätzwert „ca.“ in 50-Cent-Schritten; Zähler zurücksetzen mit Bestätigung; kein Guthaben.
- Fehler in Mail: jede fehlgeschlagene Aktion (Archivieren, Verschieben, Löschen, Markieren, Lesen, Anhang, Verlauf, Entwurf sichern, Mail sichern) zeigt einen Fehler-Toast mit Warnzeichen und „Erneut versuchen“. Ein nicht lokal gesicherter Postausgang zeigt in der Liste einen Hinweis mit „Erneut sichern“.
- App-Sperre: Die Hülle deckt bei gesperrter App alles mit dem Sperrbildschirm: Marke, Name, „Mit Touch ID entsperren“ (wartet, dann entsperrt), „Passwort eingeben“ (Feld, „Entsperren“, „Touch ID“). Fehlschlag: „Touch ID nicht erkannt“, „Passwort falsch“. Nach der eingestellten Pause sperrt die App wieder.
- HTML-Mail ohne Bilder zeigt Kacheln „Bild blockiert“ im Seitenverhältnis 4 : 3; mit Freigabe die Bilder.
- Dateien über Google Drive: Der Projektordner wird in zwei Schritten gewählt (Laufwerk, Ordner). Ohne Wahl steht „Wählen“ und es gibt keinen Abgleich. „Aus Projektordner“ im Entwurf führt über Projekt und Ordner zur Datei, zeigt „Lädt …“, „Keine Dateien“, „Ordner nicht geladen“ mit „Erneut versuchen“ und höchstens 8 Dateien, dann „n weitere im Projektordner“. „Mail in Projektordner sichern“ legt ein A4-PDF (Kopf mit Von, An, Datum, Betreff, Text, Anhänge, Fuß mit Projekt und Seite) als „<Datum> <Betreff>.pdf“ in den Ordner Korrespondenz des Projekts der Mail; ohne Projektordner oder bei Fehler Toast. „In anderes Projekt …“ am Anhang wählt das Projekt und kopiert in den Ordner Anhänge, mit „Rückgängig“.
- Firmendaten und Impressum: Felder ohne Werte mit Bezeichnung und Platzhalter; die Person trägt ein.
- Schrift: Geist, einmal als Token; alle Bögen lesen ihn.

## 19 · Mail als PDF (22.10.)
- Ob „Mail in Projektordner sichern“ ein eigenes PDF-Layout braucht, ist offen: Code prüft, ob die native macOS-Ausgabe aus der Mailansicht genügt (Johannes: wenn „gratis onboard“, umso besser). Bis zur Antwort steht der Entwurf `ALFA PDF.dc.html` als Vorschlag; Ordner und Dateiname bleiben wie in Abschnitt 18.

## 19 · Nachtrag Mail gezeichnet (22.10., Design-Festlegungen, von Johannes nicht gesehen)
- Schließen eines Entwurfs: scheitert das Sichern, bleibt die Karte offen und zeigt „Entwurf nicht gesichert“ mit Erneut sichern oder Erneut verbinden. Während des Sicherns sind Schließen und Felder gesperrt („Sichert …“). Entwürfe im Postausgang oder mit Versandfehler werden nicht gesichert: Toast „Im Postausgang“ bzw. „Nicht gesendet · im Ordner Entwürfe“, Eintrag im Ordner Entwürfe.
- Anhang: Vorschau, Drucken, Als PDF sichern laufen nativ (Johannes 22.10.); gezeichnet sind nur Menüeinträge und Rückmeldungen. Ablegen von Dateien auf die Entwurfskarte zeigt „Loslassen hängt an“.
- Lokale Mailablage: Block „Lokale Ablage“ in der Konto-Karte (Zeitraum, Anhänge lokal, Obergrenze, Ordner); Optionswerte von Design.
- Liste offline: Warnung „Keine Verbindung“.
- Details, Fundstellen, Fragen an Code: lieferung-an-code/ANTWORT-NACHTRAG-2210.md.
