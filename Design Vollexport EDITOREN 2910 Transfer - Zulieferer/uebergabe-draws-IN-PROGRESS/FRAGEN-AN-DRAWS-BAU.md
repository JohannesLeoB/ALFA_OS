Export: 22.10.2026 · IN PROGRESS · NO MASTER

# Fragen an die Draws-Bau-Session

Von: Design-Session „ALFA OS Editoren Sketches 1610“. Bitte nummeriert antworten, je Antwort mit Quelle (Datei:Zeile im Code oder Entscheidung von Johannes). „Weiß nicht“ ist eine gültige Antwort. Bitte nichts erfinden.

## A · Was der Bogen heute hat (Bestand 22.10., per Skript gezählt, 29 Bedienstellen)
**Links:** 6 Eingabefelder (Nachname, Projekt, Straße, PLZ/Ort, Kundennr., Datum) · CI wählen · Vorlage wählen · Mängelliste (Klick behebt) · Teileliste (Klick = Akzent, Auge = aus/ein) · „Objekt laden“ (Konfigurator, Datei, Claude-Import, leeren) · Spalte falten.
**Mitte:** Preset-Wahl (5) · Zoom −/%/+ · Raster an/aus · Blatt groß · Ziehen/Pan · Ansicht ziehen (Raster 10 mm, Fanglinien, Alt = frei) · 4 Eckgriffe · Leer-Zustand · Status · Toast mit Rückgängig.
**Rechts, Reiter Ansicht:** Liste der Ansichten · Typ · Richtung · Fokus · Iso-Schritte · Maßstab auto/fest · fester Maßstab · Bemaßung · Füllung Töne/Material · Duplizieren · Entfernen.
**Rechts, Reiter Stil:** Azimut · Elevation · Flächentöne oben/Seite/Front · Kante innen/Umriss · Schatten an/aus und Stärke · Akzentteil und Farbe · 4 Materialtöne · Stil zurücksetzen.
**Rechts, Reiter Export:** PDF/SVG · ein Blatt/je Ansicht · Prüfung · Fortschritt · Fehler · Sichern/Abbrechen/Erneut.
**Claude:** Panel mit Foto/PDF/Text und Textfeld, Knopf „Objekt erzeugen“. **Gespielt:** Es gibt keinen Aufruf an Claude, nur einen Zeitschalter mit 1,6 s. Danach lädt der Knopf immer das Beispielobjekt.
**Blob:** Blatt, Packs, Ansichten, Claude, Export.

## B · Fehlt sicher
- Claude wirklich aufrufen; Ergebnis prüfen, bevor es übernommen wird
- **Rendern mit Claude**
- **Stile** sichern, benennen, wählen
- Teile bearbeiten (Maß, Material, Name): Die Teileliste kann man nur lesen.
- Maße auf dem Blatt ändern oder ergänzen; Texte und Notizen aufs Blatt
- Ansicht neu anlegen (nur Duplizieren vorhanden)
- Rückgängig/Wiederholen allgemein (nur im Toast)
- Drucken; mehrere Blätter je Projekt

## C · Fragen
**Claude**
1. Was macht Claude in Draws genau? Nur Import (Foto, PDF, Text → Objekt), oder auch **Rendern**? Wenn Rendern: von was nach was (Iso → Foto-Look, Blatt → Präsentation)? Wo landet das Ergebnis?
2. Was gibt der Import zurück: Teileliste mit Maßen, Materialien, Baugruppen? In welchem Format? Gibt es dafür einen Typ im Code?
3. Wo erscheint Claude: als Blob-Doppelklick-Assistent, als eigenes Panel, im Inspektor, als Bahn?
4. Wie prüft der Nutzer, was Claude geliefert hat (Vergleich, Teile einzeln annehmen, verwerfen)? Was passiert bei unsicheren Maßen?
5. Darf Claude bestehende Ansichten, Stil oder Schriftfeld ändern, oder nur das Objekt?

**Stile**
6. Was ist ein „Stil“: der Iso-Stil aus Punkt 4 des Briefs, ein Pack wie CI und Vorlage, oder ein Render-Stil?
7. Sichern, benennen, je Projekt oder je Studio? Gibt es Vorgabestile? Welche?

**Objekt und Teile**
8. Woher kommt das Objekt (Konfigurator, Datei, Claude)? Welche Dateiarten?
9. Dürfen Teile in Draws bearbeitet werden, oder nur angesehen, ausgeblendet und als Akzent gesetzt?
10. Gibt es ein echtes Beispielobjekt im Code (statt meinem erfundenen „Sideboard SB-18“)?

