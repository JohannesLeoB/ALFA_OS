# Spec · Aufmaß

Stand 22.10.2026 · Entwurf aus Altcode-Inventur und Hub-Entwürfen. Nicht gebaut.

## Ablauf
Foto der Wand auf der Baustelle → in Aufmaß laden → mit Maus und Linienwerkzeug Punkt-zu-Punkt-Linien ins Foto setzen → Maß von Hand eintragen oder per Bluetooth vom Laser übernehmen. Aufmaß ist Zeichnen mit Maß, kein CAD.

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

## Laser (Bluetooth-Entfernungsmesser, unbelegt an Hardware)
- CoreBluetooth; Name enthält die Gerätekennung des Altcodes; Service `3AB10100-F831-4395-B29D-570977D5BF94`, Messwert-Characteristic `3AB10101-…` (LaserGeraeteProfil.swift:31-38).
- Wert: erste 4 Bytes IEEE754 float32 little-endian = Meter, endlich, ≥ 0 (LeicaDistoStatusReducer :144-150).
- Fehler im Altcode: Service/Characteristic mit `.first` statt UUID (:112, :117), kein Neuverbinden, Streams enden nie.
- Erst Diagnose am echten Gerät, dann Profil festschreiben.

## Anforderungen an Blatt und Export
1. Blatt: Foto füllt das Zeichenfeld; Maßstab „o. M.“ beim Foto; Firmendaten und Zeichner aus dem Hub.
2. Export über den Standard-Sichern-Dialog.
3. Plankopf vor dem Export: Kunde, Projekt, Straße, PLZ/Stadt, Kundennr., Datum, Maßstab, Zeichner, Mail; Live-Vorschau des Blatts.
4. Exportformate: CI-PDF (Plankopf), flaches PDF, PNG.
5. „Ablegen“ in den Projektordner, daneben „Anderswo speichern“.
6. Messen mit Lupe, Einrasten, Fadenkreuz; Maßliste mit Summe.
7. PDF-Metadaten gefüllt (Titel, Verfasser, Stichwörter), Seitengröße genau 420 × 297.
8. Vorlagen (Aufmaß, Moodboard, Pläne) kommen per Pfad über die Einstellungen.
9. Hub: Firma → Firmendaten (Fuß des Schriftfelds), Dateiordner (Projektordner, Projektdaten), Vorlagen.

## Prüfung (eine, die rot werden kann)
Kalibrierung (Strecke → mm/px), Maß aus zwei Punkten, Entzerrung (4 Punkte → bekanntes Rechteck), Laser-Dekodierung (Bytes → Meter, ungültige Werte abgelehnt), Maßliste mit Summe und Herkunft, Blatt-Golden.
