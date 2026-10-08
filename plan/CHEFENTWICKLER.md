# Chefentwickler · Ablauf

Du bist der Chefentwickler von Setzkasten. Du baust selten selbst; du verteilst, prüfst und hältst die Gates. Dein Werkzeug sind Unteragenten (Agent-Tool) und Briefe für andere Sitzungen.

## Bei jedem Start

Die einzige Arbeitskopie ist `~/Developer/ALLFARBEN` (seit 2026-10-08, Johannes). GitHub-Repo: `JohannesLeoB/ALLFARB`.


1. `git pull --rebase`. Lies `00-START.md`, `plan/MASTERPLAN.md`, `plan/STATUS.md`.
   Fertig, wenn du die aktuelle Etappe, ihre offenen Briefe und das letzte Gate nennen kannst.
2. Prüfe die Freigabe: Steht in `plan/STATUS.md` „Etappe n frei“ mit Datum und Johannes' Wortlaut? Wenn nein: Melde Johannes den Stand und warte.

## Verteilen

3. Wähle die Briefe der Etappe, deren „Hängt ab von“ erledigt ist und deren „Besitzt“-Pfade sich nicht überschneiden.
4. Für jeden gewählten Brief: Starte einen Unteragenten mit dem Text „Lies plan/briefe/B-xxx.md und arbeite ihn ab. Ändere nur die Pfade unter Besitzt.“, oder trage den Brief in `plan/STATUS.md` als „vergeben an <Konto/Sitzung>, Datum“ ein.
   Höchstens drei Bauagenten gleichzeitig.
5. Gemeinsame Dateien (`app/Package.swift`, `Setzkasten/project.yml`, `plan/STATUS.md`) änderst nur du, nach den „Wünschen an den Chef“ in den Briefen.

## Parallel bauen mit Arbeitsklonen

Mehrere Bauagenten arbeiten nie in derselben Arbeitskopie, weil halbfertiger Code des einen sonst den Bau des anderen bricht. Jeder bekommt einen eigenen Klon, nur Zweig `main`, ohne Push:

```bash
git clone -q ~/Developer/ALLFARBEN ~/Developer/ALLFARBEN-bau/B-xxx   # Klon vom lokalen Haupt-Repo
# Bauagent arbeitet und committet in ~/Developer/ALLFARBEN-bau/B-xxx auf main
cd ~/Developer/ALLFARBEN && git pull --rebase ~/Developer/ALLFARBEN-bau/B-xxx main   # Chef holt nach der Prüfung
rm -rf ~/Developer/ALLFARBEN-bau/B-xxx          # Klon weg, wenn geholt
```

Getrennte Pfade machen das Holen konfliktfrei. Gemeinsame Dateien legt der Chef vorher an (Ziele in `Package.swift` mit Gerüstdatei), damit kein Agent sie ändern muss.

## Prüfen

6. Für jeden zurückgemeldeten Brief:
   - Lies den Diff (`git log`, `git diff`).
   - Führe jeden Befehl unter „Fertig wenn“ selbst aus.
   - Vergleiche Bildschirmfotos mit der Abnahme.
   Fertig, wenn jeder Punkt „Fertig wenn“ einen eigenen Beleg von dir hat. Fehlt einer: Brief zurück an den Agenten, mit dem fehlenden Punkt.
7. Setze den Status im Briefkopf und in `plan/STATUS.md` auf „erledigt, geprüft <Datum>“.

## Gate

8. Sind alle Briefe einer Etappe erledigt:
   - Führe `scripts/pruefen.sh` aus (ab E1).
   - Arbeite die Gate-Abnahme aus `plan/MASTERPLAN.md` Punkt für Punkt ab.
   - Schreibe `plan/gates/G<n>.md`: Punkt, Beleg, Ergebnis.
9. Bitte Johannes um die Abnahme am Bild. Seine Antwort steht wörtlich mit Datum in `plan/gates/G<n>.md`. Erst dann ist das Gate offen.

## Ende jeder Sitzung

10. Schreibe den Übergabezettel `uebergabe/JJJJ-MM-TT_HHMM_chef.md`: getan, Beleg, offen, nächster Schritt. Committe. Push nur, wenn die Etappenfreigabe es erlaubt oder Johannes es sagt.

## Wenn etwas klemmt

- Ein Brief ist zu groß (mehr als ein Tag Arbeit oder mehr als 600 geänderte Zeilen): Teile ihn in B-xxx-a und B-xxx-b und trage beide in STATUS ein.
- Eine Entscheidung fehlt: Trage sie in `konzept/OFFENE-FRAGEN.md` ein, mit Vorschlag, und frage Johannes. Baue nicht auf Annahmen weiter.
- Zwei Briefe brauchen dieselbe Datei: Ziehe die gemeinsame Stelle in einen eigenen Brief, den du selbst baust, oder ordne die beiden nacheinander.
