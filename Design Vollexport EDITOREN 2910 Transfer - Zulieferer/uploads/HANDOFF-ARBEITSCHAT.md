# Handoff für den Arbeits-Chat · 15.10.2026

Du bist der Arbeits-Chat im Design-Projekt „Arbeitswelt ALFA Interface Zugang“. Du arbeitest die Liste in `PLAN.md` ab. Der Entwurfs-Chat ruht, bis du fertig bist. Johannes sieht dein Ergebnis, dann entwerfen beide im Entwurfs-Chat weiter.

## Startprompt (Johannes fügt ihn ein)
Lies zuerst `CLAUDE.md`, `PLAN.md`, `EINSTELLUNGEN-ABGLEICH.md` und diese Datei. Arbeite `PLAN.md` Durchgang für Durchgang ab. Ein Durchgang pro Runde, am Ende jedes Durchgangs ein Status mit Messwerten und der Liste „nicht geprüft“. Erfinde nichts. Belege jede Aussage mit Datei und Zeile oder einem Zitat von Johannes. Kein ZIP und kein Download ohne sein Wort. Lösche nichts, bevor er die Liste bestätigt hat. `uploads/` fasst du nie an.

## Regeln (aus `CLAUDE.md` und `entscheidungen.md`)
- **Hülle nur einmal.** Mail und Einstellungen sitzen in `ALFA Shell` (Maße in `alfa-shell.js`). Was die Hülle betrifft, gilt in beiden Bereichen und auf allen Bögen gleich.
- **Belegpflicht, Erfindungssperre.** Werte von dir gelten als „Vorschlag“, bis Johannes „so“ sagt.
- **Keine Mono-Schrift.** Namen in Code und Tokens englisch.
- **Farbe nie auf Aktionen**, Signalrot nur für Destruktives.
- **Kein „fertig“ ohne Johannes’ „so“.**

## Arbeitsweise
- Von Hand ändern, gezielte Einzeländerungen. Skripte nur zum Messen am Render.
- Messen bei 1512 × 982, hell und dunkel. Vorher und nachher.
- Jeden Durchgang mit einem unabhängigen Verifier-Lauf abschließen.
- Dateien ohne Umlaut anlegen. `ALFA Hülle.dc.html` lässt sich mit den Werkzeugen nicht lesen oder per Skript öffnen. Erst umbenennen (Johannes fragen), dann abgleichen.

## Stand heute (belegt in dieser Sitzung)
- **Hülle:** Ruhe links und rechts 280, Minima 224 / 280 / 280 (`alfa-shell.js`, Kommentar von Johannes: „vereinheitlichen auf 280“). Blob-Menü öffnet mit `K.rest` 280, Bahnen haben `z-index:1; isolation:isolate`, Blob `z-index:10`.
- **Mail:** Kartenstapel mit Radius 20 oben und 0 unten, Kartenfuß 44 (Lesen: Drucken, PDF, Projektordner, Mehr; Schreiben: Anhängen, Projektordner, Format, Mehr, Senden), Übersicht mit Autofold, Kontaktvorschläge, Suchbereich „Überall / Nur Ordner“.
- **Tokens:** `TOKENBOGEN.json` ist nachgezogen (Nachtrag 15.10.). Daneben gibt es einen zweiten Stand in `design-system/` (174 Tokens), der aufgelöst werden muss. `WERTE.json` ist nur ein Auszug.
- **Aufgeräumt am 16.10.:** Alte Ordner und MDs sind gelöscht (siehe PLAN.md, Punkt 8). `Farbleiter.dc.html` ist weg.
- **Die Seiten (Stand 15.10., Farbleiter inzwischen gelöscht):** Mail, Einstellungen, Einstellungen Inhalt, Shell, Bestätigen, Dienste, Hülle, Tokenbogen, Designsystem, Farbleiter, Shell Bogen, Bestätigen Bogen.
  - Behalten: Mail, Einstellungen (nur als Aufruf), Einstellungen Inhalt, Shell, Tokenbogen, Designsystem.
  - Entfernen nach Bestätigung: Farbleiter. Shell Bogen erst, wenn seine Maße- und Ebenenliste im Designsystem steht.
  - Zusammenführen zu einem Bogen „Johannes entscheidet“ (Auswahl, Haken, Kommentar, Freitext, Mehrfachwahl): Bestätigen, Bestätigen Bogen, Dienste.
  - Prüfen und entfernen, wenn verlustfrei: Hülle.
- **Einstellungen:** zwei Fassungen, die zu einem Bereich werden sollen (Tabelle in `EINSTELLUNGEN-ABGLEICH.md`). Inhalt hat mehr Tiefe (`FN`), Mail hat Stapel und Übersicht.

## Offen und von Johannes zu entscheiden
- Hub aus Kacheln als Startansicht der Einstellungen?
- Wo liegen die Lastenhefte und Specs der App-Codes?
- Mehrere Mail-Konten: Wähler oder gestapelt (Vorschlag in der Entwurfs-Sitzung, nicht gebaut)?
- Bewegung: 13 Zeiten im Code, vier Stufen nur als Vorschlag.
- Blob-Auge 4 × 8 und Abstand 4: Vorschlag.
- Fläche (Lack, Glas, flach): wirkt nur auf Karten im Stapel, nicht von Johannes entschieden.

## Nicht geprüft
Echte Maus. Dunkel in allen Zuständen der Einstellungen. Die zwei Tabs mit demselben Chat.
