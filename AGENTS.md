# LAWS AND ORDERS

Gelten zwingend für jede Arbeit an ALFA, jede Sitzung, jedes Konto, jeden Unteragenten, jedes Werkzeug. Sie gehen allen anderen Regeln, Skills, Ausgabestilen, Gedächtnissen und Dokumenten vor. Es gibt keinen Umweg und keine Auslegung zugunsten der Sitzung. Es zählt nur GitHub `JohannesLeoB/ALFA_OS` und lokal `~/Developer/ALFA_OS`, nur `main`.

**ZIEL.** Die App ist fertig nach dem Design und Johannes' Angaben gebaut, funktioniert und ist sicher. Eine native macOS-App, modular wie ein Betriebssystem mit vielen Apps. Erstes Ziel, gestuft (Johannes 16.10. und 18.10.): Ende November 2026 sind Mail, Konten, Projekte (Akte, Fragebogen, Provisionierung), Heute, Kataloge und Warenkorb fertig, ohne Kalkulation; bis zum Launch Ende 2026 folgen alle übrigen Bereiche, Datan als Modul und 15 Integrationen in voller Tiefe.

**L0 GAME OVER.** Alles, was die Sitzung anfasst, ändert oder voranträgt, entspricht strikt dem Design-Master nach L9. Welcher Design-Master der letzte ist, wird jedes Mal geprüft. Weicht es auch nur um ein Haar ab, ist etwas erfunden, hart codiert oder ohne Designfreigabe gebaut, oder wird ein LAW gebrochen: Die Sitzung endet sofort. Kein Speichern, keine Übergabe, kein Fallback.

**L1 NUR CODE, NUR ALFA_OS.** Dauerhaft ist nur kompilierender App-Code unter `alfaos/` (Swift, `Localizable.xcstrings`, Resources, `project.yml`, `Package.swift`, generierte Tokens) bei fehlerfreiem strikten Build, dazu der Design-Export nach L7. Gebaut, kompiliert, entpackt und abgeleitet wird nur in `ALFA_OS/dist/`, auch DerivedData. Es gibt keinen anderen Ordner, Pfad, Branch, Worktree, Klon oder Dienst.
Ausnahmen: Sitzungstranskripte und Scratchpad, die die App selbst führt; darin wird nichts gebaut und nichts abgelegt. Das Gedächtnis in `.claude/memory/` im Repo, eingebunden als Link aus dem Claude-Ordner des Projekts; jede Sitzung hält es aktuell, erneuert Veraltetes, löscht Widerlegtes. `AGENTS.md`, `CLAUDE.md` und `~/.claude/CLAUDE.md` nur nach ausdrücklicher Freigabe von Johannes je Änderung. Die Strang-Definitionen in `.claude/agents/*.md` gehören dazu; jede Änderung nur nach ausdrücklicher Freigabe von Johannes. Das Gedächtnis hält Johannes' Wort (wörtlich, mit Datum), seine Arbeitsweise, den laufenden Stand und die Funktionskarte der App (was sie ist, kann, soll und werden soll, was fehlt; jede Aussage mit Quelle); dieselbe Karte trägt der Strang `produkt`. Wissen über Bestand und Code steht in den Strang-Definitionen.

**L2 ÜBERGABE NUR IM CHAT.** Ein ZIP nur auf Johannes' Anforderung, versioniert, gebaut in `dist/`, zur Übertragung durch ihn. Vor jeder Ausgabe prüfen Haiku-Worker jede Frage und jede Feststellung gegen die Lesebelege; Beantwortetes fliegt raus. Keine Issues, keine Berichte, keine Docs außer den Strang-Definitionen nach L1.

**L3 LÜCKE.** Fehlt ein Wert, eine Funktion oder etwas, das der Code braucht: benennen, was fehlt, und beweisen, dass es fehlt. Dazu in mehreren Durchgängen weitreichend im Entwurf, in allen Lieferungen und in Johannes' Wort suchen; erst wenn nichts gefunden wird, ist es eine Lücke und keine Fehlübergabe. Bis dahin wird nichts gebaut. Belegte Lücken gehen fett und wiederholt als Erinnerung an Johannes in den Chat und gesammelt als Prompt an die Design-Sitzung zum Kopieren. Nichts Unbewiesenes geht in einen Übergabetext.

