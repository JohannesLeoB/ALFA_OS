# Abgleich Runde 1 – Durchgänge A (Front zuerst), B (Seite/Innen zuerst), C (eigen)

Konsens = 3/3 gleich; Mehrheit = 2/3; offen = keine Mehrheit oder alle unsicher.

## Konsens 3/3
| Größe | Wert | Status |
|---|---|---|
| Schränke | 3: US-GSP · US-SP · US-S1I, je b 600 | B |
| Front-/Korpushöhe | 790 | B |
| Sockel | 100 | B |
| Arbeitsplatte Stärke | 35; OK AP 925 | B / A |
| Nische | 1875 × 2200 | B |
| Fuge Stellseite–Front | 5 links, 5 rechts | B |
| Stellseite Stärke | 32,5 gerechnet; grafisch 35–37 | A (Plan-Widerspruch) |
| Deckplatte Stärke | 30 gerechnet | A (Plan-Widerspruch) |
| Zargen Pos 3 | Auszug 235 + 2 Innenschübe 115 | B |
| Spülenschrank | ohne vordere Traverse | A/N |
| Steckdosen | 2 je Stellseite | B |
| Tiefen | 600 (Rahmen) und 574 (Frontebene–Wand) | B |

## Mehrheit 2/3 (C korrigiert)
| Größe | A | B | C | Ergebnis |
|---|---|---|---|---|
| Bedeutung 600 − 574 = 26 | Rahmen vor Front | Rahmen vor Front | offen | Stellseiten + Deckplatte stehen 26 vor die Fronten (A) |
| Stellseite Höhe | 2170 | 2170 | 2200 | 2170, Deckplatte liegt oben auf (N) |
| Deckplatte Breite | 1875 | 1875 | 1810 | 1875, über die Stellseiten (N) |
| Korpustiefe t (ohne Front) | 555 | 555 | 574* | 555 = 574 − 19 (N, Frontstärke Typwert) – *C hatte t inkl. Front: Definition geschärft |
| Arbeitsplatte Tiefe | 574 | 574 | 600 | 574 bündig Frontebene (N), 600 möglich |

## Feinheiten → Default (Feintuning durch Nutzer, keine Rückfrage)
- Griffmulde-Überstand: Parameter vorhanden, Default 15 (aus Plan).
- Fuge zwischen Fronten: Default 3.
- GSP-Front: Klappe nach unten.
- Sockelrücksprung: Default 60.
- Vorstand Rahmen, Plattenstärken: Defaults aus Katalog.

## Plan-Widersprüche (notiert, nicht korrigiert)
- Breitenkette 1810 ≠ Nische 1875 (Stellseiten unbemaßt).
- Höhenkette 2170 ≠ 2200 (Deckplatte unbemaßt).
- 26 mm Tiefenvorstand unbeschriftet.
- Geräteliste nennt ein Kühlgerät, das in keiner Ansicht vorkommt (B) – Listenvorlage vermutlich aus anderem Projekt übernommen.

## Katalog-Lernpunkte → v1
- `fronten[].oeffnung` (tuer_links, tuer_rechts, klappe_unten, klappe_oben, auszug) statt nur `anschlag` (A, B).
- `fronten[].zarge_h` für den Hauptauszug (A, B).
- `innen[].lage` oben/unten für Innenschübe (B).
- `griffmulde_ueberstand` je Front (A, B, C).
- Elemente mit Parametern: Stellseite {d, t, h, vorstand_vor_front, fuge_zur_front, steckdosen[]}, Deckplatte {d, b, t, auflage}, Sockelblende {h, ruecksprung, stoesse}, Arbeitsplatte {d, t, l, ausschnitte[]} (B).
- US-SP: `becken {b, t, h}`, `technik[]` (B).
- Begriff geschärft: `t` = Korpustiefe ohne Front; `t_frontebene` = Wand bis Frontvorderseite.
