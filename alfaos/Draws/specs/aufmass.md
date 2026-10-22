# Spec · Aufmaß

Stand 22.10.2026 · Sammlung der Draws-Sitzung aus Johannes' Bildern (Altcode-App, 7 Bilder + Hub-Entwürfe) und der Altcode-Inventur. Nicht gebaut; gebaut wird vorerst nur Draws.

## Johannes' Wort
- 22.10.: „Ich mache auf baustelle ein foto von wand. habe einen laser entfernungsmesser am macbook gekoppelt. mache ein foto. lade es in alfa OS Aufmaß und kann in foto mit maus und linienwerkzeugen point to point linien in das foto setzen und maße dazu selber notieren oder vom laser einsetzen lassen per bt.“
- 22.10.: „aufmaß ist auch nur zeichnen mit nem zollstock in der anderen hand“.

## Funktion (aus dem Altcode übernehmen, Form nicht)
| Bereich | Soll | Altcode-Beleg (labor/ansicht) |
|---|---|---|
| Unterlage | Foto oder PDF (alle Seiten), füllt das Zeichenfeld | AufmassCanvasView.swift:1762-1783 (nur Seite 1) |
| Messen | zwei Klicks, Lupe, Einrasten (Endpunkt, Kante), Linienstile, Live-Maß-Pille | :1535-1558, :2632, AufmassLayer.swift:74 |
| Kalibrieren | Referenzstrecke + Länge → mm je Pixel; **neu: Entzerrung über 4 Punkte** (Altcode zeichnet Fluchtlinien nur als Hilfe) | AufmassModell.swift:88-117; AufmassPerspektive.swift:24-199 |
| Herkunft je Maß | Hand, Laser, Kalibrierung, automatisch; mit Zeit | AufmassModell.swift:36-40, :120-126 |
| Laser | Port „Messquelle“ mit Geräteprofilen + Diagnose; Wert per Klick übernehmen | LeicaDistoBluetoothAdapter.swift:5-151 |
| Ebenen | Rolle, Farbe, Schriftgröße, sichtbar, Summe je Ebene | AufmassLayer.swift |
| Symbole, Pins | Installationssymbole, Notiz-Pins, Marker-Pille | AufmassCanvasView.swift:103 |
| Auto-Maß | Kantenerkennung (Vision) → Vorschläge | AufmassKantenErkennung.swift:20, AufmassAutoBemassung.swift:24 |
| Maßliste | Nummer, Bezeichnung, Wert, Herkunft; Summe | Bild 6 |
| Blatt | Studio-A3 über `Pages` + Vorlage; Maßstab „o. M.“ beim Foto; Felder aus Akte/Firmendaten (Hub) | AufmassCIDokument.swift (Firmendaten fest im Code) |
| Export | CI-PDF mit Plankopf, flaches PDF, PNG; Ablegen in Projektordner `01 INFOS/01 Pläne`, sonst Ordner frei | Bild 4–5, :1942-1970 |
| Stände | Werkstatt-Ablage mit Papierkorb | ArbeitsstandAblage.swift |

## Laser (Leica DISTO D110, unbelegt an Hardware)
- CoreBluetooth; Name enthält „disto“; Service `3AB10100-F831-4395-B29D-570977D5BF94`, Messwert-Characteristic `3AB10101-…` (LaserGeraeteProfil.swift:31-38).
- Wert: erste 4 Bytes IEEE754 float32 little-endian = Meter, endlich, ≥ 0 (LeicaDistoStatusReducer :144-150).
- Fehler im Altcode: Service/Characteristic mit `.first` statt UUID (:112, :117), kein Neuverbinden, Streams enden nie.
- Erst Diagnose am echten Gerät, dann Profil festschreiben.

## Aus Johannes' Bildern
1. Blatt: Foto klein mittig, viel Leerraum; rechte Spalte leer bis aufs Schriftfeld; Maßstab 1:100 beim Foto sinnlos; Firmendaten und Zeichner fest.
2. Export über den Standard-Sichern-Dialog („…CI-Dokument (A3 quer)“, Name `Neues-Aufmaß-Aufmass-A3`).
3. Dialog „Plankopf“ vor dem Export: Kunde, Projekt, Straße, PLZ/Stadt, Kundennr., Datum, Maßstab, Zeichner, Mail; Live-Vorschau des Blatts.
4. Exportmenü: CI-Aufmaß-PDF (Plankopf), flaches PDF, PNG.
5. „Ablegen“ in den Projektordner, daneben „Anderswo speichern“.
6. Messen mit Lupe, Stil „Dünn“, Einrasten/Fadenkreuz; leere Maßliste zeigt einen Erklärsatz (fällt weg); Summe unten.
7. PDF-Metadaten leer (Titel, Verfasser, Stichwörter), PDF 1.3 Quartz, ohne Tags, 419,8 × 296,7 statt 420 × 297.
8. Drive „Vorlagen“: 03_AUFMASS, 04_MOODBOARD, VECTORWORKS PLÄNE (DWG A0–A3, Elektro/Sanitär; DWG_DXF; PDF Planlayouts), MOODBOARD TEMPLATES, Aufmaß-Vorlage/-Template. Kommt in ALFA per Pfad über die Einstellungen.
9. Hub-Entwürfe: Einstellungen Firma → Firmendaten (Fuß des Schriftfelds), Dateiordner (Projektordner im geteilten Drive, Projektdaten Airtable), Vorlagen (noch leer).

## Prüfung (eine, die rot werden kann)
Kalibrierung (Strecke → mm/px), Maß aus zwei Punkten, Entzerrung (4 Punkte → bekanntes Rechteck), Laser-Dekodierung (Bytes → Meter, ungültige Werte abgelehnt), Maßliste mit Summe und Herkunft, Blatt-Golden.