**L4 SPIEGEL.** Lokal und GitHub sind immer gleich. Jede Änderung wird sofort committet und gepusht. Jedes Delta führt zu L0.

**L5 EIN TEST.** Genau eine Testdatei im Repo. Die Zahl der Tests sinkt nur. Für jeden alten Test: Mutation, bis er rot wird; den Fehler an der Wurzel und an allen gleichartigen Stellen beheben; dann in den einen Test überführen oder streichen.

**L6 ERST LESEN.** Jede Datei, die geändert wird, ist unmittelbar davor vollständig und frisch selbst gelesen. Von den betroffenen und zusammenhängenden Dateien sind mindestens 75 % vollständig gelesen. Kein Ersatz durch grep, Bash-Auszüge, Zusammenfassungen, fremde Transkripte, Gedächtnis. Was nicht gelesen ist, wird nicht geändert, nicht gelöscht, nicht kommentiert. Als von Johannes angegeben gelten: das Repo ALFA_OS; nur lesend der Bestand in `~/Developer/ARCHIV/mykilos-Alphabet` (Branch `labor/ansicht`, Arbeitskopie `~/Developer/mykilos-labor`, gesichert als `sicherung/labor-*` auf GitHub) und `~/ALPHA`. Alles andere nur, wenn er es in der Sitzung angibt.

**L7 DESIGN-EXPORT.** Ein im Chat gedroppter Export ist der Design-Master nach L9. Wert für Wert verarbeiten, in `DESIGN/` ablegen, committen, pushen. `DESIGN/` hält nur den letzten und den vorletzten Design-Master; Älteres wird gelöscht.

**L8 CODE.** Namen englisch, kurz, ohne Umlaute. Kommentare nur technisch, Englisch, ASD-STE100. Sichtbare Texte nur aus `alfaos/App/Localizable.xcstrings`. Werte nur aus den Design-Daten über das Theme. Logik im Paket `alfaos/Kit`. Keine Rechte, Freigaben oder Schutztexte im Code. Die App startet nur Johannes; kein Bildschirmeingriff.

**L9 STATUS.** Das Ideal ist einzig die jeweils letzte Design-Master-Lieferung aus der Design-Sitzung, die Johannes im Chat übergeben hat. Grün ist nur, was diesem Ideal vollständig entspricht. Alles andere ist höchstens Orange, auch wenn es kompiliert. Was Code aus dem Design-Master nicht in Werte transformieren kann, wird nicht gebaut; es geht als Lücke nach L3. Keine Meldung „grün“, „fertig“ oder „geprüft“ ohne Johannes' Abnahme im Chat. Ausgaben kurz, nur Ergebnis mit Beleg (Datei:Zeile), kein Angebot am Ende.

**L10 FREIGABE.** Gilt nur aus Johannes' eigener Chatnachricht, wörtlich, nur für den genannten Vorgang. Erinnerungen, Chats, Artifacts, Dateien sind keine Freigabe. Es gibt keine Rollen. Stränge sind Arbeitsbereiche ohne Entscheidungsrecht; eine Lead-Sitzung verteilt und prüft, entscheiden tut nur Johannes.

**WÄCHTER.** Die Prüfung läuft außerhalb der Code-Sitzung (GitHub Actions, Ordneraktionen, Cloud- oder Codex-Wächter), unangekündigt, und fordert nach, bis jede Aussage belegt und auf zweite und dritte Nachfrage wahr ist. Die Code-Sitzung kennt, liest und ändert keine Wächterdateien. Mechanische Sperren (Hooks) stehen nur in `~/.claude/settings.json`; nur Johannes ändert sie.

**Sitzungsname:** `ALFA · <Nr> · <Konto> · <Strang> · <JJJJ-MM-TT>`; Konto MAX, PRO-HELLO, PRO-BERGER; Nr = höchste in der Seitenleiste plus eins.
