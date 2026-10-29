Export: 21.10.2026

# IN PROGRESS · NO MASTER · Übergabe Draws an die Prototypen-Session

**Status:** Arbeitsstand der Design-Session „ALFA OS Editoren Sketches 1610“. **Kein Master, keine Freigabe, keine Lieferung an Code.** Johannes hat nichts davon entschieden. Nur zum Lesen und Prototypen.

## Inhalt
| Datei | Was | Status |
|---|---|---|
| `ALFA Draws.dc.html` | Bogen Draws (562 Zeilen) | IN PROGRESS, enthält Erfundenes (siehe unten) |
| `alfa-draws.css` | 18 Blattfarben, hell und dunkel | set-by-design |
| `draws.tokens.json` | Auszug TOKENBOGEN › draws: 18 Farben, 21 Maße, 10 Regler, Formate, Töne, Bewegung | set-by-design |
| `ERFUNDEN_DRAWS-ABLAEUFE.md` | Abläufe und Klickzahlen | **erfunden**, keine Quelle, nicht verwenden ohne Johannes |
| `ALFA Shell.dc.html`, `alfa-shell.js`, `alfa-theme.css`, `support.js` | Hülle, nur damit der Bogen läuft | Kopie Master-Kandidat 2110, hier **nicht** Master |

## Quelle des Auftrags
Brief Draws 21.10.2026 (Johannes, m0067), 7 Punkte:
1. Linke Bahn: Projekt (Nachname, Projekt, Straße, PLZ/Ort, Kundennr., Datum), Packs (CI, Vorlage) mit Mängelliste, Objekt (Teileliste, Laden).
2. Mitte: Blatt-Vorschau (weißes A-Format auf Grund), Zoom/Pan, Kopfzeile mit Preset-Wahl (Drei Ansichten, Isometrie, Iso-Schritte, Perspektive, Kunde).
3. Rechte Bahn: Inspektor je Ansicht (Typ, Richtung, Fokus, Iso-Schritte, Maßstab auto/fest, Bemaßung an/aus), Export (PDF, SVG, mehrseitig).
4. Iso-Stil einstellbar: Azimut, Elevation, Flächentöne oben/Seite/Front, Kantenstärke innen/Umriss, Schatten an/aus und Stärke, ein Akzentteil, Materialtöne. Bedienelement und Werte je Regler.
5. Blob-Menü: Blatt, Packs, Ansichten, Claude, Export; Doppelklick Assistent (Claude-Import Foto/PDF/Text → Objekt).
6. Zustände: leer, Mängel, Überlauf, Export läuft, Fehler.
7. Ansichten per Ziehen auf ein Raster versetzen: Raster, Fanglinien, Auswahlrahmen.
Dazu: je Wert ein Token mit Quelle, hell und dunkel. Keine neuen Bausteine, wo es Bahnkopf, Zeile, Segment, Pill, Schalter schon gibt.

## Erfunden (nicht im Brief, nicht belegt) – vor Gebrauch entfernen oder von Johannes bestätigen lassen
- Beispielobjekt „Sideboard SB-18“: 6 Teile, Maße, Materialien Eiche, Nussbaum, Lack weiß, Stahl
- CI-Wahl „Studio, Kunde, Neutral“, Mangel „Kunden-CI ohne Logo“, Studio-Logo „ST“ im Schriftfeld
- Vorlagen A4 hoch, A4 quer, A2 quer (nur „A-Format“ steht im Brief)
- Material- und Akzentfarben, Abdunklung je Fläche
- Blattsatz Werkstatt, Kunde, Montage; „Blatt hinzufügen“
- Index A, B, A* im Schriftfeld und im Export-Reiter
- Stückliste auf dem Blatt
- Schritt-Texte „Sockel setzen“ und die weiteren drei
- Export-Seiten „Satz“
- „aus Akte P-2041“, Vorgabewerte der Projektfelder (Brandt, Lindenstraße 14 …)
- Duplizieren, Entfernen, Stil zurücksetzen; Kürzel R, 0, +, −
- Maßstäbe 1:1 bis 1:100

## Nicht gebaut
- **Claude-Import ist gespielt.** Der Knopf ruft Claude nicht auf, er setzt nur einen Zeitschalter (1,6 s) und lädt dann das Beispielobjekt.
- **Rendern mit Claude:** fehlt ganz. Steht nicht im Brief, Johannes nannte es am 21.10. Was Claude dabei tun soll, ist **unbekannt**.
- **Stile als Vorlage** sichern, benennen, wählen: fehlt. Es gibt nur die Regler im Reiter „Stil“.
- Kein Abgleich mit dem Funktionscode.

## Funktionsquelle im Repo (gelesen, nicht abgeglichen)
`JohannesLeoB/ALFA_OS`, `fundus/alpha/Sources/AlfaKit/Domain/`:
- `PlanProjektion.swift` (134/134 Z.) enthält u. a. `isometrie` (Symbol „cube“)
- `PlanDokument.swift` (109/109 Z.)
- `PlanTransform.swift` (61/61 Z.)
Weitere Plan-, Export- und Laser-Dateien sind nicht gelesen.

## Tokens: bekannte Abweichungen im Bogen
- Feldlabel 76 px (Token fieldLabelWidth 48), Textfeld 72 hoch, max-width 150: ohne Token.
- Toast z 40, Menü z 50 statt layer.toast 4 / layer.menu 5.
- Menübreite nur geklemmt 168–280, ohne menuWidthStep 56.
- Kein Tracking aus typography.tracking.*.

## Offene Fragen (Prompt an Bauer und Projektleiter, m0073)
1. Wer erstellt Draws-Blätter, für wen? Mehrere Blätter je Projekt?
2. Woher kommen Projektfelder und Objekt? Format der Teileliste? Beispielobjekt aus dem Code?
3. Inhalt von CI- und Vorlagen-Pack, echte Formate, Mängelregeln.
4. Erlaubte Maßstäbe, Logik „auto“, Herkunft der Iso-Schritte, Materialliste, Akzentfarbe, Bemaßungstiefe.
5. Bedeutung „mehrseitig“, Index im Schriftfeld, Exportfehler-Texte.
6. Rückgabe des Claude-Imports, Prüfschritt vor Übernahme. **Neu: Was ist „Rendern mit Claude“, und was sind „Stile“ (Vorlage, Pack)?**
7. Festgelegte Kürzel, Duplizieren, Entfernen, Zurücksetzen.
Antwort bitte nummeriert, mit Quelle (Datei:Zeile oder Entscheidung von Johannes).
