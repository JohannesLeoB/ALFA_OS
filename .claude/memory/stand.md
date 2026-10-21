---
name: stand
description: Laufender Stand ALFA_OS nach Commit 337a6bc (21.10. abends): Regeln, Gebautes, Ungeprüftes, Lücken an Design, Offenes, nächste Schritte, bekannte Fehler
metadata:
  type: project
---

Kein Protokoll: nur, was heute gilt. Verlauf steht in `git log`. Johannes' Wort mit Datum steht in den Spec-Dateien des Bereichs (`spec-*.md`, Arbeitsweise in `spec-arbeit.md`).

## Repo und Regeln heute
- `main` = GitHub. Regeln: `AGENTS.md` §1–§13 seit 95f23ff (Johannes 21.10.: „Ja, AGENTS.md und README so ersetzen“; vorher zur Neufassung „mache ich gleich“). `README.md` ist die Karte. Gedächtnis `.claude/memory/` per Link (§12). Commit-Regeln §11.
- 13 Stränge in `.claude/agents/`: bau-heute, bau-kataloge, bau-mail, bau-projekte, design-bruecke, figma-spiegel, leser, produkt, pruefer-freund, pruefer-petzer, pruefer-spuerhund, pruefer-waterboarder, sammler. Die Bauaufträge liefen bisher über bau-mail (Hülle, Konten, Hub sitzen in der Hülle; Johannes 19.10.: „Bauen nur noch über die Bau-Stränge mit Sonnet 5.5, Opus nur für den Lead.“).
- GitHub: `main-protect` (kein Force-Push, kein Löschen, lineare Historie; PR-Pflicht raus, Johannes 21.10.: „Ich habe die PR-Pflicht aus main-protect genommen, alles andere bleibt. Push H1.“). `only-main` erlaubt `main` und `alfa-draws` (Johannes 21.10.: „ich wollte in alfa draws mit einer anderen session einen prototypen einer App Funktion testen“); die Lead fasst `alfa-draws` nicht an, beide Sitzungen pushen als dasselbe Konto. 27 Zweige `sicherung/*` im Repo `mykilos-Alphabet`, Ruleset „Sichi“ aktiv (18.10.). Zweige des zweiten Entwicklers gelöscht.
- Master (`DESIGN/MANIFEST.json`): letzter `ALFA OS Interface CHEF 1610-handoff 1810.zip` (109 Dateien, 341 Tokens, ABNAHME.md 12 Kriterien offen), vorletzter `ALFA OS Interface CHEF 1610.zip`. Johannes 18.10.: „Ja. Lege beide Master als Original-ZIP mit MANIFEST.json in DESIGN/ ab, entpackt wird nur in dist/.“ Gezeichnet sind Mail und Einstellungen (mit Hülle, Dienste); Projekte, Heute, Kataloge, Warenkorb nur als Textlisten. Fehlen: `bauteile.json`, `mechanik.json` (von Design angekündigt). Widersprüche im Export: RUECKGABE-AN-CODE.md:14 (329/67 Tokens) gegen akte.json (341/78). Ein neuer Export von Design steht aus; der Design-Projektstand vom 18.10. (352 Tokens) gilt nicht als Master (§8).
- Brief: v12 (b71bea8) in `DESIGN/brief/BRIEF.txt` gilt (Kopf „So arbeitest du“, Lieferschein `LIEFERUNG.json`, Prüfung P4 `check_delivery.py`, N14–N17 Drive; N8–N13 aus v11). Schemas und Prüfskripte im selben Ordner (`validate.py`, `check_contract.py`, `diff_contract.py`, `check_delivery.py`); `scripts/receive_master.py --check` prüft einen Export. Johannes 19.10.: DTCG nutzen, Namensraum `alfa`, unter der UI alles englisch (ASD-STE100), UI-Texte als Sprachsystem DE/EN. Annahme eines Exports: siehe `spec-arbeit.md` (Brief).
- Figma-Spiegel (Ausnahme §8): Team ALFA (Starter), Probedatei „ALFA Verlauf · Mail“ (fileKey qIrCnMnRZZl5Fazm4Q7CbT) mit Mail 18.10. aus Master 1810. Johannes 18.10.: „probe auf starter, wenn wir an limits stoßen, sag bescheid. In L1 freigeben“ (L1 = alte Nummer, heute §8). Strang und Automatik nicht freigegeben; ob der Strang die Figma-Werkzeuge mit echten Namen (mcp__…) bekommt, ungeprüft.