**Blatt, Packs, Mängel**
11. Was enthält ein CI-Pack, was eine Vorlage? Welche Formate (A4, A3, A2, hoch/quer)?
12. Welche Regeln ergeben einen Mangel? Blockiert ein Mangel den Export oder nur ein Überlauf?
13. Ein Blatt je Projekt oder mehrere? Index oder Revision im Schriftfeld?
14. Was steht im Schriftfeld, in welcher Reihenfolge?

**Ansichten und Bemaßung**
15. Welche Maßstäbe sind erlaubt? Wie arbeitet „auto“?
16. Woher kommen die Iso-Schritte (Montageschritte aus dem Objekt oder vom Nutzer)?
17. Welche Bemaßung: nur Gesamtmaße, oder auch Teil- und Kettenmaße? Darf man Maße setzen?
18. Ansicht neu anlegen, löschen, duplizieren: welche davon soll es geben?

**Export und Bedienung**
19. „Mehrseitig“ heißt: eine Seite je Ansicht, je Blatt oder je Schritt?
20. Wohin wird gesichert? Wie heißt die Datei? Gibt es Druck?
21. Festgelegte Tastenkürzel? (Im Bogen stehen R, 0, + und −; die habe ich erfunden.)
22. Welche der Funktionen in PlanProjektion.swift, PlanDokument.swift und PlanTransform.swift gehören zu Draws?

## C2 · Befund im lokalen Repo ALFA_OS (23.10., gelesen)
- **Kein Draws-Bereich im Code.** Die Suche nach „Draws“, „Zeichenblatt“ und „Iso-Schritt“ in `fundus/alpha/Sources` und `alfaos` findet nichts. Einziger Treffer ist `drawsBackground` in MailHTMLView.swift:72, eine macOS-Eigenschaft.
- **Pläne und Renderings werden gesammelt, nicht erzeugt:** `AlfaServices/Google/PlanCollector.swift` (150/150 Z.) liest aus dem Drive-Projektordner die Kategorien Pläne, Werkszeichnung, Renderings, Vorplanung, Layouts und Präsentation (:4–17), Dateitypen pdf, jpg, png, heic, tiff, webp (:79–82). Dazu gehören `AllPlansCollector.swift` und `DriveProjectFolderWatcher.swift:190` („drawingDetected“).
- **Claude im Code:** `AlfaServices/Claude/ClaudeChatClient.swift` ist ein Chat mit Werkzeugen (toolUses) und Anhängen (`attachmentBlock`, :211). Die Modelle stehen in AssistantModelRouter.swift:4–6. **Bildausgabe oder Rendern gibt es dort nicht.**
- **Plan-Typen:** `AlfaKit/Domain/PlanProjektion.swift:36` (enum, u. a. `isometrie` :39), `PlanDokument.swift:70` und `PlanTransform.swift:12`.
- **Brief v13 (`DESIGN/brief/BRIEF.txt`) nennt Draws nicht.** N18 und N40 (Johannes 21.10.) verlangen: keine Erklärsätze in der UI, Fehler und Warnungen sind erlaubt. Der Draws-Bogen hat solche Sätze („Ansicht auf dem Blatt anklicken …“, „Ohne Objekt bleiben die Ansichten leer.“ und weitere). Sie müssen raus.
- N37 [Wort 22.10.]: Den Assistenten im Blob (Doppelklick) gibt es einmal für alle Bereiche, mit Eingabe, Antwort, Verlauf und Anhängen. Ein eigenes Claude-Panel in Draws widerspricht dem wahrscheinlich.

**Folgefragen dazu**
23. Liest Draws seine Pläne aus dem PlanCollector (Werkszeichnung, Renderings) oder erzeugt Draws neue Blätter? Wird ein in Draws erzeugtes Blatt in den Drive-Ordner „Werkszeichnung“ gesichert?
24. „Rendern mit Claude“: Der ClaudeChatClient gibt nur Text und Werkzeugaufrufe zurück. Rendert ein anderer Dienst, oder liefert Claude Teile und Werte, die Draws dann selbst zeichnet?
25. Läuft der Claude-Import in Draws über den einen Blob-Assistenten (N37), mit Anhang Foto oder PDF und einem Werkzeug wie „Objekt anlegen“, statt über ein eigenes Panel?

**Antworten Johannes (23.10.)**
- Zu 23: **Draws erzeugt neue Blätter.**
- Zu 24: Rendern ist ein **Dienst**. Das kann Claude sein oder eine andere KI. Es **muss aber einen geben**. Ob der Dienst wählbar ist (Hub, wie N6 KI-Integrationen) und welcher als Vorgabe gilt, ist offen.
- 25: offen.

## D · Bitte mitschicken
- Liste aller Funktionen, die Draws im Code hat oder haben soll
- echte Daten für ein Beispielobjekt
- Fehlertexte beim Export
