---
name: spec-architektur
description: Bild der App als Hub mit Einstellungen in der Mitte, Vorgangs-Bausteinen im Ring, Schubladen als Stecker darunter; fünf Bauregeln als Vorschlag der Lead
metadata:
  type: project
---

# Architektur · Spec (Stand 21.10.)

## Johannes' Bild (Skizze 21.10., Lead-Chat bc4854d7)
Grobe Idee, kein Plan: „in ca 40 sekunden mit BIC Kuli im Bett nach 23 Uhr entstanden - kein ausgetüftelter architekturplan“. Daraus nur der Kern, keine Details ableiten: Hub und Einstellungen in der Mitte (vgl. sein Wort 14.09.: „prinzipiell EINS“), ringsum die Bausteine eines Vorgangs (Projekte, Aufgaben, Team, Zeit, Geld, Mail, Artikel, Daten), darunter die Schubladen (Google, ClickUp, Clockodo, Geld, Dokumente, Mail, Personen, Firmen, Kunden, Web), alles über den Hub verbunden.

## Schichten (Vorschlag der Lead, von Johannes' Bild gedeckt, als Bauregel noch zu bestätigen)
1. **Bereiche** (Mail, Projekte, Heute, Kataloge, Warenkorb …): dünne Ansichten.
2. **Werkstatt**: neutrale Ein- und Ausgabe-Module (spec-ziel ZIEL-K11); darauf die Editoren der „Creative Cloud“ (Draws, Skizze/Atelier, Moodboard, Aufmaß; ZIEL-K12).
3. **Kern**: Vorgang, Stücke mit Merkmalen, Verknüpfung (ZIEL-K05–K08).
4. **Hub**: Systeme mit Rolle, Ströme, Protokoll, Einstellungen je Dienst (spec-hub).
5. **Schubladen**: Dienste und Speicher, bleiben die Wahrheit für ihre Stücke.

## Bauregeln (Vorschlag der Lead)
- **ARCH-R01 Eine Richtung:** Bereiche kennen Werkstatt, Kern und Hub; der Hub kennt keine Bereiche; ein neuer Bereich ändert nichts darunter.
- **ARCH-R02 Kleine Tür, großer Raum:** jedes Modul hat wenige Funktionen nach außen und viel Arbeit dahinter.
- **ARCH-R03 Dienste und Branchen sind Daten:** ein neuer Stecker ist ein Eintrag; Branchenwerte sind Presets je Firma (ZIEL-K10, HUB-R03).
- **ARCH-R04 Kern ohne Oberfläche und ohne Anbieter:** rechnet nur mit Vorgängen, Stücken, Merkmalen; deshalb später auch iPad, iPhone, Web (ZIEL-R05).
- **ARCH-R05 Jedes Modul hat eine Prüfung, die rot werden kann** (AGENTS §10).

## Ist (21.10.)
- Gebaut: Hülle (`alfaos/Kit/Sources/ShellCore`), Hub mit Zugang, Takt, Einstellungen je Dienst (`alfaos/Kit/Sources/Hub`), Mail als erster Bereich (`alfaos/Kit/Sources/Mail`, `alfaos/App/Mail`).
- Fehlt: Kern (Vorgang) und Werkstatt; erste Werkstatt-Module entstehen als neutrale Module auf `alfa-draws` (Draws-Sitzung).
- Abweichung: Kit hängt über `alfaos/Kit/Package.swift` am Fundus, dessen Dateien teils SwiftUI/AppKit importieren (spec-ziel ZIEL-F03).