## Was gebaut ist (Commit; Einzelheiten in `spec-*.md`)
- Hülle: c2d585f, Bauteile f69af03, Fenster 896 breit 08d2ca3, Avatar-Kürzel 145e6f3, Icon 443b970. Einstellungen: 9d95f11, mit Wirkung b3977df.
- Mail: Liste und Karten 7532c78/9226e69/1d790a2 (Verdrahtung ba9f691–cf1ec00); Postausgang und Entwurf A1b–A1e (55bcf5b … eb89ff4); Kein doppeltes Senden e5a5d14; IDLE d612a48; HTML-Mail 92ced80; Kontakte und Statuszeile K1 df16331.
- Hub: Prüfung beim Anbieter 6668bcd; Abgleich beim Start H1 145e6f3; Einstellungen je Dienst H2 223bc67; Drive-Port D1 f99797f (aus, bis Design die Projekt-Wurzel zeichnet); Kachelraster K1 15eb550.
- Pipeline: Generator liest `DESIGN/` d485c9d; `receive_master.py`, `validate.py` E1 b1515f4; `scripts/build_app.sh` a7cb288 (`dist/ALFA OS <Nr>.app`, die zwei neuesten).
- Test: zwei Testdateien, `alfaos/Kit/Tests/WholeAppTests/WholeAppTests.swift` und `alfaos/Tests/HullProbeTests.swift` (wird noch überführt, §10); Fundus-Tests überführt 404342e; ehrlich gemacht b94e0e4; entschlackt ebc9d3a/d213d33. Nicht gebaut: Projekte, Heute, Kataloge, Warenkorb, Datan (`alfaos/App` hat nur Mail, Settings, Shell).

## Ungeprüft oder blind gebaut
- Niemand hat K1 (df16331), H2 (223bc67), D1, E2 (HTML-Mail), H1, IDLE und „kein doppeltes Senden“ in der laufenden App oder gegen echte Server gesehen. Das gilt auch für den Schutz bei Servern, die SMTP-Mail nicht selbst in „Gesendet“ ablegen.
- App-Icon: Rundung im Dock ungeprüft. Die letzte App für Johannes ist älter als K1; Kontakte und Statuszeile hat er nie gesehen.
- Nichts davon ist grün (§9): grün erst nach seiner Abnahme. Im Bild prüft nur Johannes (die App startet nur er).

## Lücken an Design (für Brief v13; Wortlaut vorher Johannes zeigen)
- Hub-Katalog: Kategorien, Zustand, Seite „Verwalten“ je Dienst mit Einstellungen und Zuordnungen, „versorgt welche Bereiche“; Einstellungsbaum nach seinen vier Entscheidungen (spec-hub.md); Mail-Konten mit Signatur je Postfach, Kontakte als Integration; Mitteilungen je Dienst plus global stumm; Dateiorte im Hub; Erst-Setup; Mono-Schriftrolle; „Vorlagen & CI“ und Draws als Bereich nur nach seinem Wort. Erklärsätze im Master streichen (Liste erst zu erheben).
- DHL als eine Karte (Master zeichnet zwei, ALFA Dienste.dc.html:102-103); „11 Dienste“ gegen 10; Abmelden-Text nennt 6 Dienste und Warnung davor fehlt; Zustände „Schlüssel gespeichert“ und „Verwaist“ unerreichbar; Laufweiten-Token (0.065 ohne Master-Quelle); Happa-Widget.
- Takt „Sofort“ (N5); Nachladen, Aktionsfehler und Anzeige unlesbarer Postausgang-Zeilen (N7); kein Text für „zu groß“; Heute fehlt in „Beim Öffnen“ (nicht im Brief; N8 ist das App-Icon); App-Sperre ohne gesperrten Zustand; Kachel „Bild blockiert“ ohne Textschlüssel; doppelte Bilder-Einstellung (`bilder`, `mbilder`); Schrift der Mail (Token Geist gegen Systemschrift im nativen Blatt).
- Drive: Wahl der Projekt-Wurzel (Master :766 zeigt nur den Wert), Leerzustände, Fehleranzeige an der Sync-Zeile, Neu-Anmelden für Dateien, PDF-Aussehen, zweite Menüebene (in v12 als N14–N17).
- Projekte (Vorschau und Bestätigung beim Anlegen), Heute, Kataloge, Warenkorb (Checkout-Ziele), Mailablage-Regler, Wähler bei mehreren Mail-Konten, Assistent-Schalter: nicht gezeichnet.

