Export: 19.10.2026

# Kontrast-Protokoll · ALFA Mail · 19.10.2026
Messung im Render, 1512 × 982, Übergänge aus. Jedes sichtbare Textelement: Farbe (mit Deckkraft der Vorfahren) gegen den nächsten deckenden Hintergrund (Alpha-Mischung), Schwelle 4,5:1. Hell und dunkel getrennt. Skript im Chat (eval), Zähler = geprüfte Textelemente.

| Zustand | hell | dunkel |
|---|---|---|
| Ausgangszustand (Postfach, Lena Hansen vorn) | 102 ✅ | 102 ✅ |
| Übersicht Stapel / Übersicht Postfach | 15 ✅ / 45 ✅ | 15 ✅ / 45 ✅ |
| Entwurf vorn / Entwurf mit Sendefehler | 95 ✅ / 98 ✅ | 95 ✅ / 98 ✅ |
| Kontextmenü | 104 ✅ | 104 ✅ |
| Toast mit Rückgängig | 104 ✅ | 104 ✅ |
| Laden / Fehler / Leer / nicht erreichbar / nicht verbunden | 45 / 49 / 48 / 105 / 47 ✅ | gleich ✅ |
| Suche, Suche ohne Treffer | 72 ✅ (Zeilen vor der Sicherung unten ✅), 55 ✅ | 73 ✅, 55 ✅ |
| Empfängerliste offen | 108 ✅ | 108 ✅ |
| Mehrfachauswahl (m1 gewählt und gewählt, m3 gewählt) | 107 ✅ / 108 ✅ | 107 ✅ / 108 ✅ |

## Einstellungen (19.10., Nachtrag)
Zustände hell und dunkel: Ausgangszustand 68, Übersicht 18, Menü 68, Toast 66, Gruppe Ich 34, Firma 30, Schutz und System 33 ✅. Verbindungen mit 6 Karten im Stapel: Nebentext im Kartenkopf („Verbunden“, „Nicht verbunden“) auf den tiefen Stufen 3,52 bis 4,23:1 ❌ (Deckkraft 0,72 auf #a3a3a3 / #6b6b6b). Behoben: ab der vierten Karte Deckkraft 0,95 (`opacity.cardMeta` 0,72, `opacity.cardMetaDeep` 0,95, designSet), gilt in ALFA Mail und ALFA Einstellungen (gleicher Stapel). Danach: kleinster Wert hell 4,89, dunkel 4,80. Bei 0,9 lag dunkel 4,4999: zu knapp.

## Fund und Behebung
Mehrfachauswahl, wenn die vorn geöffnete Mail (Zeile „selected“) zusätzlich angehakt ist: Zeilenfläche wird hell (`--c-lane`), der Text blieb in der Farbe der gewählten Zeile (Weiß hell, #0d0d0d dunkel): Kontrast 1:1 hell, 1,05:1 dunkel, Text unsichtbar (Absender, Datum, Betreff, Vorschau, Zähler, Anhänge). Ursache: `pickRow` setzte nur Fläche und Marke um, nicht `fg`, `c2`, `c3`, `cLs`, `subFg`, `preFg`. Behoben in ALFA Mail.dc.html `pickRow`; danach 0 Fehler hell und dunkel. Das Muster stand schon vor der Trennung in der alten ALFA Mail (gleiche Funktion).

## Nicht geprüft
Mail mit 6 tiefen Karten (gleicher Code, nicht einzeln gemessen), Hover-Zustände, Fokusring, Text auf Bildern, Symbole ohne Text (Rahmen- und Symbolkontrast ≥ 3:1).

## Blob über Menü und Toast (Aufgabe 4, ALFA Mail hell)
Blob 56 × 40 bei (16, 48) im Bild. Menü bei Überlappung gesetzt (Menü 4 unter der Blobkante, 40 links): `elementFromPoint` in der Blobmitte liefert `blob-face` (Blob liegt oben), z: Blob 6, Menü 5. Der Toast sitzt unten in der rechten Bahn (886, 1333) und überlappt den Blob in der Ruhelage nicht; gemessen nur diese Lage, nicht „Blob seitlich gedockt“.
