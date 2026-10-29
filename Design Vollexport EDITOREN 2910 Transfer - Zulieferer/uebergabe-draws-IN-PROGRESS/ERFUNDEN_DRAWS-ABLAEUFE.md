Export: 21.10.2026

# Draws · Wozu, womit, wie oft · Entwurf zum Prüfen

Grundlage: Brief Draws 21.10.2026, Bogen `ALFA Draws.dc.html`. Alles hier ist **Annahme von Design** und muss von Johannes bestätigt werden (Status `set-by-design`).

## Wozu
Aus einem Möbelobjekt (Konfigurator, Datei, Claude-Import) werden Blätter, die das Studio aus der Hand gibt:
- **Werkstatt**: drei Ansichten mit Maßen und Stückliste, Maßstab fest. Für Tischler und Zuschnitt.
- **Kunde**: Isometrie und Perspektive mit Materialtönen, ohne Maße, mit Studio-CI. Für Angebot und Freigabe.
- **Montage**: Iso-Schritte 1–4 mit kurzem Satz je Schritt. Für die Monteure vor Ort.

Ein Projekt hat einen **Blattsatz** (linke Bahn › Blätter). Jedes Blatt hat Zweck, Vorlage, Ansichten und einen **Index** (A, B, …).

## Wer, wie oft
- Johannes oder Mitarbeitende im Studio, am Schreibtisch, Maus und Tastatur.
- Je Objekt einmal anlegen, dann **2 bis 6 Revisionen** (Kunde ändert, Maße ändern sich).
- Stil (Iso-Blick, Töne, Kanten) stellt man **selten** ein, eher einmal je Studio. Gehört später ins Pack, nicht in jedes Blatt.

## Abläufe mit Klicks
1. **Neues Blatt aus Objekt** (häufig, Ziel 3 Klicks): Objekt laden › Blatt hinzufügen › Zweck wählen. Projektdaten kommen aus der Akte, nicht getippt.
2. **Prüfen und ausgeben** (bei jeder Revision): Mängel links ansehen › je Mangel ein Klick zum Beheben › Export › Als PDF sichern. Der Index wird dabei gesetzt.
3. **Revision** (häufig): Objekt ändert sich › Schriftfeld zeigt `A*` › Export setzt Index B. Ein vergessener Index soll nicht möglich sein.
4. **Blatt anpassen** (gelegentlich): Ansicht ziehen (Raster 10 mm, Fanglinien) › Ecke ziehen für die Größe › Maßstab fest, wenn die Werkstatt 1:10 will. Passt etwas nicht, folgt Überlauf, Mangel und Exportstopp.
5. **Claude-Import** (selten): Foto einer Handskizze, PDF eines Angebots oder Text › Claude baut Teile › prüfen in der Teileliste.
6. **Satz ausgeben** (zum Termin): Export › Seiten › Satz. Alle Blätter landen in einem PDF.

## Folgen für die Oberfläche (eingebaut)
- Linke Bahn beginnt mit **Blätter**: wechseln mit 1 Klick, neues Blatt nach Zweck.
- **Index** im Schriftfeld und im Export-Tab (ausgegeben, geändert, nächster Index).
- **Stückliste** auf dem Werkstatt-Blatt (Schalter im Inspektor ohne Auswahl), Ansichten rücken zur Seite.
- Montage-Schritte tragen einen Satz („Sockel setzen“ …).
- Export-Seiten: Blatt · Je Ansicht · Satz.

## Offen, bitte entscheiden
1. Kommen die Projektdaten immer aus der Akte, oder wird auch frei getippt?
2. Index: Buchstaben (A, B) oder Zahlen? Mit Änderungsvermerk je Index?
3. Stil als Pack sichern (Studio-Stil) statt je Blatt?
4. Maßketten in der Werkstatt: nur Gesamtmaße wie jetzt, oder je Teil?
5. Bekommt der Kunde ein Blatt mit Notiz oder Freigabefeld?