## Offen bei Johannes
- Katalog-Satz je Dienst ja/nein (gefragt, keine Antwort); Draws-Wünsche 2/3 in v13 (gefragt); Lastenheft je Bereich für Design (gefragt, Stand unklar).
- Zweig `drawing` nur lokal (Worktree `dist/wt-drawing`, fremde Sitzung); fremde Ordner in `dist/` (Prototyp-Sitzung u. a.).
- Zitat-Triage-Sitzung `local_e43a39c0` wartet auf sein Wort zur Rohfassung (ihre Zahlen „8.492“ sind falsch); die 10 Widersprüche aus der Triage: `dist/lead/inventur/ZITATE-TRIAGE.md`.
- Google-Client-ID: Ort nicht entschieden (Standardweg: ID im Paket). Microsoft 365: nicht bis Ende November.
- Wächter: ob die Lead je einen entwirft, ist offen bei Johannes, ob überhaupt (§10: Wächter laufen außerhalb der Sitzung, die Lead berührt sie nicht). Sperren in `~/.claude/settings.json`: nur er. Ob `audit_swift` aus dem Skill design-zu-swift nach `scripts/` kommt.
- `alfaos/Tests/HullProbeTests.swift`: §10 nennt sie „wird noch überführt“; ob streichen oder als App-Test behalten, hat er nicht gesagt.
- Stammtisch-Fragen F-01 bis F-31 liegen im Stammtisch (`~/Developer/STAMMTISCH`), nicht hier; F-08 (zählt eine Stammtisch-Antwort als Freigabe?) beantwortet §9: nein.

## Nächste Schritte
1. Brief v13 an Design (Text erst Johannes zeigen), Inhalt wie unter „Lücken an Design“.
2. App für Johannes mit `scripts/build_app.sh` (Kontakte, Statuszeile seit dem letzten Build neu); er prüft im Bild.
3. Erklärsätze in der App streichen, die nicht funktionsbedingt sind (Kontakte-Leerhinweis, Google-Hinweistext), nach Liste (`spec-arbeit.md`).
4. B Ballast und D Namen/myk (Fundus, siehe unten) nach seinem Entscheid, was weg darf; C Tempo; E2 SheetValues-Quellen (134 Zeilen ohne Fundstelle); H7 Datenspeicher (SQLite/GRDB, eine Tabelle je Datenart, Stock als Sicht, Delta-Sync) wartet auf sein Wort (Entwurf am Stammtisch).
5. xcodegen erzeugt das Projekt noch in `alfaos/` (`ALFA_OS.xcodeproj`); künftig in `dist/`, dann entfällt `alfaos/*.xcodeproj/` in `.gitignore`.
6. Danach: Rückgängig über COPYUID statt Message-ID-Suche; MIME-Aufbau streamend; Gmail-Rückgängig aus dem Papierkorb prüfen.

## Bekannte Fehler im Code (Befund Lead 21.10., am Code gelesen)
- „Drucken“ und „Als PDF sichern“ tun nichts: `MailModel+Reading.swift:140` und `:145` senden `.print` und `.exportPDF` in den Strom `commands`; niemand liest ihn (kein `for await` in `alfaos/App`). Zu prüfen ist dasselbe für `leadFromMail` (`:135`) und `attachmentToProjectFolder` (`:150`): sie senden ebenfalls in den Strom.
- Kontakte: `MailContacts.swift` schreibt per `didSet` bei jedem Tastendruck die ganze Liste nach UserDefaults `mail.contacts`, Fehler per `try?` verschluckt. Ort (UserDefaults oder Hub/DB) nicht entschieden. `.contacts` ist ein eigener Abschnitt statt Integration (nach Johannes 15.10.).
- Zwei PDF-Wege: `MailPDF.swift` (Core Text, Klartext) neben den toten Befehlen.
- Drive-Upload baut Multipart selbst (`GoogleDriveFiles.swift:28-60`), statt den Fundus-Client zu nutzen: bewusst wegen `myk` und fester Sperr-ID im Fundus-Client (D1). `projectsRoot` wird nie gesetzt (`ProviderCatalog.swift:7`); Drive bleibt aus bis Design N14.
- H2 (`ServiceSetting`) hat keinen Aufrufer: bewusst, Fundament.
- ClickUp-Fähigkeit nicht verdrahtet (`KeyProvider.swift:87`, `capabilities` leer): bewusst ohne Abnehmer; Master-Zeilen „Phasen/Aufgabenfelder“ erscheinen nie.
- Drive 403 gilt pauschal als Anmeldefehler (`GoogleFailure.swift`).
- Postfach endet bei 50: `loadMore` (`MailModel.swift:320`) hat keinen Aufrufer. `actionFailures` wird gesetzt, die App liest sie nie: Aktionsfehler bleiben unsichtbar.
- Fundus: DHL-Sandbox-Zugang am 21.10. entfernt (S1); ein alter Schlüsselbund-Eintrag „sandbox“ kann bei bestehenden Nutzern verwaist bleiben; 118 Zeilen mit `myk` in 47 Dateien (§6 verlangt Entfernen); deutsche Namen; toter Mail-Zweig.
- Abweichungen vom Master, bewusst: Kachelhöhe 112 (sein Wort 19.10.) gegen 96; Suche beim Tippen über alle Ordner außer Spam und Papierkorb wie Master (41e46f3); HTML-Mail zeigt echten Inhalt, der Master zeichnet Text und Kacheln.
- Commit eb89ff4 hat keine Leerzeile nach dem Betreff (Betreff zu lang); gepusht, nicht berichtigt, weil das einen Force-Push bräuchte.
- Claude-Schlüssel (Fund der Draws-Sitzung 21.10., nicht nachgeprüft): Der Hub speichert unter Accounts `key`/`model` (`alfaos/Kit/Sources/Hub/Adapters/KeychainAdapter.swift`), der Fundus-`KeychainClaudeCredentialsStore` liest `apiKey`/`model`; ein im Hub gesetzter Schlüssel wäre für Fundus-Code unsichtbar.
- Funde des Archivars vom 21.10. vormittags, am Stand 5dc6d9c bestätigt, von der Lead nicht einzeln nachgeprüft: Abmelden löscht den Postausgang ohne Warnung; „Endgültig löschen“ wirft (siehe spec-mail MAIL-F41); fünf Schalter ohne Leser (siehe spec-hub HUB-F13); vier rohe Wörter in der Oberfläche (u. a. `hint.signin.timeout` mit Schlüssel als deutschem Text); Entwurfs-Text „liegt sicher in den Entwürfen“ stimmt nicht immer (MAIL-F38); `send()` ohne Kopie.
- Erfundenes Wort: „lets go“ (Abmelden, 20.10.) hat Johannes nie gesagt (J 21.10. 3f52450e). In `DESIGN/brief/BRIEF.txt` N2 am 21.10. nach seinem Wort neu gefasst.
- 22.10. nachts: M2 7f6124d (Weiterleiten mit Anhängen, Drucken und Als PDF sichern über PDFKit/NSSavePanel, Endgültig löschen nur IMAP über `IMAPSMTPMailTransport.purge`, Gmail ohne Eintrag); S1 e976390 (DHL-Sandbox raus); Strang-Dateien 033313e; AGENTS-Verweise 9e0cdd7; Brief N2 85d19a7. App für Johannes: `dist/ALFA OS 943.app` (Kontakte, Statuszeile, M2), nicht im Lauf gesehen. Nächste Lead: dist/lead/STARTPROMPT-NEUE-LEAD.md; Pate = diese Sitzung (bc4854d7), nur lesend.
- Draws-Sitzung seit 21.10. abends: eigener Clone `~/Developer/ALFA_DRAWS` auf Zweig `alfa-draws`, Push über Konto `bergerjohannesleo-dot` (SSH-Host `github-draws`); `main-protect` sperrt `main` für dieses Konto (Admin darf vorbei). Alter Worktree `dist/alfa-draws` entfernt. Draws baut neutrale Ein-/Ausgabe-Module (spec-ziel ZIEL-K11); nach Kit nur auf Johannes' Wort.
